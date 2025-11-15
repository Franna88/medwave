#!/usr/bin/env python3
"""
Create Weekly Summary Collection
Fetches Facebook daily insights and GHL opportunities, then aggregates by week

Usage:
  python3 create_weekly_summary_collection.py                 # Full run
  python3 create_weekly_summary_collection.py --limit=10      # Test with 10 ads
  python3 create_weekly_summary_collection.py --skip-facebook # Skip FB (use checkpoint)
  python3 create_weekly_summary_collection.py --skip-ghl      # Skip GHL fetch
  
Features:
  - Automatic checkpoint/resume (saves every 10 ads)
  - Filters ads to last 3 months only
  - Handles rate limits automatically
  - Test mode with --limit flag
"""

import firebase_admin
from firebase_admin import credentials, firestore
import requests
import json
from datetime import datetime, timedelta
from collections import defaultdict
import time
import sys

# ============================================================================
# CONFIGURATION
# ============================================================================

# Firebase
FIREBASE_CRED_PATH = 'medx-ai-firebase-adminsdk-fbsvc-a86e7bd050.json'

# Facebook API
FACEBOOK_API_VERSION = 'v24.0'
FACEBOOK_BASE_URL = f'https://graph.facebook.com/{FACEBOOK_API_VERSION}'
FACEBOOK_ACCESS_TOKEN = 'EAAc9pw8rgA0BP0S8U9s2cLzSJbCYmJZBKZCTFUNDD2zVXVqkC45q1BIQaPdZAmtXKbZBk6wjprLclIUUafHJ4icQZAXuuePybTL38pNQIcjQQZCbRGGhAtLcLVSGeJP59nMdpt8KNEoMQtvDfZBwBgpLNhQboPpaaeU8fW2rCEEhZA9pRN4RjZAAnwnLqEDaP8Fueo0cZD'

# GHL API
GHL_BASE_URL = 'https://services.leadconnectorhq.com'
GHL_API_KEY = 'pit-22f8af95-3244-41e7-9a52-22c87b166f5a'
GHL_LOCATION_ID = 'QdLXaFEqrdF0JbVbpKLw'

# Pipeline IDs to track
ANDRIES_PIPELINE_ID = 'XeAGJWRnUGJ5tuhXam2g'
DAVIDE_PIPELINE_ID = 'AUduOJBB2lxlsEaNmlJz'
TRACKED_PIPELINES = [ANDRIES_PIPELINE_ID, DAVIDE_PIPELINE_ID]

# Date range (last 3 months)
END_DATE = datetime.now()
START_DATE = END_DATE - timedelta(days=90)

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

def get_week_boundaries(date):
    """Get Monday and Sunday for the week containing the given date"""
    # Get the Monday of the week
    monday = date - timedelta(days=date.weekday())
    # Get the Sunday of the week
    sunday = monday + timedelta(days=6)
    return monday.date(), sunday.date()

def get_week_id(date):
    """Generate week ID in format YYYY-MM-DD_YYYY-MM-DD"""
    monday, sunday = get_week_boundaries(date)
    return f"{monday}_{sunday}"

def get_month_name(date):
    """Get month name and year (e.g., 'November 2025')"""
    return date.strftime('%B %Y')

def get_week_of_month(date):
    """Get week number within the month (1-5)"""
    first_day = date.replace(day=1)
    dom = date.day
    adjusted_dom = dom + first_day.weekday()
    return int((adjusted_dom - 1) / 7) + 1

def load_stage_mappings():
    """Load GHL pipeline stage mappings from JSON"""
    with open('ghl_info/pipeline_stage_mappings.json', 'r') as f:
        return json.load(f)

