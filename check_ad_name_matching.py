#!/usr/bin/env python3
"""
Check if we can match GHL opportunities to Facebook ads using ad name and adset name
"""

import firebase_admin
from firebase_admin import credentials, firestore
import requests
import os
from collections import defaultdict

# Initialize Firebase
if not firebase_admin._apps:
    cred = credentials.Certificate('medx-ai-firebase-adminsdk-fbsvc-a86e7bd050.json')
    firebase_admin.initialize_app(cred)

db = firestore.client()

# GHL Configuration
GHL_API_KEY = os.environ.get('GHL_API_KEY', 'pit-22f8af95-3244-41e7-9a52-22c87b166f5a')
GHL_LOCATION_ID = 'QdLXaFEqrdF0JbVbpKLw'
ANDRIES_PIPELINE_ID = 'XeAGJWRnUGJ5tuhXam2g'
DAVIDE_PIPELINE_ID = 'AUduOJBB2lxlsEaNmlJz'

def fetch_sample_opportunities():
    """Fetch first 200 opportunities from GHL"""
    url = 'https://services.leadconnectorhq.com/opportunities/search'
    headers = {
        'Authorization': f'Bearer {GHL_API_KEY}',
        'Version': '2021-07-28'
    }
    
    params = {
        'location_id': GHL_LOCATION_ID,
        'limit': 100,
        'page': 1
    }
    
    opportunities = []
    for page in [1, 2]:
        params['page'] = page
        try:
            response = requests.get(url, headers=headers, params=params, timeout=30)
            if response.status_code == 200:
                data = response.json()
                opportunities.extend(data.get('opportunities', []))
        except Exception as e:
            print(f"Error: {e}")
            break
    
    return opportunities

def load_ads_from_firebase():
    """Load ads from Firebase with their names"""
    print("📱 Loading ads from Firebase...")
    
    ad_map = {}
    name_to_ads = defaultdict(list)  # Map ad name -> list of ad IDs
    adset_name_to_ads = defaultdict(list)  # Map adset name -> list of ad IDs
    combined_to_ads = defaultdict(list)  # Map (campaign+adset+ad name) -> list of ad IDs
    
    months = list(db.collection('advertData').stream())
    for month_doc in months:
        month_id = month_doc.id
        month_data = month_doc.to_dict()
        if 'adId' in month_data:
            continue  # Old structure
        
        ads = list(month_doc.reference.collection('ads').stream())
        for ad in ads:
            ad_data = ad.to_dict()
            ad_id = ad.id
            ad_name = ad_data.get('adName', '').strip()
            adset_name = ad_data.get('adSetName', '').strip()
            campaign_name = ad_data.get('campaignName', '').strip()
            
            ad_map[ad_id] = {
                'month': month_id,
                'ref': ad.reference,
                'ad_name': ad_name,
                'adset_name': adset_name,
                'campaign_name': campaign_name
            }
            
            # Build lookup maps
            if ad_name:
                name_to_ads[ad_name.lower()].append(ad_id)
            if adset_name:
                adset_name_to_ads[adset_name.lower()].append(ad_id)
            
            # Combined key (most specific)
            combined_key = f"{campaign_name}|{adset_name}|{ad_name}".lower()
            combined_to_ads[combined_key].append(ad_id)
    
    print(f"   ✅ Loaded {len(ad_map)} ads")
    print(f"   ✅ {len(name_to_ads)} unique ad names")
    print(f"   ✅ {len(adset_name_to_ads)} unique adset names")
    print(f"   ✅ {len(combined_to_ads)} unique combinations")
    
    return ad_map, name_to_ads, adset_name_to_ads, combined_to_ads

