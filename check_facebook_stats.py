#!/usr/bin/env python3
"""
Quick check to see what Facebook stats look like for matched ads
"""

import firebase_admin
from firebase_admin import credentials, firestore

# Initialize Firebase Admin SDK
cred = credentials.Certificate('medx-ai-firebase-adminsdk-fbsvc-a86e7bd050.json')
firebase_admin.initialize_app(cred)

db = firestore.client()

print("🔍 Checking Facebook Stats for Matched Ads\n")
print("=" * 80)

# Get ads with matching status = 'matched'
docs = db.collection('adPerformance').where('matchingStatus', '==', 'matched').limit(5).stream()

for doc in docs:
    data = doc.to_dict()
    print(f"\n📊 Ad: {data.get('adName', 'Unknown')}")
    print(f"   Campaign: {data.get('campaignName', 'Unknown')}")
    print(f"   Matching Status: {data.get('matchingStatus', 'unknown')}")
    
    # Check Facebook stats
    fb_stats = data.get('facebookStats', {})
    if fb_stats:
        print(f"   ✅ Facebook Stats Present:")
        print(f"      - Spend: ${fb_stats.get('spend', 0)}")
        print(f"      - Impressions: {fb_stats.get('impressions', 0)}")
        print(f"      - Clicks: {fb_stats.get('clicks', 0)}")
        print(f"      - CPM: ${fb_stats.get('cpm', 0)}")
        print(f"      - CPC: ${fb_stats.get('cpc', 0)}")
        print(f"      - CTR: {fb_stats.get('ctr', 0)}%")
    else:
        print(f"   ❌ No Facebook Stats!")
    
    # Check GHL stats
    ghl_stats = data.get('ghlStats', {})
    if ghl_stats:
        print(f"   ✅ GHL Stats Present:")
        print(f"      - Leads: {ghl_stats.get('leads', 0)}")
        print(f"      - Bookings: {ghl_stats.get('bookings', 0)}")
        print(f"      - Deposits: {ghl_stats.get('deposits', 0)}")
        print(f"      - Cash: R{ghl_stats.get('cashAmount', 0)}")
    else:
        print(f"   ❌ No GHL Stats!")
    
    print(f"   Last Updated: {data.get('lastUpdated')}")

print("\n" + "=" * 80)

# Check one of the campaigns shown in the screenshot
print("\n🔍 Checking 'Obesity - Andries - DDM' campaign ads:\n")
docs = db.collection('adPerformance').where('campaignName', '==', 'Matthys - 15102025 - ABOLEADFORMZA (DDM) - Afrikaans').limit(3).stream()

count = 0
for doc in docs:
    count += 1
    data = doc.to_dict()
    print(f"\n📊 Ad #{count}: {data.get('adName', 'Unknown')}")
    
    fb_stats = data.get('facebookStats', {})
    ghl_stats = data.get('ghlStats', {})
    
    print(f"   FB Spend: ${fb_stats.get('spend', 0) if fb_stats else 'NO FB STATS'}")
    print(f"   GHL Leads: {ghl_stats.get('leads', 0) if ghl_stats else 'NO GHL STATS'}")
    print(f"   Matching: {data.get('matchingStatus', 'unknown')}")

if count == 0:
    print("   ❌ No ads found for this campaign name")
    print("\n   Let me search for campaigns with 'Obesity' in the name:")
    docs = db.collection('adPerformance').limit(10).stream()
    for doc in docs:
        data = doc.to_dict()
        campaign = data.get('campaignName', '')
        if 'Obesity' in campaign or 'Andries' in campaign:
            print(f"   Found: {campaign}")
            break

print("\n" + "=" * 80)

