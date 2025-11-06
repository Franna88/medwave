#!/usr/bin/env python3
"""
Quick Update - Fix Aayesha and Jenny's Opportunity Values
"""

import requests
import firebase_admin
from firebase_admin import credentials, firestore
from datetime import datetime
import os

# Initialize Firebase
try:
    cred = credentials.Certificate('medx-ai-firebase-adminsdk-fbsvc-a86e7bd050.json')
    firebase_admin.initialize_app(cred)
except:
    pass

db = firestore.client()

# GHL API Configuration
GHL_API_KEY = os.getenv('GHL_API_KEY', 'pit-e305020a-9a42-4290-a052-daf828c3978e')
GHL_LOCATION_ID = "QdLXaFEqrdF0JbVbpKLw"
DAVIDE_PIPELINE_ID = "AUduOJBB2lxlsEaNmlJz"

def get_ghl_headers():
    return {
        "Authorization": f"Bearer {GHL_API_KEY}",
        "Version": "2021-07-28",
        "Content-Type": "application/json"
    }

print("=" * 100)
print("🚀 QUICK UPDATE - AAYESHA AND JENNY OPPORTUNITY VALUES")
print("=" * 100)
print()

# Fetch opportunities from GHL
print("📊 Fetching opportunities from GHL...")
url = f"https://services.leadconnectorhq.com/opportunities/search"
params = {
    "location_id": GHL_LOCATION_ID,
    "pipeline_id": DAVIDE_PIPELINE_ID,
    "limit": 100
}

response = requests.get(url, headers=get_ghl_headers(), params=params, timeout=30)
response.raise_for_status()
opportunities = response.json().get('opportunities', [])

print(f"✅ Fetched {len(opportunities)} opportunities")
print()

# Find Aayesha and Jenny
aayesha = None
jenny = None

for opp in opportunities:
    name = opp.get('name', '')
    if 'Aayesha' in name or 'Kholvadia' in name:
        aayesha = opp
    if 'Jenny' in name and 'Alves' in name:
        jenny = opp

# Process Aayesha
print("1️⃣  AAYESHA KHOLVADIA")
print("-" * 100)
if aayesha:
    opp_id = aayesha['id']
    monetary_value = float(aayesha.get('monetaryValue', 0))
    
    print(f"   GHL Value: R {monetary_value:,.2f}")
    print(f"   Opportunity ID: {opp_id}")
    print()
    
    # Find in Firebase
    firebase_docs = list(db.collection('opportunityStageHistory')
                        .where('opportunityId', '==', opp_id)
                        .stream())
    
    print(f"   Found {len(firebase_docs)} records in Firebase")
    
    updated = 0
    for doc in firebase_docs:
        current_value = doc.to_dict().get('monetaryValue', 0)
        print(f"   - Record {doc.id[:20]}...")
        print(f"     Current: R {current_value:,.2f} → New: R {monetary_value:,.2f}")
        
        # UPDATE
        doc.reference.update({
            'monetaryValue': monetary_value,
            'lastUpdated': firestore.SERVER_TIMESTAMP
        })
        updated += 1
    
    print(f"   ✅ Updated {updated} records")
else:
    print("   ❌ Not found in GHL")

print()

# Process Jenny
print("2️⃣  JENNY ALVES")
print("-" * 100)
if jenny:
    opp_id = jenny['id']
    monetary_value = float(jenny.get('monetaryValue', 0))
    
    print(f"   GHL Value: R {monetary_value:,.2f}")
    print(f"   Opportunity ID: {opp_id}")
    print()
    
    # Find in Firebase
    firebase_docs = list(db.collection('opportunityStageHistory')
                        .where('opportunityId', '==', opp_id)
                        .stream())
    
    print(f"   Found {len(firebase_docs)} records in Firebase")
    
    updated = 0
    for doc in firebase_docs:
        current_value = doc.to_dict().get('monetaryValue', 0)
        print(f"   - Record {doc.id[:20]}...")
        print(f"     Current: R {current_value:,.2f} → New: R {monetary_value:,.2f}")
        
        # UPDATE
        doc.reference.update({
            'monetaryValue': monetary_value,
            'lastUpdated': firestore.SERVER_TIMESTAMP
        })
        updated += 1
    
    print(f"   ✅ Updated {updated} records")
else:
    print("   ❌ Not found in GHL")

print()
print("=" * 100)
print("✅ UPDATE COMPLETE")
print("=" * 100)
print()
print("Next: The scheduled sync (runs every 2 minutes) will pick up these changes")
print("and aggregate them into the adPerformance collection.")
print()
print("However, note:")
print("  - Aayesha: No campaign tracking → Won't appear in ad performance")
print("  - Jenny: Campaign mismatch → Won't match to current Facebook ads")
print()
print("To see these in ad performance, you would need to:")
print("  1. For Aayesha: Add campaign tracking (not possible retroactively)")
print("  2. For Jenny: Fix campaign name matching or manually attribute to an ad")

