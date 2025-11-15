#!/usr/bin/env python3
"""
Re-aggregate GHL Stats from ghlOpportunities Collection
========================================================
This script properly aggregates GHL metrics from the ghlOpportunities collection
to ads, adSets, and campaigns collections.

The current Cloud Function only INCREMENTS values on stage transitions,
but never RE-AGGREGATES from the actual opportunities data.

This script fixes that by:
1. Reading ALL opportunities from ghlOpportunities
2. Grouping by assignedAdId
3. Calculating totals (leads, bookings, deposits, cash amounts)
4. Updating ads collection with correct totals
5. Triggering ad set and campaign aggregation
"""

import firebase_admin
from firebase_admin import credentials, firestore
from collections import defaultdict
from datetime import datetime

# Initialize Firebase
if not firebase_admin._apps:
    cred = credentials.Certificate('/Users/mac/dev/medwave/medx-ai-firebase-adminsdk-fbsvc-a86e7bd050.json')
    firebase_admin.initialize_app(cred)

db = firestore.client()

print("=" * 80)
print("RE-AGGREGATING GHL STATS FROM ghlOpportunities COLLECTION")
print("=" * 80)
print()

# Step 1: Get all opportunities
print("Step 1: Loading all opportunities from ghlOpportunities collection...")
opportunities = list(db.collection('ghlOpportunities').stream())
print(f"Loaded {len(opportunities)} opportunities")
print()

# Step 2: Group opportunities by assigned ad ID
print("Step 2: Grouping opportunities by assigned ad ID...")
ads_opportunities = defaultdict(list)
unassigned_opportunities = []

for opp_doc in opportunities:
    opp = opp_doc.to_dict()
    opp['id'] = opp_doc.id
    
    assigned_ad_id = opp.get('assignedAdId')
    
    if assigned_ad_id and assigned_ad_id != 'None':
        ads_opportunities[assigned_ad_id].append(opp)
    else:
        unassigned_opportunities.append(opp)

print(f"Opportunities assigned to ads: {sum(len(opps) for opps in ads_opportunities.values())}")
print(f"Unassigned opportunities: {len(unassigned_opportunities)}")
print(f"Unique ads with opportunities: {len(ads_opportunities)}")
print()

# Step 3: Calculate GHL stats for each ad
print("Step 3: Calculating GHL stats for each ad...")
print()

ads_updated = 0
ads_not_found = 0
total_leads = 0
total_bookings = 0
total_deposits = 0
total_cash_collected = 0
total_cash_amount = 0

