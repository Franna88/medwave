#!/usr/bin/env python3
"""
Fetch 6 months of Facebook ads and weekly insights with checkpoint/resume functionality
Handles rate limits gracefully and prevents duplicates
"""

import requests
import firebase_admin
from firebase_admin import credentials, firestore
from datetime import datetime, timedelta
import time
import json
import os
import sys

# Initialize Firebase
try:
    cred = credentials.Certificate('medx-ai-firebase-adminsdk-fbsvc-a86e7bd050.json')
    firebase_admin.initialize_app(cred)
except:
    pass

db = firestore.client()

# Facebook API Configuration
FB_ACCESS_TOKEN = "EAAc9pw8rgA0BP0S8U9s2cLzSJbCYmJZBKZCTFUNDD2zVXVqkC45q1BIQaPdZAmtXKbZBk6wjprLclIUUafHJ4icQZAXuuePybTL38pNQIcjQQZCbRGGhAtLcLVSGeJP59nMdpt8KNEoMQtvDfZBwBgpLNhQboPpaaeU8fW2rCEEhZA9pRN4RjZAAnwnLqEDaP8Fueo0cZD"
FB_AD_ACCOUNT_ID = "act_220298027464902"
FB_API_VERSION = "v24.0"
CHECKPOINT_FILE = "facebook_sync_checkpoint.json"

# Rate limit thresholds
RATE_LIMIT_WARNING_THRESHOLD = 80  # Warn at 80%
RATE_LIMIT_STOP_THRESHOLD = 95     # Stop at 95%

def calculate_week_id(date_str):
    """Calculate week ID from date string (YYYY-MM-DD)"""
    date = datetime.strptime(date_str, '%Y-%m-%d')
    days_since_monday = date.weekday()
    monday = date - timedelta(days=days_since_monday)
    sunday = monday + timedelta(days=6)
    
    monday_str = monday.strftime('%Y-%m-%d')
    sunday_str = sunday.strftime('%Y-%m-%d')
    
    return f"{monday_str}_{sunday_str}"

def load_checkpoint(auto_resume=False):
    """Load checkpoint from file if it exists"""
    if os.path.exists(CHECKPOINT_FILE):
        with open(CHECKPOINT_FILE, 'r') as f:
            checkpoint = json.load(f)
            print('\n' + '='*80)
            print('📋 CHECKPOINT FOUND')
            print('='*80)
            print(f'\nLast run: {checkpoint.get("timestamp")}')
            print(f'Progress: {checkpoint.get("total_ads_processed", 0)} ads processed')
            print(f'Campaign: {checkpoint.get("last_campaign_index", 0) + 1}/{checkpoint.get("total_campaigns", "?")}')
            
            if checkpoint.get("rate_limit_hit"):
                print(f'\n⚠️  Rate limit was hit: {checkpoint.get("rate_limit_message")}')
                print('You can resume from where it left off.')
            
            if auto_resume:
                print('\n✅ Auto-resuming from checkpoint...\n')
                return checkpoint
            
            try:
                response = input('\nResume from checkpoint? (y/n): ')
                if response.lower() == 'y':
                    return checkpoint
                else:
                    print('Starting fresh...')
                    return None
            except EOFError:
                # Non-interactive mode, auto-resume
                print('\n✅ Non-interactive mode: Auto-resuming from checkpoint...\n')
                return checkpoint
    return None

def save_checkpoint(checkpoint_data):
    """Save checkpoint to file"""
    checkpoint_data['timestamp'] = datetime.now().isoformat()
    with open(CHECKPOINT_FILE, 'w') as f:
        json.dump(checkpoint_data, f, indent=2)

def delete_checkpoint():
    """Delete checkpoint file after successful completion"""
    if os.path.exists(CHECKPOINT_FILE):
        os.remove(CHECKPOINT_FILE)
        print('\n✅ Checkpoint file deleted (sync completed)')

