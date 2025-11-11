#!/usr/bin/env python3
"""
Check all month documents in advertData collection
"""

import firebase_admin
from firebase_admin import credentials, firestore

# Initialize Firebase
if not firebase_admin._apps:
    cred = credentials.Certificate('medx-ai-firebase-adminsdk-fbsvc-a86e7bd050.json')
    firebase_admin.initialize_app(cred)

db = firestore.client()

print('\n' + '='*80)
print('CHECK ALL MONTH DOCUMENTS')
print('='*80)

# Get all documents in advertData (both old structure ads and new month docs)
all_docs = list(db.collection('advertData').stream())

print(f'\n📊 Total documents in advertData: {len(all_docs)}')

# Separate old structure ads from month documents
old_structure_ads = []
month_docs = []
unknown_docs = []

for doc in all_docs:
    doc_data = doc.to_dict()
    
    # Old structure ads have 'adId' field
    if 'adId' in doc_data:
        old_structure_ads.append(doc)
    # Month documents have 'totalAds' field
    elif 'totalAds' in doc_data:
        month_docs.append(doc)
    else:
        unknown_docs.append(doc)

print(f'\n📱 Old structure ads: {len(old_structure_ads)}')
print(f'📅 Month documents: {len(month_docs)}')
print(f'❓ Unknown documents: {len(unknown_docs)}')

if len(month_docs) > 0:
    print('\n' + '='*80)
    print('MONTH DOCUMENTS')
    print('='*80)
    
    for month_doc in sorted(month_docs, key=lambda x: x.id):
        month_data = month_doc.to_dict()
        print(f'\n📅 Month: {month_doc.id}')
        print(f'   Total Ads: {month_data.get("totalAds", 0)}')
        print(f'   With Insights: {month_data.get("adsWithInsights", 0)}')
        print(f'   With GHL Data: {month_data.get("adsWithGHLData", 0)}')
        
        # Check if this looks like a valid month
        month_id = month_doc.id
        if month_id in ['_placeh', 'unknown', '_placeholder']:
            print(f'   ⚠️  INVALID MONTH ID!')
        elif not (len(month_id) == 7 and month_id[4] == '-'):
            print(f'   ⚠️  UNUSUAL MONTH FORMAT!')

if len(unknown_docs) > 0:
    print('\n' + '='*80)
    print('UNKNOWN DOCUMENTS')
    print('='*80)
    
    for doc in unknown_docs:
        print(f'\n❓ Document: {doc.id}')
        print(f'   Data: {doc.to_dict()}')

print('\n' + '='*80)
print('SUMMARY')
print('='*80)

print(f'\n📊 Structure Status:')
print(f'   Old structure (needs migration): {len(old_structure_ads)} ads')
print(f'   New structure (migrated): {len(month_docs)} months')

if len(old_structure_ads) > 0:
    print(f'\n✅ Ready to migrate {len(old_structure_ads)} ads')
    print(f'   Run: python3 migrate_to_month_structure.py')
else:
    print(f'\n✅ All ads have been migrated!')
    print(f'   Run: python3 verify_migration.py')

print('\n' + '='*80)

