#!/usr/bin/env python3
"""
Facebook Ads Collection - December 2025
Fetches all Facebook ads for December 2025 and stores them in Firestore collection 'fb_ads'
Each ad is stored with its adId as the document ID and contains the complete payload
"""

import requests
import firebase_admin
from firebase_admin import credentials, firestore
from datetime import datetime
import time
import json
import os

# Initialize Firebase
try:
    # Get the directory where this script is located
    script_dir = os.path.dirname(os.path.abspath(__file__))
    
    # Try to find Firebase credentials file in common locations
    cred_paths = [
        os.path.join(script_dir, '..', 'ghl_opp_collection', 'medx-ai-firebase-adminsdk-fbsvc-d88a6aa1a7.json'),
        os.path.join(script_dir, '..', 'ghl_data_collection', 'medx-ai-firebase-adminsdk-fbsvc-d88a6aa1a7.json'),
        os.path.join(script_dir, '..', 'summary_collection', 'medx-ai-firebase-adminsdk-fbsvc-d88a6aa1a7.json'),
        os.path.join(script_dir, '..', 'medx-ai-firebase-adminsdk-fbsvc-a86e7bd050.json'),
        os.path.join(script_dir, '..', 'medx-ai-firebase-adminsdk-fbsvc-d88a6aa1a7.json')
    ]
    
    cred_path = None
    for path in cred_paths:
        if os.path.exists(path):
            cred_path = path
            break
    
    if not cred_path:
        raise FileNotFoundError(
            f"Firebase credentials file not found. Tried:\n" + 
            "\n".join(f"  - {p}" for p in cred_paths)
        )
    
    cred = credentials.Certificate(cred_path)
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

# Date range for December 2025
START_DATE = '2026-01-01'
END_DATE = '2026-01-31'

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
        elif response.status_code == 190 or response.status_code == 401:
            print('❌ Token expired or invalid!')
            print('   Please generate a new token from Facebook Graph API Explorer\n')
            return False
        else:
            print(f'⚠️  Token validation returned status {response.status_code}')
            print(f'   Response: {response.text[:200]}\n')
            return False
    except Exception as e:
        print(f'❌ Error validating token: {e}\n')
        return False


def fetch_ad_details(ad_id):
    """Fetch complete ad details including campaign, adset, creative, tracking specs"""
    url = f'https://graph.facebook.com/{FB_API_VERSION}/{ad_id}'
    
    params = {
        'access_token': FB_ACCESS_TOKEN,
        'fields': ','.join([
            'id',
            'name',
            'status',
            'effective_status',
            'configured_status',
            'created_time',
            'updated_time',
            'account_id',
            'campaign_id',
            'campaign{id,name,status,objective}',
            'adset_id',
            'adset{id,name,status,targeting,optimization_goal,billing_event,daily_budget,lifetime_budget}',
            'creative{id,name,thumbnail_url,object_story_spec}',
            'tracking_specs',
            'conversion_specs',
            'bid_type'
        ])
    }
    
    try:
        response = requests.get(url, params=params)
        response.raise_for_status()
        return response.json()
    except Exception as e:
        print(f'   ⚠️  Error fetching ad details: {e}')
        return None


