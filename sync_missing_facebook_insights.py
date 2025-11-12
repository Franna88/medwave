#!/usr/bin/env python3
"""
Facebook Insights Gap Detector and Backfill Script

This script:
1. Fetches all ads from Facebook API for November 2025
2. Gets the first and last insights dates for each ad
3. Compares with Firebase ads collection to find missing date ranges
4. Identifies and backfills missing weekly insights
"""

import requests
import firebase_admin
from firebase_admin import credentials, firestore
from datetime import datetime, timedelta
import time
import json
from collections import defaultdict

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

def calculate_week_id(date_str):
    """Calculate week ID from date string (YYYY-MM-DD)"""
    date = datetime.strptime(date_str, '%Y-%m-%d')
    days_since_monday = date.weekday()
    monday = date - timedelta(days=days_since_monday)
    sunday = monday + timedelta(days=6)
    
    monday_str = monday.strftime('%Y-%m-%d')
    sunday_str = sunday.strftime('%Y-%m-%d')
    
    return f"{monday_str}_{sunday_str}"

def get_all_weeks_in_range(start_date, end_date):
    """Generate all week IDs between start and end date"""
    weeks = []
    current = datetime.strptime(start_date, '%Y-%m-%d')
    end = datetime.strptime(end_date, '%Y-%m-%d')
    
    while current <= end:
        week_id = calculate_week_id(current.strftime('%Y-%m-%d'))
        if week_id not in weeks:
            weeks.append(week_id)
        current += timedelta(days=7)
    
    return weeks

def validate_facebook_token():
    """Validate Facebook Access Token"""
    print('🔑 Validating Facebook Access Token...\n')
    
    headers = {
        'Authorization': f'Bearer {FB_ACCESS_TOKEN}'
    }
    
    # Test token with a simple API call
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

def fetch_facebook_ads_for_november():
    """Fetch all ads from Facebook for November 2025"""
    
    print('\n' + '='*80)
    print('FETCHING FACEBOOK ADS FOR NOVEMBER 2025')
    print('='*80 + '\n')
    
    # Validate token first
    if not validate_facebook_token():
        print('❌ Cannot proceed without valid Facebook token. Exiting.')
        return []
    
    start_date = '2025-11-01'
    end_date = '2025-11-30'
    
    print(f'📅 Date range: {start_date} to {end_date}\n')
    
    headers = {
        'Authorization': f'Bearer {FB_ACCESS_TOKEN}'
    }
    
    # Get all campaigns
    print('📊 Step 1: Fetching campaigns...\n')
    campaigns_url = f'https://graph.facebook.com/{FB_API_VERSION}/{FB_AD_ACCOUNT_ID}/campaigns'
    campaigns_params = {
        'fields': 'id,name,status',
        'limit': 100
    }
    
    try:
        response = requests.get(campaigns_url, headers=headers, params=campaigns_params)
        response.raise_for_status()
        campaigns = response.json().get('data', [])
        print(f'✅ Found {len(campaigns)} campaigns\n')
    except Exception as e:
        print(f'❌ Error fetching campaigns: {e}')
        return []
    
    # For each campaign, get ads with insights
    all_ads_data = []
    
    print('📊 Step 2: Fetching ads and insights...\n')
    
    for i, campaign in enumerate(campaigns, 1):
        campaign_id = campaign['id']
        campaign_name = campaign['name']
        
        print(f'[{i}/{len(campaigns)}] Processing: {campaign_name[:50]}')
        
        # Get ads for this campaign
        ads_url = f'https://graph.facebook.com/{FB_API_VERSION}/{campaign_id}/ads'
        ads_params = {
            'fields': 'id,name,adset_id,adset{name},campaign_id',
            'limit': 100
        }
        
        try:
            response = requests.get(ads_url, headers=headers, params=ads_params)
            
            # Check for specific error responses
            if response.status_code == 400:
                error_data = response.json()
                error_message = error_data.get('error', {}).get('message', 'Unknown error')
                error_code = error_data.get('error', {}).get('code', 0)
                
                # Check for rate limit errors
                if 'rate limit' in error_message.lower() or error_code == 4 or error_code == 17:
                    print(f'\n⚠️  RATE LIMIT REACHED!')
                    print(f'   Facebook API rate limit exceeded.')
                    print(f'   Processed {i-1} campaigns before hitting limit.')
                    print(f'   Please wait 1 hour and run the script again.\n')
                    break
                
                # Skip deleted/archived campaigns silently
                if 'does not exist' in error_message or 'been deleted' in error_message:
                    continue
                else:
                    print(f'   ⚠️  Skipping (400 error): {error_message[:80]}')
                    continue
            
            response.raise_for_status()
            ads = response.json().get('data', [])
            
            print(f'   Found {len(ads)} ads')
            
            # For each ad, get weekly insights
            for ad in ads:
                ad_id = ad['id']
                ad_name = ad.get('name', '')
                adset = ad.get('adset', {})
                
                # Get weekly insights for November
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
                    
                    if insights:
                        # Get first and last insight dates
                        first_date = insights[0]['date_start']
                        last_date = insights[-1]['date_stop']
                        
                        all_ads_data.append({
                            'adId': ad_id,
                            'adName': ad_name,
                            'adSetId': adset.get('id', ''),
                            'adSetName': adset.get('name', ''),
                            'campaignId': campaign_id,
                            'campaignName': campaign_name,
                            'firstInsightDate': first_date,
                            'lastInsightDate': last_date,
                            'totalWeeks': len(insights),
                            'insights': insights
                        })
                        print(f'      ✅ {ad_name[:40]} - {len(insights)} weeks ({first_date} to {last_date})')
                    
                    time.sleep(0.3)  # Rate limiting
                    
                except Exception as e:
                    print(f'      ⚠️  Error getting insights for {ad_name}: {e}')
                    continue
            
            time.sleep(0.5)  # Rate limiting between campaigns
            
        except Exception as e:
            print(f'   ❌ Error getting ads: {e}')
            continue
        
        print()
    
    print(f'\n✅ Total ads with insights: {len(all_ads_data)}\n')
    return all_ads_data

