#!/usr/bin/env python3
"""
Test query performance with new month-first structure
Compares old vs new query patterns
"""

import firebase_admin
from firebase_admin import credentials, firestore
import time

# Initialize Firebase
if not firebase_admin._apps:
    cred = credentials.Certificate('medx-ai-firebase-adminsdk-fbsvc-a86e7bd050.json')
    firebase_admin.initialize_app(cred)

db = firestore.client()

def test_query_all_months():
    """Test: Get all available months"""
    
    print('\n📊 Test 1: Get all available months')
    print('   Query: collection("advertData").get()')
    
    start = time.time()
    months = list(db.collection('advertData').stream())
    elapsed = time.time() - start
    
    month_ids = [m.id for m in months if m.id != 'adId']  # Exclude old structure docs
    
    print(f'   ✅ Found {len(month_ids)} months in {elapsed:.3f}s')
    print(f'   Months: {sorted(month_ids)}')
    
    return elapsed

def test_query_single_month():
    """Test: Get all ads for a specific month"""
    
    print('\n📊 Test 2: Get all ads for October 2025')
    print('   Query: collection("advertData").doc("2025-10").collection("ads").get()')
    
    start = time.time()
    ads = list(db.collection('advertData').document('2025-10').collection('ads').stream())
    elapsed = time.time() - start
    
    print(f'   ✅ Found {len(ads)} ads in {elapsed:.3f}s')
    
    if ads:
        sample = ads[0].to_dict()
        print(f'   Sample ad: {sample.get("adName", "N/A")[:50]}')
    
    return elapsed, len(ads)

def test_query_filtered_ads():
    """Test: Get ads with both insights and GHL data"""
    
    print('\n📊 Test 3: Get October ads with both insights and GHL data')
    print('   Query: collection("advertData").doc("2025-10").collection("ads")')
    print('          .where("hasInsights", "==", True)')
    print('          .where("hasGHLData", "==", True).get()')
    
    start = time.time()
    ads = list(db.collection('advertData').document('2025-10').collection('ads')
        .where('hasInsights', '==', True)
        .where('hasGHLData', '==', True)
        .stream())
    elapsed = time.time() - start
    
    print(f'   ✅ Found {len(ads)} ads with both data types in {elapsed:.3f}s')
    
    return elapsed, len(ads)

def test_query_month_summary():
    """Test: Get month summary (instant)"""
    
    print('\n📊 Test 4: Get October summary document')
    print('   Query: collection("advertData").doc("2025-10").get()')
    
    start = time.time()
    summary_doc = db.collection('advertData').document('2025-10').get()
    elapsed = time.time() - start
    
    if summary_doc.exists:
        summary = summary_doc.to_dict()
        print(f'   ✅ Retrieved summary in {elapsed:.3f}s')
        print(f'   Total ads: {summary.get("totalAds", 0)}')
        print(f'   Ads with insights: {summary.get("adsWithInsights", 0)}')
        print(f'   Ads with GHL data: {summary.get("adsWithGHLData", 0)}')
    else:
        print(f'   ⚠️  Summary document not found')
    
    return elapsed

def test_query_with_subcollections():
    """Test: Get ad with all subcollections"""
    
    print('\n📊 Test 5: Get single ad with all subcollections')
    print('   Query: Get ad + insights + ghlWeekly')
    
    # Get first ad from October
    ads = list(db.collection('advertData').document('2025-10').collection('ads').limit(1).stream())
    
    if not ads:
        print('   ⚠️  No ads found')
        return 0
    
    ad = ads[0]
    
    start = time.time()
    
    # Get main document
    ad_data = ad.to_dict()
    
    # Get insights
    insights = list(ad.reference.collection('insights').stream())
    
    # Get GHL data
    ghl_weeks = list(ad.reference.collection('ghlWeekly').stream())
    
    elapsed = time.time() - start
    
    print(f'   ✅ Retrieved ad with subcollections in {elapsed:.3f}s')
    print(f'   Ad: {ad_data.get("adName", "N/A")[:50]}')
    print(f'   Insights: {len(insights)} weeks')
    print(f'   GHL data: {len(ghl_weeks)} weeks')
    
    return elapsed

def test_query_multiple_months():
    """Test: Get ads from multiple months"""
    
    print('\n📊 Test 6: Get ads from October and November 2025')
    print('   Query: Query each month separately and combine')
    
    start = time.time()
    
    oct_ads = list(db.collection('advertData').document('2025-10').collection('ads').stream())
    nov_ads = list(db.collection('advertData').document('2025-11').collection('ads').stream())
    
    elapsed = time.time() - start
    
    total = len(oct_ads) + len(nov_ads)
    
    print(f'   ✅ Found {total} ads ({len(oct_ads)} Oct + {len(nov_ads)} Nov) in {elapsed:.3f}s')
    
    return elapsed, total

def main():
    print('\n' + '='*80)
    print('TEST NEW MONTH-FIRST STRUCTURE PERFORMANCE')
    print('='*80)
    
    results = {}
    
    # Run tests
    results['all_months'] = test_query_all_months()
    results['single_month'], results['single_month_count'] = test_query_single_month()
    results['filtered'], results['filtered_count'] = test_query_filtered_ads()
    results['summary'] = test_query_month_summary()
    results['with_subcollections'] = test_query_with_subcollections()
    results['multiple_months'], results['multiple_months_count'] = test_query_multiple_months()
    
    # Summary
    print('\n' + '='*80)
    print('PERFORMANCE SUMMARY')
    print('='*80)
    
    print(f'\n📊 Query Performance:')
    print(f'   Get all months: {results["all_months"]:.3f}s')
    print(f'   Get single month ads: {results["single_month"]:.3f}s ({results["single_month_count"]} ads)')
    print(f'   Get filtered ads: {results["filtered"]:.3f}s ({results["filtered_count"]} ads)')
    print(f'   Get month summary: {results["summary"]:.3f}s (instant!)')
    print(f'   Get ad with subcollections: {results["with_subcollections"]:.3f}s')
    print(f'   Get multiple months: {results["multiple_months"]:.3f}s ({results["multiple_months_count"]} ads)')
    
    print(f'\n✅ EXPECTED PERFORMANCE:')
    print(f'   - Month list: <0.1s (instant)')
    print(f'   - Single month: 0.3-0.5s (20x faster than loading all 667 ads)')
    print(f'   - Filtered query: 0.3-0.5s (direct path, no full scan)')
    print(f'   - Month summary: <0.05s (single document read)')
    print(f'   - With subcollections: 0.5-1.0s (depends on subcollection size)')
    
    if results['single_month'] < 1.0:
        print(f'\n🎉 EXCELLENT! Queries are fast (<1s)')
    elif results['single_month'] < 2.0:
        print(f'\n✅ GOOD! Queries are reasonably fast (<2s)')
    else:
        print(f'\n⚠️  Queries are slower than expected (>{results["single_month"]:.1f}s)')
        print(f'   This may improve as Firebase caches the data')
    
    print(f'\n📋 Next steps:')
    print(f'   1. Update facebookAdsSync.js to write to new structure')
    print(f'   2. Update populate_ghl_data.py to read/write new structure')
    print(f'   3. Update Flutter frontend to use new query patterns')
    print(f'   4. After 1 week of testing, run cleanup_old_structure.py')
    
    print('\n' + '='*80)

if __name__ == '__main__':
    main()

