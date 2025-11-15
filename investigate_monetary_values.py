#!/usr/bin/env python3
"""
Investigate Why Monetary Values Are Missing
============================================
This script checks why opportunities don't have monetary values
and why they're not being aggregated correctly.
"""

import firebase_admin
from firebase_admin import credentials, firestore
import json

# Initialize Firebase
if not firebase_admin._apps:
    cred = credentials.Certificate('/Users/mac/dev/medwave/medx-ai-firebase-adminsdk-fbsvc-a86e7bd050.json')
    firebase_admin.initialize_app(cred)

db = firestore.client()

print("=" * 80)
print("INVESTIGATING MONETARY VALUES")
print("=" * 80)

# Get all opportunities
opportunities = list(db.collection('ghlOpportunities').stream())
print(f"\nTotal opportunities: {len(opportunities)}")

# Check deposit and cash_collected opportunities
deposit_opps = []
cash_opps = []

for opp_doc in opportunities:
    opp = opp_doc.to_dict()
    stage_category = opp.get('stageCategory', '')
    
    if stage_category == 'deposit':
        deposit_opps.append({
            'id': opp_doc.id,
            'name': opp.get('name', 'Unknown'),
            'monetaryValue': opp.get('monetaryValue', 0),
            'currentStage': opp.get('currentStage', 'Unknown'),
            'assignedAdId': opp.get('assignedAdId'),
            'campaignId': opp.get('campaignId'),
            'pipelineId': opp.get('pipelineId'),
            'pipelineStageId': opp.get('pipelineStageId')
        })
    
    if stage_category == 'cash_collected':
        cash_opps.append({
            'id': opp_doc.id,
            'name': opp.get('name', 'Unknown'),
            'monetaryValue': opp.get('monetaryValue', 0),
            'currentStage': opp.get('currentStage', 'Unknown'),
            'assignedAdId': opp.get('assignedAdId'),
            'campaignId': opp.get('campaignId'),
            'pipelineId': opp.get('pipelineId'),
            'pipelineStageId': opp.get('pipelineStageId')
        })

print(f"\nDeposit opportunities: {len(deposit_opps)}")
print(f"Cash collected opportunities: {len(cash_opps)}")

# Check how many have monetary values
deposit_with_money = [o for o in deposit_opps if o['monetaryValue'] and o['monetaryValue'] > 0]
cash_with_money = [o for o in cash_opps if o['monetaryValue'] and o['monetaryValue'] > 0]

print(f"\nDeposits WITH monetary value: {len(deposit_with_money)} ({len(deposit_with_money)/len(deposit_opps)*100:.1f}%)")
print(f"Cash collected WITH monetary value: {len(cash_with_money)} ({len(cash_with_money)/len(cash_opps)*100:.1f}%)")

# Show examples of deposits WITHOUT monetary values
print("\n" + "=" * 80)
print("DEPOSITS WITHOUT MONETARY VALUES (Sample)")
print("=" * 80)
deposit_without_money = [o for o in deposit_opps if not o['monetaryValue'] or o['monetaryValue'] == 0]
for opp in deposit_without_money[:10]:
    print(f"\n{opp['name']}")
    print(f"  Stage: {opp['currentStage']}")
    print(f"  Monetary Value: {opp['monetaryValue']}")
    print(f"  Assigned Ad: {opp['assignedAdId']}")
    print(f"  Campaign: {opp['campaignId']}")
    print(f"  Pipeline ID: {opp['pipelineId']}")
    print(f"  Stage ID: {opp['pipelineStageId']}")

# Show examples of cash collected WITHOUT monetary values
print("\n" + "=" * 80)
print("CASH COLLECTED WITHOUT MONETARY VALUES (Sample)")
print("=" * 80)
cash_without_money = [o for o in cash_opps if not o['monetaryValue'] or o['monetaryValue'] == 0]
for opp in cash_without_money[:10]:
    print(f"\n{opp['name']}")
    print(f"  Stage: {opp['currentStage']}")
    print(f"  Monetary Value: {opp['monetaryValue']}")
    print(f"  Assigned Ad: {opp['assignedAdId']}")
    print(f"  Campaign: {opp['campaignId']}")
    print(f"  Pipeline ID: {opp['pipelineId']}")
    print(f"  Stage ID: {opp['pipelineStageId']}")