for ad_id, opps in ads_opportunities.items():
    try:
        # Check if ad exists
        ad_ref = db.collection('ads').document(ad_id)
        ad_doc = ad_ref.get()
        
        if not ad_doc.exists:
            print(f"⚠️  Ad {ad_id} not found in ads collection, skipping...")
            ads_not_found += 1
            continue
        
        ad_data = ad_doc.to_dict()
        
        # Calculate GHL stats from opportunities
        ghl_stats = {
            'leads': 0,
            'bookings': 0,
            'deposits': 0,
            'cashCollected': 0,
            'cashAmount': 0
        }
        
        # Track unique opportunities by stage category
        # (each opportunity should only be counted once in its current stage)
        for opp in opps:
            stage_category = opp.get('stageCategory', '')
            monetary_value = opp.get('monetaryValue', 0)
            
            # Count as lead (every opportunity is a lead)
            ghl_stats['leads'] += 1
            
            # Count by stage category
            if stage_category == 'booking' or stage_category == 'bookedAppointments':
                ghl_stats['bookings'] += 1
            
            if stage_category == 'deposit':
                ghl_stats['deposits'] += 1
                if monetary_value and monetary_value > 0:
                    ghl_stats['cashAmount'] += monetary_value
            
            if stage_category == 'cash_collected':
                ghl_stats['cashCollected'] += 1
                if monetary_value and monetary_value > 0:
                    ghl_stats['cashAmount'] += monetary_value
        
        # Calculate metrics
        facebook_stats = ad_data.get('facebookStats', {})
        spend = facebook_stats.get('spend', 0)
        profit = ghl_stats['cashAmount'] - spend
        cpl = spend / ghl_stats['leads'] if ghl_stats['leads'] > 0 else 0
        cpb = spend / ghl_stats['bookings'] if ghl_stats['bookings'] > 0 else 0
        cpa = spend / ghl_stats['deposits'] if ghl_stats['deposits'] > 0 else 0
        
        # Update ad document
        ad_ref.update({
            'ghlStats': ghl_stats,
            'profit': profit,
            'cpl': cpl,
            'cpb': cpb,
            'cpa': cpa,
            'lastGHLSync': firestore.SERVER_TIMESTAMP,
            'lastUpdated': firestore.SERVER_TIMESTAMP
        })
        
        ads_updated += 1
        total_leads += ghl_stats['leads']
        total_bookings += ghl_stats['bookings']
        total_deposits += ghl_stats['deposits']
        total_cash_collected += ghl_stats['cashCollected']
        total_cash_amount += ghl_stats['cashAmount']
        
        if ghl_stats['cashAmount'] > 0:
            print(f"✅ Updated ad {ad_id[:20]}...")
            print(f"   {ad_data.get('adName', 'Unknown')}")
            print(f"   Leads: {ghl_stats['leads']}, Bookings: {ghl_stats['bookings']}, Deposits: {ghl_stats['deposits']}, Cash: R {ghl_stats['cashAmount']:,.2f}")
        
    except Exception as e:
        print(f"❌ Error updating ad {ad_id}: {str(e)}")
        continue

print()
print("=" * 80)
print("STEP 3 COMPLETE - AD LEVEL AGGREGATION")
print("=" * 80)
print(f"Ads updated: {ads_updated}")
print(f"Ads not found: {ads_not_found}")
print(f"Total leads: {total_leads}")
print(f"Total bookings: {total_bookings}")
print(f"Total deposits: {total_deposits}")
print(f"Total cash collected: {total_cash_collected}")
print(f"Total cash amount: R {total_cash_amount:,.2f}")
print()

# Step 4: Aggregate to ad sets
print("Step 4: Aggregating to ad sets...")
print()

ad_sets_to_aggregate = set()
for ad_id in ads_opportunities.keys():
    ad_doc = db.collection('ads').document(ad_id).get()
    if ad_doc.exists:
        ad_data = ad_doc.to_dict()
        ad_set_id = ad_data.get('adSetId')
        if ad_set_id:
            ad_sets_to_aggregate.add(ad_set_id)

print(f"Found {len(ad_sets_to_aggregate)} ad sets to aggregate")

