#!/usr/bin/env python3
"""
Assign Ad IDs to GHL opportunities - IMPROVED VERSION
======================================================

This improved version includes:
1. Fuzzy matching for ad names (handles typos and variations)
2. Better normalization of campaign and ad names
3. Multiple fallback strategies
4. Detailed reporting of why opportunities couldn't be matched

Strategy:
1. Priority 1: Use existing h_ad_id if available
2. Priority 2: Match by Campaign ID + Ad Name (exact)
3. Priority 3: Match by Campaign ID + Ad Name (fuzzy)
4. Priority 4: Match by Campaign ID only (first ad)
5. Priority 5: Match by Ad Name only (fuzzy, if unique enough)

Author: MedWave Development Team
Date: November 11, 2025
"""

import firebase_admin
from firebase_admin import credentials, firestore
import requests
import os
from collections import defaultdict
from datetime import datetime
import json
from difflib import SequenceMatcher

print("🔧 Assigning Ad IDs to Opportunities (IMPROVED)...", flush=True)
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

# Fuzzy matching threshold (0.0 to 1.0, higher = more strict)
FUZZY_MATCH_THRESHOLD = 0.85


def normalize_name(name):
    """Normalize name for better matching"""
    if not name:
        return ''
    
    # Convert to lowercase
    name = name.lower().strip()
    
    # Remove common variations
    name = name.replace('|', ' ')
    name = name.replace('  ', ' ')
    name = name.replace('(ddm)', '')
    name = name.replace('- ddm', '')
    name = name.replace('ddm', '')
    name = name.strip()
    
    return name


def fuzzy_match_score(str1, str2):
    """Calculate similarity score between two strings (0.0 to 1.0)"""
    if not str1 or not str2:
        return 0.0
    
    # Normalize both strings
    s1 = normalize_name(str1)
    s2 = normalize_name(str2)
    
    # Use SequenceMatcher for fuzzy matching
    return SequenceMatcher(None, s1, s2).ratio()


def fetch_opportunities_from_ghl():
    """Fetch all opportunities from GHL API"""
    print("\n📊 Fetching opportunities from GHL API...", flush=True)
    
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
            response = requests.get(url, headers=headers, params=params, timeout=30)
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
            print(f"   ⚠️  Error fetching page {page}: {e}", flush=True)
            break
    
    # Filter to Andries & Davide pipelines
    filtered = [
        opp for opp in all_opportunities 
        if opp.get('pipelineId') in [ANDRIES_PIPELINE_ID, DAVIDE_PIPELINE_ID]
    ]
    
    print(f"   ✅ Total opportunities: {len(all_opportunities)}", flush=True)
    print(f"   ✅ Andries & Davide: {len(filtered)}", flush=True)
    
    return filtered


def load_ads_from_firebase():
    """Load all ads from Firebase and build lookup structures"""
    print("\n📊 Loading ads from Firebase...", flush=True)
    
    ad_map = {}  # ad_id -> ad_data
    campaign_and_name_to_ad = {}  # (campaign_id, ad_name_normalized) -> ad_id
    campaign_to_ads = defaultdict(list)  # campaign_id -> [ad_ids]
    ad_name_to_ads = defaultdict(list)  # ad_name_normalized -> [(ad_id, campaign_id, ad_name)]
    
    # Get all months
    months = list(db.collection('advertData').stream())
    
    total_ads = 0
    for month_doc in months:
        month_id = month_doc.id
        
        # Skip if not a valid month format
        if '-' not in month_id:
            continue
        
        # Get all ads in this month
        ads_ref = db.collection('advertData').document(month_id).collection('ads')
        ads = list(ads_ref.stream())
        
        for ad_doc in ads:
            ad_id = ad_doc.id
            ad_data = ad_doc.to_dict()
            
            campaign_id = ad_data.get('campaignId')
            ad_name = ad_data.get('adName', '')
            campaign_name = ad_data.get('campaignName', '')
            
            # Store in ad_map
            ad_map[ad_id] = {
                'ad_id': ad_id,
                'ad_name': ad_name,
                'campaign_id': campaign_id,
                'campaign_name': campaign_name,
                'adset_id': ad_data.get('adsetId'),
                'adset_name': ad_data.get('adsetName')
            }
            
            # Build lookup by (campaign_id, ad_name)
            if campaign_id and ad_name:
                ad_name_normalized = normalize_name(ad_name)
                key = (campaign_id, ad_name_normalized)
                
                # Only store if not already there (first one wins)
                if key not in campaign_and_name_to_ad:
                    campaign_and_name_to_ad[key] = ad_id
            
            # Build lookup by campaign_id
            if campaign_id:
                campaign_to_ads[campaign_id].append(ad_id)
            
            # Build lookup by ad_name
            if ad_name:
                ad_name_normalized = normalize_name(ad_name)
                ad_name_to_ads[ad_name_normalized].append((ad_id, campaign_id, ad_name))
            
            total_ads += 1
    
    print(f"   ✅ Loaded {total_ads} ads", flush=True)
    print(f"   ✅ Unique (campaign, ad name) combinations: {len(campaign_and_name_to_ad)}", flush=True)
    print(f"   ✅ Unique campaigns: {len(campaign_to_ads)}", flush=True)
    print(f"   ✅ Unique ad names: {len(ad_name_to_ads)}", flush=True)
    
    return ad_map, campaign_and_name_to_ad, campaign_to_ads, ad_name_to_ads


