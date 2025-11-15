#!/usr/bin/env python3
"""
Investigate GHL Summary Data Issues
====================================
This script checks if GHL opportunities are properly populated in Firebase
and if monetary values are correctly aggregated to campaigns collection.

Checks:
1. ghlOpportunities collection - count, monetary values, stage assignments
2. ads collection - GHL stats aggregation
3. campaigns collection - GHL metrics in summary
4. Compare with actual GHL API data
"""

import firebase_admin
from firebase_admin import credentials, firestore
from datetime import datetime, timedelta
import json
from collections import defaultdict

# Initialize Firebase
if not firebase_admin._apps:
    cred = credentials.Certificate('/Users/mac/dev/medwave/medx-ai-firebase-adminsdk-fbsvc-a86e7bd050.json')
    firebase_admin.initialize_app(cred)

db = firestore.client()

print("=" * 80)
print("GHL SUMMARY DATA INVESTIGATION")
print("=" * 80)
print()

# ============================================================================
# 1. CHECK ghlOpportunities COLLECTION
# ============================================================================
print("1. CHECKING ghlOpportunities COLLECTION")
print("-" * 80)

opportunities = list(db.collection('ghlOpportunities').stream())
print(f"Total opportunities in Firebase: {len(opportunities)}")

if len(opportunities) == 0:
    print("❌ ERROR: No opportunities found in ghlOpportunities collection!")
    print("   This is the root cause - the collection is empty.")
    exit(1)

# Analyze opportunities
assigned_count = 0
with_monetary_value = 0
total_monetary_value = 0
stage_counts = defaultdict(int)
stage_category_counts = defaultdict(int)
assignment_methods = defaultdict(int)
recent_opportunities = []

for opp_doc in opportunities:
    opp = opp_doc.to_dict()
    opp_id = opp_doc.id
    
    # Count assigned
    if opp.get('assignedAdId'):
        assigned_count += 1
    
    # Count monetary values
    monetary_value = opp.get('monetaryValue', 0)
    if monetary_value and monetary_value > 0:
        with_monetary_value += 1
        total_monetary_value += monetary_value
    
    # Count stages
    current_stage = opp.get('currentStage', 'Unknown')
    stage_counts[current_stage] += 1
    
    # Count stage categories
    stage_category = opp.get('stageCategory', 'Unknown')
    stage_category_counts[stage_category] += 1
    
    # Count assignment methods
    assignment_method = opp.get('assignmentMethod', 'Unknown')
    assignment_methods[assignment_method] += 1
    
    # Track recent opportunities with monetary values
    created_at = opp.get('createdAt')
    if created_at and monetary_value and monetary_value > 0:
        recent_opportunities.append({
            'id': opp_id,
            'name': opp.get('name', 'Unknown'),
            'monetaryValue': monetary_value,
            'currentStage': current_stage,
            'stageCategory': stage_category,
            'assignedAdId': opp.get('assignedAdId', 'None'),
            'campaignId': opp.get('campaignId', 'None'),
            'createdAt': created_at
        })

# Sort recent opportunities by monetary value
recent_opportunities.sort(key=lambda x: x['monetaryValue'], reverse=True)

print(f"\nOpportunities with assigned Ad ID: {assigned_count} ({assigned_count/len(opportunities)*100:.1f}%)")
print(f"Opportunities with monetary value: {with_monetary_value} ({with_monetary_value/len(opportunities)*100:.1f}%)")
print(f"Total monetary value: R {total_monetary_value:,.2f}")

print("\nStage Category Breakdown:")
for category, count in sorted(stage_category_counts.items(), key=lambda x: x[1], reverse=True):
    print(f"  {category}: {count}")

print("\nTop 10 Current Stages:")
for stage, count in sorted(stage_counts.items(), key=lambda x: x[1], reverse=True)[:10]:
    print(f"  {stage}: {count}")

print("\nAssignment Methods:")
for method, count in sorted(assignment_methods.items(), key=lambda x: x[1], reverse=True):
    print(f"  {method}: {count}")

