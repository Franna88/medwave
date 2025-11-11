#!/usr/bin/env python3
"""
Check specific ad that should have data
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

# Check the ad ID from the opportunity
ad_id = '120222249674970335'

print(f'\nChecking ad {ad_id} which has opportunities...\n')

# Check if ad exists in advertData
ad_ref = db.collection('advertData').document(ad_id)
ad_doc = ad_ref.get()

if ad_doc.exists:
    print(f'✅ Ad exists in advertData')
    ad_data = ad_doc.to_dict()
    print(f'   Name: {ad_data.get("adName", "N/A")}')
    print(f'   Campaign: {ad_data.get("campaignName", "N/A")}')
else:
    print(f'❌ Ad does NOT exist in advertData')

# Check GHL weekly subcollection
print(f'\nChecking ghlData/weekly/weekly subcollection...')
ghl_ref = db.collection('advertData').document(ad_id).collection('ghlData').document('weekly').collection('weekly')
ghl_docs = list(ghl_ref.stream())

print(f'Found {len(ghl_docs)} weekly documents')

for doc in ghl_docs:
    data = doc.to_dict()
    print(f'  Week {doc.id}:')
    print(f'    Leads: {data.get("leads", 0)}')
    print(f'    Booked: {data.get("bookedAppointments", 0)}')
    print(f'    Deposits: {data.get("deposits", 0)}')
    print(f'    Cash: R{data.get("cashAmount", 0)}')

# Check opportunities for this ad
print(f'\nChecking opportunities for this ad...')
opp_ref = db.collection('opportunityStageHistory').where('facebookAdId', '==', ad_id)
opps = list(opp_ref.stream())

print(f'Found {len(opps)} opportunity records')

for opp in opps[:5]:
    data = opp.to_dict()
    print(f'  Opp: {data.get("opportunityName", "N/A")}')
    print(f'    Stage: {data.get("newStageName", "N/A")}')
    print(f'    Date: {data.get("timestamp", "N/A")}')

