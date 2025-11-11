#!/usr/bin/env python3
"""
Quick review of October & November 2025 ads
Fast version - samples data instead of checking all ads
"""

import firebase_admin
from firebase_admin import credentials, firestore
from datetime import datetime

# Initialize Firebase
if not firebase_admin._apps:
    cred = credentials.Certificate('medx-ai-firebase-adminsdk-fbsvc-a86e7bd050.json')
    firebase_admin.initialize_app(cred)

db = firestore.client()

print('\n' + '='*80)
print('QUICK OCTOBER & NOVEMBER 2025 ADS REVIEW')
print('='*80)

# Get all ads (just basic info, no subcollections yet)
print('\n📊 Fetching ads from advertData...')
ads_ref = db.collection('advertData')
all_ads = list(ads_ref.stream())

print(f'✅ Total ads in collection: {len(all_ads)}')

# Sample first 50 ads to check for Oct/Nov data
print('\n🔍 Sampling first 50 ads to find Oct/Nov 2025 data...')

oct_nov_count = 0
sample_ads = []

for i, ad in enumerate(all_ads[:50]):
    ad_data = ad.to_dict()
    
    # Check campaign name for date indicators
    campaign_name = ad_data.get('campaignName', '')
    ad_name = ad_data.get('adName', '')
    
    # Quick check: look for "2025" and month indicators in names
    is_oct_nov = False
    if '2025' in campaign_name or '2025' in ad_name:
        # Check for October or November indicators
        if any(month in campaign_name.lower() or month in ad_name.lower() 
               for month in ['10', '11', 'oct', 'nov', 'october', 'november']):
            is_oct_nov = True
    
    # Also check insights date if available
    insights_ref = ad.reference.collection('insights')
    insights = list(insights_ref.limit(1).stream())
    
    if insights and not is_oct_nov:
        insight_data = insights[0].to_dict()
        date_start = insight_data.get('dateStart', '')
        if date_start and ('2025-10' in date_start or '2025-11' in date_start):
            is_oct_nov = True
    
    if is_oct_nov:
        oct_nov_count += 1
        
        # Get counts for this ad
        insights_count = len(list(insights_ref.limit(10).stream()))
        ghl_ref = ad.reference.collection('ghlWeekly')
        ghl_count = len(list(ghl_ref.limit(10).stream()))
        
        sample_ads.append({
            'id': ad.id,
            'campaignName': campaign_name[:50],
            'adSetName': ad_data.get('adSetName', 'N/A')[:40],
            'adName': ad_name[:50],
            'insights': insights_count,
            'ghlWeeks': ghl_count,
            'hasData': insights_count > 0 and ghl_count > 0
        })

print(f'✅ Found {oct_nov_count} Oct/Nov 2025 ads in first 50 samples')

# Estimate total
estimated_total = int((oct_nov_count / 50) * len(all_ads))
print(f'📊 Estimated total Oct/Nov ads: ~{estimated_total} (based on sample)')

# Show sample ads
print('\n' + '='*80)
print('SAMPLE ADS FROM OCTOBER & NOVEMBER 2025')
print('='*80)

for i, ad in enumerate(sample_ads[:10], 1):
    status = '✅' if ad['hasData'] else '⚠️'
    print(f'\n{status} Ad {i}:')
    print(f'   Campaign: {ad["campaignName"]}')
    print(f'   Ad Set: {ad["adSetName"]}')
    print(f'   Ad Name: {ad["adName"]}')
    print(f'   Insights: {ad["insights"]} weeks, GHL: {ad["ghlWeeks"]} weeks')

# Quick stats
ads_with_both = sum(1 for ad in sample_ads if ad['hasData'])
ads_with_insights = sum(1 for ad in sample_ads if ad['insights'] > 0)
ads_with_ghl = sum(1 for ad in sample_ads if ad['ghlWeeks'] > 0)

print('\n' + '='*80)
print('SAMPLE STATISTICS')
print('='*80)
print(f'\n📊 From {oct_nov_count} Oct/Nov ads sampled:')
print(f'   ✅ With Facebook insights: {ads_with_insights} ({ads_with_insights/oct_nov_count*100:.1f}%)')
print(f'   ✅ With GHL data: {ads_with_ghl} ({ads_with_ghl/oct_nov_count*100:.1f}%)')
print(f'   ✅ With BOTH: {ads_with_both} ({ads_with_both/oct_nov_count*100:.1f}%)')

# Recommendation
print('\n' + '='*80)
print('RECOMMENDATION')
print('='*80)

if ads_with_both > 0:
    print(f'\n✅ DATA IS READY FOR FRONTEND!')
    print(f'   - Estimated ~{estimated_total} Oct/Nov ads in collection')
    print(f'   - {ads_with_both/oct_nov_count*100:.1f}% have both insights and GHL data')
    print(f'   - Can start building UI with this data')
    print(f'\n🔄 NEXT STEP: Run populate_ghl_data.py to improve GHL coverage')
    print(f'   Command: cd /Users/mac/dev/medwave && python3 populate_ghl_data.py')
else:
    print(f'\n⚠️  LIMITED DATA')
    print(f'   - {ads_with_insights} ads have insights')
    print(f'   - {ads_with_ghl} ads have GHL data')
    print(f'   - Need to run populate_ghl_data.py to match GHL data')

print('\n' + '='*80)