def get_firebase_ads_insights():
    """Get all ads and their insights from Firebase"""
    
    print('\n' + '='*80)
    print('FETCHING FIREBASE ADS DATA')
    print('='*80 + '\n')
    
    firebase_ads = {}
    
    # Check ads collection (month-first structure)
    print('📊 Checking ads collection...\n')
    
    ads_ref = db.collection('ads')
    all_ads = ads_ref.get()
    
    for ad_doc in all_ads:
        ad_id = ad_doc.id
        ad_data = ad_doc.to_dict()
        
        # Get insights subcollection
        insights_ref = ad_doc.reference.collection('insights')
        insights_docs = insights_ref.get()
        
        week_ids = [doc.id for doc in insights_docs]
        
        firebase_ads[ad_id] = {
            'adName': ad_data.get('adName', 'Unknown'),
            'campaignName': ad_data.get('campaignName', 'Unknown'),
            'weekIds': week_ids,
            'totalWeeks': len(week_ids)
        }
    
    print(f'✅ Found {len(firebase_ads)} ads in Firebase\n')
    return firebase_ads

def compare_and_find_gaps(facebook_ads, firebase_ads):
    """Compare Facebook and Firebase data to find missing insights"""
    
    print('\n' + '='*80)
    print('COMPARING FACEBOOK VS FIREBASE DATA')
    print('='*80 + '\n')
    
    gaps_found = []
    stats = {
        'total_facebook_ads': len(facebook_ads),
        'total_firebase_ads': len(firebase_ads),
        'ads_not_in_firebase': 0,
        'ads_with_missing_weeks': 0,
        'total_missing_weeks': 0,
        'ads_complete': 0
    }
    
    for fb_ad in facebook_ads:
        ad_id = fb_ad['adId']
        ad_name = fb_ad['adName']
        
        # Check if ad exists in Firebase
        if ad_id not in firebase_ads:
            stats['ads_not_in_firebase'] += 1
            
            # All weeks are missing
            expected_weeks = get_all_weeks_in_range(
                fb_ad['firstInsightDate'],
                fb_ad['lastInsightDate']
            )
            
            gaps_found.append({
                'adId': ad_id,
                'adName': ad_name,
                'campaignName': fb_ad['campaignName'],
                'status': 'NOT_IN_FIREBASE',
                'firstInsightDate': fb_ad['firstInsightDate'],
                'lastInsightDate': fb_ad['lastInsightDate'],
                'expectedWeeks': expected_weeks,
                'existingWeeks': [],
                'missingWeeks': expected_weeks,
                'insights': fb_ad['insights']
            })
            
            print(f'❌ {ad_name[:50]}')
            print(f'   Status: NOT IN FIREBASE')
            print(f'   Missing all {len(expected_weeks)} weeks')
            print()
            
        else:
            # Ad exists, check for missing weeks
            firebase_ad = firebase_ads[ad_id]
            
            # Get expected weeks based on Facebook date range
            expected_weeks = get_all_weeks_in_range(
                fb_ad['firstInsightDate'],
                fb_ad['lastInsightDate']
            )
            
            existing_weeks = set(firebase_ad['weekIds'])
            missing_weeks = [week for week in expected_weeks if week not in existing_weeks]
            
            if missing_weeks:
                stats['ads_with_missing_weeks'] += 1
                stats['total_missing_weeks'] += len(missing_weeks)
                
                gaps_found.append({
                    'adId': ad_id,
                    'adName': ad_name,
                    'campaignName': fb_ad['campaignName'],
                    'status': 'PARTIAL',
                    'firstInsightDate': fb_ad['firstInsightDate'],
                    'lastInsightDate': fb_ad['lastInsightDate'],
                    'expectedWeeks': expected_weeks,
                    'existingWeeks': list(existing_weeks),
                    'missingWeeks': missing_weeks,
                    'insights': fb_ad['insights']
                })
                
                print(f'⚠️  {ad_name[:50]}')
                print(f'   Status: PARTIAL DATA')
                print(f'   Expected weeks: {len(expected_weeks)}')
                print(f'   Existing weeks: {len(existing_weeks)}')
                print(f'   Missing weeks: {len(missing_weeks)}')
                print(f'   Missing: {", ".join(missing_weeks[:3])}{"..." if len(missing_weeks) > 3 else ""}')
                print()
            else:
                stats['ads_complete'] += 1
    
    # Print summary
    print('\n' + '='*80)
    print('SUMMARY')
    print('='*80 + '\n')
    
    print(f'📊 Statistics:')
    print(f'   Total Facebook ads: {stats["total_facebook_ads"]}')
    print(f'   Total Firebase ads: {stats["total_firebase_ads"]}')
    print(f'   Ads NOT in Firebase: {stats["ads_not_in_firebase"]}')
    print(f'   Ads with PARTIAL data: {stats["ads_with_missing_weeks"]}')
    print(f'   Ads COMPLETE: {stats["ads_complete"]}')
    print(f'   Total missing weeks: {stats["total_missing_weeks"]}')
    print()
    
    return gaps_found, stats

