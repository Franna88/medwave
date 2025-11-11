#!/usr/bin/env python3
"""
Test script to verify Ad Set ID matching for Yolandi Nel
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
print("TESTING: Ad Set ID Matching for Yolandi Nel")
print("=" * 80)
print()

# Yolandi's expected data from screenshots
expected_ad_id = '120235560268260335'
expected_adset_id = '120235556204830335'
expected_campaign_id = '120235556205010335'

# Step 1: Fetch Contact
print("📞 STEP 1: Fetching Yolandi's contact...")
search_response = requests.get(
    f'https://services.leadconnectorhq.com/contacts/',
    headers=headers,
    params={
        'locationId': GHL_LOCATION_ID,
        'query': 'yolandi1712@gmail.com'
    }
)

if search_response.status_code != 200:
    print(f"❌ Error: {search_response.status_code}")
    exit(1)

contacts = search_response.json().get('contacts', [])
if not contacts:
    print("❌ Contact not found")
    exit(1)

contact_id = contacts[0].get('id')
print(f"✅ Found contact ID: {contact_id}")

# Fetch full contact
contact_response = requests.get(
    f'https://services.leadconnectorhq.com/contacts/{contact_id}',
    headers=headers
)

contact = contact_response.json().get('contact', {})

# Extract from lastAttributionSource
last_attr = contact.get('lastAttributionSource', {})
contact_ad_id = last_attr.get('adId')
contact_adset_id = last_attr.get('adSetId')
contact_campaign_id = last_attr.get('campaignId')

print(f"\n📊 STEP 2: Extracted from Contact:")
print(f"   Ad ID: {contact_ad_id or 'NULL'}")
print(f"   Ad Set ID: {contact_adset_id or 'NULL'}")
print(f"   Campaign ID: {contact_campaign_id or 'NULL'}")

# Step 3: Find ads in this ad set
print(f"\n🔍 STEP 3: Finding ads in Ad Set {contact_adset_id}...")

ads_in_adset = []
ads_ref = db.collection('ads').where('adSetId', '==', str(contact_adset_id)).stream()

for ad_doc in ads_ref:
    ad_data = ad_doc.to_dict()
    ads_in_adset.append({
        'adId': ad_data.get('adId'),
        'adName': ad_data.get('adName'),
        'adSetName': ad_data.get('adSetName'),
        'campaignName': ad_data.get('campaignName')
    })

print(f"✅ Found {len(ads_in_adset)} ad(s) in this ad set:")
for i, ad in enumerate(ads_in_adset, 1):
    print(f"   {i}. Ad ID: {ad['adId']}")
    print(f"      Name: {ad['adName']}")
    print(f"      Ad Set: {ad['adSetName']}")
    print(f"      Campaign: {ad['campaignName']}")
    
    if ad['adId'] == expected_ad_id:
        print(f"      ✅ THIS IS THE EXPECTED AD!")
    print()

# Step 4: Test matching logic
print(f"📊 STEP 4: Testing matching logic...")

if len(ads_in_adset) == 1:
    assigned_ad_id = ads_in_adset[0]['adId']
    method = 'Single ad in ad set'
    print(f"✅ {method}")
    print(f"   Assigned Ad ID: {assigned_ad_id}")
elif len(ads_in_adset) > 1:
    print(f"⚠️  Multiple ads in ad set - would try to match by utmMedium")
    
    # Get utmMedium from opportunity
    opp_response = requests.get(
        'https://services.leadconnectorhq.com/opportunities/search',
        headers=headers,
        params={
            'location_id': GHL_LOCATION_ID,
            'q': 'yolandi1712@gmail.com',
            'limit': 1
        }
    )
    
    if opp_response.status_code == 200:
        opps = opp_response.json().get('opportunities', [])
        if opps:
            opp = opps[0]
            attributions = opp.get('attributions', [])
            if attributions:
                last_opp_attr = attributions[-1]
                utm_medium = last_opp_attr.get('utmMedium', '').lower().strip()
                
                print(f"   UTM Medium from opportunity: '{utm_medium}'")
                
                # Try to match
                for ad in ads_in_adset:
                    ad_set_name = ad['adSetName'].lower()
                    print(f"   Checking if '{utm_medium}' matches '{ad_set_name}'...")
                    
                    if utm_medium in ad_set_name or ad_set_name in utm_medium:
                        assigned_ad_id = ad['adId']
                        print(f"   ✅ MATCH! Assigned Ad ID: {assigned_ad_id}")
                        break
else:
    print(f"❌ No ads found in ad set")

print()
print("=" * 80)
print("RESULT:")
print("=" * 80)

if 'assigned_ad_id' in locals():
    if assigned_ad_id == expected_ad_id:
        print(f"✅ SUCCESS! Correctly matched to expected Ad ID: {expected_ad_id}")
    else:
        print(f"⚠️  Matched to Ad ID: {assigned_ad_id}")
        print(f"   Expected Ad ID: {expected_ad_id}")
else:
    print(f"❌ FAILED: Could not assign an Ad ID")

print()

