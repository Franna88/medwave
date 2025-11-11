#!/usr/bin/env python3
"""
Check where GHL stores UTM attribution data
"""

import requests
import os
from dotenv import load_dotenv
import json

# Load environment variables
load_dotenv()

# GHL API Configuration
GHL_API_BASE_URL = "https://services.leadconnectorhq.com"
GHL_API_VERSION = "2021-07-28"
GHL_ACCESS_TOKEN = os.getenv('GHL_API_KEY', 'pit-22f8af95-3244-41e7-9a52-22c87b166f5a')
GHL_LOCATION_ID = "QdLXaFEqrdF0JbVbpKLw"

ANDRIES_PIPELINE_ID = "XeAGJWRnUGJ5tuhXam2g"

def get_ghl_headers():
    return {
        "Authorization": f"Bearer {GHL_ACCESS_TOKEN}",
        "Version": GHL_API_VERSION,
        "Content-Type": "application/json"
    }

print("=" * 100)
print("🔍 CHECKING GHL UTM DATA STORAGE")
print("=" * 100)
print()

# Step 1: Get a sample opportunity
print("1. Fetching sample opportunity...")
opp_url = f"{GHL_API_BASE_URL}/opportunities/search"
opp_params = {
    "location_id": GHL_LOCATION_ID,
    "pipeline_id": ANDRIES_PIPELINE_ID,
    "limit": 1
}

response = requests.get(opp_url, headers=get_ghl_headers(), params=opp_params)
opportunities = response.json().get('opportunities', [])

if opportunities:
    sample_opp = opportunities[0]
    print(f"✅ Found opportunity: {sample_opp.get('name')}")
    print(f"   Monetary Value: R {sample_opp.get('monetaryValue', 0)}")
    print(f"   Contact ID: {sample_opp.get('contactId')}")
    print()
    
    print("📋 Opportunity fields:")
    for key in ['source', 'attributionSource', 'lastAttributionSource', 'customFields']:
        if key in sample_opp:
            print(f"   {key}: {sample_opp[key]}")
    print()
    
    # Step 2: Get the contact
    contact_id = sample_opp.get('contactId')
    if contact_id:
        print(f"2. Fetching contact data for {contact_id}...")
        contact_url = f"{GHL_API_BASE_URL}/contacts/{contact_id}"
        
        contact_response = requests.get(contact_url, headers=get_ghl_headers())
        
        if contact_response.status_code == 200:
            contact = contact_response.json().get('contact', {})
            print(f"✅ Found contact: {contact.get('firstName', '')} {contact.get('lastName', '')}")
            print()
            
            print("📋 Contact UTM fields:")
            utm_fields = ['source', 'attributionSource', 'lastAttributionSource', 'customFields', 
                         'tags', 'dnd', 'dndSettings']
            
            for key in utm_fields:
                if key in contact:
                    value = contact[key]
                    if isinstance(value, dict) or isinstance(value, list):
                        print(f"   {key}:")
                        print(f"      {json.dumps(value, indent=6)}")
                    else:
                        print(f"   {key}: {value}")
            print()
            
            # Check for UTM in custom fields
            custom_fields = contact.get('customFields', [])
            if custom_fields:
                print("📋 Custom Fields:")
                for field in custom_fields:
                    print(f"   {field.get('id')}: {field.get('value')}")
                print()
        else:
            print(f"❌ Failed to fetch contact: {contact_response.status_code}")
            print(f"   Response: {contact_response.text}")
    
    # Step 3: Check full opportunity structure
    print("\n" + "=" * 100)
    print("📋 FULL OPPORTUNITY STRUCTURE")
    print("=" * 100)
    print(json.dumps(sample_opp, indent=2))
    
else:
    print("❌ No opportunities found")