print("\nTop 10 Opportunities by Monetary Value:")
for i, opp in enumerate(recent_opportunities[:10], 1):
    print(f"  {i}. {opp['name']}: R {opp['monetaryValue']:,.2f}")
    print(f"     Stage: {opp['currentStage']} ({opp['stageCategory']})")
    print(f"     Ad ID: {opp['assignedAdId']}")
    print(f"     Campaign ID: {opp['campaignId']}")
    print()

# ============================================================================
# 2. CHECK ads COLLECTION - GHL STATS
# ============================================================================
print("\n2. CHECKING ads COLLECTION - GHL STATS")
print("-" * 80)

ads = list(db.collection('ads').stream())
print(f"Total ads in Firebase: {len(ads)}")

ads_with_ghl_stats = 0
ads_with_leads = 0
ads_with_bookings = 0
ads_with_deposits = 0
ads_with_cash = 0
total_leads = 0
total_bookings = 0
total_deposits = 0
total_cash = 0

ads_with_high_cash = []

for ad_doc in ads:
    ad = ad_doc.to_dict()
    ad_id = ad_doc.id
    
    ghl_stats = ad.get('ghlStats', {})
    
    if ghl_stats and any(ghl_stats.values()):
        ads_with_ghl_stats += 1
    
    leads = ghl_stats.get('leads', 0)
    bookings = ghl_stats.get('bookings', 0)
    deposits = ghl_stats.get('deposits', 0)
    cash = ghl_stats.get('cashAmount', 0)
    
    if leads > 0:
        ads_with_leads += 1
        total_leads += leads
    
    if bookings > 0:
        ads_with_bookings += 1
        total_bookings += bookings
    
    if deposits > 0:
        ads_with_deposits += 1
        total_deposits += deposits
    
    if cash > 0:
        ads_with_cash += 1
        total_cash += cash
        
        if cash > 50000:  # R 50,000+
            ads_with_high_cash.append({
                'id': ad_id,
                'name': ad.get('adName', 'Unknown'),
                'campaignId': ad.get('campaignId', 'Unknown'),
                'cashAmount': cash,
                'deposits': deposits,
                'bookings': bookings,
                'leads': leads
            })

print(f"\nAds with GHL stats: {ads_with_ghl_stats} ({ads_with_ghl_stats/len(ads)*100:.1f}%)")
print(f"Ads with leads: {ads_with_leads}")
print(f"Ads with bookings: {ads_with_bookings}")
print(f"Ads with deposits: {ads_with_deposits}")
print(f"Ads with cash: {ads_with_cash}")

print(f"\nTotal GHL Metrics from Ads:")
print(f"  Leads: {total_leads}")
print(f"  Bookings: {total_bookings}")
print(f"  Deposits: {total_deposits}")
print(f"  Cash Amount: R {total_cash:,.2f}")

if ads_with_high_cash:
    print(f"\nAds with High Cash Values (R 50,000+):")
    ads_with_high_cash.sort(key=lambda x: x['cashAmount'], reverse=True)
    for ad in ads_with_high_cash[:10]:
        print(f"  {ad['name']}: R {ad['cashAmount']:,.2f}")
        print(f"    Deposits: {ad['deposits']}, Bookings: {ad['bookings']}, Leads: {ad['leads']}")
        print(f"    Campaign ID: {ad['campaignId']}")
        print()

# ============================================================================
# 3. CHECK campaigns COLLECTION - GHL METRICS
# ============================================================================
print("\n3. CHECKING campaigns COLLECTION - GHL METRICS")
print("-" * 80)

campaigns = list(db.collection('campaigns').stream())
print(f"Total campaigns in Firebase: {len(campaigns)}")

campaigns_with_ghl = 0
campaigns_with_leads = 0
campaigns_with_bookings = 0
campaigns_with_deposits = 0
campaigns_with_cash = 0
total_campaign_leads = 0
total_campaign_bookings = 0
total_campaign_deposits = 0
total_campaign_cash = 0

campaigns_with_high_cash = []

