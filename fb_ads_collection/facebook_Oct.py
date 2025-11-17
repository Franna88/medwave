#!/usr/bin/env python3
"""
Facebook Ads Collection - October 2025
Fetches all Facebook ads for October 2025 and stores them in Firestore collection 'fb_ads'
Each ad is stored with its adId as the document ID and contains the complete payload
"""

import requests
import firebase_admin
from firebase_admin import credentials, firestore
from datetime import datetime
import time
import json

# Initialize Firebase
try:
    cred = credentials.Certificate('../medx-ai-firebase-adminsdk-fbsvc-a86e7bd050.json')
    firebase_admin.initialize_app(cred)
    print('✅ Firebase initialized successfully\n')
except Exception as e:
    print(f'⚠️  Firebase already initialized or error: {e}\n')
    pass

db = firestore.client()

# Facebook API Configuration
FB_ACCESS_TOKEN = "EAAc9pw8rgA0BP0S8U9s2cLzSJbCYmJZBKZCTFUNDD2zVXVqkC45q1BIQaPdZAmtXKbZBk6wjprLclIUUafHJ4icQZAXuuePybTL38pNQIcjQQZCbRGGhAtLcLVSGeJP59nMdpt8KNEoMQtvDfZBwBgpLNhQboPpaaeU8fW2rCEEhZA9pRN4RjZAAnwnLqEDaP8Fueo0cZD"
FB_AD_ACCOUNT_ID = "act_220298027464902"
FB_API_VERSION = "v24.0"

# Date range for October 2025
START_DATE = '2025-10-01'
END_DATE = '2025-10-31'

def validate_facebook_token():
    """Validate Facebook Access Token"""
    print('🔑 Validating Facebook Access Token...\n')
    
    headers = {
        'Authorization': f'Bearer {FB_ACCESS_TOKEN}'
    }
    
    test_url = f'https://graph.facebook.com/{FB_API_VERSION}/me'
    
    try:
        response = requests.get(test_url, headers=headers, params={'fields': 'id,name'})
        
        if response.status_code == 200:
            data = response.json()
            print(f'✅ Token valid for: {data.get("name", "Unknown")}\n')
            return True
        else:
            print(f'❌ Token validation failed: {response.status_code}')
            print(f'Response: {response.text}\n')
            return False
    except Exception as e:
        print(f'❌ Error validating token: {e}\n')
        return False

def fetch_ad_insights_summary(ad_id, start_date, end_date):
    """Fetch aggregated summary insights for the entire period"""
    url = f'https://graph.facebook.com/{FB_API_VERSION}/{ad_id}/insights'
    
    fields = [
        'ad_id',
        'ad_name',
        'campaign_id',
        'campaign_name',
        'adset_id',
        'adset_name',
        'impressions',
        'clicks',
        'spend',
        'reach',
        'frequency',
        'cpc',
        'cpm',
        'cpp',
        'ctr',
        'actions',
        'action_values',
        'cost_per_action_type',
        'date_start',
        'date_stop'
    ]
    
    params = {
        'access_token': FB_ACCESS_TOKEN,
        'time_range': json.dumps({'since': start_date, 'until': end_date}),
        'fields': ','.join(fields),
        'level': 'ad'
        # No time_increment = aggregated summary
    }
    
    try:
        response = requests.get(url, params=params, timeout=30)
        
        if response.status_code == 200:
            return response.json()
        else:
            print(f'   ⚠️  Failed to fetch summary insights for ad {ad_id}: {response.status_code}')
            return {'data': []}
    except Exception as e:
        print(f'   ⚠️  Error fetching summary insights for ad {ad_id}: {e}')
        return {'data': []}

def fetch_ad_insights_daily(ad_id, start_date, end_date):
    """Fetch daily breakdown insights"""
    url = f'https://graph.facebook.com/{FB_API_VERSION}/{ad_id}/insights'
    
    fields = [
        'ad_id',
        'ad_name',
        'campaign_id',
        'campaign_name',
        'adset_id',
        'adset_name',
        'impressions',
        'clicks',
        'spend',
        'reach',
        'frequency',
        'cpc',
        'cpm',
        'cpp',
        'ctr',
        'actions',
        'action_values',
        'cost_per_action_type',
        'date_start',
        'date_stop'
    ]
    
    params = {
        'access_token': FB_ACCESS_TOKEN,
        'time_range': json.dumps({'since': start_date, 'until': end_date}),
        'fields': ','.join(fields),
        'level': 'ad',
        'time_increment': 1  # Daily breakdown
    }
    
    try:
        response = requests.get(url, params=params, timeout=30)
        
        if response.status_code == 200:
            return response.json()
        else:
            print(f'   ⚠️  Failed to fetch daily insights for ad {ad_id}: {response.status_code}')
            return {'data': []}
    except Exception as e:
        print(f'   ⚠️  Error fetching daily insights for ad {ad_id}: {e}')
        return {'data': []}