def backfill_missing_insights(gaps_found, dry_run=True):
    """Backfill missing insights into Firebase"""
    
    print('\n' + '='*80)
    if dry_run:
        print('DRY RUN - PREVIEW OF CHANGES (No data will be written)')
    else:
        print('BACKFILLING MISSING INSIGHTS')
    print('='*80 + '\n')
    
    backfill_stats = {
        'ads_processed': 0,
        'weeks_added': 0,
        'errors': 0
    }
    
    for gap in gaps_found:
        ad_id = gap['adId']
        ad_name = gap['adName']
        missing_weeks = gap['missingWeeks']
        
        print(f'Processing: {ad_name[:50]}')
        print(f'   Ad ID: {ad_id}')
        print(f'   Status: {gap["status"]}')
        print(f'   Missing weeks: {len(missing_weeks)}')
        
        if dry_run:
            print(f'   [DRY RUN] Would add {len(missing_weeks)} weeks')
            backfill_stats['weeks_added'] += len(missing_weeks)
        else:
            # Create/update ad document in ads collection
            ad_ref = db.collection('ads').document(ad_id)
            
            try:
                ad_ref.set({
                    'campaignId': gap['campaignId'],
                    'campaignName': gap['campaignName'],
                    'adSetId': gap.get('adSetId', ''),
                    'adSetName': gap.get('adSetName', ''),
                    'adId': ad_id,
                    'adName': ad_name,
                    'firstInsightDate': gap['firstInsightDate'],
                    'lastInsightDate': gap['lastInsightDate'],
                    'lastUpdated': firestore.SERVER_TIMESTAMP,
                    'lastFacebookSync': firestore.SERVER_TIMESTAMP
                }, merge=True)
                
                # Add missing insights
                for insight in gap['insights']:
                    week_id = calculate_week_id(insight['date_start'])
                    
                    # Only add if it's in the missing weeks list
                    if week_id in missing_weeks:
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
                        backfill_stats['weeks_added'] += 1
                
                print(f'   ✅ Added {len(missing_weeks)} weeks')
                backfill_stats['ads_processed'] += 1
                
            except Exception as e:
                print(f'   ❌ Error: {e}')
                backfill_stats['errors'] += 1
        
        print()
    
    # Print summary
    print('\n' + '='*80)
    print('BACKFILL SUMMARY')
    print('='*80 + '\n')
    
    print(f'📊 Results:')
    print(f'   Ads processed: {backfill_stats["ads_processed"]}')
    print(f'   Weeks added: {backfill_stats["weeks_added"]}')
    print(f'   Errors: {backfill_stats["errors"]}')
    print()
    
    return backfill_stats