def get_stage_category(pipeline_id, stage_id, stage_mappings):
    """Map stage ID to category (leads, bookedAppointments, deposits, cashCollected)"""
    if pipeline_id == ANDRIES_PIPELINE_ID:
        stages = stage_mappings['andries']['stages']
        stage_name = stages.get(stage_id, '')
    elif pipeline_id == DAVIDE_PIPELINE_ID:
        stages = stage_mappings['davide']['stages']
        stage_name = stages.get(stage_id, '')
    else:
        return 'other'
    
    # Map stage names to categories
    if 'Booked Appointments' in stage_name:
        return 'bookedAppointments'
    elif 'Deposit Received' in stage_name:
        return 'deposits'
    elif 'Cash Collected' in stage_name:
        return 'cashCollected'
    else:
        return 'other'

# ============================================================================
# FACEBOOK API FUNCTIONS
# ============================================================================

def fetch_facebook_daily_insights(ad_id, start_date, end_date):
    """Fetch daily insights for a single ad from Facebook API"""
    url = f"{FACEBOOK_BASE_URL}/{ad_id}/insights"
    
    params = {
        'access_token': FACEBOOK_ACCESS_TOKEN,
        'time_increment': 1,  # Daily breakdown
        'time_range': json.dumps({
            'since': start_date.strftime('%Y-%m-%d'),
            'until': end_date.strftime('%Y-%m-%d')
        }),
        'fields': 'impressions,reach,spend,clicks,cpm,cpc,ctr,date_start,date_stop',
        'limit': 1000
    }
    
    try:
        response = requests.get(url, params=params, timeout=30)
        
        if response.status_code == 429:
            # Rate limit hit
            print(f"  ⚠️  Rate limit hit for ad {ad_id}, waiting 60s...")
            time.sleep(60)
            return fetch_facebook_daily_insights(ad_id, start_date, end_date)
        
        response.raise_for_status()
        data = response.json()
        return data.get('data', [])
    
    except requests.exceptions.RequestException as e:
        print(f"  ❌ Error fetching insights for ad {ad_id}: {e}")
        return []

def aggregate_daily_to_weekly(daily_insights):
    """Aggregate daily Facebook insights into weekly totals"""
    weekly_data = defaultdict(lambda: {
        'spend': 0,
        'impressions': 0,
        'reach': 0,
        'clicks': 0,
        'cpm': 0,
        'cpc': 0,
        'ctr': 0,
        'days_count': 0
    })
    
    for day in daily_insights:
        date_start = datetime.strptime(day['date_start'], '%Y-%m-%d')
        week_id = get_week_id(date_start)
        
        weekly_data[week_id]['spend'] += float(day.get('spend', 0))
        weekly_data[week_id]['impressions'] += int(day.get('impressions', 0))
        weekly_data[week_id]['reach'] += int(day.get('reach', 0))
        weekly_data[week_id]['clicks'] += int(day.get('clicks', 0))
        weekly_data[week_id]['days_count'] += 1
    
    # Calculate averages for CPM, CPC, CTR
    for week_id, data in weekly_data.items():
        if data['impressions'] > 0:
            data['cpm'] = (data['spend'] / data['impressions']) * 1000
            data['ctr'] = (data['clicks'] / data['impressions']) * 100
        if data['clicks'] > 0:
            data['cpc'] = data['spend'] / data['clicks']
        
        # Remove days_count from final data
        del data['days_count']
    
    return dict(weekly_data)

# ============================================================================
# GHL API FUNCTIONS
# ============================================================================

