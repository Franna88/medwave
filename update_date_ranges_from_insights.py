#!/usr/bin/env python3
"""
Update AdSet and Campaign Date Ranges from Insights

This script:
1. Reads all ads from the ads collection
2. For each ad, gets the earliest and latest dates from insights subcollection
3. Updates the ad document with firstInsightDate and lastInsightDate
4. Aggregates dates by adSetId and updates adSets collection
5. Aggregates dates by campaignId and updates campaigns collection
"""

import firebase_admin
from firebase_admin import credentials, firestore
from datetime import datetime
from collections import defaultdict

# Initialize Firebase
try:
    cred = credentials.Certificate('medx-ai-firebase-adminsdk-fbsvc-a86e7bd050.json')
    firebase_admin.initialize_app(cred)
except:
    pass

db = firestore.client()

def get_date_range_from_ad(ad_data):
    """Get the firstInsightDate and lastInsightDate from the ad document itself"""
    
    first_date = ad_data.get('firstInsightDate')
    last_date = ad_data.get('lastInsightDate')
    
    # Handle empty strings
    if first_date == '':
        first_date = None
    if last_date == '':
        last_date = None
    
    return first_date, last_date

def collect_ad_date_ranges():
    """Collect date ranges from all ads (firstInsightDate and lastInsightDate)"""
    
    print('\n' + '='*80)
    print('STEP 1: READING DATE RANGES FROM ADS')
    print('='*80 + '\n')
    
    ads_ref = db.collection('ads')
    all_ads = ads_ref.get()
    
    print(f'📊 Found {len(all_ads)} ads in collection\n')
    
    ad_date_ranges = {}  # Store for aggregation
    stats = {
        'total_ads': len(all_ads),
        'ads_with_insights': 0,
        'ads_without_insights': 0,
        'errors': 0
    }
    
    for ad_doc in all_ads:
        ad_id = ad_doc.id
        ad_data = ad_doc.to_dict()
        ad_name = ad_data.get('adName', 'Unknown')
        ad_set_id = ad_data.get('adSetId', '')
        campaign_id = ad_data.get('campaignId', '')
        
        try:
            # Get date range from ad document itself
            earliest_date, latest_date = get_date_range_from_ad(ad_data)
            
            if earliest_date and latest_date:
                # Store for aggregation (don't update the ad)
                ad_date_ranges[ad_id] = {
                    'adSetId': ad_set_id,
                    'campaignId': campaign_id,
                    'firstDate': earliest_date,
                    'lastDate': latest_date
                }
                
                stats['ads_with_insights'] += 1
                
                print(f'✅ {ad_name[:50]} - {earliest_date} to {latest_date}')
            else:
                stats['ads_without_insights'] += 1
                print(f'⚠️  {ad_name[:50]} - No insights found')
        
        except Exception as e:
            stats['errors'] += 1
            print(f'❌ {ad_name[:50]} - Error: {e}')
    
    print(f'\n📊 Summary:')
    print(f'   Total ads: {stats["total_ads"]}')
    print(f'   Ads with insights: {stats["ads_with_insights"]}')
    print(f'   Ads without insights: {stats["ads_without_insights"]}')
    print(f'   Errors: {stats["errors"]}')
    print()
    
    return ad_date_ranges

def update_adsets_with_date_ranges(ad_date_ranges):
    """Update adSets with aggregated date ranges from their ads"""
    
    print('\n' + '='*80)
    print('STEP 2: UPDATING ADSETS WITH AGGREGATED DATE RANGES')
    print('='*80 + '\n')
    
    # Group ads by adSetId
    adset_dates = defaultdict(lambda: {'firstDate': None, 'lastDate': None, 'adCount': 0})
    
    for ad_id, ad_info in ad_date_ranges.items():
        ad_set_id = ad_info['adSetId']
        
        if not ad_set_id:
            continue
        
        first_date = ad_info['firstDate']
        last_date = ad_info['lastDate']
        
        # Update earliest date
        if adset_dates[ad_set_id]['firstDate'] is None or first_date < adset_dates[ad_set_id]['firstDate']:
            adset_dates[ad_set_id]['firstDate'] = first_date
        
        # Update latest date
        if adset_dates[ad_set_id]['lastDate'] is None or last_date > adset_dates[ad_set_id]['lastDate']:
            adset_dates[ad_set_id]['lastDate'] = last_date
        
        adset_dates[ad_set_id]['adCount'] += 1
    
    print(f'📊 Found {len(adset_dates)} ad sets to update\n')
    
    stats = {
        'total_adsets': len(adset_dates),
        'updated': 0,
        'errors': 0
    }
    
    adsets_ref = db.collection('adSets')
    
    for ad_set_id, date_info in adset_dates.items():
        try:
            adset_doc = adsets_ref.document(ad_set_id).get()
            
            if adset_doc.exists:
                adset_data = adset_doc.to_dict()
                adset_name = adset_data.get('adSetName', 'Unknown')
                
                # Update the adSet document
                adsets_ref.document(ad_set_id).update({
                    'firstAdDate': date_info['firstDate'],
                    'lastAdDate': date_info['lastDate'],
                    'lastUpdated': firestore.SERVER_TIMESTAMP
                })
                
                stats['updated'] += 1
                print(f'✅ {adset_name[:50]}')
                print(f'   Date range: {date_info["firstDate"]} to {date_info["lastDate"]}')
                print(f'   Ads: {date_info["adCount"]}')
                print()
            else:
                print(f'⚠️  AdSet {ad_set_id} not found in adSets collection')
        
        except Exception as e:
            stats['errors'] += 1
            print(f'❌ AdSet {ad_set_id} - Error: {e}')
    
    print(f'\n📊 Summary:')
    print(f'   Total ad sets: {stats["total_adsets"]}')
    print(f'   Updated: {stats["updated"]}')
    print(f'   Errors: {stats["errors"]}')
    print()
    
    return adset_dates

