#!/usr/bin/env python3
"""
Re-aggregate GHL stats from ghlOpportunities into ads collection
This updates the ads collection with accurate GHL data after form submission matching
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
print("RE-AGGREGATING GHL STATS FROM ghlOpportunities TO ads COLLECTION")
print("=" * 80)
print()

# NOTE: Stage categories are now pre-calculated in ghlOpportunities collection
# by fetch_actual_ghl_stages.py using the pipeline_stage_mappings.json
# We just read the stageCategory field directly

# ============================================================================
# STEP 1: Fetch all ghlOpportunities with assigned Ad IDs
# ============================================================================

print("📊 STEP 1: Fetching all ghlOpportunities with assigned Ad IDs...")
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
# STEP 2: Calculate GHL stats for each ad
# ============================================================================

print("📊 STEP 2: Calculating GHL stats for each ad...")
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
# STEP 3: Update ALL ads collection with new GHL stats (including zeroing out)
# ============================================================================

print("📊 STEP 3: Updating ALL ads with GHL stats (including zeroing out stale data)...")
print()

# Fetch ALL ads from the collection
all_ads_ref = db.collection('ads').stream()
all_ad_ids = set()

for ad_doc in all_ads_ref:
    all_ad_ids.add(ad_doc.id)

print(f"✅ Found {len(all_ad_ids)} total ads in collection")
print(f"✅ {len(ad_ghl_stats)} ads have opportunities")
print(f"✅ {len(all_ad_ids) - len(ad_ghl_stats)} ads will be zeroed out")
print()

batch = db.batch()
batch_count = 0
ads_updated = 0
ads_with_changes = 0
ads_zeroed_out = 0

# Process ALL ads
for ad_id in all_ad_ids:
    ad_ref = db.collection('ads').document(ad_id)
    ad_doc = ad_ref.get()
    
    if not ad_doc.exists:
        continue
    
    ad_data = ad_doc.to_dict()
    old_ghl_stats = ad_data.get('ghlStats', {})
    
    # Get new stats (or zeros if no opportunities)
    if ad_id in ad_ghl_stats:
        new_ghl_stats = ad_ghl_stats[ad_id]
    else:
        # Zero out ads with no opportunities
        new_ghl_stats = {
            'leads': 0,
            'bookings': 0,
            'deposits': 0,
            'cashCollected': 0,
            'cashAmount': 0
        }
    
    # Check if stats changed
    stats_changed = (
        old_ghl_stats.get('leads', 0) != new_ghl_stats['leads'] or
        old_ghl_stats.get('bookings', 0) != new_ghl_stats['bookings'] or
        old_ghl_stats.get('deposits', 0) != new_ghl_stats['deposits'] or
        old_ghl_stats.get('cashCollected', 0) != new_ghl_stats['cashCollected']
    )
    
    if stats_changed:
        ads_with_changes += 1
        
        # Track if we're zeroing out
        if new_ghl_stats['leads'] == 0 and old_ghl_stats.get('leads', 0) > 0:
            ads_zeroed_out += 1
        
        # Only print first 20 changes to avoid spam
        if ads_with_changes <= 20:
            print(f"   📝 Updating {ad_id}:")
            print(f"      Leads: {old_ghl_stats.get('leads', 0)} → {new_ghl_stats['leads']}")
            print(f"      Bookings: {old_ghl_stats.get('bookings', 0)} → {new_ghl_stats['bookings']}")
            print(f"      Deposits: {old_ghl_stats.get('deposits', 0)} → {new_ghl_stats['deposits']}")
            print(f"      Cash: {old_ghl_stats.get('cashCollected', 0)} → {new_ghl_stats['cashCollected']}")
    
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
        print(f"   ✅ Committed batch ({ads_updated} ads updated so far)")
        batch = db.batch()
        batch_count = 0

# Commit remaining
if batch_count > 0:
    batch.commit()

print()
print(f"✅ Updated {ads_updated} ads with new GHL stats")
print(f"✅ {ads_with_changes} ads had changes in their GHL stats")
print(f"✅ {ads_zeroed_out} ads were zeroed out (no longer have opportunities)")
print()

# ============================================================================
# STEP 4: Re-aggregate ad sets
# ============================================================================

print("📊 STEP 4: Re-aggregating ad sets...")
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
        batch = db.batch()
        batch_count = 0

if batch_count > 0:
    batch.commit()

print(f"✅ Updated {adsets_updated} ad sets")
print()

# ============================================================================
# STEP 5: Re-aggregate campaigns
# ============================================================================

print("📊 STEP 5: Re-aggregating campaigns...")
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
print("✅ RE-AGGREGATION COMPLETE!")
print("=" * 80)
print()
print("Summary:")
print(f"  - Ads updated: {ads_updated}")
print(f"  - Ads with GHL changes: {ads_with_changes}")
print(f"  - Ad Sets updated: {adsets_updated}")
print(f"  - Campaigns updated: {campaigns_updated}")
print()
print("✅ All collections are now in sync with accurate GHL data from form submissions!")
print()

