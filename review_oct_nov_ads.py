#!/usr/bin/env python3
"""
Review October & November 2025 ads in Firebase
Show campaigns, ad sets, ads with insights and GHL data
"""

import firebase_admin
from firebase_admin import credentials, firestore
from datetime import datetime
from collections import defaultdict

# Initialize Firebase
if not firebase_admin._apps:
    cred = credentials.Certificate('medx-ai-firebase-adminsdk-fbsvc-a86e7bd050.json')
    firebase_admin.initialize_app(cred)

db = firestore.client()

print('\n' + '='*80)
print('OCTOBER & NOVEMBER 2025 ADS REVIEW')
print('='*80)

# Get all ads
print('\n📊 Fetching all ads from advertData...')
ads_ref = db.collection('advertData')
all_ads = list(ads_ref.stream())

print(f'✅ Total ads in collection: {len(all_ads)}')

# Filter to October & November 2025 ads
print('\n🔍 Filtering to October & November 2025 ads...')

oct_nov_ads = []
campaigns = defaultdict(lambda: {
    'adSets': defaultdict(lambda: {
        'ads': [],
        'totalInsights': 0,
        'totalGHLWeeks': 0
    }),
    'totalAds': 0,
    'totalInsights': 0,
    'totalGHLWeeks': 0
})

for ad in all_ads:
    ad_data = ad.to_dict()
    ad_id = ad.id
    
    # Get timestamps
    last_updated = ad_data.get('lastUpdated')
    last_fb_sync = ad_data.get('lastFacebookSync')
    
    # Check if this is an Oct/Nov 2025 ad by checking insights dates
    insights_ref = ad.reference.collection('insights')
    insights = list(insights_ref.limit(1).stream())
    
    if insights:
        insight_data = insights[0].to_dict()
        date_start = insight_data.get('dateStart', '')
        
        # Check if insight is from Oct or Nov 2025
        if date_start:
            try:
                insight_date = datetime.strptime(date_start, '%Y-%m-%d')
                if insight_date.year == 2025 and insight_date.month in [10, 11]:
                    is_oct_nov = True
                else:
                    is_oct_nov = False
            except:
                is_oct_nov = False
        else:
            is_oct_nov = False
    else:
        is_oct_nov = False
    
    if not is_oct_nov:
        continue
    
    # Get full insights count
    all_insights = list(insights_ref.stream())
    insights_count = len(all_insights)
    
    # Get GHL data count
    ghl_ref = ad.reference.collection('ghlWeekly')
    ghl_weeks = list(ghl_ref.stream())
    ghl_count = len(ghl_weeks)
    
    # Extract campaign and ad set info
    campaign_id = ad_data.get('campaignId', 'Unknown')
    campaign_name = ad_data.get('campaignName', 'Unknown')
    ad_set_id = ad_data.get('adSetId', 'Unknown')
    ad_set_name = ad_data.get('adSetName', 'Unknown')
    ad_name = ad_data.get('adName', 'Unknown')
    
    # Store ad info
    ad_info = {
        'id': ad_id,
        'name': ad_name,
        'insights': insights_count,
        'ghlWeeks': ghl_count,
        'hasData': insights_count > 0 and ghl_count > 0
    }
    
    # Organize by campaign and ad set
    campaigns[campaign_id]['name'] = campaign_name
    campaigns[campaign_id]['adSets'][ad_set_id]['name'] = ad_set_name
    campaigns[campaign_id]['adSets'][ad_set_id]['ads'].append(ad_info)
    campaigns[campaign_id]['adSets'][ad_set_id]['totalInsights'] += insights_count
    campaigns[campaign_id]['adSets'][ad_set_id]['totalGHLWeeks'] += ghl_count
    campaigns[campaign_id]['totalAds'] += 1
    campaigns[campaign_id]['totalInsights'] += insights_count
    campaigns[campaign_id]['totalGHLWeeks'] += ghl_count
    
    oct_nov_ads.append(ad_info)

print(f'✅ Found {len(oct_nov_ads)} ads from October & November 2025')

# Display campaign hierarchy
print('\n' + '='*80)
print('CAMPAIGN HIERARCHY - OCTOBER & NOVEMBER 2025')
print('='*80)