for campaign_doc in campaigns:
    campaign = campaign_doc.to_dict()
    campaign_id = campaign_doc.id
    
    leads = campaign.get('totalLeads', 0)
    bookings = campaign.get('totalBookings', 0)
    deposits = campaign.get('totalDeposits', 0)
    cash = campaign.get('totalCashAmount', 0)
    
    if leads > 0 or bookings > 0 or deposits > 0 or cash > 0:
        campaigns_with_ghl += 1
    
    if leads > 0:
        campaigns_with_leads += 1
        total_campaign_leads += leads
    
    if bookings > 0:
        campaigns_with_bookings += 1
        total_campaign_bookings += bookings
    
    if deposits > 0:
        campaigns_with_deposits += 1
        total_campaign_deposits += deposits
    
    if cash > 0:
        campaigns_with_cash += 1
        total_campaign_cash += cash
        
        if cash > 50000:  # R 50,000+
            campaigns_with_high_cash.append({
                'id': campaign_id,
                'name': campaign.get('campaignName', 'Unknown'),
                'cashAmount': cash,
                'deposits': deposits,
                'bookings': bookings,
                'leads': leads,
                'spend': campaign.get('totalSpend', 0),
                'profit': campaign.get('totalProfit', 0)
            })

print(f"\nCampaigns with GHL metrics: {campaigns_with_ghl} ({campaigns_with_ghl/len(campaigns)*100:.1f}%)")
print(f"Campaigns with leads: {campaigns_with_leads}")
print(f"Campaigns with bookings: {campaigns_with_bookings}")
print(f"Campaigns with deposits: {campaigns_with_deposits}")
print(f"Campaigns with cash: {campaigns_with_cash}")

print(f"\nTotal GHL Metrics from Campaigns:")
print(f"  Leads: {total_campaign_leads}")
print(f"  Bookings: {total_campaign_bookings}")
print(f"  Deposits: {total_campaign_deposits}")
print(f"  Cash Amount: R {total_campaign_cash:,.2f}")

if campaigns_with_high_cash:
    print(f"\nCampaigns with High Cash Values (R 50,000+):")
    campaigns_with_high_cash.sort(key=lambda x: x['cashAmount'], reverse=True)
    for campaign in campaigns_with_high_cash[:10]:
        print(f"  {campaign['name']}")
        print(f"    Cash: R {campaign['cashAmount']:,.2f}")
        print(f"    Deposits: {campaign['deposits']}, Bookings: {campaign['bookings']}, Leads: {campaign['leads']}")
        print(f"    Spend: R {campaign['spend']:,.2f}, Profit: R {campaign['profit']:,.2f}")
        print()

# ============================================================================
# 4. COMPARE TOTALS - VERIFY AGGREGATION
# ============================================================================
print("\n4. AGGREGATION VERIFICATION")
print("-" * 80)

print("\nComparison: Opportunities vs Ads vs Campaigns")
print(f"{'Metric':<20} {'Opportunities':<20} {'Ads':<20} {'Campaigns':<20} {'Match?':<10}")
print("-" * 90)

# Count opportunities by stage category
opp_leads = sum(1 for opp in opportunities if opp.to_dict().get('stageCategory') in ['lead', 'new'])
opp_bookings = sum(1 for opp in opportunities if opp.to_dict().get('stageCategory') == 'bookedAppointments')
opp_deposits = sum(1 for opp in opportunities if opp.to_dict().get('stageCategory') == 'deposits')
opp_cash_count = sum(1 for opp in opportunities if opp.to_dict().get('stageCategory') == 'cashCollected')

print(f"{'Leads':<20} {opp_leads:<20} {total_leads:<20} {total_campaign_leads:<20} {'✅' if opp_leads == total_leads == total_campaign_leads else '❌'}")
print(f"{'Bookings':<20} {opp_bookings:<20} {total_bookings:<20} {total_campaign_bookings:<20} {'✅' if opp_bookings == total_bookings == total_campaign_bookings else '❌'}")
print(f"{'Deposits':<20} {opp_deposits:<20} {total_deposits:<20} {total_campaign_deposits:<20} {'✅' if opp_deposits == total_deposits == total_campaign_deposits else '❌'}")
print(f"{'Cash (count)':<20} {opp_cash_count:<20} {ads_with_cash:<20} {campaigns_with_cash:<20} {'✅' if opp_cash_count == ads_with_cash else '❌'}")
print(f"{'Cash (amount)':<20} R {total_monetary_value:,.0f}  R {total_cash:,.0f}  R {total_campaign_cash:,.0f}  {'✅' if abs(total_monetary_value - total_cash) < 1000 else '❌'}")