def extract_h_ad_id_from_attributions(opp):
    """Extract h_ad_id from opportunity attributions"""
    attributions = opp.get('attributions', [])
    
    if not attributions:
        return None
    
    # Check in reverse order (most recent first)
    for attr in reversed(attributions):
        h_ad_id = attr.get('h_ad_id') or attr.get('utmAdId') or attr.get('adId')
        if h_ad_id:
            return h_ad_id
    
    return None


def extract_utm_data(opp):
    """Extract all UTM data from opportunity"""
    attributions = opp.get('attributions', [])
    
    if not attributions:
        return {}
    
    # Extract UTM data from all attributions (check in reverse order)
    # Take the first non-empty value for each field
    utm_data = {
        'campaign_id': '',
        'campaign_name': '',
        'ad_name': '',
        'adset_name': ''
    }
    
    for attr in reversed(attributions):
        if not utm_data['campaign_id']:
            utm_data['campaign_id'] = attr.get('utmCampaignId', '').strip()
        if not utm_data['campaign_name']:
            utm_data['campaign_name'] = attr.get('utmSource', '').strip()
        if not utm_data['ad_name']:
            utm_data['ad_name'] = attr.get('utmCampaign', '').strip()
        if not utm_data['adset_name']:
            utm_data['adset_name'] = attr.get('utmMedium', '').strip()
    
    return utm_data


def find_best_ad_match(utm_data, ad_map, campaign_and_name_to_ad, campaign_to_ads, ad_name_to_ads):
    """
    Find the best matching ad using multiple strategies
    
    Returns: (ad_id, method, confidence_score)
    """
    campaign_id = utm_data.get('campaign_id', '')
    ad_name = utm_data.get('ad_name', '')
    
    # Strategy 1: Exact match by Campaign ID + Ad Name
    if campaign_id and ad_name:
        ad_name_normalized = normalize_name(ad_name)
        key = (campaign_id, ad_name_normalized)
        
        if key in campaign_and_name_to_ad:
            ad_id = campaign_and_name_to_ad[key]
            return (ad_id, 'campaign_id_and_ad_name_exact', 1.0)
    
    # Strategy 2: Fuzzy match by Campaign ID + Ad Name
    if campaign_id and ad_name and campaign_id in campaign_to_ads:
        ad_name_normalized = normalize_name(ad_name)
        
        best_match = None
        best_score = 0.0
        
        # Check all ads in this campaign
        for ad_id in campaign_to_ads[campaign_id]:
            ad_data = ad_map.get(ad_id)
            if ad_data:
                fb_ad_name = ad_data.get('ad_name', '')
                score = fuzzy_match_score(ad_name, fb_ad_name)
                
                if score > best_score and score >= FUZZY_MATCH_THRESHOLD:
                    best_score = score
                    best_match = ad_id
        
        if best_match:
            return (best_match, 'campaign_id_and_ad_name_fuzzy', best_score)
    
    # Strategy 3: Campaign ID only (first ad in campaign)
    if campaign_id and campaign_id in campaign_to_ads:
        ads = campaign_to_ads[campaign_id]
        if ads:
            return (ads[0], 'campaign_id_only', 0.7)
    
    # Strategy 4: Ad Name only (fuzzy match, but only if confidence is high)
    if ad_name:
        ad_name_normalized = normalize_name(ad_name)
        
        best_match = None
        best_score = 0.0
        best_campaign_id = None
        
        # Check all ads with similar names
        for norm_name, ad_list in ad_name_to_ads.items():
            score = fuzzy_match_score(ad_name, norm_name)
            
            if score > best_score and score >= 0.9:  # Higher threshold for name-only match
                # If multiple ads have this name, skip (ambiguous)
                if len(ad_list) == 1:
                    best_score = score
                    best_match = ad_list[0][0]  # ad_id
                    best_campaign_id = ad_list[0][1]  # campaign_id
        
        if best_match:
            return (best_match, 'ad_name_only_fuzzy', best_score)
    
    return (None, 'no_match', 0.0)


