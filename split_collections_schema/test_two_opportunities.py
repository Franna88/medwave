#!/usr/bin/env python3
"""
Mini test script to verify we can extract Ad IDs from the two specific opportunities
"""

import requests
import json
import firebase_admin
from firebase_admin import credentials, firestore

# Initialize Firebase
if not firebase_admin._apps:
    cred = credentials.Certificate('medx-ai-firebase-adminsdk-fbsvc-a86e7bd050.json')
    firebase_admin.initialize_app(cred)

db = firestore.client()

# GHL API credentials
GHL_API_KEY = 'pit-22f8af95-3244-41e7-9a52-22c87b166f5a'
GHL_LOCATION_ID = 'QdLXaFEqrdF0JbVbpKLw'

headers = {
    'Authorization': f'Bearer {GHL_API_KEY}',
    'Version': '2021-07-28'
}

def extract_ad_id_from_attribution(attr):
    """Extract Ad ID from attribution with multiple field name variations"""
    # Check direct fields
    ad_id = (
        attr.get('h_ad_id') or 
        attr.get('utmAdId') or 
        attr.get('utm_ad_id') or
        attr.get('adId') or 
        attr.get('ad_id') or
        attr.get('Ad Id')
    )
    
    # Check in customField array
    if not ad_id and 'customField' in attr:
        for field in attr.get('customField', []):
            field_name = field.get('name', '').lower()
            if field_name in ['ad_id', 'adid', 'utm_ad_id', 'utmadid', 'h_ad_id']:
                ad_id = field.get('value')
                if ad_id:
                    break
    
    # Check in pageDetails
    if not ad_id:
        page_details = attr.get('pageDetails') or attr.get('page_details') or {}
        ad_id = (
            page_details.get('adId') or 
            page_details.get('ad_id') or
            page_details.get('Ad Id')
        )
    
    return ad_id

def extract_campaign_id_from_attribution(attr):
    """Extract Campaign ID from attribution with multiple field name variations"""
    campaign_id = (
        attr.get('utmCampaignId') or
        attr.get('utm_campaign_id') or
        attr.get('campaignId') or
        attr.get('campaign_id') or
        attr.get('Campaign Id')
    )
    
    # Check in pageDetails if not found
    if not campaign_id:
        page_details = attr.get('pageDetails') or attr.get('page_details') or {}
        campaign_id = (
            page_details.get('campaignId') or
            page_details.get('campaign_id') or
            page_details.get('Campaign Id')
        )
    
    return campaign_id

print("=" * 80)
print("TESTING AD ID EXTRACTION FROM TWO SPECIFIC OPPORTUNITIES")
print("=" * 80)
print()

# Test contacts based on the screenshots
test_contacts = [
    {
        'name': 'Marilette Bes Bester',
        'email': 'marilettebester83@gmail.com',
        'expected_ad_id': '120235559827960335'
    },
    {
        'name': 'Yolandi Nel',
        'email': 'yolandi1712@gmail.com',
        'expected_ad_id': '120235560268260335'  # Should be found with enhanced extraction
    }
]

# First, check if these ads exist in our new collections
print("📊 STEP 1: Checking if ads exist in new 'ads' collection...")
print()

for contact in test_contacts:
    ad_id = contact['expected_ad_id']
    ad_ref = db.collection('ads').document(ad_id)
    ad_doc = ad_ref.get()
    
    if ad_doc.exists:
        ad_data = ad_doc.to_dict()
        print(f"✅ Found Ad ID {ad_id} in 'ads' collection")
        print(f"   Ad Name: {ad_data.get('adName', 'N/A')}")
        print(f"   Campaign: {ad_data.get('campaignName', 'N/A')}")
        print(f"   Ad Set: {ad_data.get('adSetName', 'N/A')}")
    else:
        print(f"❌ Ad ID {ad_id} NOT found in 'ads' collection")
    print()

# Now fetch the opportunities from GHL API
print("=" * 80)
print("📊 STEP 2: Fetching opportunities from GHL API...")
print("=" * 80)
print()

for contact in test_contacts:
    print(f"🔍 Searching for: {contact['name']} ({contact['email']})")
    print("-" * 80)
    
    # Search for opportunity by contact email
    params = {
        'location_id': GHL_LOCATION_ID,
        'q': contact['email'],
        'limit': 10
    }
    
    response = requests.get(
        'https://services.leadconnectorhq.com/opportunities/search',
        headers=headers,
        params=params
    )
    
    if response.status_code != 200:
        print(f"❌ Error fetching opportunity: {response.status_code}")
        print(f"   Response: {response.text}")
        continue
    
    data = response.json()
    opportunities = data.get('opportunities', [])
    
    if not opportunities:
        print(f"⚠️  No opportunities found for {contact['email']}")
        continue
    
    # Take the first (most recent) opportunity
    opp = opportunities[0]
    
    print(f"✅ Found opportunity: {opp.get('name', 'N/A')}")
    print(f"   Opportunity ID: {opp.get('id', 'N/A')}")
    print(f"   Created: {opp.get('createdAt', 'N/A')}")
    print()
    
    # Extract attributions
    attributions = opp.get('attributions', [])
    
    if not attributions:
        print("⚠️  No attributions found")
        continue
    
    print(f"📋 Found {len(attributions)} attribution(s)")
    print()
    
    # Test extraction on each attribution (most recent last)
    for i, attr in enumerate(attributions):
        print(f"   Attribution #{i+1}:")
        
        # Extract Ad ID using our enhanced function
        extracted_ad_id = extract_ad_id_from_attribution(attr)
        extracted_campaign_id = extract_campaign_id_from_attribution(attr)
        
        print(f"      Extracted Ad ID: {extracted_ad_id or 'NOT FOUND'}")
        print(f"      Extracted Campaign ID: {extracted_campaign_id or 'NOT FOUND'}")
        print(f"      UTM Source: {attr.get('utmSource', 'N/A')}")
        print(f"      UTM Medium: {attr.get('utmMedium', 'N/A')}")
        print(f"      UTM Campaign: {attr.get('utmCampaign', 'N/A')}")
        
        # Show raw attribution data for debugging
        print(f"      Raw Attribution Keys: {list(attr.keys())}")
        
        # Check if we got the expected Ad ID
        if extracted_ad_id == contact['expected_ad_id']:
            print(f"      ✅ MATCH! Found expected Ad ID: {contact['expected_ad_id']}")
        elif extracted_ad_id:
            print(f"      ⚠️  Found Ad ID but doesn't match expected: {contact['expected_ad_id']}")
        else:
            print(f"      ❌ Could not extract Ad ID (expected: {contact['expected_ad_id']})")
        
        print()
    
    # Show the most recent attribution in detail
    if attributions:
        print("   📄 FULL LAST ATTRIBUTION DATA (for debugging):")
        last_attr = attributions[-1]
        print(json.dumps(last_attr, indent=6, default=str))
    
    # Show FULL opportunity object to find where Page Details might be
    print()
    print("   📄 FULL OPPORTUNITY OBJECT (searching for Page Details):")
    print(json.dumps(opp, indent=6, default=str))
    
    print()
    print("=" * 80)
    print()

print()
print("=" * 80)
print("TEST COMPLETE")
print("=" * 80)

