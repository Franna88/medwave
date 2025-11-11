#!/usr/bin/env python3
"""
Check current status of advertData collection
"""

import firebase_admin
from firebase_admin import credentials, firestore

# Initialize Firebase
if not firebase_admin._apps:
    cred = credentials.Certificate('medx-ai-firebase-adminsdk-fbsvc-a86e7bd050.json')
    firebase_admin.initialize_app(cred)

db = firestore.client()

print('\n' + '='*80)
print('ADVERTDATA COLLECTION STATUS')
print('='*80)

# Get all ads
print('\n📊 Fetching all ads from advertData...')
ads_ref = db.collection('advertData')
all_ads = list(ads_ref.stream())

print(f'\n✅ Total ads in advertData: {len(all_ads)}')

# Check which ads have insights
print('\n🔍 Checking for Facebook insights...')
ads_with_insights = 0
ads_without_insights = 0

for ad in all_ads:
    insights_ref = ad.reference.collection('insights')
    insights = list(insights_ref.limit(1).stream())
    
    if insights:
        ads_with_insights += 1
    else:
        ads_without_insights += 1

print(f'   ✅ Ads with Facebook insights: {ads_with_insights}')
print(f'   ⚠️  Ads without Facebook insights: {ads_without_insights}')

# Check which ads have GHL data
print('\n🔍 Checking for GHL weekly data...')
ads_with_ghl = 0
ads_without_ghl = 0
total_ghl_weeks = 0

ads_with_ghl_list = []

for ad in all_ads:
    ghl_ref = ad.reference.collection('ghlWeekly')
    ghl_weeks = list(ghl_ref.stream())
    
    if ghl_weeks:
        ads_with_ghl += 1
        total_ghl_weeks += len(ghl_weeks)
        ads_with_ghl_list.append({
            'id': ad.id,
            'name': ad.to_dict().get('adName', 'N/A'),
            'weeks': len(ghl_weeks)
        })
    else:
        ads_without_ghl += 1

print(f'   ✅ Ads with GHL data: {ads_with_ghl}')
print(f'   ⚠️  Ads without GHL data: {ads_without_ghl}')
print(f'   📅 Total GHL weeks: {total_ghl_weeks}')

# Show sample of ads with GHL data
if ads_with_ghl_list:
    print('\n📋 Sample of ads with GHL data (first 10):')
    for i, ad in enumerate(ads_with_ghl_list[:10], 1):
        print(f'   {i}. {ad["id"][:20]}... - {ad["weeks"]} weeks - "{ad["name"][:50]}"')

# Summary
print('\n' + '='*80)
print('SUMMARY')
print('='*80)
print(f'\n📊 Total Facebook ads: {len(all_ads)}')
print(f'   ✅ With insights: {ads_with_insights} ({ads_with_insights/len(all_ads)*100:.1f}%)')
print(f'   ⚠️  Without insights: {ads_without_insights} ({ads_without_insights/len(all_ads)*100:.1f}%)')
print(f'\n💰 GHL Data Coverage:')
print(f'   ✅ Ads with GHL data: {ads_with_ghl} ({ads_with_ghl/len(all_ads)*100:.1f}%)')
print(f'   ⚠️  Ads without GHL data: {ads_without_ghl} ({ads_without_ghl/len(all_ads)*100:.1f}%)')
print(f'   📅 Total weekly data points: {total_ghl_weeks}')

# Recommendation
print('\n' + '='*80)
print('RECOMMENDATION')
print('='*80)

if ads_without_ghl > 0:
    print(f'\n✅ YES - Run populate_ghl_data.py again!')
    print(f'   Reason: {ads_without_ghl} ads without GHL data')
    print(f'   This will attempt to match the 1,562 unmatched opportunities')
    print(f'   to the {ads_without_ghl} ads that currently have no GHL data.')
else:
    print(f'\n⚠️  All ads already have GHL data')
    print(f'   Running again will update existing data (safe due to merge=True)')

print('\n' + '='*80)

