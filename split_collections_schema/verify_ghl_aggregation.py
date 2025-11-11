#!/usr/bin/env python3
"""
Verification script to check if GHL stats in campaigns, adSets, and ads
match the actual counts from ghlOpportunities collection.

This will detect:
- Duplicate counting
- Missing opportunities
- Incorrect aggregations
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
print("VERIFYING GHL AGGREGATION ACROSS ALL COLLECTIONS")
print("=" * 80)
print()

# STEP 1: Get actual counts from ghlOpportunities (source of truth)
print("📊 STEP 1: Calculating actual GHL stats from ghlOpportunities...")
print()

opportunities = list(db.collection('ghlOpportunities').stream())
print(f"✅ Found {len(opportunities)} total opportunities")

# Track stats by ad, adSet, and campaign
ad_stats = defaultdict(lambda: {'leads': 0, 'bookings': 0, 'deposits': 0, 'cash': 0, 'opportunities': []})
adset_stats = defaultdict(lambda: {'leads': 0, 'bookings': 0, 'deposits': 0, 'cash': 0})
campaign_stats = defaultdict(lambda: {'leads': 0, 'bookings': 0, 'deposits': 0, 'cash': 0})

opportunities_with_ads = 0
opportunities_without_ads = 0

for opp_doc in opportunities:
    opp = opp_doc.to_dict()
    opp_id = opp_doc.id
    
    assigned_ad_id = opp.get('assignedAdId')
    assigned_adset_id = opp.get('assignedAdSetId')
    assigned_campaign_id = opp.get('assignedCampaignId')
    stage_category = opp.get('stageCategory', 'other')
    
    if not assigned_ad_id:
        opportunities_without_ads += 1
        continue
    
    opportunities_with_ads += 1
    
    # Track which opportunities are assigned to each ad (for duplicate detection)
    ad_stats[assigned_ad_id]['opportunities'].append(opp_id)
    
    # Count by stage category
    if stage_category == 'lead':
        ad_stats[assigned_ad_id]['leads'] += 1
        if assigned_adset_id:
            adset_stats[assigned_adset_id]['leads'] += 1
        if assigned_campaign_id:
            campaign_stats[assigned_campaign_id]['leads'] += 1
    elif stage_category == 'booking':
        ad_stats[assigned_ad_id]['bookings'] += 1
        if assigned_adset_id:
            adset_stats[assigned_adset_id]['bookings'] += 1
        if assigned_campaign_id:
            campaign_stats[assigned_campaign_id]['bookings'] += 1
    elif stage_category == 'deposit':
        ad_stats[assigned_ad_id]['deposits'] += 1
        if assigned_adset_id:
            adset_stats[assigned_adset_id]['deposits'] += 1
        if assigned_campaign_id:
            campaign_stats[assigned_campaign_id]['deposits'] += 1
    elif stage_category == 'cash_collected':
        ad_stats[assigned_ad_id]['cash'] += 1
        if assigned_adset_id:
            adset_stats[assigned_adset_id]['cash'] += 1
        if assigned_campaign_id:
            campaign_stats[assigned_campaign_id]['cash'] += 1

print(f"✅ {opportunities_with_ads} opportunities assigned to ads")
print(f"✅ {opportunities_without_ads} opportunities without ad assignment")
print()

# STEP 2: Compare with ads collection
print("📊 STEP 2: Comparing with ads collection...")
print()

ads_docs = list(db.collection('ads').stream())
print(f"✅ Found {len(ads_docs)} ads in collection")

ads_mismatches = []
ads_correct = 0

for ad_doc in ads_docs:
    ad = ad_doc.to_dict()
    ad_id = ad_doc.id
    
    stored_ghl = ad.get('ghlStats', {})
    stored_leads = stored_ghl.get('leads', 0)
    stored_bookings = stored_ghl.get('bookings', 0)
    stored_deposits = stored_ghl.get('deposits', 0)
    stored_cash = stored_ghl.get('cashCollected', 0)
    
    actual = ad_stats[ad_id]
    actual_leads = actual['leads']
    actual_bookings = actual['bookings']
    actual_deposits = actual['deposits']
    actual_cash = actual['cash']
    
    if (stored_leads != actual_leads or 
        stored_bookings != actual_bookings or 
        stored_deposits != actual_deposits or 
        stored_cash != actual_cash):
        
        ads_mismatches.append({
            'ad_id': ad_id,
            'ad_name': ad.get('adName', 'Unknown'),
            'stored': {
                'leads': stored_leads,
                'bookings': stored_bookings,
                'deposits': stored_deposits,
                'cash': stored_cash
            },
            'actual': {
                'leads': actual_leads,
                'bookings': actual_bookings,
                'deposits': actual_deposits,
                'cash': actual_cash
            },
            'opportunities': actual['opportunities']
        })
    else:
        ads_correct += 1

if ads_mismatches:
    print(f"❌ Found {len(ads_mismatches)} ads with MISMATCHED stats:")
    print()
    for mismatch in ads_mismatches[:10]:  # Show first 10
        print(f"   Ad: {mismatch['ad_id']}")
        print(f"   Name: {mismatch['ad_name']}")
        print(f"   Stored:  L:{mismatch['stored']['leads']} B:{mismatch['stored']['bookings']} D:{mismatch['stored']['deposits']} C:{mismatch['stored']['cash']}")
        print(f"   Actual:  L:{mismatch['actual']['leads']} B:{mismatch['actual']['bookings']} D:{mismatch['actual']['deposits']} C:{mismatch['actual']['cash']}")
        print(f"   Opportunities: {len(mismatch['opportunities'])}")
        print()
else:
    print(f"✅ All {ads_correct} ads have CORRECT GHL stats!")
print()

# STEP 3: Compare with adSets collection
print("📊 STEP 3: Comparing with adSets collection...")
print()

adsets_docs = list(db.collection('adSets').stream())
print(f"✅ Found {len(adsets_docs)} ad sets in collection")

adsets_mismatches = []
adsets_correct = 0

for adset_doc in adsets_docs:
    adset = adset_doc.to_dict()
    adset_id = adset_doc.id
    
    stored_ghl = adset.get('ghlStats', {})
    stored_leads = stored_ghl.get('leads', 0)
    stored_bookings = stored_ghl.get('bookings', 0)
    stored_deposits = stored_ghl.get('deposits', 0)
    stored_cash = stored_ghl.get('cashCollected', 0)
    
    actual = adset_stats[adset_id]
    actual_leads = actual['leads']
    actual_bookings = actual['bookings']
    actual_deposits = actual['deposits']
    actual_cash = actual['cash']
    
    if (stored_leads != actual_leads or 
        stored_bookings != actual_bookings or 
        stored_deposits != actual_deposits or 
        stored_cash != actual_cash):
        
        adsets_mismatches.append({
            'adset_id': adset_id,
            'adset_name': adset.get('adSetName', 'Unknown'),
            'stored': {
                'leads': stored_leads,
                'bookings': stored_bookings,
                'deposits': stored_deposits,
                'cash': stored_cash
            },
            'actual': {
                'leads': actual_leads,
                'bookings': actual_bookings,
                'deposits': actual_deposits,
                'cash': actual_cash
            }
        })
    else:
        adsets_correct += 1

if adsets_mismatches:
    print(f"❌ Found {len(adsets_mismatches)} ad sets with MISMATCHED stats:")
    print()
    for mismatch in adsets_mismatches[:10]:  # Show first 10
        print(f"   AdSet: {mismatch['adset_id']}")
        print(f"   Name: {mismatch['adset_name']}")
        print(f"   Stored:  L:{mismatch['stored']['leads']} B:{mismatch['stored']['bookings']} D:{mismatch['stored']['deposits']} C:{mismatch['stored']['cash']}")
        print(f"   Actual:  L:{mismatch['actual']['leads']} B:{mismatch['actual']['bookings']} D:{mismatch['actual']['deposits']} C:{mismatch['actual']['cash']}")
        print()
else:
    print(f"✅ All {adsets_correct} ad sets have CORRECT GHL stats!")
print()

# STEP 4: Compare with campaigns collection
print("📊 STEP 4: Comparing with campaigns collection...")
print()

campaigns_docs = list(db.collection('campaigns').stream())
print(f"✅ Found {len(campaigns_docs)} campaigns in collection")

campaigns_mismatches = []
campaigns_correct = 0

for campaign_doc in campaigns_docs:
    campaign = campaign_doc.to_dict()
    campaign_id = campaign_doc.id
    
    stored_ghl = campaign.get('ghlStats', {})
    stored_leads = stored_ghl.get('leads', 0)
    stored_bookings = stored_ghl.get('bookings', 0)
    stored_deposits = stored_ghl.get('deposits', 0)
    stored_cash = stored_ghl.get('cashCollected', 0)
    
    actual = campaign_stats[campaign_id]
    actual_leads = actual['leads']
    actual_bookings = actual['bookings']
    actual_deposits = actual['deposits']
    actual_cash = actual['cash']
    
    if (stored_leads != actual_leads or 
        stored_bookings != actual_bookings or 
        stored_deposits != actual_deposits or 
        stored_cash != actual_cash):
        
        campaigns_mismatches.append({
            'campaign_id': campaign_id,
            'campaign_name': campaign.get('campaignName', 'Unknown'),
            'stored': {
                'leads': stored_leads,
                'bookings': stored_bookings,
                'deposits': stored_deposits,
                'cash': stored_cash
            },
            'actual': {
                'leads': actual_leads,
                'bookings': actual_bookings,
                'deposits': actual_deposits,
                'cash': actual_cash
            }
        })
    else:
        campaigns_correct += 1

if campaigns_mismatches:
    print(f"❌ Found {len(campaigns_mismatches)} campaigns with MISMATCHED stats:")
    print()
    for mismatch in campaigns_mismatches[:10]:  # Show first 10
        print(f"   Campaign: {mismatch['campaign_id']}")
        print(f"   Name: {mismatch['campaign_name']}")
        print(f"   Stored:  L:{mismatch['stored']['leads']} B:{mismatch['stored']['bookings']} D:{mismatch['stored']['deposits']} C:{mismatch['stored']['cash']}")
        print(f"   Actual:  L:{mismatch['actual']['leads']} B:{mismatch['actual']['bookings']} D:{mismatch['actual']['deposits']} C:{mismatch['actual']['cash']}")
        print()
else:
    print(f"✅ All {campaigns_correct} campaigns have CORRECT GHL stats!")
print()

# STEP 5: Summary
print("=" * 80)
print("📊 VERIFICATION SUMMARY")
print("=" * 80)
print()
print(f"Ads:")
print(f"  ✅ Correct: {ads_correct}")
print(f"  ❌ Mismatched: {len(ads_mismatches)}")
print()
print(f"Ad Sets:")
print(f"  ✅ Correct: {adsets_correct}")
print(f"  ❌ Mismatched: {len(adsets_mismatches)}")
print()
print(f"Campaigns:")
print(f"  ✅ Correct: {campaigns_correct}")
print(f"  ❌ Mismatched: {len(campaigns_mismatches)}")
print()

if ads_mismatches or adsets_mismatches or campaigns_mismatches:
    print("⚠️  MISMATCHES DETECTED - Re-aggregation recommended!")
    print()
    print("To fix, run:")
    print("  python3 split_collections_schema/reaggregate_ghl_to_ads.py")
else:
    print("✅ ALL COLLECTIONS ARE ACCURATE - No action needed!")

print()
print("=" * 80)

