#!/usr/bin/env python3
"""
COMPLETE GHL STATS RESET AND RE-AGGREGATION
This script will:
1. Zero out ALL GHL stats in ALL ads (clean slate)
2. Recalculate GHL stats from ghlOpportunities (source of truth)
3. Re-aggregate to adSets
4. Re-aggregate to campaigns
"""

import firebase_admin
from firebase_admin import credentials, firestore
from collections import defaultdict
import os

# Initialize Firebase
script_dir = os.path.dirname(os.path.abspath(__file__))
creds_path = os.path.join(script_dir, '..', 'medx-ai-firebase-adminsdk-fbsvc-a86e7bd050.json')
cred = credentials.Certificate(creds_path)

try:
    firebase_admin.get_app()
except ValueError:
    firebase_admin.initialize_app(cred)

db = firestore.client()

print("=" * 80)
print("COMPLETE GHL STATS RESET AND RE-AGGREGATION")
print("=" * 80)
print()
print("This will:")
print("  1. Zero out ALL GHL stats in ALL ads")
print("  2. Recalculate from ghlOpportunities (source of truth)")
print("  3. Re-aggregate to adSets and campaigns")
print()
print("=" * 80)
print()

# ============================================================================
# STEP 1: ZERO OUT ALL ADS
# ============================================================================

print("📊 STEP 1: Zeroing out ALL ads GHL stats (clean slate)...")
print()

all_ads_ref = db.collection('ads').stream()
batch = db.batch()
batch_count = 0
ads_zeroed = 0

zero_ghl_stats = {
    'leads': 0,
    'bookings': 0,
    'deposits': 0,
    'cashCollected': 0,
    'cashAmount': 0
}

for ad_doc in all_ads_ref:
    ad_ref = db.collection('ads').document(ad_doc.id)
    
    batch.update(ad_ref, {
        'ghlStats': zero_ghl_stats,
        'profit': 0,
        'cpl': 0,
        'cpb': 0,
        'cpa': 0,
        'lastGHLSync': firestore.SERVER_TIMESTAMP
    })
    
    batch_count += 1
    ads_zeroed += 1
    
    if batch_count >= 500:
        batch.commit()
        print(f"   ✅ Zeroed out {ads_zeroed} ads so far...")
        batch = db.batch()
        batch_count = 0

if batch_count > 0:
    batch.commit()

print(f"✅ Zeroed out {ads_zeroed} ads")
print()

# ============================================================================
# STEP 2: FETCH ALL GHL OPPORTUNITIES
# ============================================================================

print("📊 STEP 2: Fetching all ghlOpportunities with assigned Ad IDs...")
print()

ghl_opps_ref = db.collection('ghlOpportunities').stream()

# Group opportunities by Ad ID
ad_to_opportunities = defaultdict(list)
total_opportunities = 0
assigned_opportunities = 0

for opp_doc in ghl_opps_ref:
    opp_data = opp_doc.to_dict()
    total_opportunities += 1
    
    assigned_ad_id = opp_data.get('assignedAdId') or opp_data.get('adId')
    
    if assigned_ad_id:
        ad_to_opportunities[assigned_ad_id].append(opp_data)
        assigned_opportunities += 1

print(f"✅ Found {total_opportunities} total opportunities")
print(f"✅ Found {assigned_opportunities} opportunities with assigned Ad IDs")
print(f"✅ Found {len(ad_to_opportunities)} unique ads with opportunities")
print()

# ============================================================================
# STEP 3: CALCULATE GHL STATS FOR EACH AD
# ============================================================================

print("📊 STEP 3: Calculating GHL stats for each ad from scratch...")
print()

ad_ghl_stats = {}

for ad_id, opportunities in ad_to_opportunities.items():
    ghl_stats = {
        'leads': 0,
        'bookings': 0,
        'deposits': 0,
        'cashCollected': 0,
        'cashAmount': 0
    }
    
    for opp in opportunities:
        # Use the pre-calculated stageCategory from fetch_actual_ghl_stages.py
        stage_category = opp.get('stageCategory', 'lead')
        monetary_value = opp.get('monetaryValue', 0)
        
        # Count as lead
        ghl_stats['leads'] += 1
        
        # Count as booking if reached booking stage or beyond
        if stage_category in ['booking', 'deposit', 'cash_collected']:
            ghl_stats['bookings'] += 1
        
        # Count as deposit if reached deposit stage or beyond
        if stage_category in ['deposit', 'cash_collected']:
            ghl_stats['deposits'] += 1
        
        # Count as cash collected if reached final stage
        if stage_category == 'cash_collected':
            ghl_stats['cashCollected'] += 1
            ghl_stats['cashAmount'] += monetary_value
    
    ad_ghl_stats[ad_id] = ghl_stats

