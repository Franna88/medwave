#!/usr/bin/env python3
"""
Scan ghl_data collection for records without adId
"""

import firebase_admin
from firebase_admin import credentials, firestore

# Initialize Firebase
try:
    cred = credentials.Certificate('medx-ai-firebase-adminsdk-fbsvc-a86e7bd050.json')
    firebase_admin.initialize_app(cred)
    print('✅ Firebase initialized successfully\n')
except Exception as e:
    print(f'⚠️  Firebase already initialized or error: {e}\n')
    pass

# Get Firestore client
db = firestore.client()

print('='*80)
print('SCANNING GHL_DATA COLLECTION FOR RECORDS WITHOUT ADID')
print('='*80 + '\n')

# Fetch all documents from ghl_data collection
print('📄 Fetching all documents from ghl_data collection...\n')

docs = db.collection('ghl_data').stream()

total_count = 0
without_adid_count = 0
with_adid_count = 0
records_without_adid = []

for doc in docs:
    total_count += 1
    data = doc.to_dict()
    
    ad_id = data.get('adId')
    
    if not ad_id or ad_id == '' or ad_id is None:
        without_adid_count += 1
        records_without_adid.append({
            'docId': doc.id,
            'contactId': data.get('contactId', 'N/A'),
            'name': data.get('name', 'Unknown'),
            'email': data.get('email', 'N/A'),
            'source': data.get('source', 'Unknown'),
            'productType': data.get('productType', 'Unknown'),
            'createdAt': data.get('createdAt', 'N/A')
        })
    else:
        with_adid_count += 1

print('='*80)
print('SCAN RESULTS')
print('='*80 + '\n')

print(f'📊 Summary:')
print(f'   Total documents: {total_count}')
print(f'   With adId: {with_adid_count}')
print(f'   Without adId: {without_adid_count}')
print(f'   Percentage without adId: {(without_adid_count/total_count*100):.1f}%' if total_count > 0 else '   N/A')

if without_adid_count > 0:
    print(f'\n{"="*80}')
    print(f'RECORDS WITHOUT ADID ({without_adid_count} total)')
    print('='*80 + '\n')
    
    for i, record in enumerate(records_without_adid[:20], 1):  # Show first 20
        print(f'{i}. {record["name"][:30]}')
        print(f'   Doc ID: {record["docId"]}')
        print(f'   Contact ID: {record["contactId"]}')
        print(f'   Email: {record["email"]}')
        print(f'   Source: {record["source"]}')
        print(f'   Product Type: {record["productType"]}')
        print(f'   Created: {record["createdAt"][:19] if record["createdAt"] != "N/A" else "N/A"}')
        print()
    
    if without_adid_count > 20:
        print(f'... and {without_adid_count - 20} more records without adId\n')
else:
    print(f'\n✅ All records have adId values!\n')

print('='*80)
print('SCAN COMPLETE')
print('='*80)

