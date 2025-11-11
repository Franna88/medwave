#!/usr/bin/env python3
"""
Quick check of advertData collection
"""

import firebase_admin
from firebase_admin import credentials, firestore

# Initialize Firebase
try:
    cred = credentials.Certificate('medx-ai-firebase-adminsdk-fbsvc-a86e7bd050.json')
    firebase_admin.initialize_app(cred)
except:
    pass

db = firestore.client()

print('\n' + '='*80)
print('QUICK ADVERTDATA CHECK')
print('='*80 + '\n')

# 1. Count total ads
adverts_ref = db.collection('advertData')
adverts = list(adverts_ref.limit(5).stream())

print(f'Sample of 5 ads:\n')

for ad in adverts:
    ad_data = ad.to_dict()
    print(f"Ad ID: {ad.id}")
    print(f"  Name: {ad_data.get('adName', 'N/A')}")
    print(f"  Campaign: {ad_data.get('campaignName', 'N/A')}")
    
    # Check subcollections
    ghl_path = f"advertData/{ad.id}/ghlData/weekly/weekly"
    print(f"  Checking path: {ghl_path}")
    
    ghl_ref = db.collection('advertData').document(ad.id).collection('ghlData').document('weekly').collection('weekly')
    ghl_docs = list(ghl_ref.limit(5).stream())
    
    print(f"  GHL weekly docs: {len(ghl_docs)}")
    
    if ghl_docs:
        for week in ghl_docs:
            week_data = week.to_dict()
            print(f"    Week {week.id}: {week_data.get('leads', 0)} leads, R{week_data.get('cashAmount', 0)}")
    
    print()

print('\nNow checking opportunityStageHistory for facebookAdId...\n')

opp_ref = db.collection('opportunityStageHistory').where('facebookAdId', '!=', '').limit(5)
opps = list(opp_ref.stream())

print(f'Found {len(opps)} opportunities with facebookAdId\n')

for opp in opps:
    opp_data = opp.to_dict()
    print(f"Opp: {opp_data.get('opportunityName', 'N/A')}")
    print(f"  Facebook Ad ID: {opp_data.get('facebookAdId', 'N/A')}")
    print(f"  Stage: {opp_data.get('newStageName', 'N/A')}")
    print()

print('='*80)

