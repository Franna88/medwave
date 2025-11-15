#!/usr/bin/env python3
"""
Review GHL Opportunities Collection
====================================
Shows the current state after reaggregation and identifies remaining issues.
"""

import firebase_admin
from firebase_admin import credentials, firestore
from collections import defaultdict

# Initialize Firebase
if not firebase_admin._apps:
    cred = credentials.Certificate('/Users/mac/dev/medwave/medx-ai-firebase-adminsdk-fbsvc-a86e7bd050.json')
    firebase_admin.initialize_app(cred)

db = firestore.client()

print("=" * 80)
print("GHL OPPORTUNITIES COLLECTION REVIEW")
print("=" * 80)
print()

# Get all opportunities
opportunities = list(db.collection('ghlOpportunities').stream())
print(f"Total opportunities: {len(opportunities)}")
print()

# Categorize opportunities
assigned = []
unassigned = []
with_money = []
without_money = []

stage_breakdown = defaultdict(int)
assignment_breakdown = defaultdict(int)

for opp_doc in opportunities:
    opp = opp_doc.to_dict()
    opp['id'] = opp_doc.id
    
    assigned_ad_id = opp.get('assignedAdId')
    monetary_value = opp.get('monetaryValue', 0)
    stage_category = opp.get('stageCategory', 'Unknown')
    
    # Track stage categories
    stage_breakdown[stage_category] += 1
    
    # Track assignment
    if assigned_ad_id and assigned_ad_id != 'None':
        assigned.append(opp)
        assignment_breakdown['assigned'] += 1
    else:
        unassigned.append(opp)
        assignment_breakdown['unassigned'] += 1
    
    # Track monetary values
    if monetary_value and monetary_value > 0:
        with_money.append(opp)
    else:
        without_money.append(opp)

print("=" * 80)
print("1. ASSIGNMENT STATUS")
print("=" * 80)
print(f"✅ Assigned to ads: {len(assigned)} ({len(assigned)/len(opportunities)*100:.1f}%)")
print(f"❌ Unassigned: {len(unassigned)} ({len(unassigned)/len(opportunities)*100:.1f}%)")
print()

print("=" * 80)
print("2. MONETARY VALUES")
print("=" * 80)
print(f"✅ With monetary value: {len(with_money)} ({len(with_money)/len(opportunities)*100:.1f}%)")
print(f"   Total value: R {sum(o.get('monetaryValue', 0) for o in with_money):,.2f}")
print(f"❌ Without monetary value: {len(without_money)} ({len(without_money)/len(opportunities)*100:.1f}%)")
print()

print("=" * 80)
print("3. STAGE CATEGORY BREAKDOWN")
print("=" * 80)
for stage, count in sorted(stage_breakdown.items(), key=lambda x: x[1], reverse=True):
    percentage = count / len(opportunities) * 100
    print(f"  {stage:30} {count:4} ({percentage:5.1f}%)")
print()

print("=" * 80)
print("4. UNASSIGNED OPPORTUNITIES WITH HIGH VALUE")
print("=" * 80)
unassigned_with_money = [o for o in unassigned if o.get('monetaryValue', 0) > 0]
unassigned_with_money.sort(key=lambda x: x.get('monetaryValue', 0), reverse=True)

if unassigned_with_money:
    print(f"Found {len(unassigned_with_money)} unassigned opportunities with monetary values")
    print(f"Total missing value: R {sum(o.get('monetaryValue', 0) for o in unassigned_with_money):,.2f}")
    print()
    print("Top 10:")
    for i, opp in enumerate(unassigned_with_money[:10], 1):
        print(f"  {i}. {opp.get('name', 'Unknown')}: R {opp.get('monetaryValue', 0):,.2f}")
        print(f"     Stage: {opp.get('currentStage')} ({opp.get('stageCategory')})")
        print(f"     Campaign ID: {opp.get('campaignId', 'None')}")
        print()
else:
    print("✅ No unassigned opportunities with monetary values")
print()

