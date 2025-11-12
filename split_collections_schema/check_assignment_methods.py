#!/usr/bin/env python3
"""
Check what assignment methods are currently in ghlOpportunities
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
print("CHECKING ASSIGNMENT METHODS IN ghlOpportunities")
print("=" * 80)
print()

ghl_opps_ref = db.collection('ghlOpportunities').stream()

assignment_methods = Counter()
total_opps = 0
opps_with_ad_id = 0
opps_without_ad_id = 0

for opp_doc in ghl_opps_ref:
    opp_data = opp_doc.to_dict()
    total_opps += 1
    
    assigned_ad_id = opp_data.get('assignedAdId')
    assignment_method = opp_data.get('assignmentMethod', 'unknown')
    
    if assigned_ad_id:
        opps_with_ad_id += 1
        assignment_methods[assignment_method] += 1
    else:
        opps_without_ad_id += 1

print(f"Total opportunities: {total_opps}")
print(f"Opportunities with Ad ID: {opps_with_ad_id}")
print(f"Opportunities without Ad ID: {opps_without_ad_id}")
print()
print("Assignment Methods Breakdown:")
print()

for method, count in assignment_methods.most_common():
    percentage = (count / opps_with_ad_id * 100) if opps_with_ad_id > 0 else 0
    print(f"  {method}: {count} ({percentage:.1f}%)")

print()
print("=" * 80)
print()

# Show which methods we should KEEP vs REMOVE
print("✅ VALID METHODS (exact Ad ID match):")
print("  - form_submission_ad_id")
print()
print("❌ INVALID METHODS (should be removed - not exact Ad ID match):")
print("  - contact_adset_id")
print("  - contact_campaign_id")
print("  - attribution_adset_id")
print("  - attribution_campaign_id")
print("  - unknown")
print()
print("=" * 80)

