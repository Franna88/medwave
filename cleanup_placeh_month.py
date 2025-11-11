#!/usr/bin/env python3
"""
Clean up the _placeh month document that was created during migration
"""

import firebase_admin
from firebase_admin import credentials, firestore

# Initialize Firebase
if not firebase_admin._apps:
    cred = credentials.Certificate('medx-ai-firebase-adminsdk-fbsvc-a86e7bd050.json')
    firebase_admin.initialize_app(cred)

db = firestore.client()

print('\n' + '='*80)
print('CLEANUP _placeh MONTH DOCUMENT')
print('='*80)

# Check if _placeh exists
placeh_ref = db.collection('advertData').document('_placeh')
placeh_doc = placeh_ref.get()

if not placeh_doc.exists:
    print('\n✅ No _placeh document found. Nothing to clean up.')
    print('\n' + '='*80)
    exit(0)

print('\n❌ Found _placeh month document')
print(f'   Data: {placeh_doc.to_dict()}')

# Get all ads in _placeh
ads = list(placeh_ref.collection('ads').stream())
print(f'\n📊 Found {len(ads)} ads in _placeh month')

if len(ads) == 0:
    print('\n   No ads to delete, just removing the month document...')
    placeh_ref.delete()
    print('   ✅ Deleted _placeh document')
    print('\n' + '='*80)
    exit(0)

print('\n⚠️  WARNING: This will delete the _placeh month and all its ads!')
print(f'   Total ads to delete: {len(ads)}')
print('\n   These ads will need to be re-migrated with the fixed script.')

confirmation = input('\n   Type "DELETE PLACEH" to confirm: ')

if confirmation != 'DELETE PLACEH':
    print('\n❌ Deletion cancelled.')
    print('\n' + '='*80)
    exit(0)

print('\n🗑️  Deleting ads...')

# Delete each ad and its subcollections
for i, ad in enumerate(ads, 1):
    ad_ref = ad.reference
    
    # Delete insights subcollection
    insights = list(ad_ref.collection('insights').stream())
    for insight in insights:
        insight.reference.delete()
    
    # Delete ghlWeekly subcollection
    ghl_weeks = list(ad_ref.collection('ghlWeekly').stream())
    for week in ghl_weeks:
        week.reference.delete()
    
    # Delete the ad document
    ad_ref.delete()
    
    if i % 10 == 0:
        print(f'   Deleted {i}/{len(ads)} ads...')

print(f'   ✅ Deleted all {len(ads)} ads')

# Delete the month document
placeh_ref.delete()
print('   ✅ Deleted _placeh month document')

print('\n' + '='*80)
print('CLEANUP COMPLETE!')
print('='*80)
print('\n📋 Next Steps:')
print('   1. The _placeh month has been removed')
print('   2. The affected ads are still in the old structure')
print('   3. Re-run migrate_to_month_structure.py to properly migrate them')
print('   4. They will now be assigned to correct months')
print('\n' + '='*80)

