#!/usr/bin/env python3
"""
Diagnose why opportunities aren't matching to ads
"""

import firebase_admin
from firebase_admin import credentials, firestore

# Initialize Firebase
try:
    cred = credentials.Certificate('/Users/mac/dev/medwave/medx-ai-firebase-adminsdk-fbsvc-a86e7bd050.json')
    firebase_admin.initialize_app(cred)
except:
    pass

db = firestore.client()

print('=' * 80)
print('DIAGNOSING OPPORTUNITY MATCHING')
print('=' * 80)
print()

# Get a sample opportunity with monetary value
print('Step 1: Getting sample opportunities with monetary values...')
opps = list(db.collection('ghl_opportunities').limit(20).stream())

sample_opps = []
for doc in opps:
    data = doc.to_dict()
    if data.get('monetaryValue', 0) > 0:
        sample_opps.append({
            'id': doc.id,
            'contactId': data.get('contactId'),
            'name': data.get('name'),
            'monetaryValue': data.get('monetaryValue'),
            'stageName': data.get('stageName'),
            'assignedAdId': data.get('assignedAdId'),
            'createdAt': data.get('createdAt')
        })
        if len(sample_opps) >= 3:
            break

print(f'Found {len(sample_opps)} sample opportunities with monetary values\n')

for opp in sample_opps:
    print(f"Opportunity: {opp['name']}")
    print(f"  Contact ID: {opp['contactId']}")
    print(f"  Monetary Value: R {opp['monetaryValue'] / 100:,.2f}")
    print(f"  Stage: {opp['stageName']}")
    print(f"  Assigned Ad ID: {opp.get('assignedAdId', 'NOT SET')}")
    print(f"  Created: {opp['createdAt']}")
    
    # Check if contactId exists in ghl_data
    contact_id = opp['contactId']
    ghl_data_doc = db.collection('ghl_data').document(contact_id).get()
    
    if ghl_data_doc.exists:
        ghl_data = ghl_data_doc.to_dict()
        ad_id = ghl_data.get('adId')
        print(f"  ✅ Found in ghl_data: adId = {ad_id}")
        
        # Check if ad exists in fb_ads
        if ad_id and ad_id != 'None':
            fb_ad_doc = db.collection('fb_ads').document(ad_id).get()
            if fb_ad_doc.exists:
                fb_ad = fb_ad_doc.to_dict()
                print(f"  ✅ Found in fb_ads:")
                print(f"     Ad Name: {fb_ad.get('adName')}")
                print(f"     Campaign ID: {fb_ad.get('campaignId')}")
                print(f"     Campaign Name: {fb_ad.get('campaignName')}")
                print(f"     Ad Set ID: {fb_ad.get('adSetId')}")
            else:
                print(f"  ❌ Ad {ad_id} NOT found in fb_ads")
        else:
            print(f"  ⚠️  No valid adId in ghl_data")
    else:
        print(f"  ❌ Contact ID NOT found in ghl_data")
    
    print()

print('=' * 80)
print('CHECKING COLLECTION STRUCTURES')
print('=' * 80)
print()

# Check ghl_data structure
print('Sample ghl_data document:')
ghl_data_sample = list(db.collection('ghl_data').limit(1).stream())
if ghl_data_sample:
    data = ghl_data_sample[0].to_dict()
    print(f"  Document ID: {ghl_data_sample[0].id}")
    print(f"  Fields: {list(data.keys())}")
    print(f"  adId: {data.get('adId')}")
print()

# Check fb_ads structure
print('Sample fb_ads document:')
fb_ads_sample = list(db.collection('fb_ads').limit(1).stream())
if fb_ads_sample:
    data = fb_ads_sample[0].to_dict()
    print(f"  Document ID: {fb_ads_sample[0].id}")
    print(f"  Fields: {list(data.keys())[:10]}...")
    print(f"  campaignId: {data.get('campaignId')}")
    print(f"  adSetId: {data.get('adSetId')}")
print()

print('=' * 80)

