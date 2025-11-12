#!/usr/bin/env python3
"""
Check monetary values in ghlOpportunities to see if they're populated
"""

import firebase_admin
from firebase_admin import credentials, firestore
from collections import Counter

# Initialize Firebase
cred = credentials.Certificate('/Users/mac/dev/medwave/medx-ai-firebase-adminsdk-fbsvc-a86e7bd050.json')
try:
    firebase_admin.get_app()
except ValueError:
    firebase_admin.initialize_app(cred)

db = firestore.client()

print("=" * 80)
print("CHECKING MONETARY VALUES IN ghlOpportunities")
print("=" * 80)
print()

ghl_opps_ref = db.collection('ghlOpportunities').stream()

total_opps = 0
opps_with_monetary_value = 0
opps_without_monetary_value = 0
stage_category_counts = Counter()
monetary_value_by_stage = {}

for opp_doc in ghl_opps_ref:
    opp_data = opp_doc.to_dict()
    total_opps += 1
    
    monetary_value = opp_data.get('monetaryValue', 0)
    stage_category = opp_data.get('stageCategory', 'unknown')
    
    stage_category_counts[stage_category] += 1
    
    if stage_category not in monetary_value_by_stage:
        monetary_value_by_stage[stage_category] = {'with_value': 0, 'without_value': 0, 'total_value': 0}
    
    if monetary_value and monetary_value > 0:
        opps_with_monetary_value += 1
        monetary_value_by_stage[stage_category]['with_value'] += 1
        monetary_value_by_stage[stage_category]['total_value'] += monetary_value
    else:
        opps_without_monetary_value += 1
        monetary_value_by_stage[stage_category]['without_value'] += 1

print(f"Total opportunities: {total_opps}")
print(f"Opportunities with monetary value > 0: {opps_with_monetary_value}")
print(f"Opportunities without monetary value: {opps_without_monetary_value}")
print()

print("=" * 80)
print("BREAKDOWN BY STAGE CATEGORY:")
print("=" * 80)
print()

for stage, counts in sorted(stage_category_counts.items()):
    mv_data = monetary_value_by_stage.get(stage, {})
    with_value = mv_data.get('with_value', 0)
    without_value = mv_data.get('without_value', 0)
    total_value = mv_data.get('total_value', 0)
    
    print(f"{stage.upper()}:")
    print(f"  Total opportunities: {counts}")
    print(f"  With monetary value: {with_value}")
    print(f"  Without monetary value: {without_value}")
    print(f"  Total monetary value: R{total_value:,.2f}")
    print()

print("=" * 80)
print()

# Sample a few opportunities with deposits to see their monetary values
print("📋 SAMPLE: Opportunities with 'deposit' or 'cash_collected' stage:")
print()

ghl_opps_ref = db.collection('ghlOpportunities').where('stageCategory', 'in', ['deposit', 'cash_collected']).limit(10).stream()

for i, opp_doc in enumerate(ghl_opps_ref, 1):
    opp_data = opp_doc.to_dict()
    print(f"{i}. Opportunity: {opp_doc.id}")
    print(f"   Name: {opp_data.get('opportunityName', 'Unknown')}")
    print(f"   Stage Category: {opp_data.get('stageCategory', 'unknown')}")
    print(f"   Stage Name: {opp_data.get('stageName', 'unknown')}")
    print(f"   Monetary Value: R{opp_data.get('monetaryValue', 0)}")
    print()

print("=" * 80)