def fetch_ads_with_activity():
    """Fetch all ads that had activity in October 2025"""
    print('='*80)
    print('FACEBOOK ADS COLLECTION - OCTOBER 2025')
    print('='*80 + '\n')
    
    print(f'📅 Date Range: {START_DATE} to {END_DATE}')
    print(f'📊 Ad Account: {FB_AD_ACCOUNT_ID}')
    print(f'🔗 API Version: {FB_API_VERSION}\n')
    
    # Validate token first
    if not validate_facebook_token():
        print('❌ Cannot proceed without valid token\n')
        return
    
    print('='*80)
    print('STEP 1: FETCHING ADS WITH ACTIVITY IN OCTOBER 2025')
    print('='*80 + '\n')
    
    # Use insights endpoint to find ads with activity
    url = f'https://graph.facebook.com/{FB_API_VERSION}/{FB_AD_ACCOUNT_ID}/insights'
    
    params = {
        'access_token': FB_ACCESS_TOKEN,
        'time_range': json.dumps({'since': START_DATE, 'until': END_DATE}),
        'level': 'ad',
        'fields': 'ad_id,ad_name',
        'limit': 100
    }
    
    all_ad_ids = set()
    page_count = 0
    
    try:
        while True:
            page_count += 1
            print(f'📄 Fetching page {page_count}...')
            
            response = requests.get(url, params=params, timeout=30)
            
            if response.status_code != 200:
                print(f'❌ Error: {response.status_code}')
                print(f'Response: {response.text}\n')
                break
            
            data = response.json()
            insights = data.get('data', [])
            
            if not insights:
                print(f'   ✅ No more ads found\n')
                break
            
            for insight in insights:
                ad_id = insight.get('ad_id')
                if ad_id:
                    all_ad_ids.add(ad_id)
            
            print(f'   Found {len(insights)} ads on this page (Total unique: {len(all_ad_ids)})')
            
            # Check for next page
            paging = data.get('paging', {})
            next_url = paging.get('next')
            
            if not next_url:
                print(f'   ✅ Reached last page\n')
                break
            
            url = next_url
            params = {}  # Next URL already has all params
            time.sleep(0.5)
            
    except Exception as e:
        print(f'❌ Error fetching ads: {e}\n')
    
    print(f'✅ Total ads with activity in October 2025: {len(all_ad_ids)}\n')
    
    if not all_ad_ids:
        print('⚠️  No ads found with activity in October 2025\n')
        return
    
    # Step 2: Fetch complete data for each ad
    print('='*80)
    print('STEP 2: FETCHING COMPLETE AD DATA')
    print('='*80 + '\n')
    
    stored_count = 0
    error_count = 0
    
    for i, ad_id in enumerate(all_ad_ids, 1):
        try:
            print(f'📄 {i}/{len(all_ad_ids)} - Processing ad {ad_id}...')
            
            # Fetch ad details
            ad_url = f'https://graph.facebook.com/{FB_API_VERSION}/{ad_id}'
            ad_params = {
                'access_token': FB_ACCESS_TOKEN,
                'fields': 'id,name,status,effective_status,creative,campaign_id,adset_id,created_time,updated_time'
            }
            
            ad_response = requests.get(ad_url, params=ad_params, timeout=30)
            
            if ad_response.status_code != 200:
                print(f'   ⚠️  Failed to fetch ad details: {ad_response.status_code}')
                error_count += 1
                continue
            
            ad = ad_response.json()
            ad_name = ad.get('name', 'Unknown')
            
            # Get ad details
            ad_details = {
                'id': ad.get('id'),
                'name': ad.get('name'),
                'status': ad.get('status'),
                'effectiveStatus': ad.get('effective_status'),
                'campaignId': ad.get('campaign_id'),
                'adsetId': ad.get('adset_id'),
                'createdTime': ad.get('created_time'),
                'updatedTime': ad.get('updated_time'),
                'creative': ad.get('creative', {})
            }
            
            # Fetch aggregated summary insights
            print(f'   Fetching summary insights...')
            insights_summary = fetch_ad_insights_summary(ad_id, START_DATE, END_DATE)
            
            # Fetch daily breakdown insights
            print(f'   Fetching daily insights...')
            insights_daily = fetch_ad_insights_daily(ad_id, START_DATE, END_DATE)
            
            # Create complete ad data structure
            complete_ad_data = {
                'adId': ad_id,
                'adName': ad_name,
                'status': ad.get('status'),
                'effectiveStatus': ad.get('effective_status'),
                'adDetails': ad_details,
                'insightsSummary': insights_summary.get('data', []),  # Aggregated totals
                'insightsDaily': insights_daily.get('data', []),      # Daily breakdown
                'fetchedAt': datetime.now().isoformat(),
                'month': 'October',
                'year': 2025,
                'dateRange': {
                    'start': START_DATE,
                    'end': END_DATE
                }
            }
            
            # Store in Firestore
            doc_ref = db.collection('fb_ads').document(ad_id)
            doc_ref.set(complete_ad_data)
            
            stored_count += 1
            
            # Show summary
            summary_data = insights_summary.get('data', [])
            if summary_data and len(summary_data) > 0:
                summary = summary_data[0]
                impressions = summary.get('impressions', 0)
                clicks = summary.get('clicks', 0)
                spend = summary.get('spend', 0)
                print(f'   ✅ Stored: {ad_name[:40]} - Impressions: {impressions}, Clicks: {clicks}, Spend: ${spend}')
            else:
                print(f'   ✅ Stored: {ad_name[:40]} - No insights data')
            
            time.sleep(0.3)
            
        except Exception as e:
            error_count += 1
            print(f'   ❌ Error processing ad {ad_id}: {e}')
    
    # Summary
    print('\n' + '='*80)
    print('COLLECTION COMPLETE')
    print('='*80 + '\n')
    
    print(f'📊 Summary:')
    print(f'   Total ads with activity: {len(all_ad_ids)}')
    print(f'   Successfully stored: {stored_count}')
    print(f'   Errors: {error_count}')
    print(f'\n   Collection: fb_ads')
    print(f'   Document ID format: adId (Facebook Ad ID)')
    print(f'   Month: October 2025')
    print(f'   Fields include:')
    print(f'     - adDetails: Complete ad information')
    print(f'     - insightsSummary: Aggregated totals for the month')
    print(f'     - insightsDaily: Daily breakdown of performance')
    print(f'\n✅ All October 2025 Facebook ads stored in Firestore!\n')


if __name__ == '__main__':
    fetch_ads_with_activity()



