#!/usr/bin/env python3
"""
Test script to fetch CONTACT objects (not opportunities) to find Page Details
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

print("=" * 80)
print("TESTING: Fetching CONTACT objects to find Page Details")
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
        'expected_ad_id': '120235560268260335'
    }
]

for test_contact in test_contacts:
    print(f"\n{'='*80}")
    print(f"Testing: {test_contact['name']} ({test_contact['email']})")
    print('='*80)
    
    # STEP 1: Search for contact by email
    print(f"\n📞 STEP 1: Searching for contact by email...")
    search_response = requests.get(
        f'https://services.leadconnectorhq.com/contacts/',
        headers=headers,
        params={
            'locationId': GHL_LOCATION_ID,
            'query': test_contact['email']
        }
    )
    
    if search_response.status_code != 200:
        print(f"❌ Error searching contacts: {search_response.status_code}")
        print(search_response.text)
        continue
    
    search_data = search_response.json()
    contacts = search_data.get('contacts', [])
    
    if not contacts:
        print(f"❌ No contact found for {test_contact['email']}")
        continue
    
    contact_id = contacts[0].get('id')
    print(f"✅ Found contact ID: {contact_id}")
    
    # STEP 2: Fetch the full CONTACT object
    print(f"\n📞 STEP 2: Fetching full contact object...")
    contact_response = requests.get(
        f'https://services.leadconnectorhq.com/contacts/{contact_id}',
        headers=headers
    )
    
    if contact_response.status_code != 200:
        print(f"❌ Error fetching contact: {contact_response.status_code}")
        print(contact_response.text)
        continue
    
    contact_data = contact_response.json()
    contact = contact_data.get('contact', {})
    
    print(f"✅ Contact fetched successfully")
    print(f"   Name: {contact.get('firstName')} {contact.get('lastName')}")
    print(f"   Email: {contact.get('email')}")
    
    # STEP 3: Look for Page Details in the contact object
    print(f"\n📄 STEP 3: Searching for Page Details / Ad ID in contact...")
    
    # Check various possible locations
    found_ad_id = False
    
    # Check direct fields
    if 'adId' in contact or 'ad_id' in contact:
        ad_id = contact.get('adId') or contact.get('ad_id')
        print(f"   ✅ Found Ad ID in direct field: {ad_id}")
        found_ad_id = True
    
    # Check attributions
    if 'attributions' in contact:
        attributions = contact.get('attributions', [])
        print(f"   Found {len(attributions)} attribution(s)")
        
        for i, attr in enumerate(attributions):
            print(f"\n   Attribution #{i+1}:")
            
            # Check all possible Ad ID fields
            ad_id = (
                attr.get('adId') or
                attr.get('ad_id') or
                attr.get('Ad Id') or
                attr.get('utmAdId') or
                attr.get('utm_ad_id')
            )
            
            campaign_id = (
                attr.get('campaignId') or
                attr.get('campaign_id') or
                attr.get('Campaign Id') or
                attr.get('utmCampaignId') or
                attr.get('utm_campaign_id')
            )
            
            adset_id = (
                attr.get('adsetId') or
                attr.get('adset_id') or
                attr.get('Adset Id') or
                attr.get('utmAdsetId') or
                attr.get('utm_adset_id')
            )
            
            print(f"      Ad ID: {ad_id or 'NOT FOUND'}")
            print(f"      Campaign ID: {campaign_id or 'NOT FOUND'}")
            print(f"      Adset ID: {adset_id or 'NOT FOUND'}")
            print(f"      UTM Source: {attr.get('utmSource', 'N/A')}")
            print(f"      UTM Medium: {attr.get('utmMedium', 'N/A')}")
            
            if ad_id == test_contact['expected_ad_id']:
                print(f"      ✅ MATCH! Found expected Ad ID: {test_contact['expected_ad_id']}")
                found_ad_id = True
            elif ad_id:
                print(f"      ⚠️  Found Ad ID but doesn't match expected: {test_contact['expected_ad_id']}")
                found_ad_id = True
    
    # Check customFields
    if 'customFields' in contact or 'customField' in contact:
        custom_fields = contact.get('customFields', []) or contact.get('customField', [])
        print(f"\n   Found {len(custom_fields)} custom field(s)")
        
        for field in custom_fields:
            field_name = field.get('name', '').lower()
            if 'ad' in field_name or 'campaign' in field_name:
                print(f"      {field.get('name')}: {field.get('value')}")
                if field_name in ['ad_id', 'adid', 'ad id']:
                    ad_id = field.get('value')
                    if ad_id == test_contact['expected_ad_id']:
                        print(f"      ✅ MATCH! Found expected Ad ID in custom field")
                        found_ad_id = True
    
    # Show FULL contact object for debugging
    print(f"\n📄 FULL CONTACT OBJECT:")
    print(json.dumps(contact, indent=3, default=str))
    
    if not found_ad_id:
        print(f"\n❌ Could not find expected Ad ID: {test_contact['expected_ad_id']}")
    
    print()

print()
print("=" * 80)
print("TEST COMPLETE")
print("=" * 80)

