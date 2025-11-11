#!/usr/bin/env python3
"""
Migrate advertData collection to month-first structure
Moves ads from advertData/{adId} to advertData/{month}/ads/{adId}
"""

import firebase_admin
from firebase_admin import credentials, firestore
from collections import defaultdict
import time

# Initialize Firebase
if not firebase_admin._apps:
    cred = credentials.Certificate('medx-ai-firebase-adminsdk-fbsvc-a86e7bd050.json')
    firebase_admin.initialize_app(cred)

db = firestore.client()

def get_month_from_ad(ad_ref):
    """Determine month from insights or ghlWeekly subcollection"""
    
    # Try insights first (skip _placeholder documents)
    try:
        insights = list(ad_ref.collection('insights').stream())
        for insight in insights:
            # Skip placeholder documents
            if insight.id == '_placeholder':
                continue
            
            insight_data = insight.to_dict()
            date_start = insight_data.get('dateStart', '')
            if date_start and len(date_start) >= 7:
                return date_start[:7]  # "2025-10"
    except Exception as e:
        print(f"      Warning: Could not read insights: {e}")
    
    # Fallback to ghlWeekly (skip _placeholder documents)
    try:
        ghl_weeks = list(ad_ref.collection('ghlWeekly').stream())
        for week in ghl_weeks:
            # Skip placeholder documents
            if week.id == '_placeholder':
                continue
            
            week_id = week.id  # "2025-10-14_2025-10-20"
            if len(week_id) >= 7:
                return week_id[:7]  # "2025-10"
    except Exception as e:
        print(f"      Warning: Could not read ghlWeekly: {e}")
    
    # Last resort: use current month for ads with no data
    return '2025-11'  # Default to November 2025 for ads without any date info

def migrate_ad(old_ad_doc, month_stats):
    """Migrate a single ad to new structure"""
    
    ad_id = old_ad_doc.id
    old_ad_ref = old_ad_doc.reference
    ad_data = old_ad_doc.to_dict()
    
    # Skip if this is already a month document (has no adId field)
    if 'adId' not in ad_data:
        return None
    
    print(f"   📱 Migrating ad: {ad_id}")
    
    # Determine month
    month = get_month_from_ad(old_ad_ref)
    print(f"      Month: {month}")
    
    # Get subcollections
    insights = list(old_ad_ref.collection('insights').stream())
    ghl_weeks = list(old_ad_ref.collection('ghlWeekly').stream())
    
    print(f"      Insights: {len(insights)}, GHL weeks: {len(ghl_weeks)}")
    
    # New location
    new_ad_ref = db.collection('advertData').document(month).collection('ads').document(ad_id)
    
    # Prepare ad data with new fields
    ad_data['createdMonth'] = month
    ad_data['hasInsights'] = len(insights) > 0
    ad_data['hasGHLData'] = len(ghl_weeks) > 0
    
    # Write main document
    new_ad_ref.set(ad_data)
    
    # Copy insights subcollection
    for insight in insights:
        insight_data = insight.to_dict()
        new_ad_ref.collection('insights').document(insight.id).set(insight_data)
    
    # Copy ghlWeekly subcollection
    for week in ghl_weeks:
        week_data = week.to_dict()
        new_ad_ref.collection('ghlWeekly').document(week.id).set(week_data)
    
    # Update month stats
    month_stats[month]['totalAds'] += 1
    if len(insights) > 0:
        month_stats[month]['adsWithInsights'] += 1
    if len(ghl_weeks) > 0:
        month_stats[month]['adsWithGHLData'] += 1
    
    print(f"      ✅ Migrated to advertData/{month}/ads/{ad_id}")
    
    return month

def update_month_summaries(month_stats):
    """Update month-level summary documents"""
    
    print('\n📊 Updating month summaries...')
    
    for month, stats in month_stats.items():
        month_ref = db.collection('advertData').document(month)
        month_ref.set({
            'totalAds': stats['totalAds'],
            'adsWithInsights': stats['adsWithInsights'],
            'adsWithGHLData': stats['adsWithGHLData'],
            'lastUpdated': firestore.SERVER_TIMESTAMP
        }, merge=True)
        
        print(f"   ✅ {month}: {stats['totalAds']} ads ({stats['adsWithGHLData']} with GHL data)")

def main():
    print('\n' + '='*80)
    print('MIGRATE TO MONTH-FIRST STRUCTURE')
    print('='*80)
    
    # Step 1: Get all ads from old structure
    print('\n📱 Step 1: Fetching ads from old structure...')
    
    # Get ads that have 'adId' field (old structure)
    all_ads = list(db.collection('advertData').where('adId', '!=', '').stream())
    
    print(f'   ✅ Found {len(all_ads)} ads to migrate')
    
    if len(all_ads) == 0:
        print('\n⚠️  No ads found in old structure. Migration may have already been done.')
        print('   Run verify_migration.py to check current structure.')
        return
    
    # Step 2: Migrate each ad
    print('\n🔄 Step 2: Migrating ads to new structure...')
    
    month_stats = defaultdict(lambda: {
        'totalAds': 0,
        'adsWithInsights': 0,
        'adsWithGHLData': 0
    })
    
    migrated_count = 0
    failed_count = 0
    
    for i, ad_doc in enumerate(all_ads, 1):
        try:
            print(f'\n   [{i}/{len(all_ads)}]')
            month = migrate_ad(ad_doc, month_stats)
            
            if month:
                migrated_count += 1
            
            # Rate limiting
            if i % 10 == 0:
                print(f'\n   ⏸️  Pausing briefly (processed {i} ads)...')
                time.sleep(1)
                
        except Exception as e:
            print(f'   ❌ Error migrating ad {ad_doc.id}: {e}')
            failed_count += 1
    
    # Step 3: Update month summaries
    update_month_summaries(month_stats)
    
    # Summary
    print('\n' + '='*80)
    print('MIGRATION COMPLETE!')
    print('='*80)
    
    print(f'\n📊 Summary:')
    print(f'   Total ads processed: {len(all_ads)}')
    print(f'   Successfully migrated: {migrated_count}')
    print(f'   Failed: {failed_count}')
    print(f'   Months created: {len(month_stats)}')
    
    print(f'\n📅 Months:')
    for month in sorted(month_stats.keys()):
        stats = month_stats[month]
        print(f'   {month}: {stats["totalAds"]} ads ({stats["adsWithGHLData"]} with GHL)')
    
    print(f'\n✅ New structure: advertData/{{month}}/ads/{{adId}}')
    print(f'\n⚠️  IMPORTANT: Run verify_migration.py to confirm all data copied correctly')
    print(f'   Then update facebookAdsSync.js and populate_ghl_data.py')
    print(f'   Finally, run cleanup_old_structure.py to delete old data')
    
    print('\n' + '='*80)

if __name__ == '__main__':
    main()