def check_rate_limit(response):
    """
    Check rate limit from response headers
    Returns: (usage_percentage, should_stop, warning_message)
    """
    headers = response.headers
    
    # Check app-level usage
    app_usage = headers.get('x-app-usage')
    account_usage = headers.get('x-ad-account-usage')
    
    max_usage = 0
    usage_type = None
    
    if app_usage:
        try:
            app_usage_data = json.loads(app_usage)
            app_pct = app_usage_data.get('call_count', 0)
            if app_pct > max_usage:
                max_usage = app_pct
                usage_type = 'App'
        except:
            pass
    
    if account_usage:
        try:
            account_usage_data = json.loads(account_usage)
            account_pct = account_usage_data.get('call_count', 0)
            if account_pct > max_usage:
                max_usage = account_pct
                usage_type = 'Account'
        except:
            pass
    
    should_stop = max_usage >= RATE_LIMIT_STOP_THRESHOLD
    should_warn = max_usage >= RATE_LIMIT_WARNING_THRESHOLD
    
    warning = None
    if should_stop:
        warning = f'⛔ {usage_type} rate limit at {max_usage}% - STOPPING'
    elif should_warn:
        warning = f'⚠️  {usage_type} rate limit at {max_usage}%'
    
    return max_usage, should_stop, warning

def fetch_campaigns():
    """Fetch all campaigns from Facebook"""
    headers = {'Authorization': f'Bearer {FB_ACCESS_TOKEN}'}
    
    campaigns_url = f'https://graph.facebook.com/{FB_API_VERSION}/{FB_AD_ACCOUNT_ID}/campaigns'
    campaigns_params = {
        'fields': 'id,name,status',
        'limit': 100
    }
    
    try:
        response = requests.get(campaigns_url, headers=headers, params=campaigns_params)
        response.raise_for_status()
        
        # Check rate limit
        usage, should_stop, warning = check_rate_limit(response)
        if warning:
            print(f'   {warning}')
        
        campaigns = response.json().get('data', [])
        return campaigns, should_stop
    except requests.exceptions.HTTPError as e:
        if e.response.status_code == 400:
            error_data = e.response.json()
            if error_data.get('error', {}).get('code') == 17:
                print(f'\n⛔ RATE LIMIT HIT: {error_data.get("error", {}).get("message")}')
                return None, True
        raise

def fetch_ads_for_campaign(campaign_id):
    """Fetch all ads for a campaign"""
    headers = {'Authorization': f'Bearer {FB_ACCESS_TOKEN}'}
    
    ads_url = f'https://graph.facebook.com/{FB_API_VERSION}/{campaign_id}/ads'
    ads_params = {
        'fields': 'id,name,adset_id,adset{name},campaign_id',
        'limit': 100
    }
    
    try:
        response = requests.get(ads_url, headers=headers, params=ads_params)
        response.raise_for_status()
        
        # Check rate limit
        usage, should_stop, warning = check_rate_limit(response)
        if warning:
            print(f'      {warning}')
        
        ads = response.json().get('data', [])
        return ads, should_stop
    except requests.exceptions.HTTPError as e:
        if e.response.status_code == 400:
            error_data = e.response.json()
            if error_data.get('error', {}).get('code') == 17:
                print(f'\n⛔ RATE LIMIT HIT: {error_data.get("error", {}).get("message")}')
                return None, True
        raise

def fetch_insights_for_ad(ad_id, start_date, end_date):
    """Fetch weekly insights for an ad"""
    headers = {'Authorization': f'Bearer {FB_ACCESS_TOKEN}'}
    
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
        
        # Check rate limit
        usage, should_stop, warning = check_rate_limit(response)
        if warning:
            print(f'         {warning}')
        
        insights = response.json().get('data', [])
        return insights, should_stop
    except requests.exceptions.HTTPError as e:
        if e.response.status_code == 400:
            error_data = e.response.json()
            if error_data.get('error', {}).get('code') == 17:
                print(f'\n⛔ RATE LIMIT HIT: {error_data.get("error", {}).get("message")}')
                return None, True
        raise