def analyze_matching():
    """Analyze how well we can match using names"""
    
    print("=" * 80)
    print("ANALYZING AD NAME MATCHING POTENTIAL")
    print("=" * 80)
    print()
    
    # Load Firebase ads
    ad_map, name_to_ads, adset_name_to_ads, combined_to_ads = load_ads_from_firebase()
    
    # Fetch GHL opportunities
    print("\n📊 Fetching sample opportunities from GHL...")
    opportunities = fetch_sample_opportunities()
    
    # Filter to Andries & Davide
    filtered_opps = [opp for opp in opportunities 
                     if opp.get('pipelineId') in [ANDRIES_PIPELINE_ID, DAVIDE_PIPELINE_ID]]
    
    print(f"   ✅ Got {len(filtered_opps)} Andries & Davide opportunities")
    print()
    
    # Try matching strategies
    matched_by_ad_id = 0
    matched_by_campaign_id = 0
    matched_by_ad_name = 0
    matched_by_adset_name = 0
    matched_by_combined = 0
    matched_by_campaign_adset = 0
    unmatched = 0
    
    match_details = []
    
    for opp in filtered_opps:
        attributions = opp.get('attributions', [])
        
        # Extract fields
        utm_ad_id = None
        utm_campaign_id = None
        utm_campaign = None
        utm_medium = None
        
        for attr in reversed(attributions):
            if not utm_ad_id:
                utm_ad_id = attr.get('h_ad_id') or attr.get('utmAdId') or attr.get('adId')
            if not utm_campaign_id:
                utm_campaign_id = attr.get('utmCampaignId')
            if not utm_campaign:
                utm_campaign = attr.get('utmCampaign')
            if not utm_medium:
                utm_medium = attr.get('utmMedium')
        
        matched = False
        match_method = None
        matched_ad_ids = []
        
        # Strategy 1: Direct ad ID match
        if utm_ad_id and utm_ad_id in ad_map:
            matched_by_ad_id += 1
            matched = True
            match_method = "ad_id"
            matched_ad_ids = [utm_ad_id]
        
        # Strategy 2: Campaign ID match
        elif utm_campaign_id and utm_campaign_id in ad_map:
            matched_by_campaign_id += 1
            matched = True
            match_method = "campaign_id"
            matched_ad_ids = [utm_campaign_id]
        
        # Strategy 3: Ad name match (utm_campaign = ad name)
        elif utm_campaign:
            ad_name_lower = utm_campaign.lower().strip()
            if ad_name_lower in name_to_ads:
                matched_by_ad_name += 1
                matched = True
                match_method = "ad_name"
                matched_ad_ids = name_to_ads[ad_name_lower]
        
        # Strategy 4: Combined match (campaign + adset + ad name)
        if not matched and utm_campaign and utm_medium:
            # We don't have campaign name in GHL, but we can try adset + ad name
            for combined_key, ad_ids in combined_to_ads.items():
                parts = combined_key.split('|')
                if len(parts) == 3:
                    _, adset, ad = parts
                    if utm_medium.lower().strip() in adset and utm_campaign.lower().strip() in ad:
                        matched_by_combined += 1
                        matched = True
                        match_method = "combined"
                        matched_ad_ids = ad_ids
                        break
        
        # Strategy 5: Just adset name
        if not matched and utm_medium:
            adset_lower = utm_medium.lower().strip()
            if adset_lower in adset_name_to_ads:
                matched_by_adset_name += 1
                matched = True
                match_method = "adset_name"
                matched_ad_ids = adset_name_to_ads[adset_lower]
        
        if not matched:
            unmatched += 1
            match_details.append({
                'name': opp.get('name'),
                'utm_campaign': utm_campaign,
                'utm_medium': utm_medium,
                'utm_campaign_id': utm_campaign_id,
                'matched': False
            })
        else:
            match_details.append({
                'name': opp.get('name'),
                'utm_campaign': utm_campaign,
                'utm_medium': utm_medium,
                'matched': True,
                'method': match_method,
                'ad_count': len(matched_ad_ids)
            })
    
    # Results
    print("=" * 80)
    print("MATCHING RESULTS")
    print("=" * 80)
    print(f"Total opportunities analyzed: {len(filtered_opps)}")
    print()
    print(f"✅ Matched by ad ID: {matched_by_ad_id}")
    print(f"✅ Matched by campaign ID: {matched_by_campaign_id}")
    print(f"✅ Matched by ad name: {matched_by_ad_name}")
    print(f"✅ Matched by adset name: {matched_by_adset_name}")
    print(f"✅ Matched by combined: {matched_by_combined}")
    print(f"❌ Unmatched: {unmatched}")
    print()
    
    total_matched = matched_by_ad_id + matched_by_campaign_id + matched_by_ad_name + matched_by_adset_name + matched_by_combined
    coverage = (total_matched / len(filtered_opps) * 100) if filtered_opps else 0
    print(f"📊 Total Coverage: {total_matched}/{len(filtered_opps)} ({coverage:.1f}%)")
    print()
    
    # Show samples
    print("=" * 80)
    print("SAMPLE MATCHES")
    print("=" * 80)
    for detail in match_details[:10]:
        if detail['matched']:
            print(f"✅ {detail['name']}")
            print(f"   Method: {detail['method']}")
            print(f"   Ad Name: {detail['utm_campaign']}")
            print(f"   AdSet: {detail['utm_medium']}")
            print(f"   Matched to {detail['ad_count']} ad(s)")
        else:
            print(f"❌ {detail['name']}")
            print(f"   Ad Name: {detail['utm_campaign']}")
            print(f"   AdSet: {detail['utm_medium']}")
            print(f"   Campaign ID: {detail['utm_campaign_id']}")
        print()

if __name__ == "__main__":
    analyze_matching()

