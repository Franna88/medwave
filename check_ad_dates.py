#!/usr/bin/env python3
"""
Check all ads in advertData collection for date fields
"""

import firebase_admin
from firebase_admin import credentials, firestore
from datetime import datetime

# Initialize Firebase
try:
    cred = credentials.Certificate('medx-ai-firebase-adminsdk-fbsvc-a86e7bd050.json')
    firebase_admin.initialize_app(cred)
except:
    pass

db = firestore.client()

print('\n' + '='*80)
print('CHECKING AD DATES IN ADVERTDATA COLLECTION')
print('='*80 + '\n')

# Check if using month-first structure or flat structure
print('📊 Checking collection structure...\n')

# Try to get a few top-level documents to determine structure
top_docs = list(db.collection('advertData').limit(5).stream())

if not top_docs:
    print('❌ No documents found in advertData collection!')
    exit(1)

# Check if first doc looks like a month document (has totalAds field) or an ad document
first_doc = top_docs[0]
first_data = first_doc.to_dict()

if 'totalAds' in first_data:
    print('✅ Using MONTH-FIRST structure: advertData/{month}/ads/{adId}\n')
    structure = 'month-first'
else:
    print('✅ Using FLAT structure: advertData/{adId}\n')
    structure = 'flat'

# Collect all ads and their date information
all_ads = []
date_fields_found = set()

if structure == 'month-first':
    print('📂 Scanning month documents...\n')
    
    # Get all month documents
    months = list(db.collection('advertData').stream())
    
    for month_doc in months:
        month_data = month_doc.to_dict()
        
        # Skip if not a month document
        if 'totalAds' not in month_data:
            continue
        
        month_id = month_doc.id
        print(f'   Month: {month_id} ({month_data.get("totalAds", 0)} ads)')
        
        # Get ads in this month
        ads = list(db.collection('advertData').document(month_id).collection('ads').stream())
        
        for ad_doc in ads:
            ad_data = ad_doc.to_dict()
            ad_id = ad_doc.id
            
            # Collect all date-related fields
            ad_info = {
                'adId': ad_id,
                'adName': ad_data.get('adName', 'Unknown'),
                'campaignName': ad_data.get('campaignName', 'Unknown'),
                'month': month_id
            }
            
            # Check for various date fields
            for field in ad_data.keys():
                if any(date_word in field.lower() for date_word in ['date', 'created', 'time', 'updated', 'sync']):
                    date_fields_found.add(field)
                    ad_info[field] = ad_data[field]
            
            # Get earliest insight date (ad start date)
            insights = list(ad_doc.reference.collection('insights').order_by('dateStart').limit(1).stream())
            if insights:
                insight_data = insights[0].to_dict()
                ad_info['firstInsightDate'] = insight_data.get('dateStart')
                date_fields_found.add('firstInsightDate')
            
            all_ads.append(ad_info)
    
    print(f'\n✅ Found {len(all_ads)} ads across {len([m for m in months if "totalAds" in m.to_dict()])} months\n')

else:  # flat structure
    print('📂 Scanning ads...\n')
    
    ads = list(db.collection('advertData').stream())
    
    for ad_doc in ads:
        ad_data = ad_doc.to_dict()
        ad_id = ad_doc.id
        
        # Collect all date-related fields
        ad_info = {
            'adId': ad_id,
            'adName': ad_data.get('adName', 'Unknown'),
            'campaignName': ad_data.get('campaignName', 'Unknown')
        }
        
        # Check for various date fields
        for field in ad_data.keys():
            if any(date_word in field.lower() for date_word in ['date', 'created', 'time', 'updated', 'sync']):
                date_fields_found.add(field)
                ad_info[field] = ad_data[field]
        
        # Get earliest insight date (ad start date)
        insights = list(ad_doc.reference.collection('insights').order_by('dateStart').limit(1).stream())
        if insights:
            insight_data = insights[0].to_dict()
            ad_info['firstInsightDate'] = insight_data.get('dateStart')
            date_fields_found.add('firstInsightDate')
        
        all_ads.append(ad_info)
    
    print(f'\n✅ Found {len(all_ads)} ads\n')

# Display date fields found
print('='*80)
print('DATE FIELDS FOUND IN ADS:')
print('='*80 + '\n')

for field in sorted(date_fields_found):
    print(f'   • {field}')

print('\n')

# Display sample ads with their dates
print('='*80)
print('SAMPLE ADS WITH DATE INFORMATION (First 10):')
print('='*80 + '\n')

for i, ad in enumerate(all_ads[:10]):
    print(f'{i+1}. Ad: {ad["adName"][:50]}')
    print(f'   Campaign: {ad["campaignName"][:50]}')
    if 'month' in ad:
        print(f'   Month: {ad["month"]}')
    
    # Display all date fields
    for field in sorted(date_fields_found):
        if field in ad:
            value = ad[field]
            if isinstance(value, datetime):
                print(f'   {field}: {value.strftime("%Y-%m-%d %H:%M:%S")}')
            elif isinstance(value, str):
                print(f'   {field}: {value}')
            else:
                print(f'   {field}: {value}')
    
    print()

# Summary statistics
print('='*80)
print('SUMMARY:')
print('='*80 + '\n')

print(f'Total ads: {len(all_ads)}')
print(f'Date fields found: {len(date_fields_found)}')

# Count how many ads have each date field
for field in sorted(date_fields_found):
    count = sum(1 for ad in all_ads if field in ad and ad[field] is not None)
    percentage = (count / len(all_ads) * 100) if all_ads else 0
    print(f'   {field}: {count} ads ({percentage:.1f}%)')

# Check if ads have firstInsightDate (actual ad start date)
ads_with_start_date = sum(1 for ad in all_ads if 'firstInsightDate' in ad and ad['firstInsightDate'])
print(f'\n✅ Ads with actual start date (from insights): {ads_with_start_date} ({ads_with_start_date/len(all_ads)*100:.1f}%)')

# Find date range
if ads_with_start_date > 0:
    dates = []
    for ad in all_ads:
        if 'firstInsightDate' in ad and ad['firstInsightDate']:
            date_val = ad['firstInsightDate']
            if isinstance(date_val, str):
                try:
                    dates.append(datetime.strptime(date_val, '%Y-%m-%d'))
                except:
                    pass
            elif isinstance(date_val, datetime):
                dates.append(date_val)
    
    if dates:
        earliest = min(dates)
        latest = max(dates)
        print(f'\n📅 Date range of ads:')
        print(f'   Earliest ad started: {earliest.strftime("%Y-%m-%d")}')
        print(f'   Latest ad started: {latest.strftime("%Y-%m-%d")}')
        print(f'   Span: {(latest - earliest).days} days')

print('\n' + '='*80 + '\n')





