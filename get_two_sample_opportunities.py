#!/usr/bin/env python3
"""
Get 2 sample opportunities - one with h_ad_id and one without
"""

import requests
import os
import json
from datetime import datetime

# GHL Configuration
GHL_API_KEY = os.environ.get('GHL_API_KEY', 'pit-22f8af95-3244-41e7-9a52-22c87b166f5a')
GHL_LOCATION_ID = 'QdLXaFEqrdF0JbVbpKLw'
ANDRIES_PIPELINE_ID = 'XeAGJWRnUGJ5tuhXam2g'
DAVIDE_PIPELINE_ID = 'AUduOJBB2lxlsEaNmlJz'

def extract_attribution_fields(attributions):
    """Extract all possible ID fields from attributions"""
    result = {
        'h_ad_id': None,
        'utmAdId': None,
        'adId': None,
        'utmCampaignId': None,
        'fbc_id': None,
    }
    
    for attr in reversed(attributions):
        if not result['h_ad_id']:
            result['h_ad_id'] = attr.get('h_ad_id')
        if not result['utmAdId']:
            result['utmAdId'] = attr.get('utmAdId')
        if not result['adId']:
            result['adId'] = attr.get('adId')
        if not result['utmCampaignId']:
            result['utmCampaignId'] = attr.get('utmCampaignId')
        if not result['fbc_id']:
            result['fbc_id'] = attr.get('fbc_id')
    
    return result

def fetch_opportunities():
    """Fetch opportunities from GHL API"""
    url = 'https://services.leadconnectorhq.com/opportunities/search'
    headers = {
        'Authorization': f'Bearer {GHL_API_KEY}',
        'Version': '2021-07-28'
    }
    
    all_opportunities = []
    page = 1
    
    print("📊 Fetching opportunities...")
    
    while page <= 70:
        params = {
            'location_id': GHL_LOCATION_ID,
            'limit': 100,
            'page': page
        }
        
        try:
            response = requests.get(url, headers=headers, params=params, timeout=30)
            
            if response.status_code != 200:
                break
            
            data = response.json()
            opportunities = data.get('opportunities', [])
            
            if not opportunities:
                break
            
            all_opportunities.extend(opportunities)
            
            if len(opportunities) < 100:
                break
            
            if page % 10 == 0:
                print(f"   Page {page}... ({len(all_opportunities)} total)")
            
            page += 1
            
        except Exception as e:
            print(f"Error: {e}")
            break
    
    print(f"✅ Fetched {len(all_opportunities)} opportunities\n")
    return all_opportunities

def get_samples():
    """Get 2 sample opportunities"""
    
    print("=" * 80)
    print("GETTING 2 SAMPLE OPPORTUNITIES FOR FORM VERIFICATION")
    print("=" * 80)
    print()
    
    all_opps = fetch_opportunities()
    
    # Filter to Andries & Davide
    filtered_opps = [opp for opp in all_opps 
                     if opp.get('pipelineId') in [ANDRIES_PIPELINE_ID, DAVIDE_PIPELINE_ID]]
    
    print(f"📊 Andries & Davide opportunities: {len(filtered_opps)}\n")
    
    # Find one WITH h_ad_id and one WITHOUT
    sample_with = None
    sample_without = None
    
    for opp in filtered_opps:
        attributions = opp.get('attributions', [])
        fields = extract_attribution_fields(attributions)
        
        has_h_ad_id = bool(fields['h_ad_id'] or fields['utmAdId'] or fields['adId'])
        
        # Get recent opportunities only (October/November 2025)
        created = opp.get('createdAt', '')
        if '2025-10' not in created and '2025-11' not in created:
            continue
        
        if has_h_ad_id and not sample_with:
            sample_with = opp
        elif not has_h_ad_id and not sample_without:
            sample_without = opp
        
        if sample_with and sample_without:
            break
    
    # Display results
    print("=" * 80)
    print("✅ OPPORTUNITY WITH h_ad_id (UTM WORKING)")
    print("=" * 80)
    if sample_with:
        fields = extract_attribution_fields(sample_with.get('attributions', []))
        print(f"Name: {sample_with.get('name')}")
        print(f"Email: {sample_with.get('contact', {}).get('email', 'N/A')}")
        print(f"Phone: {sample_with.get('contact', {}).get('phone', 'N/A')}")
        print(f"Created: {sample_with.get('createdAt')}")
        print()
        print(f"✅ h_ad_id: {fields['h_ad_id']}")
        print(f"✅ utmAdId: {fields['utmAdId']}")
        print(f"✅ adId: {fields['adId']}")
        print(f"   utmCampaignId: {fields['utmCampaignId']}")
        print(f"   fbc_id: {fields['fbc_id']}")
        print()
        print("Full Attributions:")
        print(json.dumps(sample_with.get('attributions', []), indent=2))
    else:
        print("❌ None found")
    
    print()
    print("=" * 80)
    print("❌ OPPORTUNITY WITHOUT h_ad_id (UTM NOT WORKING)")
    print("=" * 80)
    if sample_without:
        fields = extract_attribution_fields(sample_without.get('attributions', []))
        print(f"Name: {sample_without.get('name')}")
        print(f"Email: {sample_without.get('contact', {}).get('email', 'N/A')}")
        print(f"Phone: {sample_without.get('contact', {}).get('phone', 'N/A')}")
        print(f"Created: {sample_without.get('createdAt')}")
        print()
        print(f"❌ h_ad_id: {fields['h_ad_id']}")
        print(f"❌ utmAdId: {fields['utmAdId']}")
        print(f"❌ adId: {fields['adId']}")
        print(f"   utmCampaignId: {fields['utmCampaignId']}")
        print(f"   fbc_id: {fields['fbc_id']}")
        print()
        print("Full Attributions:")
        print(json.dumps(sample_without.get('attributions', []), indent=2))
    else:
        print("❌ None found")
    
    print()
    print("=" * 80)
    print("SUMMARY FOR FORM VERIFICATION")
    print("=" * 80)
    print()
    if sample_with:
        print("✅ CHECK THIS FORM (has UTM working):")
        print(f"   Contact: {sample_with.get('name')} - {sample_with.get('contact', {}).get('email', 'N/A')}")
        print(f"   Created: {sample_with.get('createdAt')}")
    print()
    if sample_without:
        print("❌ CHECK THIS FORM (UTM not working):")
        print(f"   Contact: {sample_without.get('name')} - {sample_without.get('contact', {}).get('email', 'N/A')}")
        print(f"   Created: {sample_without.get('createdAt')}")

if __name__ == "__main__":
    get_samples()