def process_opportunities_and_assign_ad_ids(opportunities, ad_map, campaign_and_name_to_ad, campaign_to_ads, ad_name_to_ads):
    """Process all opportunities and assign Ad IDs"""
    
    print("\n" + "=" * 80, flush=True)
    print("PROCESSING OPPORTUNITIES", flush=True)
    print("=" * 80, flush=True)
    print(flush=True)
    
    stats = {
        'total': len(opportunities),
        'with_h_ad_id': 0,
        'assigned_exact': 0,
        'assigned_fuzzy': 0,
        'assigned_campaign_only': 0,
        'assigned_name_only': 0,
        'unassigned': 0,
        'unassigned_reasons': defaultdict(int)
    }
    
    mappings = []
    unmatched_details = []
    
    for i, opp in enumerate(opportunities, 1):
        opp_id = opp.get('id')
        opp_name = opp.get('contact', {}).get('name', 'Unknown')
        
        if i % 100 == 0:
            print(f"   Processing {i}/{len(opportunities)}...", flush=True)
        
        # Check for existing h_ad_id
        h_ad_id = extract_h_ad_id_from_attributions(opp)
        
        if h_ad_id and h_ad_id in ad_map:
            # Already has Ad ID
            stats['with_h_ad_id'] += 1
            
            mappings.append({
                'opportunity_id': opp_id,
                'opportunity_name': opp_name,
                'assigned_ad_id': h_ad_id,
                'assignment_method': 'original_h_ad_id',
                'confidence': 1.0,
                'created_at': opp.get('createdAt'),
                'pipeline_id': opp.get('pipelineId'),
                'stage': opp.get('pipelineStageName', 'Unknown'),
                'monetary_value': opp.get('monetaryValue', 0)
            })
            continue
        
        # Extract UTM data
        utm_data = extract_utm_data(opp)
        
        # Try to find best match
        ad_id, method, confidence = find_best_ad_match(
            utm_data, ad_map, campaign_and_name_to_ad, campaign_to_ads, ad_name_to_ads
        )
        
        if ad_id:
            # Successfully assigned
            ad_data = ad_map.get(ad_id, {})
            
            mappings.append({
                'opportunity_id': opp_id,
                'opportunity_name': opp_name,
                'assigned_ad_id': ad_id,
                'assignment_method': method,
                'confidence': confidence,
                'campaign_id': utm_data.get('campaign_id'),
                'campaign_name': ad_data.get('campaign_name'),
                'ad_name': ad_data.get('ad_name'),
                'ghl_ad_name': utm_data.get('ad_name'),
                'created_at': opp.get('createdAt'),
                'pipeline_id': opp.get('pipelineId'),
                'stage': opp.get('pipelineStageName', 'Unknown'),
                'monetary_value': opp.get('monetaryValue', 0)
            })
            
            # Update stats
            if 'exact' in method:
                stats['assigned_exact'] += 1
            elif 'fuzzy' in method:
                stats['assigned_fuzzy'] += 1
            elif 'campaign_id_only' in method:
                stats['assigned_campaign_only'] += 1
            elif 'name_only' in method:
                stats['assigned_name_only'] += 1
        else:
            # Could not assign
            stats['unassigned'] += 1
            
            # Determine reason
            if not utm_data.get('campaign_id') and not utm_data.get('ad_name'):
                reason = 'no_utm_data'
            elif utm_data.get('campaign_id') and not utm_data.get('ad_name'):
                reason = 'no_ad_name'
            elif not utm_data.get('campaign_id') and utm_data.get('ad_name'):
                reason = 'no_campaign_id'
            else:
                reason = 'no_matching_ad_found'
            
            stats['unassigned_reasons'][reason] += 1
            
            unmatched_details.append({
                'opportunity_id': opp_id,
                'opportunity_name': opp_name,
                'reason': reason,
                'utm_data': utm_data,
                'created_at': opp.get('createdAt'),
                'pipeline_id': opp.get('pipelineId')
            })
    
    return mappings, stats, unmatched_details