def save_report(facebook_ads, gaps_found, stats):
    """Save a detailed report to JSON file"""
    
    timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
    filename = f'facebook_insights_gap_report_{timestamp}.json'
    
    report = {
        'timestamp': timestamp,
        'dateRange': '2025-11-01 to 2025-11-30',
        'summary': stats,
        'gaps': gaps_found,
        'allFacebookAds': facebook_ads
    }
    
    with open(filename, 'w') as f:
        json.dump(report, f, indent=2)
    
    print(f'📄 Report saved to: {filename}\n')
    return filename

def main():
    """Main execution function"""
    
    print('\n' + '='*80)
    print('FACEBOOK INSIGHTS GAP DETECTOR & BACKFILL TOOL')
    print('='*80)
    print(f'Started at: {datetime.now().strftime("%Y-%m-%d %H:%M:%S")}')
    print('='*80 + '\n')
    
    # Step 1: Fetch Facebook ads for November 2025
    facebook_ads = fetch_facebook_ads_for_november()
    
    if not facebook_ads:
        print('❌ No Facebook ads found. Exiting.')
        return
    
    # Step 2: Get Firebase ads data
    firebase_ads = get_firebase_ads_insights()
    
    # Step 3: Compare and find gaps
    gaps_found, stats = compare_and_find_gaps(facebook_ads, firebase_ads)
    
    # Step 4: Save report
    report_file = save_report(facebook_ads, gaps_found, stats)
    
    # Step 5: Ask user if they want to backfill
    if gaps_found:
        print('\n' + '='*80)
        print('BACKFILL OPTIONS')
        print('='*80 + '\n')
        
        print(f'Found {len(gaps_found)} ads with missing data.')
        print(f'Total missing weeks: {stats["total_missing_weeks"]}')
        print()
        print('Options:')
        print('  1. Dry run (preview changes without writing)')
        print('  2. Backfill missing data')
        print('  3. Skip backfill')
        print()
        
        choice = input('Enter your choice (1/2/3): ').strip()
        
        if choice == '1':
            backfill_missing_insights(gaps_found, dry_run=True)
        elif choice == '2':
            confirm = input('⚠️  This will write data to Firebase. Are you sure? (yes/no): ').strip().lower()
            if confirm == 'yes':
                backfill_missing_insights(gaps_found, dry_run=False)
            else:
                print('Backfill cancelled.')
        else:
            print('Skipping backfill.')
    else:
        print('✅ No gaps found! All Facebook ads are properly synced in Firebase.')
    
    print('\n' + '='*80)
    print('COMPLETED')
    print('='*80)
    print(f'Finished at: {datetime.now().strftime("%Y-%m-%d %H:%M:%S")}')
    if report_file:
        print(f'Report saved to: {report_file}')
    print('='*80 + '\n')
    
    # Show rate limit message if applicable
    if not facebook_ads:
        print('⚠️  NOTE: If you hit the rate limit, wait 1 hour and run again.')
        print('   The script will pick up where it left off.\n')

if __name__ == '__main__':
    main()

