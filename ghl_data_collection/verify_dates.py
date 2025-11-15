#!/usr/bin/env python3
"""
Verify that GHL submissions stored in Firestore are from November 2025
"""

import firebase_admin
from firebase_admin import credentials, firestore
from datetime import datetime
from collections import Counter

# Initialize Firebase
try:
    cred = credentials.Certificate('../medx-ai-firebase-adminsdk-fbsvc-a86e7bd050.json')
    firebase_admin.initialize_app(cred)
except:
    pass

db = firestore.client()

print('\n' + '='*80)
print('VERIFYING GHL SUBMISSION DATES IN FIRESTORE')
print('='*80 + '\n')

# Get all documents from ghl_data collection
docs = db.collection('ghl_data').stream()

dates = []
months = Counter()
years = Counter()

print('📊 Analyzing stored submissions...\n')

for doc in docs:
    data = doc.to_dict()
    created_at = data.get('createdAt')
    
    if created_at:
        # Parse the date
        try:
            dt = datetime.fromisoformat(created_at.replace('Z', '+00:00'))
            date_str = dt.strftime('%Y-%m-%d')
            month_str = dt.strftime('%B %Y')
            
            dates.append(date_str)
            months[month_str] += 1
            years[dt.year] += 1
            
        except Exception as e:
            print(f'⚠️  Could not parse date: {created_at}')

if dates:
    print(f'✅ Total submissions analyzed: {len(dates)}\n')
    
    print('📅 DATE RANGE:')
    print(f'   Earliest: {min(dates)}')
    print(f'   Latest: {max(dates)}\n')
    
    print('📊 BREAKDOWN BY MONTH:')
    for month, count in sorted(months.items()):
        print(f'   {month}: {count} submissions')
    
    print('\n📊 BREAKDOWN BY YEAR:')
    for year, count in sorted(years.items()):
        print(f'   {year}: {count} submissions')
    
    # Check if all are from November 2025
    print('\n' + '='*80)
    if len(months) == 1 and 'November 2025' in months:
        print('✅ VERIFIED: All submissions are from November 2025!')
    else:
        print('⚠️  WARNING: Found submissions from other months!')
        print('   This might indicate an issue with the date filtering.')
    print('='*80 + '\n')
    
    # Show sample dates
    print('📋 Sample submission dates (first 10):')
    for i, date in enumerate(sorted(dates)[:10], 1):
        print(f'   {i}. {date}')
    
else:
    print('❌ No submissions found in ghl_data collection\n')