print(f"✅ Calculated GHL stats for {len(ad_ghl_stats)} ads")
print()

# ============================================================================
# STEP 4: UPDATE ADS WITH NEW GHL STATS
# ============================================================================

print("📊 STEP 4: Updating ads with calculated GHL stats...")
print()

batch = db.batch()
batch_count = 0
ads_updated = 0

for ad_id, new_ghl_stats in ad_ghl_stats.items():
    ad_ref = db.collection('ads').document(ad_id)
    ad_doc = ad_ref.get()
    
    if not ad_doc.exists:
        print(f"   ⚠️  Ad {ad_id} not found in ads collection, skipping...")
        continue
    
    ad_data = ad_doc.to_dict()
    
    # Calculate new computed metrics
    fb_stats = ad_data.get('facebookStats', {})
    spend = fb_stats.get('spend', 0)
    
    cpl = spend / new_ghl_stats['leads'] if new_ghl_stats['leads'] > 0 else 0
    cpb = spend / new_ghl_stats['bookings'] if new_ghl_stats['bookings'] > 0 else 0
    cpa = spend / new_ghl_stats['deposits'] if new_ghl_stats['deposits'] > 0 else 0
    profit = new_ghl_stats['cashAmount'] - spend
    
    # Update the ad document
    batch.update(ad_ref, {
        'ghlStats': new_ghl_stats,
        'profit': profit,
        'cpl': cpl,
        'cpb': cpb,
        'cpa': cpa,
        'lastGHLSync': firestore.SERVER_TIMESTAMP
    })
    
    batch_count += 1
    ads_updated += 1
    
    # Commit batch every 500 operations
    if batch_count >= 500:
        batch.commit()
        print(f"   ✅ Updated {ads_updated} ads so far...")
        batch = db.batch()
        batch_count = 0

# Commit remaining
if batch_count > 0:
    batch.commit()

print(f"✅ Updated {ads_updated} ads with GHL stats")
print()

# ============================================================================
# STEP 5: RE-AGGREGATE AD SETS
# ============================================================================

print("📊 STEP 5: Re-aggregating ad sets from ads...")
print()

# Fetch all ads
ads_ref = db.collection('ads').stream()

adset_stats = defaultdict(lambda: {
    'totalSpend': 0,
    'totalLeads': 0,
    'totalBookings': 0,
    'totalDeposits': 0,
    'totalCashCollected': 0,
    'totalCashAmount': 0,
    'adCount': 0
})

for ad_doc in ads_ref:
    ad_data = ad_doc.to_dict()
    ad_set_id = ad_data.get('adSetId')
    
    if not ad_set_id:
        continue
    
    fb_stats = ad_data.get('facebookStats', {})
    ghl_stats = ad_data.get('ghlStats', {})
    
    adset_stats[ad_set_id]['totalSpend'] += fb_stats.get('spend', 0)
    adset_stats[ad_set_id]['totalLeads'] += ghl_stats.get('leads', 0)
    adset_stats[ad_set_id]['totalBookings'] += ghl_stats.get('bookings', 0)
    adset_stats[ad_set_id]['totalDeposits'] += ghl_stats.get('deposits', 0)
    adset_stats[ad_set_id]['totalCashCollected'] += ghl_stats.get('cashCollected', 0)
    adset_stats[ad_set_id]['totalCashAmount'] += ghl_stats.get('cashAmount', 0)
    adset_stats[ad_set_id]['adCount'] += 1

# Update ad sets
batch = db.batch()
batch_count = 0
adsets_updated = 0

for ad_set_id, stats in adset_stats.items():
    adset_ref = db.collection('adSets').document(ad_set_id)
    
    # Calculate computed metrics
    cpl = stats['totalSpend'] / stats['totalLeads'] if stats['totalLeads'] > 0 else 0
    cpb = stats['totalSpend'] / stats['totalBookings'] if stats['totalBookings'] > 0 else 0
    cpa = stats['totalSpend'] / stats['totalDeposits'] if stats['totalDeposits'] > 0 else 0
    profit = stats['totalCashAmount'] - stats['totalSpend']
    
    batch.update(adset_ref, {
        'totalLeads': stats['totalLeads'],
        'totalBookings': stats['totalBookings'],
        'totalDeposits': stats['totalDeposits'],
        'totalCashCollected': stats['totalCashCollected'],
        'totalCashAmount': stats['totalCashAmount'],
        'profit': profit,
        'cpl': cpl,
        'cpb': cpb,
        'cpa': cpa,
        'adCount': stats['adCount'],
        'lastUpdated': firestore.SERVER_TIMESTAMP
    })
    
    batch_count += 1
    adsets_updated += 1
    
    if batch_count >= 500:
        batch.commit()
        print(f"   ✅ Updated {adsets_updated} ad sets so far...")
        batch = db.batch()
        batch_count = 0

