#!/usr/bin/env python3
"""
Inspect ONE deposit opportunity in detail to see ALL its fields
"""

import requests
import os
import json

# GHL Configuration
GHL_API_KEY = os.environ.get('GHL_API_KEY', 'pit-22f8af95-3244-41e7-9a52-22c87b166f5a')
GHL_LOCATION_ID = 'QdLXaFEqrdF0JbVbpKLw'
ANDRIES_PIPELINE_ID = 'XeAGJWRnUGJ5tuhXam2g'
ANDRIES_DEPOSIT_STAGE = "52a076ca-851f-43fc-a57d-309403a4b208"

def fetch_one_deposit():
    """Fetch opportunities until we find ONE deposit"""
    url = 'https://services.leadconnectorhq.com/opportunities/search'
    headers = {
        'Authorization': f'Bearer {GHL_API_KEY}',
        'Version': '2021-07-28'
    }
    
    print("🔍 Searching for a deposit opportunity...")
    
    for page in range(1, 20):  # Check first 20 pages
        params = {
            'location_id': GHL_LOCATION_ID,
            'limit': 100,
            'page': page
        }
        
        try:
            response = requests.get(url, headers=headers, params=params, timeout=30)
            
            if response.status_code != 200:
                print(f"Error: {response.status_code}")
                return None
            
            data = response.json()
            opportunities = data.get('opportunities', [])
            
            if not opportunities:
                break
            
            # Find first deposit
            for opp in opportunities:
                if (opp.get('pipelineId') == ANDRIES_PIPELINE_ID and 
                    opp.get('pipelineStageId') == ANDRIES_DEPOSIT_STAGE):
                    print(f"✅ Found deposit: {opp.get('name')}")
                    return opp
            
            print(f"   Page {page}: No deposits found, checking next page...")
            
        except Exception as e:
            print(f"Error: {e}")
            return None
    
    return None

def inspect():
    """Inspect one deposit opportunity in detail"""
    
    print("=" * 80)
    print("INSPECTING ONE DEPOSIT OPPORTUNITY")
    print("=" * 80)
    print()
    
    opp = fetch_one_deposit()
    
    if not opp:
        print("❌ Could not find any deposit opportunities")
        return
    
    print()
    print("=" * 80)
    print("FULL OPPORTUNITY DATA")
    print("=" * 80)
    print()
    print(json.dumps(opp, indent=2))
    print()
    
    # Save to file
    output_file = f"deposit_opportunity_sample.json"
    with open(output_file, 'w') as f:
        json.dump(opp, f, indent=2)
    print(f"📄 Full data saved to: {output_file}")
    print()
    
    # Highlight key fields
    print("=" * 80)
    print("KEY FIELDS")
    print("=" * 80)
    print(f"Name: {opp.get('name')}")
    print(f"Value: R{float(opp.get('monetaryValue', 0) or 0):,.2f}")
    print(f"Pipeline: {opp.get('pipelineId')}")
    print(f"Stage: {opp.get('pipelineStageId')}")
    print(f"Created: {opp.get('createdAt')}")
    print()
    
    # Check attributions
    print("=" * 80)
    print("ATTRIBUTIONS DATA")
    print("=" * 80)
    attributions = opp.get('attributions', {})
    print(f"Type: {type(attributions)}")
    print(f"Raw data: {json.dumps(attributions, indent=2)}")
    print()
    
    # Try to extract h_ad_id
    if isinstance(attributions, dict):
        attr_list = attributions.get('attributions', [])
        print(f"Found {len(attr_list)} attributions")
        for i, attr in enumerate(attr_list, 1):
            print(f"\nAttribution {i}:")
            for key, value in attr.items():
                print(f"   {key}: {value}")

if __name__ == "__main__":
    inspect()