def save_mappings_to_firebase(mappings):
    """Save opportunity -> ad_id mappings to Firebase"""
    
    print("\n" + "=" * 80, flush=True)
    print("SAVING MAPPINGS TO FIREBASE", flush=True)
    print("=" * 80, flush=True)
    print(flush=True)
    
    mapping_ref = db.collection('ghlOpportunityMapping')
    
    batch_size = 500
    saved_count = 0
    
    for i in range(0, len(mappings), batch_size):
        batch = db.batch()
        batch_mappings = mappings[i:i + batch_size]
        
        for mapping in batch_mappings:
            doc_ref = mapping_ref.document(mapping['opportunity_id'])
            batch.set(doc_ref, {
                **mapping,
                'assigned_at': firestore.SERVER_TIMESTAMP
            })
        
        batch.commit()
        saved_count += len(batch_mappings)
        print(f"   Saved {saved_count}/{len(mappings)} mappings...", flush=True)
    
    print(f"✅ Saved {saved_count} mappings to Firebase", flush=True)


def main():
    """Main execution function"""
    
    print("\n" + "=" * 80, flush=True)
    print("ASSIGN AD IDS TO OPPORTUNITIES - IMPROVED VERSION", flush=True)
    print("=" * 80, flush=True)
    print(flush=True)
    
    # Step 1: Fetch opportunities
    opportunities = fetch_opportunities_from_ghl()
    
    if not opportunities:
        print("\n❌ No opportunities found!", flush=True)
        return
    
    # Step 2: Load ads from Firebase
    ad_map, campaign_and_name_to_ad, campaign_to_ads, ad_name_to_ads = load_ads_from_firebase()
    
    # Step 3: Process and assign
    mappings, stats, unmatched_details = process_opportunities_and_assign_ad_ids(
        opportunities, ad_map, campaign_and_name_to_ad, campaign_to_ads, ad_name_to_ads
    )
    
    # Step 4: Display results
    print("\n" + "=" * 80, flush=True)
    print("RESULTS SUMMARY", flush=True)
    print("=" * 80, flush=True)
    print(flush=True)
    
    total_assigned = stats['with_h_ad_id'] + stats['assigned_exact'] + stats['assigned_fuzzy'] + stats['assigned_campaign_only'] + stats['assigned_name_only']
    
    print(f"📊 Total Opportunities: {stats['total']}", flush=True)
    print(f"   ✅ Successfully Assigned: {total_assigned} ({total_assigned/stats['total']*100:.1f}%)", flush=True)
    print(f"   ❌ Unassigned: {stats['unassigned']} ({stats['unassigned']/stats['total']*100:.1f}%)", flush=True)
    print(flush=True)
    
    print(f"📊 Assignment Methods:", flush=True)
    print(f"   Original h_ad_id: {stats['with_h_ad_id']} ({stats['with_h_ad_id']/stats['total']*100:.1f}%)", flush=True)
    print(f"   Campaign + Name (Exact): {stats['assigned_exact']} ({stats['assigned_exact']/stats['total']*100:.1f}%)", flush=True)
    print(f"   Campaign + Name (Fuzzy): {stats['assigned_fuzzy']} ({stats['assigned_fuzzy']/stats['total']*100:.1f}%)", flush=True)
    print(f"   Campaign Only: {stats['assigned_campaign_only']} ({stats['assigned_campaign_only']/stats['total']*100:.1f}%)", flush=True)
    print(f"   Name Only (Fuzzy): {stats['assigned_name_only']} ({stats['assigned_name_only']/stats['total']*100:.1f}%)", flush=True)
    print(flush=True)
    
    if stats['unassigned'] > 0:
        print(f"❓ Unassigned Reasons:", flush=True)
        for reason, count in sorted(stats['unassigned_reasons'].items(), key=lambda x: x[1], reverse=True):
            print(f"   {reason}: {count} ({count/stats['unassigned']*100:.1f}%)", flush=True)
        print(flush=True)
    
    # Step 5: Save to Firebase
    if mappings:
        save_mappings_to_firebase(mappings)
    
    # Step 6: Save detailed report
    output_file = f"ad_assignment_report_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
    with open(output_file, 'w') as f:
        json.dump({
            'summary': stats,
            'total_assigned': total_assigned,
            'mappings_count': len(mappings),
            'unmatched_count': len(unmatched_details),
            'unmatched_sample': unmatched_details[:50]  # First 50 unmatched
        }, f, indent=2, default=str)
    
    print(f"\n📄 Detailed report saved to: {output_file}", flush=True)
    print(flush=True)
    
    print("=" * 80, flush=True)
    print("✅ ASSIGNMENT COMPLETE!", flush=True)
    print("=" * 80, flush=True)
    print(flush=True)


if __name__ == "__main__":
    main()

