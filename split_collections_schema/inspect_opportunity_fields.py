#!/usr/bin/env python3
"""
Inspect actual opportunity documents to see what fields are available
"""

import firebase_admin
from firebase_admin import credentials, firestore
import os
import json

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
print("INSPECTING OPPORTUNITY FIELDS")
print("=" * 80)
print()

# Fetch 5 opportunities with different characteristics
ghl_opps_ref = db.collection('ghlOpportunities').limit(10).stream()

for i, opp_doc in enumerate(ghl_opps_ref, 1):
    opp_data = opp_doc.to_dict()
    
    print(f"📋 Opportunity {i}: {opp_data.get('opportunityName', 'Unknown')}")
    print(f"   ID: {opp_doc.id}")
    print(f"   Current Stage: {opp_data.get('currentStage', 'N/A')}")
    print(f"   Stage Category: {opp_data.get('stageCategory', 'N/A')}")
    print(f"   Monetary Value: ${opp_data.get('monetaryValue', 0)}")
    print(f"   Pipeline: {opp_data.get('pipelineName', 'N/A')}")
    print(f"   Contact: {opp_data.get('contactName', 'N/A')}")
    print(f"   Ad ID: {opp_data.get('assignedAdId', 'N/A')}")
    print()
    print(f"   All Fields:")
    for key in sorted(opp_data.keys()):
        value = opp_data[key]
        if isinstance(value, str) and len(value) > 100:
            value = value[:100] + "..."
        print(f"      {key}: {value}")
    print()
    print("-" * 80)
    print()

print("=" * 80)

