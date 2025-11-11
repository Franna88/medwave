#!/usr/bin/env python3
"""
Verify split collections migration

This script verifies that the migration from advertData to split collections
was successful and checks for data integrity issues, especially cross-campaign duplicates.
"""

import firebase_admin
from firebase_admin import credentials, firestore
from collections import defaultdict
import json
from datetime import datetime

# Initialize Firebase
if not firebase_admin._apps:
    cred = credentials.Certificate('medx-ai-firebase-adminsdk-fbsvc-a86e7bd050.json')
    firebase_admin.initialize_app(cred)

db = firestore.client()

print("=" * 100)
print("SPLIT COLLECTIONS VERIFICATION")
print("=" * 100)
print()

# ============================================================================
# PHASE 1: Count documents in each collection
# ============================================================================

print("📊 PHASE 1: Counting documents...")
print()

campaigns_count = len(list(db.collection('campaigns').stream()))
ad_sets_count = len(list(db.collection('adSets').stream()))
ads_count = len(list(db.collection('ads').stream()))
opportunities_count = len(list(db.collection('ghlOpportunities').stream()))
mappings_count = len(list(db.collection('ghlOpportunityMapping').stream()))

print(f"✅ campaigns: {campaigns_count}")
print(f"✅ adSets: {ad_sets_count}")
print(f"✅ ads: {ads_count}")
print(f"✅ ghlOpportunities: {opportunities_count}")
print(f"✅ ghlOpportunityMapping: {mappings_count}")
print()

# ============================================================================
# PHASE 2: Verify aggregations match
# ============================================================================

print("📊 PHASE 2: Verifying aggregations...")
print()

# Load all ads
all_ads = {}
for ad_doc in db.collection('ads').stream():
    ad_data = ad_doc.to_dict()
    all_ads[ad_doc.id] = ad_data

# Verify campaign aggregations
campaigns = db.collection('campaigns').stream()
campaign_errors = []

for campaign_doc in campaigns:
    campaign_data = campaign_doc.to_dict()
    campaign_id = campaign_doc.id
    
    # Find all ads in this campaign
    campaign_ads = [ad for ad in all_ads.values() if ad.get('campaignId') == campaign_id]
    
    # Calculate expected totals
    expected_spend = sum(ad.get('facebookStats', {}).get('spend', 0) for ad in campaign_ads)
    expected_leads = sum(ad.get('ghlStats', {}).get('leads', 0) for ad in campaign_ads)
    expected_cash = sum(ad.get('ghlStats', {}).get('cashAmount', 0) for ad in campaign_ads)
    
    # Compare with stored values
    actual_spend = campaign_data.get('totalSpend', 0)
    actual_leads = campaign_data.get('totalLeads', 0)
    actual_cash = campaign_data.get('totalCashAmount', 0)
    
    # Allow small floating point differences
    spend_diff = abs(expected_spend - actual_spend)
    cash_diff = abs(expected_cash - actual_cash)
    
    if spend_diff > 0.01 or expected_leads != actual_leads or cash_diff > 0.01:
        campaign_errors.append({
            'campaignId': campaign_id,
            'campaignName': campaign_data.get('campaignName', ''),
            'expected_spend': expected_spend,
            'actual_spend': actual_spend,
            'expected_leads': expected_leads,
            'actual_leads': actual_leads,
            'expected_cash': expected_cash,
            'actual_cash': actual_cash
        })

if campaign_errors:
    print(f"⚠️  Found {len(campaign_errors)} campaigns with aggregation mismatches")
    for error in campaign_errors[:5]:  # Show first 5
        print(f"   Campaign: {error['campaignName']}")
        print(f"   - Spend: expected {error['expected_spend']}, got {error['actual_spend']}")
        print(f"   - Leads: expected {error['expected_leads']}, got {error['actual_leads']}")
        print(f"   - Cash: expected {error['expected_cash']}, got {error['actual_cash']}")
        print()
else:
    print("✅ All campaign aggregations match!")
    print()

# Verify ad set aggregations
ad_sets = db.collection('adSets').stream()
ad_set_errors = []

for ad_set_doc in ad_sets:
    ad_set_data = ad_set_doc.to_dict()
    ad_set_id = ad_set_doc.id
    
    # Find all ads in this ad set
    ad_set_ads = [ad for ad in all_ads.values() if ad.get('adSetId') == ad_set_id]
    
    # Calculate expected totals
    expected_spend = sum(ad.get('facebookStats', {}).get('spend', 0) for ad in ad_set_ads)
    expected_leads = sum(ad.get('ghlStats', {}).get('leads', 0) for ad in ad_set_ads)
    
    # Compare with stored values
    actual_spend = ad_set_data.get('totalSpend', 0)
    actual_leads = ad_set_data.get('totalLeads', 0)
    
    spend_diff = abs(expected_spend - actual_spend)
    
    if spend_diff > 0.01 or expected_leads != actual_leads:
        ad_set_errors.append({
            'adSetId': ad_set_id,
            'adSetName': ad_set_data.get('adSetName', ''),
            'expected_spend': expected_spend,
            'actual_spend': actual_spend,
            'expected_leads': expected_leads,
            'actual_leads': actual_leads
        })