def fetch_ghl_opportunities():
    """Fetch all opportunities from GHL API for last 3 months"""
    url = f"{GHL_BASE_URL}/opportunities/search"
    headers = {
        'Authorization': f'Bearer {GHL_API_KEY}',
        'Version': '2021-07-28'
    }
    
    all_opportunities = []
    page = 1
    
    print(f"\n📊 Fetching GHL opportunities...")
    
    while True:
        params = {
            'location_id': GHL_LOCATION_ID,
            'limit': 100,
            'page': page
        }
        
        try:
            response = requests.get(url, headers=headers, params=params, timeout=30)
            
            if response.status_code == 429:
                print(f"  ⚠️  Rate limit hit, waiting 60s...")
                time.sleep(60)
                continue
            
            response.raise_for_status()
            data = response.json()
            
            opportunities = data.get('opportunities', [])
            if not opportunities:
                break
            
            # Filter for tracked pipelines and last 3 months
            for opp in opportunities:
                pipeline_id = opp.get('pipelineId', '')
                created_at = opp.get('createdAt', '')
                
                if pipeline_id in TRACKED_PIPELINES and created_at:
                    created_date = datetime.fromisoformat(created_at.replace('Z', '+00:00'))
                    if created_date >= START_DATE.replace(tzinfo=created_date.tzinfo):
                        all_opportunities.append(opp)
            
            print(f"  Page {page}: {len(opportunities)} opportunities ({len(all_opportunities)} total tracked)")
            page += 1
            
            # Small delay to avoid rate limits
            time.sleep(0.5)
        
        except requests.exceptions.RequestException as e:
            print(f"  ❌ Error fetching opportunities page {page}: {e}")
            break
    
    print(f"✅ Fetched {len(all_opportunities)} opportunities from tracked pipelines")
    return all_opportunities

def fetch_ghl_form_submissions():
    """Fetch form submissions from GHL API to get ad_id mappings"""
    url = f"{GHL_BASE_URL}/forms/submissions"
    headers = {
        'Authorization': f'Bearer {GHL_API_KEY}',
        'Version': '2021-07-28'
    }
    
    contact_to_ad_map = {}
    page = 1
    
    print(f"\n📝 Fetching GHL form submissions for ad_id mapping...")
    
    # Fetch submissions from last 3 months
    start_at = START_DATE.strftime('%Y-%m-%dT00:00:00Z')
    end_at = END_DATE.strftime('%Y-%m-%dT23:59:59Z')
    
    while True:
        params = {
            'locationId': GHL_LOCATION_ID,
            'limit': 100,
            'startAt': start_at,
            'endAt': end_at,
            'page': page
        }
        
        try:
            response = requests.get(url, headers=headers, params=params, timeout=30)
            
            if response.status_code == 429:
                print(f"  ⚠️  Rate limit hit, waiting 60s...")
                time.sleep(60)
                continue
            
            response.raise_for_status()
            data = response.json()
            
            submissions = data.get('submissions', [])
            if not submissions:
                break
            
            # Extract ad_id from submissions
            for submission in submissions:
                contact_id = submission.get('contactId')
                others = submission.get('others', {})
                
                # Try to get ad_id from lastAttributionSource
                last_attr = others.get('lastAttributionSource', {})
                ad_id = last_attr.get('adId')
                
                # Fallback to eventData
                if not ad_id:
                    event_data = others.get('eventData', {})
                    url_params = event_data.get('url_params', {})
                    ad_id = url_params.get('ad_id')
                
                if contact_id and ad_id:
                    contact_to_ad_map[contact_id] = ad_id
            
            print(f"  Page {page}: {len(submissions)} submissions ({len(contact_to_ad_map)} contacts mapped)")
            page += 1
            
            # Small delay to avoid rate limits
            time.sleep(0.5)
        
        except requests.exceptions.RequestException as e:
            print(f"  ❌ Error fetching form submissions page {page}: {e}")
            break
    
    print(f"✅ Mapped {len(contact_to_ad_map)} contacts to ad IDs")
    return contact_to_ad_map

# ============================================================================
# FIREBASE FUNCTIONS
# ============================================================================