ad_sets_updated = 0
for ad_set_id in ad_sets_to_aggregate:
    try:
        # Get all ads in this ad set
        ads_in_set = db.collection('ads').where('adSetId', '==', ad_set_id).stream()
        
        # Aggregate stats
        aggregates = {
            'totalSpend': 0,
            'totalImpressions': 0,
            'totalClicks': 0,
            'totalReach': 0,
            'totalLeads': 0,
            'totalBookings': 0,
            'totalDeposits': 0,
            'totalCashCollected': 0,
            'totalCashAmount': 0,
            'adSetName': '',
            'campaignId': '',
            'campaignName': ''
        }
        
        ad_count = 0
        for ad_doc in ads_in_set:
            ad_data = ad_doc.to_dict()
            ad_count += 1
            
            # Get names from first ad
            if not aggregates['adSetName']:
                aggregates['adSetName'] = ad_data.get('adSetName', '')
                aggregates['campaignId'] = ad_data.get('campaignId', '')
                aggregates['campaignName'] = ad_data.get('campaignName', '')
            
            # Aggregate Facebook stats
            fb_stats = ad_data.get('facebookStats', {})
            aggregates['totalSpend'] += fb_stats.get('spend', 0)
            aggregates['totalImpressions'] += fb_stats.get('impressions', 0)
            aggregates['totalClicks'] += fb_stats.get('clicks', 0)
            aggregates['totalReach'] += fb_stats.get('reach', 0)
            
            # Aggregate GHL stats
            ghl_stats = ad_data.get('ghlStats', {})
            aggregates['totalLeads'] += ghl_stats.get('leads', 0)
            aggregates['totalBookings'] += ghl_stats.get('bookings', 0)
            aggregates['totalDeposits'] += ghl_stats.get('deposits', 0)
            aggregates['totalCashCollected'] += ghl_stats.get('cashCollected', 0)
            aggregates['totalCashAmount'] += ghl_stats.get('cashAmount', 0)
        
        if ad_count == 0:
            continue
        
        # Calculate metrics
        total_profit = aggregates['totalCashAmount'] - aggregates['totalSpend']
        cpl = aggregates['totalSpend'] / aggregates['totalLeads'] if aggregates['totalLeads'] > 0 else 0
        cpb = aggregates['totalSpend'] / aggregates['totalBookings'] if aggregates['totalBookings'] > 0 else 0
        cpa = aggregates['totalSpend'] / aggregates['totalDeposits'] if aggregates['totalDeposits'] > 0 else 0
        
        # Update ad set document
        db.collection('adSets').document(ad_set_id).set({
            'adSetId': ad_set_id,
            'adSetName': aggregates['adSetName'],
            'campaignId': aggregates['campaignId'],
            'campaignName': aggregates['campaignName'],
            'totalSpend': aggregates['totalSpend'],
            'totalImpressions': aggregates['totalImpressions'],
            'totalClicks': aggregates['totalClicks'],
            'totalReach': aggregates['totalReach'],
            'totalLeads': aggregates['totalLeads'],
            'totalBookings': aggregates['totalBookings'],
            'totalDeposits': aggregates['totalDeposits'],
            'totalCashCollected': aggregates['totalCashCollected'],
            'totalCashAmount': aggregates['totalCashAmount'],
            'totalProfit': total_profit,
            'cpl': cpl,
            'cpb': cpb,
            'cpa': cpa,
            'adCount': ad_count,
            'lastUpdated': firestore.SERVER_TIMESTAMP
        }, merge=True)
        
        ad_sets_updated += 1
        
        if aggregates['totalCashAmount'] > 0:
            print(f"✅ Updated ad set: {aggregates['adSetName'][:50]}...")
            print(f"   Cash: R {aggregates['totalCashAmount']:,.2f}, Profit: R {total_profit:,.2f}")
        
    except Exception as e:
        print(f"❌ Error aggregating ad set {ad_set_id}: {str(e)}")
        continue

print()
print(f"Ad sets updated: {ad_sets_updated}")
print()

# Step 5: Aggregate to campaigns
print("Step 5: Aggregating to campaigns...")
print()

campaigns_to_aggregate = set()
for ad_id in ads_opportunities.keys():
    ad_doc = db.collection('ads').document(ad_id).get()
    if ad_doc.exists:
        ad_data = ad_doc.to_dict()
        campaign_id = ad_data.get('campaignId')
        if campaign_id:
            campaigns_to_aggregate.add(campaign_id)

print(f"Found {len(campaigns_to_aggregate)} campaigns to aggregate")