if ad_set_errors:
    print(f"⚠️  Found {len(ad_set_errors)} ad sets with aggregation mismatches")
else:
    print("✅ All ad set aggregations match!")
    print()

# ============================================================================
# PHASE 3: Check for orphaned records
# ============================================================================

print("📊 PHASE 3: Checking for orphaned records...")
print()

# Check for ads without campaigns
orphaned_ads = []
for ad_id, ad_data in all_ads.items():
    campaign_id = ad_data.get('campaignId')
    if campaign_id:
        # Check if campaign exists
        campaign_doc = db.collection('campaigns').document(campaign_id).get()
        if not campaign_doc.exists:
            orphaned_ads.append({
                'adId': ad_id,
                'adName': ad_data.get('adName', ''),
                'campaignId': campaign_id
            })

if orphaned_ads:
    print(f"⚠️  Found {len(orphaned_ads)} ads with missing campaigns")
    for orphan in orphaned_ads[:5]:
        print(f"   Ad: {orphan['adName']} (campaign {orphan['campaignId']} not found)")
else:
    print("✅ No orphaned ads found!")
    print()

# Check for ad sets without campaigns
orphaned_ad_sets = []
for ad_set_doc in db.collection('adSets').stream():
    ad_set_data = ad_set_doc.to_dict()
    campaign_id = ad_set_data.get('campaignId')
    if campaign_id:
        campaign_doc = db.collection('campaigns').document(campaign_id).get()
        if not campaign_doc.exists:
            orphaned_ad_sets.append({
                'adSetId': ad_set_doc.id,
                'adSetName': ad_set_data.get('adSetName', ''),
                'campaignId': campaign_id
            })

if orphaned_ad_sets:
    print(f"⚠️  Found {len(orphaned_ad_sets)} ad sets with missing campaigns")
else:
    print("✅ No orphaned ad sets found!")
    print()

# ============================================================================
# PHASE 4: Check for cross-campaign duplicates (CRITICAL)
# ============================================================================

print("📊 PHASE 4: Checking for cross-campaign duplicates...")
print()

# Load all opportunity mappings
opportunity_to_ads = defaultdict(list)

for opp_doc in db.collection('ghlOpportunities').stream():
    opp_data = opp_doc.to_dict()
    opp_id = opp_doc.id
    ad_id = opp_data.get('adId')
    campaign_id = opp_data.get('campaignId')
    
    if ad_id and campaign_id:
        opportunity_to_ads[opp_id].append({
            'adId': ad_id,
            'campaignId': campaign_id,
            'campaignName': opp_data.get('campaignName', '')
        })

# Find opportunities appearing in multiple campaigns
cross_campaign_duplicates = []

for opp_id, ads in opportunity_to_ads.items():
    unique_campaigns = set(ad['campaignId'] for ad in ads)
    
    if len(unique_campaigns) > 1:
        cross_campaign_duplicates.append({
            'opportunityId': opp_id,
            'campaigns': list(unique_campaigns),
            'ad_count': len(ads)
        })

if cross_campaign_duplicates:
    print(f"❌ CRITICAL: Found {len(cross_campaign_duplicates)} opportunities in multiple campaigns!")
    print()
    print("   Worst offenders:")
    sorted_dupes = sorted(cross_campaign_duplicates, key=lambda x: x['ad_count'], reverse=True)
    for dupe in sorted_dupes[:10]:
        print(f"   - Opportunity {dupe['opportunityId']}: appears in {len(dupe['campaigns'])} campaigns ({dupe['ad_count']} ads)")
    print()
    print("   ⚠️  THIS IS A CRITICAL ISSUE - Metrics will be inflated!")
    print()
else:
    print("✅ NO cross-campaign duplicates found! Each opportunity in exactly ONE campaign.")
    print()

# ============================================================================
# PHASE 5: Verify opportunity mappings
# ============================================================================

print("📊 PHASE 5: Verifying opportunity mappings...")
print()

# Check that all ghlOpportunities have corresponding mappings
opportunities_without_mapping = []

for opp_doc in db.collection('ghlOpportunities').stream():
    opp_id = opp_doc.id
    mapping_doc = db.collection('ghlOpportunityMapping').document(opp_id).get()
    
    if not mapping_doc.exists:
        opportunities_without_mapping.append(opp_id)

if opportunities_without_mapping:
    print(f"⚠️  Found {len(opportunities_without_mapping)} opportunities without mappings")
else:
    print("✅ All opportunities have mappings!")
    print()

# Check that all mappings point to valid ads
invalid_mappings = []

