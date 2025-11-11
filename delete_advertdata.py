#!/usr/bin/env python3
"""
Clean slate - Delete advertData collection and rebuild properly
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
print('CLEAN SLATE - DELETE ADVERTDATA COLLECTION')
print('='*80 + '\n')

print('⚠️  This will DELETE all documents in the advertData collection.')
print('⚠️  This action cannot be undone!')
print('\nType "DELETE" to confirm: ', end='')

confirmation = input()

if confirmation != 'DELETE':
    print('\n❌ Aborted. No data was deleted.\n')
    exit(0)

print('\n🗑️  Deleting advertData collection...\n')

# Get all documents
adverts = list(db.collection('advertData').stream())
print(f'Found {len(adverts)} documents to delete\n')

deleted_count = 0
deleted_subcollections = 0

for advert in adverts:
    ad_id = advert.id
    
    # Delete all subcollections first
    # Delete ghlWeekly subcollection
    ghl_weekly_docs = list(db.collection('advertData').document(ad_id).collection('ghlWeekly').stream())
    for doc in ghl_weekly_docs:
        doc.reference.delete()
        deleted_subcollections += 1
    
    # Delete old ghlData/weekly/weekly structure if it exists
    try:
        weekly_docs = list(db.collection('advertData').document(ad_id)
                          .collection('ghlData').document('weekly')
                          .collection('weekly').stream())
        for doc in weekly_docs:
            doc.reference.delete()
            deleted_subcollections += 1
        
        # Delete the intermediate 'weekly' document
        db.collection('advertData').document(ad_id).collection('ghlData').document('weekly').delete()
    except:
        pass
    
    # Delete insights subcollection
    insights_docs = list(db.collection('advertData').document(ad_id).collection('insights').stream())
    for doc in insights_docs:
        doc.reference.delete()
        deleted_subcollections += 1
    
    # Delete the main document
    advert.reference.delete()
    deleted_count += 1
    
    if deleted_count % 100 == 0:
        print(f'   Deleted {deleted_count}/{len(adverts)} documents...')

print(f'\n✅ Deleted {deleted_count} main documents')
print(f'✅ Deleted {deleted_subcollections} subcollection documents')

print('\n' + '='*80)
print('COLLECTION DELETED - READY FOR FRESH START')
print('='*80 + '\n')