# ============================================================================
# 5. CHECK SPECIFIC HIGH-VALUE OPPORTUNITIES
# ============================================================================
print("\n5. CHECKING SPECIFIC HIGH-VALUE OPPORTUNITIES")
print("-" * 80)

# Check if high-value opportunities are assigned to ads
print("\nVerifying high-value opportunities are assigned to ads:")
for opp in recent_opportunities[:5]:
    opp_id = opp['id']
    assigned_ad_id = opp['assignedAdId']
    
    if assigned_ad_id and assigned_ad_id != 'None':
        # Check if ad exists
        ad_doc = db.collection('ads').document(assigned_ad_id).get()
        if ad_doc.exists:
            ad_data = ad_doc.to_dict()
            ghl_stats = ad_data.get('ghlStats', {})
            print(f"\n✅ {opp['name']} (R {opp['monetaryValue']:,.2f})")
            print(f"   Assigned to Ad: {assigned_ad_id}")
            print(f"   Ad GHL Stats: {ghl_stats}")
        else:
            print(f"\n❌ {opp['name']} (R {opp['monetaryValue']:,.2f})")
            print(f"   Assigned to Ad: {assigned_ad_id} (AD NOT FOUND!)")
    else:
        print(f"\n❌ {opp['name']} (R {opp['monetaryValue']:,.2f})")
        print(f"   NOT ASSIGNED TO ANY AD")

# ============================================================================
# 6. SUMMARY AND RECOMMENDATIONS
# ============================================================================
print("\n" + "=" * 80)
print("SUMMARY AND RECOMMENDATIONS")
print("=" * 80)

issues_found = []

if len(opportunities) == 0:
    issues_found.append("❌ CRITICAL: ghlOpportunities collection is EMPTY")
elif assigned_count < len(opportunities) * 0.5:
    issues_found.append(f"⚠️  Only {assigned_count/len(opportunities)*100:.1f}% of opportunities are assigned to ads")

if with_monetary_value < len(opportunities) * 0.1:
    issues_found.append(f"⚠️  Only {with_monetary_value/len(opportunities)*100:.1f}% of opportunities have monetary values")

if ads_with_ghl_stats < len(ads) * 0.1:
    issues_found.append(f"⚠️  Only {ads_with_ghl_stats/len(ads)*100:.1f}% of ads have GHL stats")

if total_campaign_leads != total_leads:
    issues_found.append(f"❌ Campaign leads ({total_campaign_leads}) don't match ad leads ({total_leads})")

if total_campaign_bookings != total_bookings:
    issues_found.append(f"❌ Campaign bookings ({total_campaign_bookings}) don't match ad bookings ({total_bookings})")

if abs(total_campaign_cash - total_cash) > 1000:
    issues_found.append(f"❌ Campaign cash (R {total_campaign_cash:,.2f}) doesn't match ad cash (R {total_cash:,.2f})")

if issues_found:
    print("\nISSUES FOUND:")
    for issue in issues_found:
        print(f"  {issue}")
    
    print("\nRECOMMENDED ACTIONS:")
    
    if len(opportunities) == 0:
        print("  1. Run GHL sync to populate ghlOpportunities collection")
        print("     Script: update_ghl_with_form_submissions.py")
    
    if assigned_count < len(opportunities) * 0.5:
        print("  2. Run opportunity assignment script to match opportunities to ads")
        print("     Script: update_ghl_with_form_submissions.py")
    
    if ads_with_ghl_stats < len(ads) * 0.1:
        print("  3. Run aggregation script to update ad GHL stats from opportunities")
        print("     This should happen automatically via Cloud Functions")
    
    if total_campaign_leads != total_leads or total_campaign_bookings != total_bookings:
        print("  4. Run campaign aggregation to recalculate campaign metrics")
        print("     Script: reaggregate_ghl_to_ads.py or trigger Cloud Function")
else:
    print("\n✅ No major issues found!")
    print("   GHL data appears to be properly populated and aggregated.")

print("\n" + "=" * 80)
print("Investigation complete!")
print("=" * 80)

