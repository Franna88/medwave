#!/usr/bin/env python3
"""
Compare matched vs unmatched opportunities to see when the h_ad_id stopped being passed
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

# Deposit/Cash stage IDs
ANDRIES_DEPOSIT_STAGE = "52a076ca-851f-43fc-a57d-309403a4b208"
ANDRIES_CASH_STAGE = "3a8ead84-92b0-4796-aaf8-6594c3217a2c"
DAVIDE_DEPOSIT_STAGE = "13d54d18-d1e7-476b-aad8-cb4767b8b979"
DAVIDE_CASH_STAGE = "3c89afba-9797-4b0f-947c-ba00b60468c6"

def extract_attribution_fields(attributions):
    """Extract all possible ID fields from attributions"""
    result = {
        'h_ad_id': None,
        'utmAdId': None,
        'adId': None,
        'utmCampaignId': None,
        'fbc_id': None,
        'all_fields': []
    }
    
    for attr in reversed(attributions):
        result['all_fields'].append(list(attr.keys()))
        
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

def analyze():
    """Analyze when h_ad_id stopped being passed"""
    
    print("=" * 80)
    print("COMPARING MATCHED VS UNMATCHED OPPORTUNITIES")
    print("=" * 80)
    print()
    
    all_opps = fetch_opportunities()
    
    # Filter to Andries & Davide
    filtered_opps = [opp for opp in all_opps 
                     if opp.get('pipelineId') in [ANDRIES_PIPELINE_ID, DAVIDE_PIPELINE_ID]]
    
    print(f"📊 Andries & Davide opportunities: {len(filtered_opps)}\n")
    
    # Categorize opportunities
    with_h_ad_id = []
    without_h_ad_id = []
    deposit_cash_opps = []
    
    for opp in filtered_opps:
        attributions = opp.get('attributions', [])
        fields = extract_attribution_fields(attributions)
        
        has_h_ad_id = bool(fields['h_ad_id'] or fields['utmAdId'] or fields['adId'])
        
        opp_info = {
            'name': opp.get('name'),
            'created': opp.get('createdAt'),
            'stage_id': opp.get('pipelineStageId'),
            'fields': fields
        }
        
        # Check if deposit/cash
        stage_id = opp.get('pipelineStageId')
        is_deposit_cash = stage_id in [
            ANDRIES_DEPOSIT_STAGE, ANDRIES_CASH_STAGE,
            DAVIDE_DEPOSIT_STAGE, DAVIDE_CASH_STAGE
        ]
        
        if is_deposit_cash:
            deposit_cash_opps.append(opp_info)
        
        if has_h_ad_id:
            with_h_ad_id.append(opp_info)
        else:
            without_h_ad_id.append(opp_info)
    
    print("=" * 80)
    print("RESULTS")
    print("=" * 80)
    print(f"✅ WITH h_ad_id: {len(with_h_ad_id)}")
    print(f"❌ WITHOUT h_ad_id: {len(without_h_ad_id)}")
    print(f"💰 Deposit/Cash opportunities: {len(deposit_cash_opps)}")
    print()
    
    # Show date range for WITH h_ad_id
    if with_h_ad_id:
        dates_with = [datetime.fromisoformat(o['created'].replace('Z', '+00:00')) 
                      for o in with_h_ad_id if o['created']]
        dates_with.sort()
        print("✅ OPPORTUNITIES WITH h_ad_id:")
        print(f"   Oldest: {dates_with[0].strftime('%Y-%m-%d')}")
        print(f"   Newest: {dates_with[-1].strftime('%Y-%m-%d')}")
        print(f"   Sample fields: {with_h_ad_id[0]['fields']['all_fields']}")
        print()
    
    # Show date range for WITHOUT h_ad_id
    if without_h_ad_id:
        dates_without = [datetime.fromisoformat(o['created'].replace('Z', '+00:00')) 
                        for o in without_h_ad_id if o['created']]
        dates_without.sort()
        print("❌ OPPORTUNITIES WITHOUT h_ad_id:")
        print(f"   Oldest: {dates_without[0].strftime('%Y-%m-%d')}")
        print(f"   Newest: {dates_without[-1].strftime('%Y-%m-%d')}")
        print(f"   Sample fields: {without_h_ad_id[0]['fields']['all_fields']}")
        print()
    
    # Analyze deposit/cash opportunities specifically
    if deposit_cash_opps:
        print("=" * 80)
        print("DEPOSIT/CASH OPPORTUNITIES ANALYSIS")
        print("=" * 80)
        
        dep_with_h_ad = [o for o in deposit_cash_opps 
                         if o['fields']['h_ad_id'] or o['fields']['utmAdId'] or o['fields']['adId']]
        dep_without_h_ad = [o for o in deposit_cash_opps 
                           if not (o['fields']['h_ad_id'] or o['fields']['utmAdId'] or o['fields']['adId'])]
        
        print(f"✅ Deposits/Cash WITH h_ad_id: {len(dep_with_h_ad)}")
        print(f"❌ Deposits/Cash WITHOUT h_ad_id: {len(dep_without_h_ad)}")
        print()
        
        if dep_without_h_ad:
            print("Sample deposits WITHOUT h_ad_id:")
            for i, opp in enumerate(dep_without_h_ad[:5], 1):
                print(f"\n{i}. {opp['name']}")
                print(f"   Created: {opp['created']}")
                print(f"   Has utmCampaignId: {bool(opp['fields']['utmCampaignId'])}")
                print(f"   utmCampaignId: {opp['fields']['utmCampaignId']}")
                print(f"   Has fbc_id: {bool(opp['fields']['fbc_id'])}")
                print(f"   Available fields: {opp['fields']['all_fields']}")

if __name__ == "__main__":
    analyze()