def get_firebase_ad_assignments(db):
    """Get ad assignments from Firebase ghlOpportunities collection"""
    print(f"\n🔥 Loading ad assignments from Firebase...")
    
    opp_to_ad_map = {}
    opps = db.collection('ghlOpportunities').where('assignedAdId', '!=', None).stream()
    
    for opp in opps:
        opp_data = opp.to_dict()
        opp_id = opp.id
        assigned_ad_id = opp_data.get('assignedAdId')
        
        if assigned_ad_id:
            opp_to_ad_map[opp_id] = assigned_ad_id
    
    print(f"✅ Loaded {len(opp_to_ad_map)} opportunity-to-ad mappings from Firebase")
    return opp_to_ad_map

def load_ads_from_firebase(db, limit=None):
    """Load ads from Firebase that have activity in the last 3 months"""
    print(f"\n🔥 Loading ads from Firebase...")
    
    ads_data = {}
    
    # Query ads with lastFacebookSync in the last 3 months (more reliable than lastInsightDate)
    cutoff_date = START_DATE
    
    # Get all ads and filter
    ads_query = db.collection('ads')
    if limit:
        ads_query = ads_query.limit(limit)
    
    ads = ads_query.stream()
    
    total_checked = 0
    filtered_out = 0
    
    # Filter ads based on date range
    for ad in ads:
        total_checked += 1
        ad_data = ad.to_dict()
        
        # Check if ad has recent sync
        last_fb_sync = ad_data.get('lastFacebookSync')
        last_insight_date = ad_data.get('lastInsightDate')
        
        # Skip ads that are clearly old
        should_skip = False
        
        if last_insight_date:
            try:
                if isinstance(last_insight_date, str):
                    last_date = datetime.strptime(last_insight_date, '%Y-%m-%d')
                else:
                    last_date = last_insight_date
                
                # Skip if last insight is before our start date
                if last_date.date() < START_DATE.date():
                    should_skip = True
            except:
                pass
        
        # Also check lastFacebookSync
        if last_fb_sync and not should_skip:
            try:
                if hasattr(last_fb_sync, 'timestamp'):
                    sync_date = datetime.fromtimestamp(last_fb_sync.timestamp())
                else:
                    sync_date = last_fb_sync
                
                # If synced recently, include it
                if sync_date >= cutoff_date:
                    should_skip = False
            except:
                pass
        
        if should_skip:
            filtered_out += 1
            continue
        
        ads_data[ad.id] = {
            'adId': ad.id,
            'adName': ad_data.get('adName', ''),
            'adSetId': ad_data.get('adSetId', ''),
            'adSetName': ad_data.get('adSetName', ''),
            'campaignId': ad_data.get('campaignId', ''),
            'campaignName': ad_data.get('campaignName', ''),
            'lastInsightDate': last_insight_date,
            'firstInsightDate': ad_data.get('firstInsightDate')
        }
    
    print(f"✅ Loaded {len(ads_data)} ads from Firebase")
    print(f"   Total checked: {total_checked}, Filtered out: {filtered_out}")
    return ads_data

# ============================================================================
# AGGREGATION FUNCTIONS
# ============================================================================

