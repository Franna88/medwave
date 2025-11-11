#!/usr/bin/env python3
"""
Check what stage names are actually in ghlOpportunities
"""

import firebase_admin
from firebase_admin import credentials, firestore
from collections import Counter
import os

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
print("CHECKING GHL OPPORTUNITY STAGE NAMES")
print("=" * 80)
print()

# Fetch all ghlOpportunities
ghl_opps_ref = db.collection('ghlOpportunities').stream()

stage_counts = Counter()
stage_category_counts = Counter()

for opp_doc in ghl_opps_ref:
    opp_data = opp_doc.to_dict()
    current_stage = opp_data.get('currentStage', 'UNKNOWN')
    stage_category = opp_data.get('stageCategory', 'UNKNOWN')
    
    stage_counts[current_stage] += 1
    stage_category_counts[stage_category] += 1

print("📊 Current Stage Names (top 20):")
print()
for stage, count in stage_counts.most_common(20):
    print(f"   {count:4d} × '{stage}'")

print()
print("=" * 80)
print("📊 Stage Categories:")
print()
for category, count in stage_category_counts.most_common():
    print(f"   {count:4d} × '{category}'")

print()
print("=" * 80)

