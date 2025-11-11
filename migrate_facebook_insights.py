#!/usr/bin/env python3
"""
Migrate Facebook insights from adPerformance to advertData/insights
"""

import firebase_admin
from firebase_admin import credentials, firestore
from datetime import datetime, timedelta

# Initialize Firebase
try:
    cred = credentials.Certificate('medx-ai-firebase-adminsdk-fbsvc-a86e7bd050.json')
    firebase_admin.initialize_app(cred)
except:
    pass

db = firestore.client()

print('\n' + '='*80)
print('MIGRATE FACEBOOK INSIGHTS TO ADVERTDATA')
print('='*80 + '\n')

# Get all ads from adPerformance that have insights
print('Fetching ads from adPerformance...')
ad_perf_ref = db.collection('adPerformance')
ad_perf_docs = list(ad_perf_ref.stream())

print(f'Found {len(ad_perf_docs)} ads in adPerformance\n')

migrated_count = 0
insights_count = 0
errors = 0

for i, ad_doc in enumerate(ad_perf_docs, 1):
    ad_id = ad_doc.id
    ad_data = ad_doc.to_dict()
    
    # Check if ad exists in advertData
    advert_ref = db.collection('advertData').document(ad_id)
    if not advert_ref.get().exists:
        continue
    
    # Get insights from adPerformance
    insights_data = ad_data.get('insights', {})
    
    if not insights_data:
        continue
    
    try:
        # Write each week's insights to advertData/insights subcollection
        for week_id, week_data in insights_data.items():
            # Create insights document
            insights_ref = advert_ref.collection('insights').document(week_id)
            
            insights_ref.set({
                'dateStart': week_data.get('dateStart', ''),
                'dateStop': week_data.get('dateStop', ''),
                'spend': float(week_data.get('spend', 0)),
                'impressions': int(week_data.get('impressions', 0)),
                'reach': int(week_data.get('reach', 0)),
                'clicks': int(week_data.get('clicks', 0)),
                'cpm': float(week_data.get('cpm', 0)),
                'cpc': float(week_data.get('cpc', 0)),
                'ctr': float(week_data.get('ctr', 0)),
                'fetchedAt': firestore.SERVER_TIMESTAMP
            }, merge=True)
            
            insights_count += 1
        
        migrated_count += 1
        
        if migrated_count % 50 == 0:
            print(f'✅ Migrated {migrated_count} ads, {insights_count} weekly insights...')
            
    except Exception as e:
        errors += 1
        print(f'❌ Error migrating ad {ad_id}: {e}')
    
    if i % 100 == 0:
        print(f'   Progress: {i}/{len(ad_perf_docs)} processed...')

print('\n' + '='*80)
print('MIGRATION COMPLETE')
print('='*80 + '\n')

print(f'Total ads processed: {len(ad_perf_docs)}')
print(f'Ads migrated: {migrated_count}')
print(f'Weekly insights created: {insights_count}')
print(f'Errors: {errors}')

print('\n' + '='*80)