print("=" * 80)
print("5. OPPORTUNITIES BY STAGE CATEGORY (WITH MONETARY VALUES)")
print("=" * 80)
stage_money = defaultdict(lambda: {'count': 0, 'total': 0, 'assigned': 0, 'unassigned': 0})

for opp_doc in opportunities:
    opp = opp_doc.to_dict()
    stage_category = opp.get('stageCategory', 'Unknown')
    monetary_value = opp.get('monetaryValue', 0)
    
    if monetary_value > 0:
        stage_money[stage_category]['count'] += 1
        stage_money[stage_category]['total'] += monetary_value
        
        if opp.get('assignedAdId') and opp.get('assignedAdId') != 'None':
            stage_money[stage_category]['assigned'] += 1
        else:
            stage_money[stage_category]['unassigned'] += 1

for stage, data in sorted(stage_money.items(), key=lambda x: x[1]['total'], reverse=True):
    if data['count'] > 0:
        print(f"\n{stage}:")
        print(f"  Count: {data['count']}")
        print(f"  Total Value: R {data['total']:,.2f}")
        print(f"  Assigned: {data['assigned']} ({data['assigned']/data['count']*100:.1f}%)")
        print(f"  Unassigned: {data['unassigned']} ({data['unassigned']/data['count']*100:.1f}%)")

print()
print("=" * 80)
print("6. CAMPAIGN ATTRIBUTION FOR UNASSIGNED")
print("=" * 80)
unassigned_with_campaign = [o for o in unassigned if o.get('campaignId')]
unassigned_without_campaign = [o for o in unassigned if not o.get('campaignId')]

print(f"Unassigned WITH campaign ID: {len(unassigned_with_campaign)} ({len(unassigned_with_campaign)/len(unassigned)*100:.1f}%)")
print(f"Unassigned WITHOUT campaign ID: {len(unassigned_without_campaign)} ({len(unassigned_without_campaign)/len(unassigned)*100:.1f}%)")
print()

if unassigned_with_campaign:
    print("These opportunities COULD be assigned to campaigns (even without specific ad):")
    print(f"  Total: {len(unassigned_with_campaign)}")
    with_money_and_campaign = [o for o in unassigned_with_campaign if o.get('monetaryValue', 0) > 0]
    if with_money_and_campaign:
        total_value = sum(o.get('monetaryValue', 0) for o in with_money_and_campaign)
        print(f"  With monetary value: {len(with_money_and_campaign)}")
        print(f"  Total value: R {total_value:,.2f}")
        print()
        print("  Top 5:")
        for i, opp in enumerate(sorted(with_money_and_campaign, key=lambda x: x.get('monetaryValue', 0), reverse=True)[:5], 1):
            print(f"    {i}. {opp.get('name')}: R {opp.get('monetaryValue', 0):,.2f}")
            print(f"       Campaign: {opp.get('campaignId')}")
            print(f"       Stage: {opp.get('stageCategory')}")

print()
print("=" * 80)
print("7. SUMMARY & NEXT STEPS")
print("=" * 80)
print()
print("✅ COMPLETED:")
print("  - Re-aggregated GHL stats from ghlOpportunities to ads/campaigns")
print(f"  - {len(assigned)} opportunities properly counted in campaign summaries")
print(f"  - R {sum(o.get('monetaryValue', 0) for o in assigned if o.get('monetaryValue', 0) > 0):,.2f} in revenue properly attributed")
print()
print("⚠️  REMAINING ISSUES:")
print(f"  - {len(unassigned)} opportunities ({len(unassigned)/len(opportunities)*100:.1f}%) are NOT assigned to ads")
if unassigned_with_money:
    print(f"  - R {sum(o.get('monetaryValue', 0) for o in unassigned_with_money):,.2f} in revenue is NOT counted in campaign summaries")
print()
print("💡 RECOMMENDATIONS:")
print("  1. Run update_ghl_with_form_submissions.py to assign more opportunities")
print("  2. For opportunities with campaignId but no adId, assign to campaign-level totals")
print("  3. Consider fetching monetaryValue from GHL API for opportunities without it")
print()
print("=" * 80)

