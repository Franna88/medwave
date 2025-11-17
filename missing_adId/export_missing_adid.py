#!/usr/bin/env python3
"""
Export all ghl_data records without adId to a text file
"""

import firebase_admin
from firebase_admin import credentials, firestore
import json
from datetime import datetime

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
print('EXPORTING GHL_DATA RECORDS WITHOUT ADID')
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
        records_without_adid.append(data)

print(f'✅ Scan complete!\n')
print(f'📊 Summary:')
print(f'   Total records in ghl_data: {total_count}')
print(f'   Records WITHOUT adId: {len(records_without_adid)}\n')

# Write to text file
output_file = 'ghl_data_missing_adId.txt'

print(f'📝 Writing to {output_file}...\n')

with open(output_file, 'w', encoding='utf-8') as f:
    f.write('='*80 + '\n')
    f.write('GHL_DATA RECORDS WITHOUT ADID\n')
    f.write('='*80 + '\n')
    f.write(f'Generated: {datetime.now().strftime("%Y-%m-%d %H:%M:%S")}\n')
    f.write(f'Total Records: {len(records_without_adid)}\n')
    f.write('='*80 + '\n\n')
    
    for i, record in enumerate(records_without_adid, 1):
        f.write(f'RECORD {i}\n')
        f.write('-'*80 + '\n')
        f.write(f'Contact ID: {record.get("contactId", "N/A")}\n')
        f.write(f'Name: {record.get("name", "Unknown")}\n')
        f.write(f'Email: {record.get("email", "N/A")}\n')
        f.write(f'Submission ID: {record.get("submissionId", "N/A")}\n')
        f.write(f'Form ID: {record.get("formId", "N/A")}\n')
        f.write(f'Source: {record.get("source", "Unknown")}\n')
        f.write(f'Product Type: {record.get("productType", "Unknown")}\n')
        f.write(f'Created At: {record.get("createdAt", "N/A")}\n')
        f.write(f'External: {record.get("external", False)}\n')
        f.write(f'Ad ID: {record.get("adId", "MISSING")}\n')
        f.write(f'Attribution: {record.get("attribution", "None")}\n')
        f.write('\n')
        
        # Write full submission data
        f.write('FULL SUBMISSION DATA:\n')
        f.write('-'*80 + '\n')
        full_submission = record.get('fullSubmission', {})
        f.write(json.dumps(full_submission, indent=2, ensure_ascii=False))
        f.write('\n\n')
        f.write('='*80 + '\n\n')

print(f'✅ Export complete!\n')
print(f'📄 File saved: {output_file}')
print(f'📊 Records exported: {len(records_without_adid)}\n')

print('='*80)
print('EXPORT COMPLETE')
print('='*80 + '\n')