def fetch_ad_insights_summary(ad_id, start_date, end_date):
    """Fetch aggregated summary insights for the entire period"""
    url = f'https://graph.facebook.com/{FB_API_VERSION}/{ad_id}/insights'
    
    # All available insight fields
    fields = [
        'account_id',
        'account_name',
        'ad_id',
        'ad_name',
        'adset_id',
        'adset_name',
        'campaign_id',
        'campaign_name',
        'objective',
        'buying_type',
        'optimization_goal',
        'impressions',
        'reach',
        'frequency',
        'clicks',
        'unique_clicks',
        'ctr',
        'unique_ctr',
        'inline_link_clicks',
        'inline_link_click_ctr',
        'unique_inline_link_clicks',
        'spend',
        'cpm',
        'cpc',
        'cpp',
        'cost_per_inline_link_click',
        'cost_per_unique_click',
        'cost_per_unique_inline_link_click',
        'actions',
        'cost_per_action_type',
        'video_play_actions',
        'video_avg_time_watched_actions',
        'video_p25_watched_actions',
        'video_p50_watched_actions',
        'video_p75_watched_actions',
        'video_p95_watched_actions',
        'video_p100_watched_actions',
        'video_30_sec_watched_actions',
        'social_spend',
        'attribution_setting',
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
        response = requests.get(url, params=params)
        response.raise_for_status()
        return response.json()
    except Exception as e:
        print(f'   ⚠️  Error fetching summary: {e}')
        return None


def fetch_ad_insights_daily(ad_id, start_date, end_date):
    """Fetch daily breakdown insights"""
    url = f'https://graph.facebook.com/{FB_API_VERSION}/{ad_id}/insights'
    
    # All available insight fields
    fields = [
        'account_id',
        'account_name',
        'ad_id',
        'ad_name',
        'adset_id',
        'adset_name',
        'campaign_id',
        'campaign_name',
        'objective',
        'buying_type',
        'optimization_goal',
        'impressions',
        'reach',
        'frequency',
        'clicks',
        'unique_clicks',
        'ctr',
        'unique_ctr',
        'inline_link_clicks',
        'inline_link_click_ctr',
        'unique_inline_link_clicks',
        'spend',
        'cpm',
        'cpc',
        'cpp',
        'cost_per_inline_link_click',
        'cost_per_unique_click',
        'cost_per_unique_inline_link_click',
        'actions',
        'cost_per_action_type',
        'video_play_actions',
        'video_avg_time_watched_actions',
        'video_p25_watched_actions',
        'video_p50_watched_actions',
        'video_p75_watched_actions',
        'video_p95_watched_actions',
        'video_p100_watched_actions',
        'video_30_sec_watched_actions',
        'social_spend',
        'attribution_setting',
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
        response = requests.get(url, params=params)
        response.raise_for_status()
        return response.json()
    except Exception as e:
        print(f'   ⚠️  Error fetching daily breakdown: {e}')
        return None


def fetch_all_ads_for_december():
    """Fetch all ads that ran in December 2025"""
    print('='*80)
    print('FACEBOOK ADS COLLECTION - DECEMBER 2025')
    print('='*80 + '\n')
    
    print(f'📅 Date Range: {START_DATE} to {END_DATE}')
    print(f'🎯 Ad Account: {FB_AD_ACCOUNT_ID}')
    print(f'📊 API Version: {FB_API_VERSION}\n')
    
    # Validate token first
    if not validate_facebook_token():
        print('❌ Cannot proceed without valid token. Exiting.\n')
        return
    
    print('='*80)
    print('STEP 1: FETCHING ADS WITH ACTIVITY IN DECEMBER')
    print('='*80 + '\n')
    
    # Use insights endpoint to find ads that actually ran in November
    # This is more accurate than the ads endpoint
    url = f'https://graph.facebook.com/{FB_API_VERSION}/{FB_AD_ACCOUNT_ID}/insights'
    
    params = {
        'access_token': FB_ACCESS_TOKEN,
        'level': 'ad',
        'fields': 'ad_id,ad_name',
        'time_range': json.dumps({'since': START_DATE, 'until': END_DATE}),
        'limit': 500  # Max per page
    }
    
    all_ads = []
    seen_ad_ids = set()
    page_count = 0
    
    try:
        while url:
            page_count += 1
            print(f'📄 Fetching page {page_count}...')
            
            response = requests.get(url, params=params)
            response.raise_for_status()
            data = response.json()
            
            insights = data.get('data', [])
            
            # Extract unique ads from insights
            for insight in insights:
                ad_id = insight.get('ad_id')
                if ad_id and ad_id not in seen_ad_ids:
                    seen_ad_ids.add(ad_id)
                    all_ads.append({
                        'id': ad_id,
                        'name': insight.get('ad_name', 'Unnamed Ad')
                    })
            
            print(f'   Found {len(insights)} insight records (unique ads so far: {len(all_ads)})')
            
            # Get next page URL
            url = data.get('paging', {}).get('next')
            params = {}  # Next URL already has params
            
            time.sleep(0.5)  # Rate limiting
        
        print(f'\n✅ Total unique ads with activity in December: {len(all_ads)}\n')
        
    except Exception as e:
        print(f'\n❌ Error fetching ads: {e}\n')
        return
    
    if len(all_ads) == 0:
        print('⚠️  No ads found for December 2025. Exiting.\n')
        return
    
    # Step 2: Fetch complete data for each ad
    print('='*80)
    print('STEP 2: FETCHING COMPLETE DATA FOR EACH AD')
    print('='*80 + '\n')
    
    ads_with_complete_data = []
    
    for i, ad in enumerate(all_ads, 1):
        ad_id = ad['id']
        ad_name = ad.get('name', 'Unnamed Ad')
        
        print(f'{i}/{len(all_ads)}. {ad_name[:60]}')
        print(f'   Ad ID: {ad_id}')
        
        # Fetch ad details
        print(f'   📦 Fetching ad details...')
        ad_details = fetch_ad_details(ad_id)
        
        if not ad_details:
            print(f'   ⚠️  Skipping ad (no details)\n')
            continue
        
        # Fetch aggregated summary insights
        print(f'   📊 Fetching summary insights...')
        insights_summary = fetch_ad_insights_summary(ad_id, START_DATE, END_DATE)
        
        if not insights_summary:
            print(f'   ⚠️  No summary data\n')
            insights_summary = {'data': []}
        
        # Fetch daily breakdown
        print(f'   📅 Fetching daily breakdown...')
        insights_daily = fetch_ad_insights_daily(ad_id, START_DATE, END_DATE)
        
        if not insights_daily:
            print(f'   ⚠️  No daily data\n')
            insights_daily = {'data': []}
        
        # Combine all data
        complete_ad_data = {
            'adId': ad_id,
            'adName': ad_name,
            'status': ad.get('status'),
            'effectiveStatus': ad.get('effective_status'),
            'adDetails': ad_details,
            'insightsSummary': insights_summary.get('data', []),  # Aggregated totals
            'insightsDaily': insights_daily.get('data', []),      # Daily breakdown
            'fetchedAt': datetime.now().isoformat(),
            'month': 'December',
            'year': 2025,
            'dateRange': {
                'start': START_DATE,
                'end': END_DATE
            }
        }
        
        ads_with_complete_data.append(complete_ad_data)
        
        summary_count = len(insights_summary.get('data', []))
        daily_count = len(insights_daily.get('data', []))
        print(f'   ✅ Complete data fetched (summary: {summary_count}, daily: {daily_count} records)\n')
        
        time.sleep(0.5)  # Rate limiting
    
    # Step 3: Store in Firestore
    print('='*80)
    print('STEP 3: STORING IN FIRESTORE COLLECTION "fb_ads"')
    print('='*80 + '\n')
    
    stored_count = 0
    updated_count = 0
    created_count = 0
    error_count = 0
    
    for ad_data in ads_with_complete_data:
        ad_id = ad_data['adId']
        
        try:
            doc_ref = db.collection('fb_ads').document(ad_id)
            existing_doc = doc_ref.get()
            
            if existing_doc.exists:
                # Document exists - merge data
                existing_data = existing_doc.to_dict()
                
                # Get existing insights
                existing_daily = existing_data.get('insightsDaily', [])
                existing_summary = existing_data.get('insightsSummary', [])
                
                # Get new insights
                new_daily = ad_data.get('insightsDaily', [])
                new_summary = ad_data.get('insightsSummary', [])
                
                # Create sets of dates to avoid duplicates
                existing_daily_dates = {d.get('date_start') for d in existing_daily if d.get('date_start')}
                
                # Merge daily insights (only add new dates)
                merged_daily = existing_daily.copy()
                new_daily_added = 0
                for new_insight in new_daily:
                    if new_insight.get('date_start') not in existing_daily_dates:
                        merged_daily.append(new_insight)
                        new_daily_added += 1
                
                # For summary, check if we have a summary for this date range
                new_summary_date_range = f"{START_DATE}_{END_DATE}"
                existing_summary_ranges = [f"{s.get('date_start', '')}_{s.get('date_stop', '')}" for s in existing_summary]
                
                merged_summary = existing_summary.copy()
                if new_summary_date_range not in existing_summary_ranges and new_summary:
                    merged_summary.extend(new_summary)
                
                # Update date range to span all periods
                existing_range = existing_data.get('dateRange', {})
                existing_start = existing_range.get('start', START_DATE)
                existing_end = existing_range.get('end', END_DATE)
                
                merged_date_range = {
                    'start': min(existing_start, START_DATE),
                    'end': max(existing_end, END_DATE)
                }
                
                # Update ad_data with merged values
                ad_data['insightsDaily'] = merged_daily
                ad_data['insightsSummary'] = merged_summary
                ad_data['dateRange'] = merged_date_range
                
                # Update month field to reflect multiple months if needed
                existing_month = existing_data.get('month', '')
                new_month = ad_data.get('month', '')
                if existing_month and existing_month != new_month:
                    # Combine months (e.g., "November, December")
                    month_order = ['January', 'February', 'March', 'April', 'May', 'June', 
                                  'July', 'August', 'September', 'October', 'November', 'December']
                    months_list = [m.strip() for m in existing_month.split(',')]
                    if new_month not in months_list:
                        months_list.append(new_month)
                    # Sort by month order
                    unique_months = sorted(set(months_list), 
                                         key=lambda x: month_order.index(x) if x in month_order else 999)
                    ad_data['month'] = ', '.join(unique_months)
                
                # Preserve other existing fields that might be important
                if 'fetchedAt' in existing_data:
                    # Keep original fetch time, but we could also track updates
                    ad_data['firstFetchedAt'] = existing_data.get('firstFetchedAt', existing_data.get('fetchedAt'))
                
                doc_ref.set(ad_data)
                updated_count += 1
                print(f'🔄 {stored_count + 1}/{len(ads_with_complete_data)}. Updated: {ad_data["adName"][:60]} (+{new_daily_added} new daily insights)')
            else:
                # New document - store as is
                ad_data['firstFetchedAt'] = ad_data.get('fetchedAt')
                doc_ref.set(ad_data)
                created_count += 1
                print(f'✅ {stored_count + 1}/{len(ads_with_complete_data)}. Created: {ad_data["adName"][:60]}')
            
            stored_count += 1
            
        except Exception as e:
            error_count += 1
            print(f'❌ Error storing {ad_id}: {e}')
    
    # Summary
    print('\n' + '='*80)
    print('COLLECTION COMPLETE')
    print('='*80 + '\n')
    
    print(f'📊 Summary:')
    print(f'   Total ads found: {len(all_ads)}')
    print(f'   Ads with complete data: {len(ads_with_complete_data)}')
    print(f'   Successfully stored: {stored_count}')
    print(f'   - New documents created: {created_count}')
    print(f'   - Existing documents updated: {updated_count}')
    print(f'   Errors: {error_count}')
    print(f'\n   Collection: fb_ads')
    print(f'   Document ID format: adId (e.g., "120233712971960335")')
    print(f'   Month: December 2025')
    print(f'\n✅ All December 2025 ads stored in Firestore!')
    if updated_count > 0:
        print(f'   ℹ️  {updated_count} existing ads were updated with merged data (preserving historical insights)\n')
    else:
        print()


if __name__ == '__main__':
    fetch_all_ads_for_december()