def store_ad_in_firebase(ad_data, campaign_name):
    """Store ad document in Firebase (or update if exists)"""
    ad_id = ad_data['adId']
    ad_ref = db.collection('advertData').document(ad_id)
    
    # Check if ad already exists
    existing_ad = ad_ref.get()
    
    if existing_ad.exists:
        # Only update timestamp
        ad_ref.update({
            'lastFacebookSync': firestore.SERVER_TIMESTAMP
        })
        return True  # Already existed
    else:
        # Create new ad document
        ad_ref.set({
            'campaignId': ad_data['campaignId'],
            'campaignName': campaign_name,
            'adSetId': ad_data.get('adSetId', ''),
            'adSetName': ad_data.get('adSetName', ''),
            'adId': ad_id,
            'adName': ad_data['adName'],
            'lastUpdated': firestore.SERVER_TIMESTAMP,
            'lastFacebookSync': firestore.SERVER_TIMESTAMP,
            'createdAt': firestore.SERVER_TIMESTAMP
        })
        
        # Create GHL placeholder
        ad_ref.collection('ghlWeekly').document('_placeholder').set({
            'note': 'GHL data will be populated from API',
            'createdAt': firestore.SERVER_TIMESTAMP
        })
        
        return False  # Newly created

def store_insights_in_firebase(ad_id, insights):
    """Store insights in Firebase (skip duplicates)"""
    ad_ref = db.collection('advertData').document(ad_id)
    
    new_weeks = 0
    existing_weeks = 0
    
    for insight in insights:
        week_id = calculate_week_id(insight['date_start'])
        insight_ref = ad_ref.collection('insights').document(week_id)
        
        # Check if this week already exists
        if insight_ref.get().exists:
            existing_weeks += 1
            continue
        
        # Store new insight
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
        new_weeks += 1
    
    return new_weeks, existing_weeks

