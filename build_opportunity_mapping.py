#!/usr/bin/env python3
"""
Build GHL Opportunity -> Ad IDs mapping to prevent cross-campaign duplicates

This script:
1. Fetches all opportunities from GHL API
2. Matches each opportunity to Facebook ads using multi-level strategy
3. Stores the mapping in Firebase (ghlOpportunityMapping collection)
4. This mapping will be used by populate_ghl_data.py to prevent duplicates
"""

import firebase_admin
from firebase_admin import credentials, firestore
import requests
import os
from collections import defaultdict
from datetime import datetime

print("🔧 Building GHL Opportunity -> Ad IDs Mapping...", flush=True)
print("📦 Initializing Firebase...", flush=True)

# Initialize Firebase
if not firebase_admin._apps:
    cred = credentials.Certificate('medx-ai-firebase-adminsdk-fbsvc-a86e7bd050.json')
    firebase_admin.initialize_app(cred)

db = firestore.client()
print("✅ Firebase initialized", flush=True)

# GHL Configuration
GHL_API_KEY = os.environ.get('GHL_API_KEY', 'pit-22f8af95-3244-41e7-9a52-22c87b166f5a')
GHL_LOCATION_ID = 'QdLXaFEqrdF0JbVbpKLw'
ANDRIES_PIPELINE_ID = 'XeAGJWRnUGJ5tuhXam2g'
DAVIDE_PIPELINE_ID = 'AUduOJBB2lxlsEaNmlJz'

def fetch_opportunities_from_ghl():
    """Fetch all opportunities from GHL API"""
    print("\n📊 Fetching opportunities from GHL API...")
    
    url = 'https://services.leadconnectorhq.com/opportunities/search'
    headers = {
        'Authorization': f'Bearer {GHL_API_KEY}',
        'Version': '2021-07-28'
    }
    
    all_opportunities = []
    page = 1
    
    while True:
        params = {
            'location_id': GHL_LOCATION_ID,
            'limit': 100,
            'page': page
        }
        
        try:
            response = requests.get(url, headers=headers, params=params)
            response.raise_for_status()
            data = response.json()
            
            opportunities = data.get('opportunities', [])
            if not opportunities:
                break
            
            all_opportunities.extend(opportunities)
            print(f"   Page {page}: {len(opportunities)} opportunities (Total: {len(all_opportunities)})", flush=True)
            
            if len(opportunities) < 100:
                break
            
            page += 1
            
        except Exception as e:
            print(f"   ⚠️  Error fetching page {page}: {e}")
            break
    
    # Filter to Andries & Davide pipelines
    filtered = [
        opp for opp in all_opportunities 
        if opp.get('pipelineId') in [ANDRIES_PIPELINE_ID, DAVIDE_PIPELINE_ID]
    ]
    
    print(f"   ✅ Total opportunities: {len(all_opportunities)}")
    print(f"   ✅ Andries & Davide: {len(filtered)}")
    
    return filtered

def load_ads_from_firebase():
    """Load all ads from Firebase advertData collection"""
    print("\n📊 Loading ads from Firebase...")
    
    ad_map = {}
    campaign_to_ads = defaultdict(list)
    ad_name_to_ads = defaultdict(list)
    adset_name_to_ads = defaultdict(list)
    
    months = list(db.collection('advertData').stream())
    
    for month_doc in months:
        month_id = month_doc.id
        month_data = month_doc.to_dict()
        
        # Skip old structure documents
        if 'adId' in month_data:
            continue
        
        # Get all ads in this month
        ads = list(month_doc.reference.collection('ads').stream())
        for ad in ads:
            ad_data = ad.to_dict()
            campaign_id = ad_data.get('campaignId', '')
            ad_name = ad_data.get('adName', '').strip()
            adset_name = ad_data.get('adSetName', '').strip()
            
            ad_map[ad.id] = {
                'month': month_id,
                'ref': ad.reference,
                'campaign_id': campaign_id,
                'ad_name': ad_name,
                'adset_name': adset_name
            }
            
            # Build lookup maps (case-insensitive)
            if campaign_id:
                campaign_to_ads[campaign_id].append(ad.id)
            if ad_name:
                ad_name_to_ads[ad_name.lower()].append(ad.id)
            if adset_name:
                adset_name_to_ads[adset_name.lower()].append(ad.id)
    
    ad_ids = set(ad_map.keys())
    print(f'   ✅ Found {len(ad_ids)} ads across {len(months)} months')
    print(f'   ✅ Found {len(campaign_to_ads)} unique campaigns')
    print(f'   ✅ Found {len(ad_name_to_ads)} unique ad names')
    print(f'   ✅ Found {len(adset_name_to_ads)} unique adset names')
    
    return ad_map, ad_ids, campaign_to_ads, ad_name_to_ads, adset_name_to_ads