total_campaigns = len(campaigns)
total_ad_sets = sum(len(c['adSets']) for c in campaigns.values())
total_ads = len(oct_nov_ads)
total_insights = sum(ad['insights'] for ad in oct_nov_ads)
total_ghl_weeks = sum(ad['ghlWeeks'] for ad in oct_nov_ads)
ads_with_both = sum(1 for ad in oct_nov_ads if ad['hasData'])

print(f'\n📊 Summary:')
print(f'   Campaigns: {total_campaigns}')
print(f'   Ad Sets: {total_ad_sets}')
print(f'   Ads: {total_ads}')
print(f'   Total Insights: {total_insights}')
print(f'   Total GHL Weeks: {total_ghl_weeks}')
print(f'   Ads with BOTH insights & GHL: {ads_with_both} ({ads_with_both/total_ads*100:.1f}%)')

# Show first 5 campaigns in detail
print('\n' + '='*80)
print('DETAILED VIEW - FIRST 5 CAMPAIGNS')
print('='*80)

for i, (campaign_id, campaign_data) in enumerate(list(campaigns.items())[:5], 1):
    campaign_name = campaign_data['name']
    total_ads = campaign_data['totalAds']
    total_insights = campaign_data['totalInsights']
    total_ghl = campaign_data['totalGHLWeeks']
    
    print(f'\n📁 Campaign {i}: {campaign_name[:60]}')
    print(f'   ID: {campaign_id}')
    print(f'   Total Ads: {total_ads}')
    print(f'   Total Insights: {total_insights}')
    print(f'   Total GHL Weeks: {total_ghl}')
    print(f'   Ad Sets: {len(campaign_data["adSets"])}')
    
    # Show first 2 ad sets
    for j, (ad_set_id, ad_set_data) in enumerate(list(campaign_data['adSets'].items())[:2], 1):
        ad_set_name = ad_set_data['name']
        ads_count = len(ad_set_data['ads'])
        insights_count = ad_set_data['totalInsights']
        ghl_count = ad_set_data['totalGHLWeeks']
        
        print(f'\n   📂 Ad Set {j}: {ad_set_name[:50]}')
        print(f'      ID: {ad_set_id}')
        print(f'      Ads: {ads_count}')
        print(f'      Insights: {insights_count}')
        print(f'      GHL Weeks: {ghl_count}')
        
        # Show first 3 ads
        for k, ad in enumerate(ad_set_data['ads'][:3], 1):
            status = '✅' if ad['hasData'] else '⚠️'
            print(f'      {status} Ad {k}: {ad["name"][:40]}')
            print(f'         Insights: {ad["insights"]}, GHL: {ad["ghlWeeks"]} weeks')

# Show ads with most GHL data
print('\n' + '='*80)
print('TOP 10 ADS WITH MOST GHL DATA')
print('='*80)

sorted_ads = sorted(oct_nov_ads, key=lambda x: x['ghlWeeks'], reverse=True)[:10]

for i, ad in enumerate(sorted_ads, 1):
    status = '✅' if ad['hasData'] else '⚠️'
    print(f'\n{status} {i}. {ad["name"][:60]}')
    print(f'   ID: {ad["id"]}')
    print(f'   Insights: {ad["insights"]} weeks')
    print(f'   GHL Data: {ad["ghlWeeks"]} weeks')

# Recommendation
print('\n' + '='*80)
print('RECOMMENDATION FOR FRONTEND')
print('='*80)

if ads_with_both > 0:
    print(f'\n✅ READY FOR FRONTEND!')
    print(f'   {ads_with_both} ads have both Facebook insights and GHL data')
    print(f'   Coverage: {ads_with_both/total_ads*100:.1f}% of Oct/Nov ads')
    print(f'\n📊 Data Structure:')
    print(f'   - {total_campaigns} campaigns to display')
    print(f'   - {total_ad_sets} ad sets to display')
    print(f'   - {total_ads} ads to display')
    print(f'   - Weekly breakdown available for {ads_with_both} ads')
else:
    print(f'\n⚠️  NO DATA READY')
    print(f'   Need to run populate_ghl_data.py first')

print('\n' + '='*80)