def update_campaigns_with_date_ranges(ad_date_ranges):
    """Update campaigns with aggregated date ranges from their ads"""
    
    print('\n' + '='*80)
    print('STEP 3: UPDATING CAMPAIGNS WITH AGGREGATED DATE RANGES')
    print('='*80 + '\n')
    
    # Group ads by campaignId
    campaign_dates = defaultdict(lambda: {'firstDate': None, 'lastDate': None, 'adCount': 0})
    
    for ad_id, ad_info in ad_date_ranges.items():
        campaign_id = ad_info['campaignId']
        
        if not campaign_id:
            continue
        
        first_date = ad_info['firstDate']
        last_date = ad_info['lastDate']
        
        # Update earliest date
        if campaign_dates[campaign_id]['firstDate'] is None or first_date < campaign_dates[campaign_id]['firstDate']:
            campaign_dates[campaign_id]['firstDate'] = first_date
        
        # Update latest date
        if campaign_dates[campaign_id]['lastDate'] is None or last_date > campaign_dates[campaign_id]['lastDate']:
            campaign_dates[campaign_id]['lastDate'] = last_date
        
        campaign_dates[campaign_id]['adCount'] += 1
    
    print(f'📊 Found {len(campaign_dates)} campaigns to update\n')
    
    stats = {
        'total_campaigns': len(campaign_dates),
        'updated': 0,
        'errors': 0
    }
    
    campaigns_ref = db.collection('campaigns')
    
    for campaign_id, date_info in campaign_dates.items():
        try:
            campaign_doc = campaigns_ref.document(campaign_id).get()
            
            if campaign_doc.exists:
                campaign_data = campaign_doc.to_dict()
                campaign_name = campaign_data.get('campaignName', 'Unknown')
                
                # Update the campaign document
                campaigns_ref.document(campaign_id).update({
                    'firstAdDate': date_info['firstDate'],
                    'lastAdDate': date_info['lastDate'],
                    'lastUpdated': firestore.SERVER_TIMESTAMP
                })
                
                stats['updated'] += 1
                print(f'✅ {campaign_name[:60]}')
                print(f'   Date range: {date_info["firstDate"]} to {date_info["lastDate"]}')
                print(f'   Ads: {date_info["adCount"]}')
                print()
            else:
                print(f'⚠️  Campaign {campaign_id} not found in campaigns collection')
        
        except Exception as e:
            stats['errors'] += 1
            print(f'❌ Campaign {campaign_id} - Error: {e}')
    
    print(f'\n📊 Summary:')
    print(f'   Total campaigns: {stats["total_campaigns"]}')
    print(f'   Updated: {stats["updated"]}')
    print(f'   Errors: {stats["errors"]}')
    print()

def main():
    """Main execution function"""
    
    print('\n' + '='*80)
    print('UPDATE DATE RANGES FROM INSIGHTS')
    print('='*80)
    print(f'Started at: {datetime.now().strftime("%Y-%m-%d %H:%M:%S")}')
    print('='*80 + '\n')
    
    print('This script will:')
    print('1. Read insights dates from all ads (from insights subcollection)')
    print('2. Update adSets with aggregated firstAdDate and lastAdDate')
    print('3. Update campaigns with aggregated firstAdDate and lastAdDate')
    print()
    
    confirm = input('Do you want to proceed? (yes/no): ').strip().lower()
    
    if confirm != 'yes':
        print('Operation cancelled.')
        return
    
    # Step 1: Collect date ranges from ads' insights
    ad_date_ranges = collect_ad_date_ranges()
    
    if not ad_date_ranges:
        print('❌ No ads with insights found. Exiting.')
        return
    
    # Step 2: Update adSets with aggregated dates
    update_adsets_with_date_ranges(ad_date_ranges)
    
    # Step 3: Update campaigns with aggregated dates
    update_campaigns_with_date_ranges(ad_date_ranges)
    
    print('\n' + '='*80)
    print('✅ COMPLETED SUCCESSFULLY')
    print('='*80)
    print(f'Finished at: {datetime.now().strftime("%Y-%m-%d %H:%M:%S")}')
    print('='*80 + '\n')
    
    print('📋 What was updated:')
    print('   - adSets collection: firstAdDate, lastAdDate')
    print('   - campaigns collection: firstAdDate, lastAdDate')
    print()
    print('✅ Your date ranges now reflect the actual insights data!')
    print('   (Dates are aggregated from ads → insights subcollections)')
    print()

if __name__ == '__main__':
    main()

