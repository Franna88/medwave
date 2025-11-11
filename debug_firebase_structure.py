#!/usr/bin/env python3
"""
Debug Firebase structure - check all possible paths
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
print('DEBUGGING FIREBASE STRUCTURE')
print('='*80 + '\n')

# Pick the ad we know has data
ad_id = '120222249674970335'

print(f'Testing ad: {ad_id}\n')

# 1. Check main document
ad_ref = db.collection('advertData').document(ad_id)
ad_doc = ad_ref.get()

if ad_doc.exists:
    print('✅ Main document exists')
    print(f'   Fields: {list(ad_doc.to_dict().keys())}')
else:
    print('❌ Main document does NOT exist')

# 2. List all subcollections
print('\nSubcollections of main document:')
subcollections = list(ad_ref.collections())
for subcol in subcollections:
    print(f'  - {subcol.id}')
    docs = list(subcol.limit(5).stream())
    print(f'    Documents: {len(docs)}')
    if docs:
        for doc in docs:
            print(f'      {doc.id}')

# 3. Try different paths for GHL data
print('\n\nTrying different GHL data paths:')

# Path 1: advertData/{adId}/ghlData/weekly/weekly
print('\n1. advertData/{adId}/ghlData/weekly/weekly')
try:
    ghl_ref1 = db.collection('advertData').document(ad_id).collection('ghlData').document('weekly').collection('weekly')
    docs1 = list(ghl_ref1.stream())
    print(f'   Found {len(docs1)} documents')
    if docs1:
        for doc in docs1[:2]:
            print(f'     {doc.id}: {doc.to_dict()}')
except Exception as e:
    print(f'   Error: {e}')

# Path 2: advertData/{adId}/ghlData
print('\n2. advertData/{adId}/ghlData')
try:
    ghl_ref2 = db.collection('advertData').document(ad_id).collection('ghlData')
    docs2 = list(ghl_ref2.stream())
    print(f'   Found {len(docs2)} documents')
    if docs2:
        for doc in docs2[:5]:
            print(f'     {doc.id}: {list(doc.to_dict().keys())}')
except Exception as e:
    print(f'   Error: {e}')

# Path 3: advertData/{adId}/ghlWeekly
print('\n3. advertData/{adId}/ghlWeekly')
try:
    ghl_ref3 = db.collection('advertData').document(ad_id).collection('ghlWeekly')
    docs3 = list(ghl_ref3.stream())
    print(f'   Found {len(docs3)} documents')
    if docs3:
        for doc in docs3[:2]:
            print(f'     {doc.id}: {doc.to_dict()}')
except Exception as e:
    print(f'   Error: {e}')

# 4. Check insights subcollection
print('\n4. advertData/{adId}/insights')
try:
    insights_ref = db.collection('advertData').document(ad_id).collection('insights')
    docs4 = list(insights_ref.stream())
    print(f'   Found {len(docs4)} documents')
    if docs4:
        for doc in docs4[:2]:
            print(f'     {doc.id}: {list(doc.to_dict().keys())}')
except Exception as e:
    print(f'   Error: {e}')

print('\n' + '='*80)
print('CHECKING WHAT THE BACKFILL SCRIPT SHOULD HAVE WRITTEN')
print('='*80 + '\n')

# Check if there are ANY collections with weekly data anywhere
print('Checking opportunityStageHistory for this ad...')
opp_ref = db.collection('opportunityStageHistory').where('facebookAdId', '==', ad_id)
opps = list(opp_ref.stream())
print(f'Found {len(opps)} opportunity records')

for opp in opps:
    data = opp.to_dict()
    print(f'\nOpportunity: {data.get("opportunityName")}')
    print(f'  Stage: {data.get("newStageName")}')
    print(f'  Stage Category: {data.get("stageCategory")}')
    print(f'  Timestamp: {data.get("timestamp")}')
    print(f'  Monetary Value: {data.get("monetaryValue", "N/A")}')
    print(f'  Facebook Ad ID: {data.get("facebookAdId")}')

print('\n' + '='*80)