def calculate_weekly_ghl_metrics(opportunities, opp_to_ad_map, contact_to_ad_map, stage_mappings):
    """Calculate weekly GHL metrics from opportunities"""
    print(f"\n📊 Calculating weekly GHL metrics...")
    
    # Structure: {ad_id: {week_id: {leads: 0, bookings: 0, deposits: 0, cash: 0, cashAmount: 0}}}
    weekly_ghl_data = defaultdict(lambda: defaultdict(lambda: {
        'leads': 0,
        'bookedAppointments': 0,
        'deposits': 0,
        'cashCollected': 0,
        'cashAmount': 0
    }))
    
    matched = 0
    unmatched = 0
    
    for opp in opportunities:
        opp_id = opp.get('id')
        contact_id = opp.get('contactId')
        pipeline_id = opp.get('pipelineId')
        stage_id = opp.get('pipelineStageId')
        monetary_value = opp.get('monetaryValue', 0)
        created_at = opp.get('createdAt')
        updated_at = opp.get('updatedAt')
        last_stage_change = opp.get('lastStageChangeAt')
        
        # Get assigned ad ID
        ad_id = opp_to_ad_map.get(opp_id)
        if not ad_id and contact_id:
            ad_id = contact_to_ad_map.get(contact_id)
        
        if not ad_id:
            unmatched += 1
            continue
        
        matched += 1
        
        # Get stage category
        stage_category = get_stage_category(pipeline_id, stage_id, stage_mappings)
        
        # Assign lead to week based on createdAt
        if created_at:
            created_date = datetime.fromisoformat(created_at.replace('Z', '+00:00'))
            lead_week_id = get_week_id(created_date)
            weekly_ghl_data[ad_id][lead_week_id]['leads'] += 1
        
        # Assign stage to week based on lastStageChangeAt or updatedAt
        stage_date = None
        if last_stage_change:
            stage_date = datetime.fromisoformat(last_stage_change.replace('Z', '+00:00'))
        elif updated_at:
            if isinstance(updated_at, str):
                stage_date = datetime.fromisoformat(updated_at.replace('Z', '+00:00'))
            else:
                stage_date = updated_at
        
        if stage_date and stage_category != 'other':
            stage_week_id = get_week_id(stage_date)
            
            if stage_category == 'bookedAppointments':
                weekly_ghl_data[ad_id][stage_week_id]['bookedAppointments'] += 1
            elif stage_category == 'deposits':
                weekly_ghl_data[ad_id][stage_week_id]['deposits'] += 1
                weekly_ghl_data[ad_id][stage_week_id]['cashAmount'] += monetary_value / 100  # Convert cents to currency
            elif stage_category == 'cashCollected':
                weekly_ghl_data[ad_id][stage_week_id]['cashCollected'] += 1
                weekly_ghl_data[ad_id][stage_week_id]['cashAmount'] += monetary_value / 100
    
    print(f"✅ Matched {matched} opportunities to ads")
    print(f"⚠️  {unmatched} opportunities could not be matched to ads")
    
    # Convert defaultdict to regular dict
    return {ad_id: dict(weeks) for ad_id, weeks in weekly_ghl_data.items()}

