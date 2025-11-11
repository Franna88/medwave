#!/usr/bin/env python3
"""
Backfill missing Facebook insights for ads in advertData collection
Identifies ads without insights subcollection and fetches their data
"""

import requests
import firebase_admin
from firebase_admin import credentials, firestore
from datetime import datetime, timedelta
import time

# Initialize Firebase
try:
    cred = credentials.Certificate('medx-ai-firebase-adminsdk-fbsvc-a86e7bd050.json')
    firebase_admin.initialize_app(cred)
except:
    pass

db = firestore.client()

# Facebook API Configuration
FB_ACCESS_TOKEN = "EAAc9pw8rgA0BP0S8U9s2cLzSJbCYmJZBKZCTFUNDD2zVXVqkC45q1BIQaPdZAmtXKbZBk6wjprLclIUUafHJ4icQZAXuuePybTL38pNQIcjQQZCbRGGhAtLcLVSGeJP59nMdpt8KNEoMQtvDfZBwBgpLNhQboPpaaeU8fW2rCEEhZA9pRN4RjZAAnwnLqEDaP8Fueo0cZD"
FB_API_VERSION = "v24.0"

def calculate_week_id(date_str):
    """Calculate week ID from date string (YYYY-MM-DD)"""
    date = datetime.strptime(date_str, '%Y-%m-%d')
    days_since_monday = date.weekday()
    monday = date - timedelta(days=days_since_monday)
    sunday = monday + timedelta(days=6)
    
    monday_str = monday.strftime('%Y-%m-%d')
    sunday_str = sunday.strftime('%Y-%m-%d')
    
    return f"{monday_str}_{sunday_str}"

def check_ad_has_insights(ad_id):
    """Check if an ad has insights subcollection"""
    insights_ref = db.collection('advertData').document(ad_id).collection('insights')
    insights = insights_ref.limit(1).get()
    return len(insights) > 0

def fetch_insights_for_ad(ad_id, start_date='2025-10-01', end_date='2025-11-30'):
    """Fetch weekly insights from Facebook for a specific ad"""
    
    headers = {
        'Authorization': f'Bearer {FB_ACCESS_TOKEN}'
    }
    
    insights_url = f'https://graph.facebook.com/{FB_API_VERSION}/{ad_id}/insights'
    insights_params = {
        'time_range': f'{{"since":"{start_date}","until":"{end_date}"}}',
        'time_increment': 7,  # Weekly
        'fields': 'spend,impressions,reach,clicks,cpm,cpc,ctr,date_start,date_stop',
        'limit': 100
    }
    
    try:
        response = requests.get(insights_url, headers=headers, params=insights_params)
        response.raise_for_status()
        insights = response.json().get('data', [])
        return insights
    except Exception as e:
        print(f'      ⚠️  Error fetching insights: {e}')
        return None

def store_insights_for_ad(ad_id, insights):
    """Store insights in Firebase"""
    if not insights:
        return 0
    
    ad_ref = db.collection('advertData').document(ad_id)
    count = 0
    
    for insight in insights:
        week_id = calculate_week_id(insight['date_start'])
        
        insight_ref = ad_ref.collection('insights').document(week_id)
        insight_ref.set({
            'dateStart': insight['date_start'],
            'dateStop': insight['date_stop'],
            'spend': float(insight.get('spend', 0)),
            'impressions': int(insight.get('impressions', 0)),
            'reach': int(insight.get('reach', 0)),
            'clicks': int(insight.get('clicks', 0)),
            'cpm': float(insight.get('cpm', 0)),
            'cpc': float(insight.get('cpc', 0)),
            'ctr': float(insight.get('ctr', 0)),
            'fetchedAt': firestore.SERVER_TIMESTAMP
        })
        count += 1
    
    # Update lastFacebookSync
    ad_ref.update({
        'lastFacebookSync': firestore.SERVER_TIMESTAMP
    })
    
    return count

def backfill_missing_insights():
    """Main function to backfill missing Facebook insights"""
    
    print('\n' + '='*80)
    print('BACKFILL MISSING FACEBOOK INSIGHTS')
    print('='*80 + '\n')
    
    # Step 1: Get all ads from advertData
    print('📊 Step 1: Scanning advertData collection...\n')
    
    ads_ref = db.collection('advertData')
    all_ads = ads_ref.get()
    
    total_ads = len(all_ads)
    print(f'✅ Found {total_ads} ads in advertData\n')
    
    # Step 2: Identify ads without insights
    print('🔍 Step 2: Identifying ads without insights...\n')
    
    ads_without_insights = []
    ads_with_insights = []
    
    for ad_doc in all_ads:
        ad_id = ad_doc.id
        ad_data = ad_doc.to_dict()
        ad_name = ad_data.get('adName', 'Unknown')
        
        has_insights = check_ad_has_insights(ad_id)
        
        if has_insights:
            ads_with_insights.append({
                'adId': ad_id,
                'adName': ad_name
            })
        else:
            ads_without_insights.append({
                'adId': ad_id,
                'adName': ad_name,
                'campaignName': ad_data.get('campaignName', 'Unknown')
            })
    
    print(f'✅ Ads WITH insights: {len(ads_with_insights)}')
    print(f'❌ Ads WITHOUT insights: {len(ads_without_insights)}\n')
    
    if len(ads_without_insights) == 0:
        print('🎉 All ads already have insights!')
        return
    
    # Step 3: Fetch and store insights for missing ads
    print('📥 Step 3: Fetching missing insights from Facebook...\n')
    
    success_count = 0
    no_data_count = 0
    error_count = 0
    
    for i, ad in enumerate(ads_without_insights, 1):
        ad_id = ad['adId']
        ad_name = ad['adName']
        
        print(f'[{i}/{len(ads_without_insights)}] Processing: {ad_name[:50]}')
        print(f'   Ad ID: {ad_id}')
        print(f'   Campaign: {ad["campaignName"]}')
        
        # Fetch insights
        insights = fetch_insights_for_ad(ad_id)
        
        if insights is None:
            print(f'   ❌ Error fetching insights\n')
            error_count += 1
            continue
        
        if len(insights) == 0:
            print(f'   ⚠️  No insights data available (ad may not have run in Oct-Nov)\n')
            no_data_count += 1
            continue
        
        # Store insights
        weeks_stored = store_insights_for_ad(ad_id, insights)
        print(f'   ✅ Stored {weeks_stored} weeks of insights\n')
        success_count += 1
        
        # Rate limiting
        time.sleep(0.5)
    
    # Summary
    print('='*80)
    print('BACKFILL COMPLETE!')
    print('='*80 + '\n')
    
    print(f'📊 Summary:')
    print(f'   Total ads scanned: {total_ads}')
    print(f'   Ads already had insights: {len(ads_with_insights)}')
    print(f'   Ads missing insights: {len(ads_without_insights)}')
    print(f'   Successfully backfilled: {success_count}')
    print(f'   No data available: {no_data_count}')
    print(f'   Errors: {error_count}')
    print('\n' + '='*80 + '\n')
    
    # List ads that still have no data
    if no_data_count > 0:
        print('⚠️  Ads with no insights data (may not have run in Oct-Nov):')
        for ad in ads_without_insights:
            insights = fetch_insights_for_ad(ad['adId'])
            if insights is not None and len(insights) == 0:
                print(f'   - {ad["adName"]} ({ad["adId"]})')
        print()

if __name__ == '__main__':
    backfill_missing_insights()