def main(auto_resume=False):
    """Main sync function"""
    
    print('\n' + '='*80)
    print('FACEBOOK 6-MONTH SYNC WITH CHECKPOINT/RESUME')
    print('='*80 + '\n')
    
    # Calculate date range (6 months)
    end_date = datetime.now()
    start_date = end_date - timedelta(days=180)
    
    start_date_str = start_date.strftime('%Y-%m-%d')
    end_date_str = end_date.strftime('%Y-%m-%d')
    
    print(f'📅 Date range: {start_date_str} to {end_date_str} (6 months)')
    print(f'📊 Fetching weekly insights (26 weeks per ad)\n')
    
    # Load checkpoint if exists
    checkpoint = load_checkpoint(auto_resume)
    
    if checkpoint:
        start_campaign_idx = checkpoint.get('last_campaign_index', 0)
        start_ad_idx = checkpoint.get('last_ad_index', 0) + 1  # Start from next ad
        total_ads_processed = checkpoint.get('total_ads_processed', 0)
    else:
        start_campaign_idx = 0
        start_ad_idx = 0
        total_ads_processed = 0
    
    # Fetch campaigns
    print('📊 Step 1: Fetching campaigns...\n')
    campaigns, should_stop = fetch_campaigns()
    
    if should_stop:
        print('\n⛔ Rate limit hit while fetching campaigns. Exiting...')
        save_checkpoint({
            'last_campaign_index': start_campaign_idx,
            'last_ad_index': -1,
            'total_campaigns': 0,
            'total_ads_processed': total_ads_processed,
            'rate_limit_hit': True,
            'rate_limit_message': 'Hit while fetching campaigns'
        })
        return
    
    if not campaigns:
        print('❌ No campaigns found or error occurred')
        return
    
    print(f'✅ Found {len(campaigns)} campaigns\n')
    
    # Process campaigns
    print('📥 Step 2: Processing campaigns and ads...\n')
    
    total_new_ads = 0
    total_updated_ads = 0
    total_new_insights = 0
    total_existing_insights = 0
    start_time = time.time()
    
    for campaign_idx in range(start_campaign_idx, len(campaigns)):
        campaign = campaigns[campaign_idx]
        campaign_id = campaign['id']
        campaign_name = campaign['name']
        
        print(f'Campaign [{campaign_idx + 1}/{len(campaigns)}]: {campaign_name}')
        
        # Fetch ads for this campaign
        ads, should_stop = fetch_ads_for_campaign(campaign_id)
        
        if should_stop:
            print(f'\n⛔ Rate limit hit. Saving checkpoint...')
            save_checkpoint({
                'last_campaign_index': campaign_idx,
                'last_ad_index': -1,
                'total_campaigns': len(campaigns),
                'total_ads_processed': total_ads_processed,
                'rate_limit_hit': True,
                'rate_limit_message': 'Hit while fetching ads for campaign'
            })
            print(f'\n💾 Progress saved. Run script again to resume.')
            return
        
        if not ads:
            print(f'   No ads found\n')
            continue
        
        print(f'   Found {len(ads)} ads')
        
        # Determine starting ad index
        ad_start_idx = start_ad_idx if campaign_idx == start_campaign_idx else 0
        
        # Process each ad
        for ad_idx in range(ad_start_idx, len(ads)):
            ad = ads[ad_idx]
            ad_id = ad['id']
            ad_name = ad.get('name', 'Unnamed')
            adset = ad.get('adset', {})
            
            print(f'   Ad [{ad_idx + 1}/{len(ads)}]: {ad_name[:50]}')
            
            # Fetch insights
            insights, should_stop = fetch_insights_for_ad(ad_id, start_date_str, end_date_str)
            
            if should_stop:
                print(f'\n⛔ Rate limit hit. Saving checkpoint...')
                save_checkpoint({
                    'last_campaign_index': campaign_idx,
                    'last_ad_index': ad_idx,
                    'total_campaigns': len(campaigns),
                    'total_ads_processed': total_ads_processed,
                    'rate_limit_hit': True,
                    'rate_limit_message': 'Hit while fetching insights'
                })
                print(f'\n💾 Progress saved. Run script again to resume.')
                return
            
            if insights is None:
                print(f'      ⚠️  Error fetching insights')
                continue
            
            print(f'      ✓ Fetched {len(insights)} weeks of insights')
            
            # Store in Firebase
            ad_data = {
                'adId': ad_id,
                'adName': ad_name,
                'campaignId': campaign_id,
                'adSetId': adset.get('id', ''),
                'adSetName': adset.get('name', '')
            }
            
            ad_existed = store_ad_in_firebase(ad_data, campaign_name)
            
            if ad_existed:
                total_updated_ads += 1
            else:
                total_new_ads += 1
            
            # Store insights
            if insights:
                new_weeks, existing_weeks = store_insights_in_firebase(ad_id, insights)
                total_new_insights += new_weeks
                total_existing_insights += existing_weeks
                
                print(f'      ✓ Stored in Firebase ({new_weeks} new weeks, {existing_weeks} existing)')
            else:
                print(f'      ⚠️  No insights data for this period')
            
            total_ads_processed += 1
            
            # Save checkpoint after each ad
            save_checkpoint({
                'last_campaign_index': campaign_idx,
                'last_ad_index': ad_idx,
                'total_campaigns': len(campaigns),
                'total_ads_processed': total_ads_processed,
                'rate_limit_hit': False,
                'rate_limit_message': None
            })
            
            # Progress summary
            elapsed = time.time() - start_time
            ads_per_sec = total_ads_processed / elapsed if elapsed > 0 else 0
            
            print(f'      Progress: {total_ads_processed} ads | Rate Limit: OK')
            
            # Small delay to be nice to the API
            time.sleep(0.3)
        
        print()  # Blank line after campaign
        
        # Reset ad start index for next campaign
        start_ad_idx = 0
    
    # Completion
    print('\n' + '='*80)
    print('✅ SYNC COMPLETE!')
    print('='*80 + '\n')
    
    elapsed_time = time.time() - start_time
    minutes = int(elapsed_time // 60)
    seconds = int(elapsed_time % 60)
    
    print(f'📊 Summary:')
    print(f'   Total campaigns processed: {len(campaigns)}')
    print(f'   Total ads processed: {total_ads_processed}')
    print(f'   New ads created: {total_new_ads}')
    print(f'   Existing ads updated: {total_updated_ads}')
    print(f'   New insight weeks stored: {total_new_insights}')
    print(f'   Existing insight weeks skipped: {total_existing_insights}')
    print(f'   Time elapsed: {minutes}m {seconds}s')
    print('\n' + '='*80 + '\n')
    
    # Delete checkpoint
    delete_checkpoint()

if __name__ == '__main__':
    # Check for --resume flag
    auto_resume = '--resume' in sys.argv or '-r' in sys.argv
    
    try:
        main(auto_resume)
    except KeyboardInterrupt:
        print('\n\n⚠️  Interrupted by user. Checkpoint saved.')
        sys.exit(0)
    except Exception as e:
        print(f'\n\n❌ Error: {e}')
        import traceback
        traceback.print_exc()
        sys.exit(1)