for mapping_doc in db.collection('ghlOpportunityMapping').stream():
    mapping_data = mapping_doc.to_dict()
    assigned_ad_id = mapping_data.get('assignedAdId')
    
    if assigned_ad_id and assigned_ad_id not in all_ads:
        invalid_mappings.append({
            'opportunityId': mapping_doc.id,
            'assignedAdId': assigned_ad_id
        })

if invalid_mappings:
    print(f"⚠️  Found {len(invalid_mappings)} mappings pointing to non-existent ads")
    for invalid in invalid_mappings[:5]:
        print(f"   - Opportunity {invalid['opportunityId']} -> Ad {invalid['assignedAdId']} (not found)")
else:
    print("✅ All mappings point to valid ads!")
    print()

# ============================================================================
# PHASE 6: Compare with advertData (if it still exists)
# ============================================================================

print("📊 PHASE 6: Comparing with original advertData...")
print()

# Count ads in advertData
advertdata_ad_count = 0
for month_doc in db.collection('advertData').stream():
    month_data = month_doc.to_dict()
    if 'totalAds' in month_data:
        ads_in_month = len(list(month_doc.reference.collection('ads').stream()))
        advertdata_ad_count += ads_in_month

if advertdata_ad_count > 0:
    print(f"   advertData has {advertdata_ad_count} ads")
    print(f"   New ads collection has {ads_count} ads")
    
    if advertdata_ad_count == ads_count:
        print("   ✅ Ad counts match!")
    else:
        print(f"   ⚠️  Mismatch: {abs(advertdata_ad_count - ads_count)} ads difference")
else:
    print("   ℹ️  advertData collection is empty or already archived")

print()

# ============================================================================
# SUMMARY
# ============================================================================

print("=" * 100)
print("VERIFICATION SUMMARY")
print("=" * 100)
print()

all_checks_passed = True

print("Document Counts:")
print(f"  ✅ Campaigns: {campaigns_count}")
print(f"  ✅ Ad Sets: {ad_sets_count}")
print(f"  ✅ Ads: {ads_count}")
print(f"  ✅ Opportunities: {opportunities_count}")
print(f"  ✅ Mappings: {mappings_count}")
print()

print("Data Integrity:")
if campaign_errors:
    print(f"  ⚠️  Campaign aggregation errors: {len(campaign_errors)}")
    all_checks_passed = False
else:
    print(f"  ✅ Campaign aggregations: OK")

if ad_set_errors:
    print(f"  ⚠️  Ad set aggregation errors: {len(ad_set_errors)}")
    all_checks_passed = False
else:
    print(f"  ✅ Ad set aggregations: OK")

if orphaned_ads:
    print(f"  ⚠️  Orphaned ads: {len(orphaned_ads)}")
    all_checks_passed = False
else:
    print(f"  ✅ No orphaned ads")

if orphaned_ad_sets:
    print(f"  ⚠️  Orphaned ad sets: {len(orphaned_ad_sets)}")
    all_checks_passed = False
else:
    print(f"  ✅ No orphaned ad sets")

print()
print("Cross-Campaign Duplicates (CRITICAL):")
if cross_campaign_duplicates:
    print(f"  ❌ CRITICAL: {len(cross_campaign_duplicates)} opportunities in multiple campaigns")
    all_checks_passed = False
else:
    print(f"  ✅ NO duplicates - each opportunity in ONE campaign")

print()
print("Opportunity Mappings:")
if opportunities_without_mapping:
    print(f"  ⚠️  Opportunities without mappings: {len(opportunities_without_mapping)}")
    all_checks_passed = False
else:
    print(f"  ✅ All opportunities have mappings")

if invalid_mappings:
    print(f"  ⚠️  Invalid mappings: {len(invalid_mappings)}")
    all_checks_passed = False
else:
    print(f"  ✅ All mappings valid")

print()
print("=" * 100)

if all_checks_passed:
    print("✅ ALL CHECKS PASSED - Migration successful!")
else:
    print("⚠️  SOME CHECKS FAILED - Review issues above")

print("=" * 100)

# Save detailed report
report = {
    'timestamp': datetime.now().isoformat(),
    'document_counts': {
        'campaigns': campaigns_count,
        'adSets': ad_sets_count,
        'ads': ads_count,
        'ghlOpportunities': opportunities_count,
        'ghlOpportunityMapping': mappings_count
    },
    'errors': {
        'campaign_aggregation_errors': len(campaign_errors),
        'ad_set_aggregation_errors': len(ad_set_errors),
        'orphaned_ads': len(orphaned_ads),
        'orphaned_ad_sets': len(orphaned_ad_sets),
        'cross_campaign_duplicates': len(cross_campaign_duplicates),
        'opportunities_without_mapping': len(opportunities_without_mapping),
        'invalid_mappings': len(invalid_mappings)
    },
    'all_checks_passed': all_checks_passed
}

report_filename = f"verification_report_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
with open(report_filename, 'w') as f:
    json.dump(report, f, indent=2)

print(f"\n📄 Detailed report saved to: {report_filename}")

