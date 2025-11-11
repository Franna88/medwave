#!/usr/bin/env python3
"""
Find 10 ads that actually have data (Facebook insights OR GHL opportunities)
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

print('\n🔍 Finding ads with actual data...\n')

# Get ads from adPerformance that have insights
ad_perf_docs = list(db.collection('adPerformance').stream())

ads_with_data = []

for ad_doc in ad_perf_docs:
    ad_id = ad_doc.id
    ad_data = ad_doc.to_dict()
    
    insights = ad_data.get('insights', {})
    
    if insights and len(insights) > 0:
        ads_with_data.append({
            'id': ad_id,
            'name': ad_data.get('adName', 'N/A'),
            'campaign': ad_data.get('campaignName', 'N/A'),
            'insights_weeks': len(insights)
        })
    
    if len(ads_with_data) >= 10:
        break

print(f'✅ Found {len(ads_with_data)} ads with Facebook insights:\n')

for i, ad in enumerate(ads_with_data, 1):
    print(f'{i}. {ad["name"][:50]}')
    print(f'   ID: {ad["id"]}')
    print(f'   Campaign: {ad["campaign"][:60]}')
    print(f'   Insights weeks: {ad["insights_weeks"]}')
    print()

if ads_with_data:
    print('\n📋 These Ad IDs have data:')
    for ad in ads_with_data:
        print(f'   {ad["id"]}')
