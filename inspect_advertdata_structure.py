#!/usr/bin/env python3
"""
Inspect advertData Collection Structure
Shows both old and new structure side-by-side
"""

import firebase_admin
from firebase_admin import credentials, firestore
from collections import defaultdict

# Initialize Firebase
if not firebase_admin._apps:
    cred = credentials.Certificate('medx-ai-firebase-adminsdk-fbsvc-a86e7bd050.json')
    firebase_admin.initialize_app(cred)

db = firestore.client()

print('=' * 80)
print('ADVERTDATA COLLECTION STRUCTURE INSPECTION')
print('=' * 80)

# Get all documents in advertData collection
print('\n📊 Step 1: Fetching all top-level documents in advertData...')
all_docs = list(db.collection('advertData').stream())
print(f'   ✅ Found {len(all_docs)} top-level documents')

# Categorize documents
old_structure_ads = []
new_structure_months = []

for doc in all_docs:
    data = doc.to_dict()
    
    # Check if this is a month document (new structure)
    # Month docs have 'totalAds' field or doc ID looks like a month (YYYY-MM)
    if 'totalAds' in data or doc.id.count('-') == 1 or doc.id in ['_placeh', 'unknown']:
        new_structure_months.append(doc)
    else:
        # This is an old structure ad (has adId, adName, etc.)
        old_structure_ads.append(doc)

print('\n' + '=' * 80)
print('STRUCTURE BREAKDOWN')
print('=' * 80)

print(f'\n📁 OLD STRUCTURE (advertData/{{adId}}):')
print(f'   Total ads: {len(old_structure_ads)}')
if len(old_structure_ads) > 0:
    print(f'\n   Sample ads (first 5):')
    for i, ad in enumerate(old_structure_ads[:5], 1):
        data = ad.to_dict()
        print(f'   {i}. {ad.id}')
        print(f'      Name: {data.get("adName", "N/A")}')
        print(f'      Campaign: {data.get("campaignName", "N/A")}')

print(f'\n📅 NEW STRUCTURE (advertData/{{month}}/ads/{{adId}}):')
print(f'   Total month documents: {len(new_structure_months)}')

# Inspect each month
month_details = {}
for month_doc in new_structure_months:
    month_id = month_doc.id
    month_data = month_doc.to_dict()
    
    # Count ads in this month's subcollection
    ads_ref = month_doc.reference.collection('ads')
    ads_count = len(list(ads_ref.limit(1000).stream()))
    
    month_details[month_id] = {
        'totalAds': month_data.get('totalAds', 0),
        'adsWithInsights': month_data.get('adsWithInsights', 0),
        'adsWithGHLData': month_data.get('adsWithGHLData', 0),
        'actualAdsCount': ads_count,
        'lastUpdated': month_data.get('lastUpdated')
    }

# Sort months
sorted_months = sorted([m for m in month_details.keys() if m not in ['_placeh', 'unknown']])
if '_placeh' in month_details:
    sorted_months.insert(0, '_placeh')
if 'unknown' in month_details:
    sorted_months.append('unknown')

print(f'\n   Month breakdown:')
total_new_ads = 0
for month_id in sorted_months:
    details = month_details[month_id]
    total_new_ads += details['actualAdsCount']
    
    flag = '⚠️ ' if month_id in ['_placeh', 'unknown'] else '✅'
    print(f'\n   {flag} {month_id}:')
    print(f'      Summary says: {details["totalAds"]} ads')
    print(f'      Actually has: {details["actualAdsCount"]} ads in subcollection')
    print(f'      With insights: {details["adsWithInsights"]}')
    print(f'      With GHL data: {details["adsWithGHLData"]}')
    
    # Sample 2 ads from this month
    if details['actualAdsCount'] > 0:
        sample_ads = list(db.collection('advertData').document(month_id).collection('ads').limit(2).stream())
        if sample_ads:
            print(f'      Sample ads:')
            for ad in sample_ads:
                ad_data = ad.to_dict()
                print(f'         - {ad.id}: {ad_data.get("adName", "N/A")}')

print('\n' + '=' * 80)
print('SUMMARY')
print('=' * 80)
print(f'\n📊 Total ads in OLD structure: {len(old_structure_ads)}')
print(f'📊 Total ads in NEW structure: {total_new_ads}')
print(f'📊 Total top-level documents: {len(all_docs)}')

if len(old_structure_ads) > 0:
    print(f'\n⚠️  WARNING: You still have {len(old_structure_ads)} ads in the OLD structure!')
    print(f'   These are at: advertData/{{adId}}')
    print(f'   The migration created NEW copies at: advertData/{{month}}/ads/{{adId}}')
    print(f'   You now have DUPLICATE data!')
else:
    print(f'\n✅ No ads in old structure - migration cleanup complete!')

print('\n' + '=' * 80)
print('ISSUES DETECTED')
print('=' * 80)

issues = []

if '_placeh' in month_details:
    issues.append(f"⚠️  {month_details['_placeh']['actualAdsCount']} ads assigned to '_placeh' (placeholder month)")
    issues.append(f"   These ads had no insights to determine their month")

if 'unknown' in month_details:
    issues.append(f"⚠️  {month_details['unknown']['actualAdsCount']} ads assigned to 'unknown' month")
    issues.append(f"   These ads had no insights or GHL data to determine their month")

if len(old_structure_ads) > 0:
    issues.append(f"⚠️  {len(old_structure_ads)} ads still in old structure (duplicates)")
    issues.append(f"   Run cleanup_old_structure.py to remove them")

if issues:
    for issue in issues:
        print(issue)
else:
    print('✅ No issues detected!')

print('\n' + '=' * 80)
print('NEXT STEPS')
print('=' * 80)

if '_placeh' in month_details or 'unknown' in month_details:
    print('\n1. Fix placeholder/unknown ads:')
    print('   - These ads need their month determined from insights dateStart')
    print('   - Create a script to reassign them to correct months')

if len(old_structure_ads) > 0:
    print('\n2. Clean up old structure:')
    print('   python3 cleanup_old_structure.py')
    print('   (This will delete the old advertData/{adId} documents)')

print('\n3. Update Firebase Functions:')
print('   firebase deploy --only functions')
print('   (Deploy the updated facebookAdsSync.js)')

print('\n4. Test queries:')
print('   - Query advertData/2025-10/ads to get October ads')
print('   - Verify performance is faster')

print('\n' + '=' * 80)





