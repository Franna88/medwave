#!/usr/bin/env python3
"""
Check high-value opportunities and their attribution
"""

import firebase_admin
from firebase_admin import credentials, firestore

# Initialize Firebase
try:
    cred = credentials.Certificate('medx-ai-firebase-adminsdk-fbsvc-a86e7bd050.json')
    firebase_admin.initialize_app(cred)
except ValueError:
    pass

db = firestore.client()

print("=" * 100)
print("🔍 CHECKING HIGH-VALUE OPPORTUNITIES")
print("=" * 100)
print()

# Check the high-value opportunities we saw earlier
high_value_names = [
    "Aayesha Kholvadia",
    "Terri Pickels",
    "Jenny Alves",
    "NADIA HARRIS",
    "Sashnie Naicker"
]

for name in high_value_names:
    print(f"\n{'='*80}")
    print(f"Opportunity: {name}")
    print(f"{'='*80}")
    
    # Get all records for this opportunity
    opp_query = db.collection('opportunityStageHistory')\
        .where('opportunityName', '==', name)\
        .limit(5)\
        .stream()
    
    found = False
    for opp_doc in opp_query:
        found = True
        opp_data = opp_doc.to_dict()
        
        print(f"\nStage: {opp_data.get('newStageName')} ({opp_data.get('stageCategory')})")
        print(f"Monetary Value: R {opp_data.get('monetaryValue', 0):,.2f}")
        print(f"Campaign: '{opp_data.get('campaignName', '')}'")
        print(f"Ad Name: '{opp_data.get('adName', '')}'")
        print(f"Ad Set: '{opp_data.get('adSetName', '')}'")
        print(f"Source: '{opp_data.get('campaignSource', '')}'")
    
    if not found:
        print("⚠️  No records found in Firebase")

print("\n" + "=" * 100)