def aggregate_to_summary_collection(ads_data, weekly_fb_data, weekly_ghl_data):
    """Aggregate all data into summary collection structure"""
    print(f"\n📦 Aggregating data into summary collection structure...")
    
    # Structure: {campaign_id: {weeks: {week_id: {...}}}}
    summary_data = defaultdict(lambda: {
        'campaignId': '',
        'campaignName': '',
        'weeks': {}
    })
    
    # Process each ad
    for ad_id, ad_info in ads_data.items():
        campaign_id = ad_info['campaignId']
        ad_set_id = ad_info['adSetId']
        
        if not campaign_id:
            continue
        
        # Set campaign info
        if not summary_data[campaign_id]['campaignId']:
            summary_data[campaign_id]['campaignId'] = campaign_id
            summary_data[campaign_id]['campaignName'] = ad_info['campaignName']
        
        # Get Facebook and GHL data for this ad
        fb_weeks = weekly_fb_data.get(ad_id, {})
        ghl_weeks = weekly_ghl_data.get(ad_id, {})
        
        # Combine all weeks for this ad
        all_weeks = set(list(fb_weeks.keys()) + list(ghl_weeks.keys()))
        
        for week_id in all_weeks:
            # Initialize week structure if not exists
            if week_id not in summary_data[campaign_id]['weeks']:
                monday_str, sunday_str = week_id.split('_')
                monday = datetime.strptime(monday_str, '%Y-%m-%d')
                sunday = datetime.strptime(sunday_str, '%Y-%m-%d')
                
                summary_data[campaign_id]['weeks'][week_id] = {
                    'month': get_month_name(monday),
                    'dateRange': f"{monday.strftime('%d %b %Y')} - {sunday.strftime('%d %b %Y')}",
                    'weekNumber': get_week_of_month(monday),
                    'ads': {},
                    'adSets': {},
                    'campaign': {
                        'campaignId': campaign_id,
                        'campaignName': ad_info['campaignName'],
                        'facebookInsights': {
                            'spend': 0, 'impressions': 0, 'reach': 0, 'clicks': 0,
                            'cpm': 0, 'cpc': 0, 'ctr': 0
                        },
                        'ghlData': {
                            'leads': 0, 'bookedAppointments': 0, 'deposits': 0,
                            'cashCollected': 0, 'cashAmount': 0
                        }
                    }
                }
            
            week_data = summary_data[campaign_id]['weeks'][week_id]
            
            # Add ad-level data
            if ad_id not in week_data['ads']:
                week_data['ads'][ad_id] = {
                    'adId': ad_id,
                    'adName': ad_info['adName'],
                    'facebookInsights': fb_weeks.get(week_id, {
                        'spend': 0, 'impressions': 0, 'reach': 0, 'clicks': 0,
                        'cpm': 0, 'cpc': 0, 'ctr': 0
                    }),
                    'ghlData': ghl_weeks.get(week_id, {
                        'leads': 0, 'bookedAppointments': 0, 'deposits': 0,
                        'cashCollected': 0, 'cashAmount': 0
                    })
                }
            
            # Initialize ad set if not exists
            if ad_set_id and ad_set_id not in week_data['adSets']:
                week_data['adSets'][ad_set_id] = {
                    'adSetId': ad_set_id,
                    'adSetName': ad_info['adSetName'],
                    'facebookInsights': {
                        'spend': 0, 'impressions': 0, 'reach': 0, 'clicks': 0,
                        'cpm': 0, 'cpc': 0, 'ctr': 0
                    },
                    'ghlData': {
                        'leads': 0, 'bookedAppointments': 0, 'deposits': 0,
                        'cashCollected': 0, 'cashAmount': 0
                    }
                }
            
            # Aggregate to ad set level
            if ad_set_id:
                ad_set_data = week_data['adSets'][ad_set_id]
                ad_data = week_data['ads'][ad_id]
                
                # Sum Facebook metrics
                for key in ['spend', 'impressions', 'reach', 'clicks']:
                    ad_set_data['facebookInsights'][key] += ad_data['facebookInsights'].get(key, 0)
                
                # Sum GHL metrics
                for key in ['leads', 'bookedAppointments', 'deposits', 'cashCollected', 'cashAmount']:
                    ad_set_data['ghlData'][key] += ad_data['ghlData'].get(key, 0)
            
            # Aggregate to campaign level
            campaign_data = week_data['campaign']
            ad_data = week_data['ads'][ad_id]
            
            # Sum Facebook metrics
            for key in ['spend', 'impressions', 'reach', 'clicks']:
                campaign_data['facebookInsights'][key] += ad_data['facebookInsights'].get(key, 0)
            
            # Sum GHL metrics
            for key in ['leads', 'bookedAppointments', 'deposits', 'cashCollected', 'cashAmount']:
                campaign_data['ghlData'][key] += ad_data['ghlData'].get(key, 0)
    
    # Calculate averages for CPM, CPC, CTR at ad set and campaign levels
    for campaign_id, campaign_summary in summary_data.items():
        for week_id, week_data in campaign_summary['weeks'].items():
            # Ad set level
            for ad_set_id, ad_set_data in week_data['adSets'].items():
                fb = ad_set_data['facebookInsights']
                if fb['impressions'] > 0:
                    fb['cpm'] = (fb['spend'] / fb['impressions']) * 1000
                    fb['ctr'] = (fb['clicks'] / fb['impressions']) * 100
                if fb['clicks'] > 0:
                    fb['cpc'] = fb['spend'] / fb['clicks']
            
            # Campaign level
            fb = week_data['campaign']['facebookInsights']
            if fb['impressions'] > 0:
                fb['cpm'] = (fb['spend'] / fb['impressions']) * 1000
                fb['ctr'] = (fb['clicks'] / fb['impressions']) * 100
            if fb['clicks'] > 0:
                fb['cpc'] = fb['spend'] / fb['clicks']
    
    print(f"✅ Aggregated data for {len(summary_data)} campaigns")
    return dict(summary_data)

