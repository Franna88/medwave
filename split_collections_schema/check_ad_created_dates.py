#!/usr/bin/env python3
"""
Check all ads in the new split collections schema for date fields
Verify when ads were created and when they started running
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
print('CHECKING AD DATES IN SPLIT COLLECTIONS SCHEMA')
print('='*80 + '\n')

print('📊 Analyzing ads collection...\n')

# Fetch all ads
ads_ref = db.collection('ads')
ads = list(ads_ref.stream())

print(f'✅ Found {len(ads)} ads in collection\n')

if not ads:
    print('❌ No ads found!')
    exit(1)

# Collect date field information
date_fields_found = set()
all_ads_data = []

print('📂 Scanning ads for date fields...\n')

for ad_doc in ads:
    ad_data = ad_doc.to_dict()
    ad_id = ad_doc.id
    
    ad_info = {
        'adId': ad_id,
        'adName': ad_data.get('adName', 'Unknown'),
        'campaignName': ad_data.get('campaignName', 'Unknown'),
        'campaignId': ad_data.get('campaignId', 'Unknown')
    }
    
    # Collect all date-related fields from main document
    for field in ad_data.keys():
        if any(date_word in field.lower() for date_word in ['date', 'created', 'time', 'updated', 'sync']):
            date_fields_found.add(field)
            ad_info[field] = ad_data[field]
    
    # Check for facebookStats with dates
    if 'facebookStats' in ad_data:
        fb_stats = ad_data['facebookStats']
        if isinstance(fb_stats, dict):
            for field in fb_stats.keys():
                if any(date_word in field.lower() for date_word in ['date', 'start', 'stop', 'created']):
                    full_field = f'facebookStats.{field}'
                    date_fields_found.add(full_field)
                    ad_info[full_field] = fb_stats[field]
    
    # Check for insights subcollection (first insight = ad start date)
    insights = list(ad_doc.reference.collection('insights').order_by('dateStart').limit(1).stream())
    if insights:
        first_insight = insights[0].to_dict()
        if 'dateStart' in first_insight:
            ad_info['firstInsightDate'] = first_insight['dateStart']
            date_fields_found.add('firstInsightDate')
    
    all_ads_data.append(ad_info)

print(f'✅ Scanned {len(all_ads_data)} ads\n')

# Display date fields found
print('='*80)
print('DATE FIELDS FOUND IN ADS:')
print('='*80 + '\n')

for field in sorted(date_fields_found):
    count = sum(1 for ad in all_ads_data if field in ad and ad[field] is not None)
    percentage = (count / len(all_ads_data) * 100) if all_ads_data else 0
    print(f'   • {field}: {count} ads ({percentage:.1f}%)')

print('\n')

# Display sample ads with their dates
print('='*80)
print('SAMPLE ADS WITH DATE INFORMATION (First 15):')
print('='*80 + '\n')

for i, ad in enumerate(all_ads_data[:15]):
    print(f'{i+1}. Ad: {ad["adName"][:60]}')
    print(f'   Campaign: {ad["campaignName"][:60]}')
    
    # Display all date fields
    for field in sorted(date_fields_found):
        if field in ad:
            value = ad[field]
            if isinstance(value, datetime):
                print(f'   {field}: {value.strftime("%Y-%m-%d %H:%M:%S")}')
            elif isinstance(value, str):
                # Try to parse if it's a date string
                try:
                    if len(value) == 10 and value.count('-') == 2:  # YYYY-MM-DD
                        print(f'   {field}: {value}')
                    else:
                        dt = datetime.fromisoformat(value.replace('Z', '+00:00'))
                        print(f'   {field}: {dt.strftime("%Y-%m-%d %H:%M:%S")}')
                except:
                    print(f'   {field}: {value}')
            else:
                print(f'   {field}: {value}')
    
    print()

# Summary statistics
print('='*80)
print('SUMMARY:')
print('='*80 + '\n')

print(f'Total ads: {len(all_ads_data)}')
print(f'Date fields found: {len(date_fields_found)}')
print()

# Count how many ads have each date field
for field in sorted(date_fields_found):
    count = sum(1 for ad in all_ads_data if field in ad and ad[field] is not None)
    percentage = (count / len(all_ads_data) * 100) if all_ads_data else 0
    print(f'   {field}: {count} ads ({percentage:.1f}%)')

# Analyze date ranges
print('\n' + '='*80)
print('DATE RANGE ANALYSIS:')
print('='*80 + '\n')

# Check firstInsightDate (actual ad start date from Facebook)
ads_with_start_date = [ad for ad in all_ads_data if 'firstInsightDate' in ad and ad['firstInsightDate']]
print(f'✅ Ads with actual start date (from insights): {len(ads_with_start_date)} ({len(ads_with_start_date)/len(all_ads_data)*100:.1f}%)\n')

if ads_with_start_date:
    dates = []
    for ad in ads_with_start_date:
        date_val = ad['firstInsightDate']
        if isinstance(date_val, str):
            try:
                if len(date_val) == 10:  # YYYY-MM-DD
                    dates.append(datetime.strptime(date_val, '%Y-%m-%d'))
                else:
                    dates.append(datetime.fromisoformat(date_val.replace('Z', '+00:00')))
            except:
                pass
        elif isinstance(date_val, datetime):
            dates.append(date_val)
    
    if dates:
        earliest = min(dates)
        latest = max(dates)
        print(f'📅 Ad Start Date Range (from Facebook insights):')
        print(f'   Earliest ad started: {earliest.strftime("%Y-%m-%d")}')
        print(f'   Latest ad started: {latest.strftime("%Y-%m-%d")}')
        print(f'   Span: {(latest - earliest).days} days')
        print()

# Check facebookStats.dateStart
ads_with_fb_start = [ad for ad in all_ads_data if 'facebookStats.dateStart' in ad and ad['facebookStats.dateStart']]
print(f'✅ Ads with facebookStats.dateStart: {len(ads_with_fb_start)} ({len(ads_with_fb_start)/len(all_ads_data)*100:.1f}%)\n')

if ads_with_fb_start:
    dates = []
    for ad in ads_with_fb_start:
        date_val = ad['facebookStats.dateStart']
        if isinstance(date_val, str):
            try:
                if len(date_val) == 10:  # YYYY-MM-DD
                    dates.append(datetime.strptime(date_val, '%Y-%m-%d'))
                else:
                    dates.append(datetime.fromisoformat(date_val.replace('Z', '+00:00')))
            except:
                pass
        elif isinstance(date_val, datetime):
            dates.append(date_val)
    
    if dates:
        earliest = min(dates)
        latest = max(dates)
        print(f'📅 Facebook Stats Date Range:')
        print(f'   Earliest: {earliest.strftime("%Y-%m-%d")}')
        print(f'   Latest: {latest.strftime("%Y-%m-%d")}')
        print(f'   Span: {(latest - earliest).days} days')
        print()

# Check createdAt (when ad was added to Firebase)
ads_with_created = [ad for ad in all_ads_data if 'createdAt' in ad and ad['createdAt']]
print(f'✅ Ads with createdAt (Firebase timestamp): {len(ads_with_created)} ({len(ads_with_created)/len(all_ads_data)*100:.1f}%)\n')

if ads_with_created:
    dates = []
    for ad in ads_with_created:
        date_val = ad['createdAt']
        if isinstance(date_val, datetime):
            dates.append(date_val)
    
    if dates:
        earliest = min(dates)
        latest = max(dates)
        print(f'📅 Firebase Creation Date Range:')
        print(f'   Earliest created: {earliest.strftime("%Y-%m-%d %H:%M:%S")}')
        print(f'   Latest created: {latest.strftime("%Y-%m-%d %H:%M:%S")}')
        print(f'   Span: {(latest - earliest).days} days')
        print()

# Group ads by month of first insight
print('='*80)
print('ADS BY MONTH (based on first insight date):')
print('='*80 + '\n')

ads_by_month = defaultdict(int)
for ad in ads_with_start_date:
    date_val = ad['firstInsightDate']
    if isinstance(date_val, str):
        try:
            if len(date_val) == 10:
                dt = datetime.strptime(date_val, '%Y-%m-%d')
            else:
                dt = datetime.fromisoformat(date_val.replace('Z', '+00:00'))
            month_key = dt.strftime('%Y-%m')
            ads_by_month[month_key] += 1
        except:
            pass
    elif isinstance(date_val, datetime):
        month_key = date_val.strftime('%Y-%m')
        ads_by_month[month_key] += 1

for month in sorted(ads_by_month.keys()):
    count = ads_by_month[month]
    print(f'   {month}: {count} ads')

# Check for ads without date information
print('\n' + '='*80)
print('ADS WITHOUT DATE INFORMATION:')
print('='*80 + '\n')

ads_without_dates = [ad for ad in all_ads_data if 'firstInsightDate' not in ad and 'facebookStats.dateStart' not in ad]
print(f'⚠️  Ads with NO date information: {len(ads_without_dates)} ({len(ads_without_dates)/len(all_ads_data)*100:.1f}%)\n')

if ads_without_dates and len(ads_without_dates) <= 20:
    print('Ads without dates:')
    for ad in ads_without_dates:
        print(f'   • {ad["adId"]}: {ad["adName"][:50]}')
        print(f'     Campaign: {ad["campaignName"][:50]}')
elif len(ads_without_dates) > 20:
    print(f'Too many ads without dates to list ({len(ads_without_dates)} ads)')
    print('Sample of first 10:')
    for ad in ads_without_dates[:10]:
        print(f'   • {ad["adId"]}: {ad["adName"][:50]}')

print('\n' + '='*80)
print('CONCLUSION:')
print('='*80 + '\n')

if len(ads_with_start_date) == len(all_ads_data):
    print('✅ ALL ads have start date information!')
elif len(ads_with_start_date) > len(all_ads_data) * 0.95:
    print(f'✅ Most ads have start date information ({len(ads_with_start_date)/len(all_ads_data)*100:.1f}%)')
else:
    print(f'⚠️  Only {len(ads_with_start_date)/len(all_ads_data)*100:.1f}% of ads have start date information')

print('\n' + '='*80 + '\n')