def extract_h_ad_id_from_attributions(opportunity):
    """Extract h_ad_id from opportunity attributions"""
    attributions = opportunity.get('attributions', [])
    
    # Check most recent attribution first (last in list)
    for attr in reversed(attributions):
        # Try different field names
        ad_id = attr.get('h_ad_id') or attr.get('utmAdId') or attr.get('adId')
        if ad_id:
            return ad_id.strip()
    
    return None

def match_opportunity_to_ads(opportunity, ad_ids, campaign_to_ads, ad_name_to_ads, adset_name_to_ads):
    """
    Match opportunity to ads using 4-tier strategy
    Returns: (matched_ad_ids[], match_method)
    """
    attributions = opportunity.get('attributions', [])
    
    # TIER 1: Try Ad ID (most specific)
    identifier = extract_h_ad_id_from_attributions(opportunity)
    if identifier and identifier in ad_ids:
        return [identifier], 'ad_id'
    
    # TIER 2: Try Campaign ID
    for attr in reversed(attributions):
        campaign_id = attr.get('utmCampaignId', '').strip()
        if campaign_id and campaign_id in campaign_to_ads:
            return campaign_to_ads[campaign_id], 'campaign_id'
    
    # TIER 3: Try Ad Name
    for attr in reversed(attributions):
        utm_campaign = attr.get('utmCampaign', '').strip()
        if utm_campaign and utm_campaign.lower() in ad_name_to_ads:
            return ad_name_to_ads[utm_campaign.lower()], 'ad_name'
    
    # TIER 4: Try AdSet Name
    for attr in reversed(attributions):
        utm_medium = attr.get('utmMedium', '').strip()
        if utm_medium and utm_medium.lower() in adset_name_to_ads:
            return adset_name_to_ads[utm_medium.lower()], 'adset_name'
    
    return [], 'unmatched'

