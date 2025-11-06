#!/usr/bin/env python3
"""
Firebase Data Inspector
Checks the adPerformance collection for data quality issues
"""

import firebase_admin
from firebase_admin import credentials, firestore
import json
from collections import defaultdict
from datetime import datetime

# Initialize Firebase Admin SDK
# Use medx-ai project (where Cloud Functions are deployed)
cred = credentials.Certificate('medx-ai-firebase-adminsdk-fbsvc-a86e7bd050.json')
firebase_admin.initialize_app(cred)

db = firestore.client()

def list_all_collections():
    """List all root-level collections in Firebase"""
    print("=" * 80)
    print("LISTING ALL FIREBASE COLLECTIONS")
    print("=" * 80)
    
    collections = db.collections()
    collection_names = []
    
    for collection in collections:
        collection_names.append(collection.id)
        # Get document count
        docs = list(collection.limit(1000).stream())
        print(f"  - {collection.id}: {len(docs)} documents")
    
    return collection_names

def inspect_ad_performance_collection():
    """Inspect the adPerformance collection"""
    print("=" * 80)
    print("INSPECTING adPerformance COLLECTION")
    print("=" * 80)
    
    # Get all documents
    docs = db.collection('adPerformance').stream()
    
    stats = {
        'total_ads': 0,
        'with_facebook_stats': 0,
        'with_ghl_stats': 0,
        'with_admin_config': 0,
        'matched': 0,
        'unmatched': 0,
        'facebook_only': 0,
        'zero_spend': 0,
        'zero_impressions': 0,
        'zero_clicks': 0,
        'has_valid_data': 0,
        'campaigns': defaultdict(int),
        'sample_ads': []
    }
    
    for doc in docs:
        stats['total_ads'] += 1
        data = doc.to_dict()
        
        # Check Facebook stats
        fb_stats = data.get('facebookStats', {})
        if fb_stats:
            stats['with_facebook_stats'] += 1
            
            spend = fb_stats.get('spend', 0)
            impressions = fb_stats.get('impressions', 0)
            clicks = fb_stats.get('clicks', 0)
            
            if spend == 0:
                stats['zero_spend'] += 1
            if impressions == 0:
                stats['zero_impressions'] += 1
            if clicks == 0:
                stats['zero_clicks'] += 1
                
            # Check if ad has ANY valid data
            if spend > 0 or impressions > 0 or clicks > 0:
                stats['has_valid_data'] += 1
        
        # Check GHL stats
        if data.get('ghlStats'):
            stats['with_ghl_stats'] += 1
        
        # Check admin config
        if data.get('adminConfig'):
            stats['with_admin_config'] += 1
        
        # Check matching status
        matching = data.get('matchingStatus', 'unknown')
        if matching == 'matched':
            stats['matched'] += 1
        elif matching == 'unmatched':
            stats['unmatched'] += 1
        elif matching == 'facebook_only':
            stats['facebook_only'] += 1
        
        # Track campaigns
        campaign = data.get('campaignName', 'Unknown')
        stats['campaigns'][campaign] += 1
        
        # Save sample ads (first 10 with issues)
        if len(stats['sample_ads']) < 10:
            if fb_stats.get('spend', 0) == 0 and fb_stats.get('impressions', 0) == 0:
                stats['sample_ads'].append({
                    'id': doc.id,
                    'adName': data.get('adName', 'Unknown'),
                    'campaignName': data.get('campaignName', 'Unknown'),
                    'facebookStats': fb_stats,
                    'lastUpdated': data.get('lastUpdated'),
                    'matchingStatus': data.get('matchingStatus', 'unknown')
                })
    
    # Print summary
    print(f"\n📊 SUMMARY STATISTICS")
    print("-" * 80)
    print(f"Total Ads:                  {stats['total_ads']}")
    print(f"With Facebook Stats:        {stats['with_facebook_stats']}")
    print(f"With GHL Stats:             {stats['with_ghl_stats']}")
    print(f"With Admin Config:          {stats['with_admin_config']}")
    print()
    print(f"Matching Status:")
    print(f"  - Matched:                {stats['matched']}")
    print(f"  - Unmatched:              {stats['unmatched']}")
    print(f"  - Facebook Only:          {stats['facebook_only']}")
    print()
    print(f"⚠️  DATA QUALITY ISSUES:")
    if stats['total_ads'] > 0:
        print(f"  - Ads with $0 spend:      {stats['zero_spend']} ({stats['zero_spend']/stats['total_ads']*100:.1f}%)")
        print(f"  - Ads with 0 impressions: {stats['zero_impressions']} ({stats['zero_impressions']/stats['total_ads']*100:.1f}%)")
        print(f"  - Ads with 0 clicks:      {stats['zero_clicks']} ({stats['zero_clicks']/stats['total_ads']*100:.1f}%)")
        print(f"  ✅ Ads with valid data:   {stats['has_valid_data']} ({stats['has_valid_data']/stats['total_ads']*100:.1f}%)")
    else:
        print(f"  ❌ CRITICAL: adPerformance collection is EMPTY!")
        print(f"     The Facebook sync may have failed or written to wrong location")
    print()
    print(f"📈 CAMPAIGNS: {len(stats['campaigns'])} unique campaigns")
    
    # Print top campaigns
    print("\nTop 10 Campaigns by Ad Count:")
    for campaign, count in sorted(stats['campaigns'].items(), key=lambda x: x[1], reverse=True)[:10]:
        print(f"  - {campaign}: {count} ads")
    
    # Print sample problematic ads
    if stats['sample_ads']:
        print("\n⚠️  SAMPLE ADS WITH ZERO DATA (First 10):")
        print("-" * 80)
        for i, ad in enumerate(stats['sample_ads'], 1):
            print(f"\n{i}. Ad ID: {ad['id']}")
            print(f"   Name: {ad['adName']}")
            print(f"   Campaign: {ad['campaignName']}")
            print(f"   Matching: {ad['matchingStatus']}")
            print(f"   FB Stats: spend=${ad['facebookStats'].get('spend', 0)}, "
                  f"impressions={ad['facebookStats'].get('impressions', 0)}, "
                  f"clicks={ad['facebookStats'].get('clicks', 0)}")
            if ad.get('lastUpdated'):
                print(f"   Last Updated: {ad['lastUpdated']}")
    
    return stats