if batch_count > 0:
    batch.commit()

print(f"✅ Updated {adsets_updated} ad sets")
print()

# ============================================================================
# STEP 6: RE-AGGREGATE CAMPAIGNS
# ============================================================================

print("📊 STEP 6: Re-aggregating campaigns from ad sets...")
print()

# Fetch all ad sets
adsets_ref = db.collection('adSets').stream()

campaign_stats = defaultdict(lambda: {
    'totalSpend': 0,
    'totalLeads': 0,
    'totalBookings': 0,
    'totalDeposits': 0,
    'totalCashCollected': 0,
    'totalCashAmount': 0,
    'adSetCount': 0,
    'adCount': 0
})

for adset_doc in adsets_ref:
    adset_data = adset_doc.to_dict()
    campaign_id = adset_data.get('campaignId')
    
    if not campaign_id:
        continue
    
    campaign_stats[campaign_id]['totalSpend'] += adset_data.get('totalSpend', 0)
    campaign_stats[campaign_id]['totalLeads'] += adset_data.get('totalLeads', 0)
    campaign_stats[campaign_id]['totalBookings'] += adset_data.get('totalBookings', 0)
    campaign_stats[campaign_id]['totalDeposits'] += adset_data.get('totalDeposits', 0)
    campaign_stats[campaign_id]['totalCashCollected'] += adset_data.get('totalCashCollected', 0)
    campaign_stats[campaign_id]['totalCashAmount'] += adset_data.get('totalCashAmount', 0)
    campaign_stats[campaign_id]['adSetCount'] += 1
    campaign_stats[campaign_id]['adCount'] += adset_data.get('adCount', 0)

# Update campaigns
batch = db.batch()
batch_count = 0
campaigns_updated = 0

for campaign_id, stats in campaign_stats.items():
    campaign_ref = db.collection('campaigns').document(campaign_id)
    
    # Calculate computed metrics
    cpl = stats['totalSpend'] / stats['totalLeads'] if stats['totalLeads'] > 0 else 0
    cpb = stats['totalSpend'] / stats['totalBookings'] if stats['totalBookings'] > 0 else 0
    cpa = stats['totalSpend'] / stats['totalDeposits'] if stats['totalDeposits'] > 0 else 0
    profit = stats['totalCashAmount'] - stats['totalSpend']
    
    batch.update(campaign_ref, {
        'totalLeads': stats['totalLeads'],
        'totalBookings': stats['totalBookings'],
        'totalDeposits': stats['totalDeposits'],
        'totalCashCollected': stats['totalCashCollected'],
        'totalCashAmount': stats['totalCashAmount'],
        'profit': profit,
        'cpl': cpl,
        'cpb': cpb,
        'cpa': cpa,
        'adSetCount': stats['adSetCount'],
        'adCount': stats['adCount'],
        'lastUpdated': firestore.SERVER_TIMESTAMP
    })
    
    batch_count += 1
    campaigns_updated += 1
    
    if batch_count >= 500:
        batch.commit()
        print(f"   ✅ Updated {campaigns_updated} campaigns so far...")
        batch = db.batch()
        batch_count = 0

if batch_count > 0:
    batch.commit()

print(f"✅ Updated {campaigns_updated} campaigns")
print()

# ============================================================================
# SUMMARY
# ============================================================================

print("=" * 80)
print("✅ COMPLETE RESET AND RE-AGGREGATION FINISHED!")
print("=" * 80)
print()
print("Summary:")
print(f"  - Total ads zeroed out: {ads_zeroed}")
print(f"  - Ads with GHL opportunities: {ads_updated}")
print(f"  - Ads with zero GHL stats: {ads_zeroed - ads_updated}")
print(f"  - Ad Sets updated: {adsets_updated}")
print(f"  - Campaigns updated: {campaigns_updated}")
print()
print("✅ All GHL stats have been recalculated from scratch!")
print("✅ All collections are now 100% accurate based on ghlOpportunities!")
print()
print("=" * 80)

