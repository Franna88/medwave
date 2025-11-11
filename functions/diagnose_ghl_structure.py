#!/usr/bin/env python3
"""
Diagnostic script to inspect the actual structure of GHL opportunities
to find where Campaign Id, Ad Id, and Adset Id are stored
"""

import os
import json
import requests
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

GHL_API_KEY = os.getenv('GHL_API_KEY')
GHL_LOCATION_ID = os.getenv('GHL_LOCATION_ID')
GHL_BASE_URL = 'https://services.leadconnectorhq.com'

def get_ghl_headers():
    return {
        'Authorization': f'Bearer {GHL_API_KEY}',
        'Version': '2021-07-28',
        'Content-Type': 'application/json'
    }

def fetch_sample_opportunity():
    """Fetch a single opportunity and inspect its structure"""
    print('🔍 Fetching a sample opportunity from GHL API...')
    print()
    
    response = requests.get(
        f'{GHL_BASE_URL}/opportunities/search',
        headers=get_ghl_headers(),
        params={
            'location_id': GHL_LOCATION_ID,
            'limit': 1
        },
        timeout=30
    )
    
    data = response.json()
    opportunities = data.get('opportunities', [])
    
    if not opportunities:
        print('❌ No opportunities found')
        return
    
    opp = opportunities[0]
    
    print('=' * 80)
    print('FULL OPPORTUNITY STRUCTURE')
    print('=' * 80)
    print(json.dumps(opp, indent=2))
    print()
    print('=' * 80)
    
    # Check specific fields
    print()
    print('🔍 Checking for Facebook Ad data...')
    print()
    
    # Check attributions
    if 'attributions' in opp:
        print('✅ Found "attributions" field:')
        print(json.dumps(opp['attributions'], indent=2))
        print()
    
    # Check contact
    if 'contact' in opp:
        print('✅ Found "contact" field:')
        print(json.dumps(opp['contact'], indent=2))
        print()
    
    # Check customFields
    if 'customFields' in opp:
        print('✅ Found "customFields" field:')
        print(json.dumps(opp['customFields'], indent=2))
        print()
    
    # Check all top-level keys
    print('📋 All top-level keys in opportunity:')
    for key in sorted(opp.keys()):
        print(f'   - {key}')
    print()

if __name__ == '__main__':
    fetch_sample_opportunity()