def write_to_firebase(db, summary_data):
    """Write summary data to Firebase"""
    print(f"\n🔥 Writing summary data to Firebase...")
    
    batch = db.batch()
    batch_count = 0
    total_written = 0
    
    for campaign_id, campaign_summary in summary_data.items():
        doc_ref = db.collection('summary').document(campaign_id)
        batch.set(doc_ref, campaign_summary)
        batch_count += 1
        total_written += 1
        
        # Commit batch every 500 operations (Firestore limit)
        if batch_count >= 500:
            batch.commit()
            print(f"  ✅ Committed batch ({total_written} campaigns written)")
            batch = db.batch()
            batch_count = 0
    
    # Commit remaining
    if batch_count > 0:
        batch.commit()
        print(f"  ✅ Committed final batch ({total_written} campaigns written)")
    
    print(f"✅ Successfully wrote {total_written} campaign summaries to Firebase")

# ============================================================================
# MAIN FUNCTION
# ============================================================================

def main():
    """Main execution function"""
    print("="*80)
    print("WEEKLY SUMMARY COLLECTION CREATION")
    print("="*80)
    print(f"Date range: {START_DATE.strftime('%Y-%m-%d')} to {END_DATE.strftime('%Y-%m-%d')}")
    print("="*80)
    
    # Check for command line arguments
    skip_facebook = '--skip-facebook' in sys.argv
    skip_ghl = '--skip-ghl' in sys.argv
    
    # Check for limit argument
    limit = None
    for arg in sys.argv:
        if arg.startswith('--limit='):
            limit = int(arg.split('=')[1])
            print(f"⚠️  Limiting to {limit} ads for testing")
    
    if skip_facebook:
        print("⚠️  Skipping Facebook data fetch (using checkpoint)")
    if skip_ghl:
        print("⚠️  Skipping GHL data fetch (using existing data)")
    
    # Initialize Firebase
    if not firebase_admin._apps:
        cred = credentials.Certificate(FIREBASE_CRED_PATH)
        firebase_admin.initialize_app(cred)
    db = firestore.client()
    
    # Load stage mappings
    stage_mappings = load_stage_mappings()
    print(f"✅ Loaded stage mappings for {len(stage_mappings)} pipelines")
    
    # Step 1: Load ads from Firebase
    ads_data = load_ads_from_firebase(db, limit=limit)
    
    # Step 2: Fetch Facebook daily insights and aggregate to weekly
    checkpoint_file = 'facebook_insights_checkpoint.json'
    weekly_fb_data = {}
    
    if not skip_facebook:
        print(f"\n{'='*80}")
        print(f"STEP 1: FETCHING FACEBOOK INSIGHTS")
        print(f"{'='*80}")
        
        # Check for checkpoint file
        processed_ads = set()
        
        try:
            with open(checkpoint_file, 'r') as f:
                checkpoint_data = json.load(f)
                weekly_fb_data = checkpoint_data.get('weekly_fb_data', {})
                processed_ads = set(checkpoint_data.get('processed_ads', []))
                print(f"📂 Loaded checkpoint: {len(processed_ads)} ads already processed")
        except FileNotFoundError:
            print(f"📂 No checkpoint found, starting fresh")
        
        total_ads = len(ads_data)
        processed = len(processed_ads)
        skipped = 0
        errors = 0
        
        for ad_id, ad_info in ads_data.items():
            # Skip if already processed
            if ad_id in processed_ads:
                continue
            
            processed += 1
            print(f"\n[{processed}/{total_ads}] Fetching insights for ad: {ad_info['adName'][:50]}")
            print(f"  Ad ID: {ad_id}")
            
            try:
                daily_insights = fetch_facebook_daily_insights(ad_id, START_DATE, END_DATE)
                
                if daily_insights:
                    weekly_insights = aggregate_daily_to_weekly(daily_insights)
                    weekly_fb_data[ad_id] = weekly_insights
                    print(f"  ✅ Aggregated {len(daily_insights)} days into {len(weekly_insights)} weeks")
                else:
                    skipped += 1
                    print(f"  ⚠️  No insights found (likely no activity in date range)")
                
                processed_ads.add(ad_id)
                
                # Save checkpoint every 10 ads
                if processed % 10 == 0:
                    with open(checkpoint_file, 'w') as f:
                        json.dump({
                            'weekly_fb_data': weekly_fb_data,
                            'processed_ads': list(processed_ads)
                        }, f)
                    print(f"  💾 Checkpoint saved ({processed}/{total_ads} ads)")
                
                # Small delay to avoid rate limits
                time.sleep(0.5)
            
            except Exception as e:
                errors += 1
                print(f"  ❌ Error: {e}")
                # Continue with next ad
                continue
        
        # Save final checkpoint
        with open(checkpoint_file, 'w') as f:
            json.dump({
                'weekly_fb_data': weekly_fb_data,
                'processed_ads': list(processed_ads)
            }, f)
        
        print(f"\n✅ Fetched Facebook insights for {len(weekly_fb_data)} ads")
        print(f"   Processed: {processed}/{total_ads}")
        print(f"   Skipped (no data): {skipped}")
        print(f"   Errors: {errors}")
    else:
        # Load from checkpoint
        try:
            with open(checkpoint_file, 'r') as f:
                checkpoint_data = json.load(f)
                weekly_fb_data = checkpoint_data.get('weekly_fb_data', {})
                print(f"✅ Loaded Facebook data from checkpoint: {len(weekly_fb_data)} ads")
        except FileNotFoundError:
            print(f"❌ No checkpoint file found! Run without --skip-facebook first.")
            return
    
    # Step 3: Fetch GHL opportunities
    print(f"\n{'='*80}")
    print(f"STEP 2: FETCHING GHL DATA")
    print(f"{'='*80}")
    
    opportunities = fetch_ghl_opportunities()
    
    # Step 4: Get ad assignments
    opp_to_ad_map = get_firebase_ad_assignments(db)
    contact_to_ad_map = fetch_ghl_form_submissions()
    
    # Step 5: Calculate weekly GHL metrics
    weekly_ghl_data = calculate_weekly_ghl_metrics(
        opportunities,
        opp_to_ad_map,
        contact_to_ad_map,
        stage_mappings
    )
    
    # Step 6: Aggregate into summary collection
    print(f"\n{'='*80}")
    print(f"STEP 3: AGGREGATING DATA")
    print(f"{'='*80}")
    
    summary_data = aggregate_to_summary_collection(ads_data, weekly_fb_data, weekly_ghl_data)
    
    # Step 7: Write to Firebase
    print(f"\n{'='*80}")
    print(f"STEP 4: WRITING TO FIREBASE")
    print(f"{'='*80}")
    
    write_to_firebase(db, summary_data)
    
    # Summary
    print(f"\n{'='*80}")
    print(f"SUMMARY")
    print(f"{'='*80}")
    print(f"✅ Total ads processed: {len(ads_data)}")
    print(f"✅ Ads with Facebook data: {len(weekly_fb_data)}")
    print(f"✅ Ads with GHL data: {len(weekly_ghl_data)}")
    print(f"✅ Campaigns in summary: {len(summary_data)}")
    print(f"✅ Total opportunities processed: {len(opportunities)}")
    print(f"{'='*80}")
    print("COMPLETE!")
    print(f"{'='*80}")

if __name__ == '__main__':
    main()