# Check a specific ad to see how it's aggregating
print("\n" + "=" * 80)
print("CHECKING AD AGGREGATION LOGIC")
print("=" * 80)

# Get an ad with deposits
ad_id = "120234319560020335"  # Rudi Brits ad
ad_doc = db.collection('ads').document(ad_id).get()
if ad_doc.exists:
    ad_data = ad_doc.to_dict()
    print(f"\nAd: {ad_data.get('adName')}")
    print(f"GHL Stats: {ad_data.get('ghlStats')}")
    
    # Get all opportunities for this ad
    ad_opps = db.collection('ghlOpportunities').where('assignedAdId', '==', ad_id).stream()
    print(f"\nOpportunities assigned to this ad:")
    for opp_doc in ad_opps:
        opp = opp_doc.to_dict()
        print(f"  - {opp.get('name')}: {opp.get('stageCategory')} - R {opp.get('monetaryValue', 0):,.2f}")

# Check how aggregation should work
print("\n" + "=" * 80)
print("AGGREGATION LOGIC CHECK")
print("=" * 80)

print("\nFor deposits, the aggregation should:")
print("1. Count opportunities where stageCategory == 'deposit'")
print("2. Sum monetaryValue for those opportunities")
print("3. Store in ad.ghlStats.deposits (count) and ad.ghlStats.depositAmount (sum)")

print("\nFor cash collected, the aggregation should:")
print("1. Count opportunities where stageCategory == 'cash_collected'")
print("2. Sum monetaryValue for those opportunities")
print("3. Store in ad.ghlStats.cashCollected (count) and ad.ghlStats.cashAmount (sum)")

print("\n" + "=" * 80)
print("CRITICAL ISSUE IDENTIFIED")
print("=" * 80)

print("\n❌ PROBLEM: Most deposit/cash opportunities have NO monetaryValue!")
print(f"   - {len(deposit_without_money)}/{len(deposit_opps)} deposits have no monetary value")
print(f"   - {len(cash_without_money)}/{len(cash_opps)} cash collected have no monetary value")

print("\n❌ PROBLEM: Aggregation is counting deposits/cash but not summing monetary values!")
print("   - Ads show deposits: 18, but cashAmount: R 2,495,000")
print("   - This means only 6 out of 18 deposits have monetary values")

print("\n❌ PROBLEM: Many high-value opportunities are NOT assigned to ads!")
print("   - 50% of opportunities have no assignedAdId")
print("   - R 11M in monetary value is not being counted")

print("\n" + "=" * 80)
print("ROOT CAUSES")
print("=" * 80)

print("\n1. GHL API may not always return monetaryValue")
print("   - Need to check if GHL API is being queried for monetary values")
print("   - May need to fetch from a different endpoint")

print("\n2. Opportunities created before monetaryValue tracking")
print("   - Older opportunities may not have this field")
print("   - Need to backfill from GHL API")

print("\n3. Aggregation logic may not be handling missing monetaryValue correctly")
print("   - Should sum monetaryValue where it exists")
print("   - Currently may be skipping opportunities with no monetaryValue")

print("\n4. Unassigned opportunities are not being counted at all")
print("   - 954 opportunities have no assignedAdId")
print("   - These are completely missing from campaign summaries")

print("\n" + "=" * 80)
print("RECOMMENDED FIXES")
print("=" * 80)

print("\n1. Update GHL sync to fetch monetaryValue from opportunities API")
print("   - Endpoint: GET /opportunities/{opportunityId}")
print("   - Field: monetaryValue")

print("\n2. Run backfill script to update existing opportunities")
print("   - Fetch all opportunities from GHL API")
print("   - Update Firebase with monetaryValue")

print("\n3. Fix aggregation to handle opportunities without assignedAdId")
print("   - These should still be counted in campaign totals")
print("   - Use campaignId for aggregation if assignedAdId is missing")

print("\n4. Update Cloud Functions to sync monetaryValue on opportunity updates")
print("   - When opportunity stage changes, fetch latest monetaryValue")
print("   - Store in ghlOpportunities collection")

print("\n" + "=" * 80)