def inspect_opportunity_history():
    """Check opportunityStageHistory collection for GHL data"""
    print("\n" + "=" * 80)
    print("INSPECTING opportunityStageHistory COLLECTION")
    print("=" * 80)
    
    docs = db.collection('opportunityStageHistory').limit(100).stream()
    
    count = 0
    sample_opps = []
    
    for doc in docs:
        count += 1
        data = doc.to_dict()
        
        if len(sample_opps) < 5:
            sample_opps.append({
                'id': doc.id,
                'campaignName': data.get('campaignName', 'N/A'),
                'adName': data.get('adName', 'N/A'),
                'adSetName': data.get('adSetName', 'N/A'),
                'stageName': data.get('newStageName', 'N/A'),
                'monetaryValue': data.get('monetaryValue', 0)
            })
    
    print(f"\n📊 Found {count} opportunity records (showing first 100)")
    
    if sample_opps:
        print("\n📋 Sample Opportunities:")
        print("-" * 80)
        for i, opp in enumerate(sample_opps, 1):
            print(f"\n{i}. Opportunity ID: {opp['id']}")
            print(f"   Campaign: {opp['campaignName']}")
            print(f"   Ad Name: {opp['adName']}")
            print(f"   Ad Set: {opp['adSetName']}")
            print(f"   Stage: {opp['stageName']}")
            print(f"   Value: R{opp['monetaryValue']}")

def check_facebook_sync_logs():
    """Check if there are any error patterns"""
    print("\n" + "=" * 80)
    print("RECOMMENDATIONS")
    print("=" * 80)
    
    print("""
    Based on the data inspection, here are the issues and recommendations:
    
    1. ⚠️  HIGH NUMBER OF ZERO-VALUE ADS
       - Many ads have $0 spend and 0 impressions
       - This could mean:
         a) These are draft/inactive ads that Facebook API returns
         b) The Facebook API date range doesn't match the data
         c) The ads are from old campaigns with no recent activity
    
    2. 🔍 POSSIBLE CAUSES:
       - Date preset issue: Currently using 'last_30d' - some ads might be older
       - Ad status filtering: Not filtering out paused/archived ads
       - Facebook API returning all ads regardless of spend
    
    3. ✅ RECOMMENDED FIXES:
       a) Add filtering in facebookAdsSync.js to only sync active ads
       b) Add minimum spend threshold (e.g., > $0.01)
       c) Check effective_status field from Facebook API
       d) Add date range validation
    
    4. 📝 NEXT STEPS:
       - Check Cloud Function logs for Facebook API responses
       - Verify date_preset parameter in sync function
       - Add ad status filtering to only sync ACTIVE ads
       - Consider adding a cleanup job for zero-spend ads
    """)

def main():
    print("\n🔍 FIREBASE DATABASE INSPECTION TOOL")
    print("=" * 80)
    print(f"Started at: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    
    # First, list all collections
    print()
    collection_names = list_all_collections()
    
    # Inspect collections
    print()
    ad_stats = inspect_ad_performance_collection()
    inspect_opportunity_history()
    check_facebook_sync_logs()
    
    # Final assessment
    print("\n" + "=" * 80)
    print("🎯 FINAL ASSESSMENT")
    print("=" * 80)
    
    if ad_stats['has_valid_data'] < ad_stats['total_ads'] * 0.5:
        print("\n❌ CRITICAL: Less than 50% of ads have valid data!")
        print("   Action required: Review Facebook sync logic immediately")
    elif ad_stats['has_valid_data'] < ad_stats['total_ads'] * 0.8:
        print("\n⚠️  WARNING: Less than 80% of ads have valid data")
        print("   Recommendation: Add filtering for inactive ads")
    else:
        print("\n✅ GOOD: Most ads have valid data")
        print("   Note: Some zero-value ads are normal (inactive campaigns)")
    
    print("\n" + "=" * 80)
    print(f"Completed at: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print("=" * 80)

if __name__ == '__main__':
    main()

