#!/usr/bin/env python3
"""
Investigate why opportunities don't have h_ad_id in their attributions
"""

import requests
import os
import json

# GHL Configuration
GHL_API_KEY = os.environ.get('GHL_API_KEY', 'pit-22f8af95-3244-41e7-9a52-22c87b166f5a')
GHL_LOCATION_ID = 'QdLXaFEqrdF0JbVbpKLw'
ANDRIES_PIPELINE_ID = 'XeAGJWRnUGJ5tuhXam2g'
DAVIDE_PIPELINE_ID = 'AUduOJBB2lxlsEaNmlJz'

# Expected stage IDs for deposits/cash
ANDRIES_DEPOSIT_STAGE = "52a076ca-851f-43fc-a57d-309403a4b208"
ANDRIES_CASH_STAGE = "3a8ead84-92b0-4796-aaf8-6594c3217a2c"
DAVIDE_DEPOSIT_STAGE = "13d54d18-d1e7-476b-aad8-cb4767b8b979"
DAVIDE_CASH_STAGE = "3c89afba-9797-4b0f-947c-ba00b60468c6"

def extract_h_ad_id(attributions):
    """Extract h_ad_id from attributions - same logic as populate_ghl_data.py"""
    if not attributions:
        return None
    
    # Check each attribution in reverse order (most recent first)
    for attr in reversed(attributions):
        # Try different possible field names
        h_ad_id = attr.get('h_ad_id') or attr.get('utmAdId') or attr.get('adId')
        if h_ad_id:
            return h_ad_id
    
    return None

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
            
            page += 1
            
        except Exception as e:
            print(f"Error: {e}")
            break
    
    print(f"✅ Fetched {len(all_opportunities)} opportunities\n")
    return all_opportunities

def investigate():
    """Investigate attribution data in deposit/cash opportunities"""
    
    print("=" * 80)
    print("INVESTIGATING MISSING UTM DATA IN DEPOSIT/CASH OPPORTUNITIES")
    print("=" * 80)
    print()
    
    all_opps = fetch_opportunities()
    
    # Filter to Andries & Davide
    filtered_opps = [opp for opp in all_opps 
                     if opp.get('pipelineId') in [ANDRIES_PIPELINE_ID, DAVIDE_PIPELINE_ID]]
    
    print(f"📊 Andries & Davide opportunities: {len(filtered_opps)}\n")
    
    # Find deposit/cash opportunities
    deposit_cash_opps = []
    
    for opp in filtered_opps:
        pipeline_id = opp.get('pipelineId')
        stage_id = opp.get('pipelineStageId')
        
        is_deposit_or_cash = False
        stage_type = ""
        
        if pipeline_id == ANDRIES_PIPELINE_ID:
            if stage_id == ANDRIES_DEPOSIT_STAGE:
                is_deposit_or_cash = True
                stage_type = "Andries Deposit"
            elif stage_id == ANDRIES_CASH_STAGE:
                is_deposit_or_cash = True
                stage_type = "Andries Cash"
        elif pipeline_id == DAVIDE_PIPELINE_ID:
            if stage_id == DAVIDE_DEPOSIT_STAGE:
                is_deposit_or_cash = True
                stage_type = "Davide Deposit"
            elif stage_id == DAVIDE_CASH_STAGE:
                is_deposit_or_cash = True
                stage_type = "Davide Cash"
        
        if is_deposit_or_cash:
            deposit_cash_opps.append({
                'opp': opp,
                'stage_type': stage_type
            })
    
    print(f"🔍 Found {len(deposit_cash_opps)} deposit/cash opportunities\n")
    
    # Analyze their attribution data
    with_h_ad_id = []
    without_h_ad_id = []
    
    for item in deposit_cash_opps:
        opp = item['opp']
        attributions = opp.get('attributions', {})
        
        # Handle both dict and list formats
        if isinstance(attributions, dict):
            attributions = attributions.get('attributions', [])
        
        h_ad_id = extract_h_ad_id(attributions)
        
        if h_ad_id:
            with_h_ad_id.append(item)
        else:
            without_h_ad_id.append(item)
    
    print("=" * 80)
    print("RESULTS")
    print("=" * 80)
    print(f"✅ WITH h_ad_id: {len(with_h_ad_id)}")
    print(f"❌ WITHOUT h_ad_id: {len(without_h_ad_id)}")
    print()
    
    # Show samples of those WITHOUT h_ad_id
    if without_h_ad_id:
        print("=" * 80)
        print("SAMPLE OPPORTUNITIES WITHOUT h_ad_id (THESE ARE THE PROBLEM!)")
        print("=" * 80)
        print()
        
        for i, item in enumerate(without_h_ad_id[:10], 1):
            opp = item['opp']
            stage_type = item['stage_type']
            
            print(f"{i}. {opp.get('name', 'Unknown')} - {stage_type}")
            print(f"   Value: R{float(opp.get('monetaryValue', 0) or 0):,.2f}")
            print(f"   Created: {opp.get('createdAt', 'Unknown')}")
            
            # Show attribution data
            attributions = opp.get('attributions', {})
            if isinstance(attributions, dict):
                attributions = attributions.get('attributions', [])
            
            if attributions:
                print(f"   Attributions ({len(attributions)} total):")
                for j, attr in enumerate(attributions, 1):
                    print(f"      Attribution {j}:")
                    print(f"         utmSource: {attr.get('utmSource', 'N/A')}")
                    print(f"         utmMedium: {attr.get('utmMedium', 'N/A')}")
                    print(f"         utmCampaign: {attr.get('utmCampaign', 'N/A')}")
                    print(f"         h_ad_id: {attr.get('h_ad_id', 'MISSING ❌')}")
                    print(f"         utmAdId: {attr.get('utmAdId', 'MISSING ❌')}")
                    print(f"         adId: {attr.get('adId', 'MISSING ❌')}")
                    print(f"         fbc_id: {attr.get('fbc_id', 'N/A')}")
                    
                    # Show ALL fields in attribution
                    other_fields = {k: v for k, v in attr.items() 
                                   if k not in ['utmSource', 'utmMedium', 'utmCampaign', 'h_ad_id', 'utmAdId', 'adId', 'fbc_id']}
                    if other_fields:
                        print(f"         Other fields: {json.dumps(other_fields, indent=10)}")
            else:
                print(f"   ❌ NO ATTRIBUTIONS AT ALL!")
            
            print()
        
        # Save full data to file for analysis
        output_file = f"missing_utm_opportunities_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
        with open(output_file, 'w') as f:
            json.dump([item['opp'] for item in without_h_ad_id], f, indent=2, default=str)
        print(f"📄 Full data saved to: {output_file}")
        print()
    
    # Show samples of those WITH h_ad_id (for comparison)
    if with_h_ad_id:
        print("=" * 80)
        print("SAMPLE OPPORTUNITIES WITH h_ad_id (WORKING CORRECTLY)")
        print("=" * 80)
        print()
        
        for i, item in enumerate(with_h_ad_id[:3], 1):
            opp = item['opp']
            stage_type = item['stage_type']
            
            attributions = opp.get('attributions', {})
            if isinstance(attributions, dict):
                attributions = attributions.get('attributions', [])
            
            h_ad_id = extract_h_ad_id(attributions)
            
            print(f"{i}. {opp.get('name', 'Unknown')} - {stage_type}")
            print(f"   Value: R{float(opp.get('monetaryValue', 0) or 0):,.2f}")
            print(f"   ✅ h_ad_id: {h_ad_id}")
            print()

from datetime import datetime

if __name__ == "__main__":
    investigate()

