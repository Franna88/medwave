#!/usr/bin/env python3
"""
TEST - Populate first 10 ads only (no GHL data)
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
print('TEST - POPULATE FIRST 10 ADS ONLY')
print('='*80 + '\n')

# Get first 10 ads from adPerformance
ad_perf_docs = list(db.collection('adPerformance').limit(10).stream())
print(f'Found {len(ad_perf_docs)} ads to migrate\n')

for i, ad_doc in enumerate(ad_perf_docs, 1):
    ad_id = ad_doc.id
    ad_data = ad_doc.to_dict()
    
    print(f'{i}. Migrating: {ad_data.get("adName", ad_id)[:50]}')
    print(f'   Ad ID: {ad_id}')
    
    # Create clean advertData document
    advert_ref = db.collection('advertData').document(ad_id)
    advert_ref.set({
        'campaignId': ad_data.get('campaignId', ''),
        'campaignName': ad_data.get('campaignName', ''),
        'adSetId': ad_data.get('adSetId', ''),
        'adSetName': ad_data.get('adSetName', ''),
        'adId': ad_id,
        'adName': ad_data.get('adName', ''),
        'lastUpdated': firestore.SERVER_TIMESTAMP,
        'lastFacebookSync': ad_data.get('lastFacebookSync'),
        'createdAt': firestore.SERVER_TIMESTAMP
    })
    
    print(f'   ✅ Created main document')
    
    # Create empty ghlWeekly subcollection with a placeholder
    # (Firestore doesn't show empty subcollections, so we add a test doc)
    test_week_ref = advert_ref.collection('ghlWeekly').document('_placeholder')
    test_week_ref.set({
        'note': 'This is a placeholder. Real data will come from GHL API.',
        'createdAt': firestore.SERVER_TIMESTAMP
    })
    print(f'   ✅ Created ghlWeekly subcollection (placeholder)')
    
    # Create empty insights subcollection with a placeholder
    test_insight_ref = advert_ref.collection('insights').document('_placeholder')
    test_insight_ref.set({
        'note': 'This is a placeholder. Real data will come from Facebook API.',
        'createdAt': firestore.SERVER_TIMESTAMP
    })
    print(f'   ✅ Created insights subcollection (placeholder)')
    
    print(f'   📍 Firebase path: advertData/{ad_id}')
    print()

print('='*80)
print('TEST COMPLETE!')
print('='*80 + '\n')

print('✅ Created 10 ads with correct structure:')
print('   - Main document with ad info')
print('   - ghlWeekly/ subcollection (with placeholder)')
print('   - insights/ subcollection (with placeholder)')
print('\n📋 Check in Firebase Console:')
print('   https://console.firebase.google.com/project/medx-ai/firestore/databases/-default-/data/~2FadvertData')
print('\nYou should see:')
print('   1. 10 ad documents')
print('   2. Each has 2 subcollections: ghlWeekly and insights')
print('   3. Each subcollection has a _placeholder document')
print('\n' + '='*80 + '\n')