campaigns_updated = 0
for campaign_id in campaigns_to_aggregate:
    try:
        # Get all ads in this campaign
        ads_in_campaign = db.collection('ads').where('campaignId', '==', campaign_id).stream()
        
        # Aggregate stats
        aggregates = {
            'totalSpend': 0,
            'totalImpressions': 0,
            'totalClicks': 0,
            'totalReach': 0,
            'totalLeads': 0,
            'totalBookings': 0,
            'totalDeposits': 0,
            'totalCashCollected': 0,
            'totalCashAmount': 0,
            'campaignName': ''
        }
        
        ad_count = 0
        for ad_doc in ads_in_campaign:
            ad_data = ad_doc.to_dict()
            ad_count += 1
            
            # Get name from first ad
            if not aggregates['campaignName']:
                aggregates['campaignName'] = ad_data.get('campaignName', '')
            
            # Aggregate Facebook stats
            fb_stats = ad_data.get('facebookStats', {})
            aggregates['totalSpend'] += fb_stats.get('spend', 0)
            aggregates['totalImpressions'] += fb_stats.get('impressions', 0)
            aggregates['totalClicks'] += fb_stats.get('clicks', 0)
            aggregates['totalReach'] += fb_stats.get('reach', 0)
            
            # Aggregate GHL stats
            ghl_stats = ad_data.get('ghlStats', {})
            aggregates['totalLeads'] += ghl_stats.get('leads', 0)
            aggregates['totalBookings'] += ghl_stats.get('bookings', 0)
            aggregates['totalDeposits'] += ghl_stats.get('deposits', 0)
            aggregates['totalCashCollected'] += ghl_stats.get('cashCollected', 0)
            aggregates['totalCashAmount'] += ghl_stats.get('cashAmount', 0)
        
        if ad_count == 0:
            continue
        
        # Calculate metrics
        total_profit = aggregates['totalCashAmount'] - aggregates['totalSpend']
        cpl = aggregates['totalSpend'] / aggregates['totalLeads'] if aggregates['totalLeads'] > 0 else 0
        cpb = aggregates['totalSpend'] / aggregates['totalBookings'] if aggregates['totalBookings'] > 0 else 0
        cpa = aggregates['totalSpend'] / aggregates['totalDeposits'] if aggregates['totalDeposits'] > 0 else 0
        roi = (total_profit / aggregates['totalSpend'] * 100) if aggregates['totalSpend'] > 0 else 0
        
        # Update campaign document
        db.collection('campaigns').document(campaign_id).set({
            'campaignId': campaign_id,
            'campaignName': aggregates['campaignName'],
            'totalSpend': aggregates['totalSpend'],
            'totalImpressions': aggregates['totalImpressions'],
            'totalClicks': aggregates['totalClicks'],
            'totalReach': aggregates['totalReach'],
            'totalLeads': aggregates['totalLeads'],
            'totalBookings': aggregates['totalBookings'],
            'totalDeposits': aggregates['totalDeposits'],
            'totalCashCollected': aggregates['totalCashCollected'],
            'totalCashAmount': aggregates['totalCashAmount'],
            'totalProfit': total_profit,
            'cpl': cpl,
            'cpb': cpb,
            'cpa': cpa,
            'roi': roi,
            'adCount': ad_count,
            'lastUpdated': firestore.SERVER_TIMESTAMP
        }, merge=True)
        
        campaigns_updated += 1
        
        print(f"✅ Updated campaign: {aggregates['campaignName'][:60]}...")
        print(f"   Leads: {aggregates['totalLeads']}, Bookings: {aggregates['totalBookings']}, Deposits: {aggregates['totalDeposits']}")
        print(f"   Cash: R {aggregates['totalCashAmount']:,.2f}, Profit: R {total_profit:,.2f}, ROI: {roi:.1f}%")
        print()
        
    except Exception as e:
        print(f"❌ Error aggregating campaign {campaign_id}: {str(e)}")
        continue

print()
print("=" * 80)
print("RE-AGGREGATION COMPLETE!")
print("=" * 80)
print(f"Ads updated: {ads_updated}")
print(f"Ad sets updated: {ad_sets_updated}")
print(f"Campaigns updated: {campaigns_updated}")
print(f"Total cash amount aggregated: R {total_cash_amount:,.2f}")
print()
print("✅ GHL stats have been re-aggregated from ghlOpportunities collection")
print("   The campaigns summary should now show correct monetary values!")
print("=" * 80)

