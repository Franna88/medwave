#!/usr/bin/env python3
"""
Quick check of advertData collection status
"""

import firebase_admin
from firebase_admin import credentials, firestore

# Initialize Firebase
if not firebase_admin._apps:
    cred = credentials.Certificate('medx-ai-firebase-adminsdk-fbsvc-a86e7bd050.json')
    firebase_admin.initialize_app(cred)

db = firestore.client()

print('\n' + '='*80)
print('QUICK ADVERTDATA STATUS CHECK')
print('='*80)

# Get count of ads
print('\n📊 Counting ads in advertData...')
ads_ref = db.collection('advertData')
all_ads = list(ads_ref.stream())

total_ads = len(all_ads)
print(f'✅ Total ads: {total_ads}')

# Sample first 5 ads to check structure
print('\n🔍 Sampling first 5 ads...')
sample_ads = all_ads[:5]

for i, ad in enumerate(sample_ads, 1):
    ad_data = ad.to_dict()
    ad_name = ad_data.get('adName', 'N/A')[:50]
    campaign_name = ad_data.get('campaignName', 'N/A')[:30]
    
    # Quick check for subcollections
    insights_count = len(list(ad.reference.collection('insights').limit(1).stream()))
    ghl_count = len(list(ad.reference.collection('ghlWeekly').limit(1).stream()))
    
    print(f'\n   Ad {i}: {ad.id}')
    print(f'      Name: {ad_name}')
    print(f'      Campaign: {campaign_name}')
    print(f'      Has insights: {"✅" if insights_count > 0 else "❌"}')
    print(f'      Has GHL data: {"✅" if ghl_count > 0 else "❌"}')

print('\n' + '='*80)
print('RECOMMENDATION')
print('='*80)
print(f'\n✅ You have {total_ads} Facebook ads in advertData')
print(f'\n🔄 NEXT STEP: Run populate_ghl_data.py to match GHL opportunities')
print(f'   Command: cd /Users/mac/dev/medwave && python3 populate_ghl_data.py')
print(f'\n   This will:')
print(f'   - Fetch all 6,641 opportunities from GHL API')
print(f'   - Match them to your {total_ads} Facebook ads')
print(f'   - Update weekly GHL metrics (safe - uses merge=True)')
print('\n' + '='*80)

