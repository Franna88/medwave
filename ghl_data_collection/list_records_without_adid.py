#!/usr/bin/env python3
"""
Simple script to list all records in ghl_data that don't have an adId
"""

import firebase_admin
from firebase_admin import credentials, firestore

# Initialize Firebase
try:
    cred = credentials.Certificate('../medx-ai-firebase-adminsdk-fbsvc-a86e7bd050.json')
    firebase_admin.initialize_app(cred)
    print('✅ Firebase initialized successfully\n')
except Exception as e:
    print(f'⚠️  Firebase already initialized or error: {e}\n')
    pass

try:
    db = firestore.client()
except Exception as e:
    print(f'❌ Error getting Firestore client: {e}')
    print('Trying alternative initialization...\n')
    firebase_admin.delete_app(firebase_admin.get_app())
    cred = credentials.Certificate('../medx-ai-firebase-adminsdk-fbsvc-a86e7bd050.json')
    firebase_admin.initialize_app(cred)
    db = firestore.client()

print('='*80)
print('LOADING RECORDS WITHOUT ADID FROM GHL_DATA')
print('='*80 + '\n')

# Fetch all records from ghl_data
print('📄 Fetching all documents from ghl_data collection...\n')

ghl_data_ref = db.collection('ghl_data')
docs = ghl_data_ref.stream()

records_without_adid = []
total_count = 0

for doc in docs:
    total_count += 1
    data = doc.to_dict()
    ad_id = data.get('adId')
    
    if not ad_id or ad_id == '' or ad_id == 'None':
        records_without_adid.append({
            'docId': doc.id,
            'contactId': data.get('contactId'),
            'name': data.get('name', 'Unknown'),
            'email': data.get('email', ''),
            'source': data.get('source', 'Unknown'),
            'productType': data.get('productType', 'Unknown'),
            'createdAt': data.get('createdAt', ''),
            'submissionId': data.get('submissionId', ''),
            'formId': data.get('formId', '')
        })

print(f'✅ Scan complete!\n')
print(f'📊 Summary:')
print(f'   Total records in ghl_data: {total_count}')
print(f'   Records WITH adId: {total_count - len(records_without_adid)}')
print(f'   Records WITHOUT adId: {len(records_without_adid)}\n')

if not records_without_adid:
    print('✅ All records have adId!\n')
else:
    print('='*80)
    print(f'RECORDS WITHOUT ADID ({len(records_without_adid)} total)')
    print('='*80 + '\n')
    
    for i, record in enumerate(records_without_adid, 1):
        print(f'{i}. {record["name"][:40]}')
        print(f'   Contact ID: {record["contactId"]}')
        print(f'   Email: {record["email"][:40]}')
        print(f'   Source: {record["source"]}')
        print(f'   Product Type: {record["productType"]}')
        print(f'   Created: {record["createdAt"][:19]}')
        print(f'   Form ID: {record["formId"]}')
        print()

print('='*80)
print('LOAD COMPLETE')
print('='*80 + '\n')

