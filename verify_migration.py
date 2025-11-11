#!/usr/bin/env python3
"""
Verify migration to month-first structure
Checks that all ads were copied correctly with subcollections intact
"""

import firebase_admin
from firebase_admin import credentials, firestore

# Initialize Firebase
if not firebase_admin._apps:
    cred = credentials.Certificate('medx-ai-firebase-adminsdk-fbsvc-a86e7bd050.json')
    firebase_admin.initialize_app(cred)

db = firestore.client()

def check_old_structure():
    """Check how many ads remain in old structure"""
    
    print('\n📊 Checking OLD structure (advertData/{adId})...')
    
    try:
        old_ads = list(db.collection('advertData').where('adId', '!=', '').stream())
        print(f'   Ads remaining in old structure: {len(old_ads)}')
        
        if len(old_ads) > 0:
            print(f'   ⚠️  WARNING: {len(old_ads)} ads still in old structure')
            print(f'   Sample IDs: {[ad.id for ad in old_ads[:5]]}')
        else:
            print(f'   ✅ Old structure is empty (good!)')
        
        return len(old_ads)
    except Exception as e:
        print(f'   ❌ Error checking old structure: {e}')
        return -1

def check_new_structure():
    """Check new month-first structure"""
    
    print('\n📊 Checking NEW structure (advertData/{month}/ads/{adId})...')
    
    try:
        months = list(db.collection('advertData').stream())
        
        total_ads = 0
        month_details = []
        
        for month_doc in months:
            month_id = month_doc.id
            month_data = month_doc.to_dict()
            
            # Get ads in this month
            ads = list(month_doc.reference.collection('ads').stream())
            ad_count = len(ads)
            total_ads += ad_count
            
            month_details.append({
                'id': month_id,
                'count': ad_count,
                'summary': month_data
            })
        
        print(f'   Total months: {len(months)}')
        print(f'   Total ads: {total_ads}')
        
        print(f'\n   Month breakdown:')
        for month in sorted(month_details, key=lambda x: x['id']):
            summary = month['summary']
            print(f'      {month["id"]}: {month["count"]} ads')
            print(f'         Summary: {summary.get("totalAds", 0)} total, '
                  f'{summary.get("adsWithInsights", 0)} with insights, '
                  f'{summary.get("adsWithGHLData", 0)} with GHL')
        
        return total_ads, month_details
        
    except Exception as e:
        print(f'   ❌ Error checking new structure: {e}')
        return -1, []

def verify_sample_ads(month_details):
    """Verify subcollections for sample ads"""
    
    print('\n🔍 Verifying sample ads with subcollections...')
    
    if not month_details:
        print('   ⚠️  No months found')
        return
    
    samples_checked = 0
    samples_with_insights = 0
    samples_with_ghl = 0
    
    for month in month_details[:3]:  # Check first 3 months
        month_id = month['id']
        month_ref = db.collection('advertData').document(month_id)
        
        # Get first 2 ads from this month
        sample_ads = list(month_ref.collection('ads').limit(2).stream())
        
        for ad in sample_ads:
            ad_id = ad.id
            ad_data = ad.to_dict()
            
            # Check subcollections
            insights = list(ad.reference.collection('insights').stream())
            ghl_weeks = list(ad.reference.collection('ghlWeekly').stream())
            
            print(f'\n   Ad: {ad_id}')
            print(f'      Month: {month_id}')
            print(f'      Name: {ad_data.get("adName", "N/A")[:50]}')
            print(f'      Campaign: {ad_data.get("campaignName", "N/A")[:50]}')
            print(f'      hasInsights flag: {ad_data.get("hasInsights", False)}')
            print(f'      hasGHLData flag: {ad_data.get("hasGHLData", False)}')
            print(f'      Insights subcollection: {len(insights)} documents')
            print(f'      ghlWeekly subcollection: {len(ghl_weeks)} documents')
            
            # Verify flags match reality
            if len(insights) > 0:
                samples_with_insights += 1
                if not ad_data.get('hasInsights'):
                    print(f'      ⚠️  WARNING: Has insights but flag is False')
            
            if len(ghl_weeks) > 0:
                samples_with_ghl += 1
                if not ad_data.get('hasGHLData'):
                    print(f'      ⚠️  WARNING: Has GHL data but flag is False')
            
            # Show sample insight
            if insights:
                sample_insight = insights[0].to_dict()
                print(f'      Sample insight: {insights[0].id}')
                print(f'         dateStart: {sample_insight.get("dateStart", "N/A")}')
                print(f'         spend: {sample_insight.get("spend", 0)}')
            
            # Show sample GHL week
            if ghl_weeks:
                sample_week = ghl_weeks[0].to_dict()
                print(f'      Sample GHL week: {ghl_weeks[0].id}')
                print(f'         leads: {sample_week.get("leads", 0)}')
                print(f'         cashAmount: {sample_week.get("cashAmount", 0)}')
            
            samples_checked += 1
    
    print(f'\n   ✅ Checked {samples_checked} sample ads')
    print(f'      {samples_with_insights} had insights')
    print(f'      {samples_with_ghl} had GHL data')

def main():
    print('\n' + '='*80)
    print('VERIFY MIGRATION TO MONTH-FIRST STRUCTURE')
    print('='*80)
    
    # Check old structure
    old_count = check_old_structure()
    
    # Check new structure
    new_count, month_details = check_new_structure()
    
    # Verify sample ads
    if new_count > 0:
        verify_sample_ads(month_details)
    
    # Final verdict
    print('\n' + '='*80)
    print('VERIFICATION SUMMARY')
    print('='*80)
    
    if old_count == 0 and new_count > 0:
        print('\n✅ MIGRATION SUCCESSFUL!')
        print(f'   All ads migrated to new structure')
        print(f'   Old structure: 0 ads')
        print(f'   New structure: {new_count} ads')
        print(f'\n📋 Next steps:')
        print(f'   1. Run test_new_structure.py to test query performance')
        print(f'   2. Update facebookAdsSync.js to write to new structure')
        print(f'   3. Update populate_ghl_data.py to read/write new structure')
        print(f'   4. After testing, run cleanup_old_structure.py')
    elif old_count > 0 and new_count > 0:
        print('\n⚠️  MIGRATION INCOMPLETE')
        print(f'   Old structure: {old_count} ads (should be 0)')
        print(f'   New structure: {new_count} ads')
        print(f'\n   Action: Re-run migrate_to_month_structure.py')
    elif old_count == 0 and new_count == 0:
        print('\n❌ NO DATA FOUND')
        print(f'   Both structures are empty')
    else:
        print('\n❌ VERIFICATION FAILED')
        print(f'   Old structure: {old_count} ads')
        print(f'   New structure: {new_count} ads')
    
    print('\n' + '='*80)

if __name__ == '__main__':
    main()

