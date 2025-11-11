#!/usr/bin/env python3
"""
Preview which ads will have their GHL stats zeroed out
Shows why each ad has no opportunities assigned
"""

import firebase_admin
from firebase_admin import credentials, firestore
from collections import defaultdict
from datetime import datetime

# Initialize Firebase
cred = credentials.Certificate('/Users/mac/dev/medwave/medx-ai-firebase-adminsdk-fbsvc-a86e7bd050.json')
try:
    firebase_admin.get_app()
except ValueError:
    firebase_admin.initialize_app(cred)

db = firestore.client()

print("=" * 80)
print("PREVIEW: ADS THAT WILL HAVE GHL STATS ZEROED OUT")
print("=" * 80)
print()

# STEP 1: Get ads with opportunities
print("📊 STEP 1: Finding ads with GHL opportunities...")
print()

ghl_opps_ref = db.collection('ghlOpportunities').stream()
ads_with_opportunities = set()

for opp_doc in ghl_opps_ref:
    opp_data = opp_doc.to_dict()
    assigned_ad_id = opp_data.get('assignedAdId') or opp_data.get('adId')
    
    if assigned_ad_id:
        ads_with_opportunities.add(assigned_ad_id)

print(f"✅ Found {len(ads_with_opportunities)} ads with opportunities")
print()

# STEP 2: Get ALL ads and find ones without opportunities
print("📊 STEP 2: Finding ads WITHOUT opportunities...")
print()

all_ads_ref = db.collection('ads').stream()
ads_to_zero = []

for ad_doc in all_ads_ref:
    ad_id = ad_doc.id
    ad_data = ad_doc.to_dict()
    
    # Check if this ad has opportunities
    if ad_id not in ads_with_opportunities:
        ghl_stats = ad_data.get('ghlStats', {})
        
        # Only include if it currently has GHL stats that will be zeroed
        if (ghl_stats.get('leads', 0) > 0 or 
            ghl_stats.get('bookings', 0) > 0 or 
            ghl_stats.get('deposits', 0) > 0 or
            ghl_stats.get('cashCollected', 0) > 0):
            
            fb_stats = ad_data.get('facebookStats', {})
            
            ads_to_zero.append({
                'ad_id': ad_id,
                'ad_name': ad_data.get('adName', 'Unknown'),
                'campaign_name': ad_data.get('campaignName', 'Unknown'),
                'spend': fb_stats.get('spend', 0),
                'current_ghl': {
                    'leads': ghl_stats.get('leads', 0),
                    'bookings': ghl_stats.get('bookings', 0),
                    'deposits': ghl_stats.get('deposits', 0),
                    'cash': ghl_stats.get('cashCollected', 0)
                },
                'last_updated': ad_data.get('lastGHLSync', 'Never')
            })

print(f"✅ Found {len(ads_to_zero)} ads that will be zeroed out")
print()

# STEP 3: Show details
print("=" * 80)
print("📋 DETAILED LIST (showing first 50)")
print("=" * 80)
print()

for i, ad in enumerate(ads_to_zero[:50]):
    print(f"{i+1}. Ad ID: {ad['ad_id']}")
    print(f"   Name: {ad['ad_name']}")
    print(f"   Campaign: {ad['campaign_name']}")
    print(f"   Facebook Spend: R{ad['spend']:.2f}")
    print(f"   Current GHL Stats (will be zeroed):")
    print(f"      Leads: {ad['current_ghl']['leads']}")
    print(f"      Bookings: {ad['current_ghl']['bookings']}")
    print(f"      Deposits: {ad['current_ghl']['deposits']}")
    print(f"      Cash: {ad['current_ghl']['cash']}")
    print(f"   Last GHL Sync: {ad['last_updated']}")
    print()

if len(ads_to_zero) > 50:
    print(f"... and {len(ads_to_zero) - 50} more ads")
    print()

# STEP 4: Summary by campaign
print("=" * 80)
print("📊 SUMMARY BY CAMPAIGN")
print("=" * 80)
print()

campaign_summary = defaultdict(lambda: {'count': 0, 'total_leads': 0, 'total_spend': 0})

for ad in ads_to_zero:
    campaign_name = ad['campaign_name']
    campaign_summary[campaign_name]['count'] += 1
    campaign_summary[campaign_name]['total_leads'] += ad['current_ghl']['leads']
    campaign_summary[campaign_name]['total_spend'] += ad['spend']

for campaign_name, stats in sorted(campaign_summary.items(), key=lambda x: x[1]['count'], reverse=True):
    print(f"Campaign: {campaign_name}")
    print(f"  Ads to zero: {stats['count']}")
    print(f"  Total leads being removed: {stats['total_leads']}")
    print(f"  Total spend on these ads: R{stats['total_spend']:.2f}")
    print()

# STEP 5: Overall summary
print("=" * 80)
print("📊 OVERALL SUMMARY")
print("=" * 80)
print()

total_leads_removed = sum(ad['current_ghl']['leads'] for ad in ads_to_zero)
total_bookings_removed = sum(ad['current_ghl']['bookings'] for ad in ads_to_zero)
total_deposits_removed = sum(ad['current_ghl']['deposits'] for ad in ads_to_zero)
total_cash_removed = sum(ad['current_ghl']['cash'] for ad in ads_to_zero)

print(f"Total ads to be zeroed: {len(ads_to_zero)}")
print(f"Total GHL stats being removed (these are likely duplicates/mismatches):")
print(f"  Leads: {total_leads_removed}")
print(f"  Bookings: {total_bookings_removed}")
print(f"  Deposits: {total_deposits_removed}")
print(f"  Cash: {total_cash_removed}")
print()

print("⚠️  IMPORTANT:")
print("   - These ads are REAL Facebook ads (they will NOT be deleted)")
print("   - Only their GHL stats will be zeroed out")
print("   - Facebook stats (spend, impressions, etc.) remain unchanged")
print("   - This removes duplicate/incorrect GHL opportunity assignments")
print()

print("To proceed with zeroing out, run:")
print("  python3 split_collections_schema/reaggregate_ghl_to_ads.py")
print()
print("=" * 80)