def build_and_store_mapping():
    """Main function to build and store the mapping"""
    
    print("\n" + "="*80)
    print("BUILDING GHL OPPORTUNITY -> AD IDS MAPPING")
    print("="*80)
    
    # Step 1: Load ads from Firebase
    ad_map, ad_ids, campaign_to_ads, ad_name_to_ads, adset_name_to_ads = load_ads_from_firebase()
    
    # Step 2: Fetch opportunities from GHL
    opportunities = fetch_opportunities_from_ghl()
    
    # Step 3: Match each opportunity to ads
    print("\n📊 Matching opportunities to ads...")
    
    mapping = {}
    match_stats = {
        'ad_id': 0,
        'campaign_id': 0,
        'ad_name': 0,
        'adset_name': 0,
        'unmatched': 0
    }
    
    for opp in opportunities:
        opp_id = opp['id']
        matched_ad_ids, match_method = match_opportunity_to_ads(
            opp, ad_ids, campaign_to_ads, ad_name_to_ads, adset_name_to_ads
        )
        
        if matched_ad_ids:
            mapping[opp_id] = {
                'opportunity_id': opp_id,
                'matched_ad_ids': matched_ad_ids,
                'match_method': match_method,
                'campaign_id': opp.get('pipelineId'),
                'stage': opp.get('pipelineStageName'),
                'monetary_value': opp.get('monetaryValue', 0),
                'created_at': opp.get('createdAt'),
                'updated_at': datetime.now().isoformat()
            }
            match_stats[match_method] += 1
        else:
            match_stats['unmatched'] += 1
    
    print(f"\n   ✅ Matched: {len(mapping)} opportunities")
    print(f"      - By Ad ID: {match_stats['ad_id']}")
    print(f"      - By Campaign ID: {match_stats['campaign_id']}")
    print(f"      - By Ad Name: {match_stats['ad_name']}")
    print(f"      - By AdSet Name: {match_stats['adset_name']}")
    print(f"   ⚠️  Unmatched: {match_stats['unmatched']} opportunities")
    
    # Step 4: Store mapping in Firebase
    print("\n📊 Storing mapping in Firebase...")
    
    mapping_ref = db.collection('ghlOpportunityMapping')
    
    # Use batch writes for efficiency
    batch = db.batch()
    batch_count = 0
    total_written = 0
    
    for opp_id, mapping_data in mapping.items():
        doc_ref = mapping_ref.document(opp_id)
        batch.set(doc_ref, mapping_data, merge=True)
        batch_count += 1
        
        # Commit batch every 500 documents
        if batch_count >= 500:
            batch.commit()
            total_written += batch_count
            print(f"   ✅ Written {total_written} mappings...", flush=True)
            batch = db.batch()
            batch_count = 0
    
    # Commit remaining documents
    if batch_count > 0:
        batch.commit()
        total_written += batch_count
    
    print(f"   ✅ Total mappings written: {total_written}")
    
    # Step 5: Generate summary report
    print("\n" + "="*80)
    print("MAPPING SUMMARY")
    print("="*80)
    
    print(f"\n📊 Total opportunities processed: {len(opportunities)}")
    print(f"   ✅ Mapped: {len(mapping)} ({len(mapping)/len(opportunities)*100:.1f}%)")
    print(f"   ❌ Unmapped: {match_stats['unmatched']} ({match_stats['unmatched']/len(opportunities)*100:.1f}%)")
    
    print(f"\n📊 Matching Methods:")
    print(f"   Tier 1 (Ad ID): {match_stats['ad_id']} ({match_stats['ad_id']/len(mapping)*100:.1f}% of mapped)")
    print(f"   Tier 2 (Campaign ID): {match_stats['campaign_id']} ({match_stats['campaign_id']/len(mapping)*100:.1f}% of mapped)")
    print(f"   Tier 3 (Ad Name): {match_stats['ad_name']} ({match_stats['ad_name']/len(mapping)*100:.1f}% of mapped)")
    print(f"   Tier 4 (AdSet Name): {match_stats['adset_name']} ({match_stats['adset_name']/len(mapping)*100:.1f}% of mapped)")
    
    # Analyze multi-ad mappings
    single_ad = sum(1 for m in mapping.values() if len(m['matched_ad_ids']) == 1)
    multi_ad = sum(1 for m in mapping.values() if len(m['matched_ad_ids']) > 1)
    
    print(f"\n📊 Ad Distribution:")
    print(f"   Single Ad: {single_ad} opportunities ({single_ad/len(mapping)*100:.1f}%)")
    print(f"   Multiple Ads: {multi_ad} opportunities ({multi_ad/len(mapping)*100:.1f}%)")
    
    if multi_ad > 0:
        max_ads = max(len(m['matched_ad_ids']) for m in mapping.values())
        avg_ads = sum(len(m['matched_ad_ids']) for m in mapping.values()) / len(mapping)
        print(f"   Average ads per opportunity: {avg_ads:.1f}")
        print(f"   Max ads for single opportunity: {max_ads}")
    
    print(f"\n✅ Mapping stored in Firebase collection: ghlOpportunityMapping")
    print(f"   Use this mapping in populate_ghl_data.py to prevent duplicates")
    print()

if __name__ == '__main__':
    build_and_store_mapping()

