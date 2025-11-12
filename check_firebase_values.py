#!/usr/bin/env python3
"""
Check Firebase to see what values are actually stored
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
print("🔍 CHECKING FIREBASE VALUES")
print("=" * 100)
print()

# Check opportunityStageHistory for deposits/cash collected
print("1. Checking opportunityStageHistory for deposits with monetary values...")
print()

opp_query = db.collection('opportunityStageHistory')\
    .where('stageCategory', 'in', ['deposits', 'cashCollected'])\
    .limit(10)\
    .stream()

for opp_doc in opp_query:
    opp_data = opp_doc.to_dict()
    print(f"Opportunity: {opp_data.get('opportunityName')}")
    print(f"  Stage: {opp_data.get('newStageName')} ({opp_data.get('stageCategory')})")
    print(f"  Monetary Value: R {opp_data.get('monetaryValue', 0):,.2f}")
    print(f"  Campaign: {opp_data.get('campaignName', 'N/A')}")
    print(f"  Ad Name: {opp_data.get('adName', 'N/A')}")
    print()

print("\n" + "=" * 100)
print("2. Checking adPerformance collection for GHL stats...")
print("=" * 100)
print()

# Check a few ads with GHL data
ads_query = db.collection('adPerformance')\
    .where('matchingStatus', '==', 'matched')\
    .limit(5)\
    .stream()

for ad_doc in ads_query:
    ad_data = ad_doc.to_dict()
    ghl_stats = ad_data.get('ghlStats', {})
    fb_stats = ad_data.get('facebookStats', {})
    
    if ghl_stats.get('deposits', 0) > 0 or ghl_stats.get('cashCollected', 0) > 0:
        print(f"Ad: {ad_data.get('adName')}")
        print(f"  Campaign: {ad_data.get('campaignName')}")
        print(f"  FB Spend: R {fb_stats.get('spend', 0):,.2f}")
        print(f"  GHL Stats:")
        print(f"    - Leads: {ghl_stats.get('leads', 0)}")
        print(f"    - Bookings: {ghl_stats.get('bookings', 0)}")
        print(f"    - Deposits: {ghl_stats.get('deposits', 0)}")
        print(f"    - Cash Collected: {ghl_stats.get('cashCollected', 0)}")
        print(f"    - Cash Amount: R {ghl_stats.get('cashAmount', 0):,.2f}")
        print(f"  Calculated Profit: R {ghl_stats.get('cashAmount', 0) - fb_stats.get('spend', 0):,.2f}")
        print()

print("\n" + "=" * 100)
print("3. Checking specific campaign: 'Matthys - 13102025 - ABOLEADFORMZA (DDM) - Medical Doctor'")
print("=" * 100)
print()

# Check the specific campaign shown in screenshot
campaign_name = "Matthys - 13102025 - ABOLEADFORMZA (DDM) - Medical Doctor"
ads_query = db.collection('adPerformance')\
    .where('campaignName', '==', campaign_name)\
    .stream()

total_spend = 0
total_cash = 0
ad_count = 0

for ad_doc in ads_query:
    ad_data = ad_doc.to_dict()
    ghl_stats = ad_data.get('ghlStats', {})
    fb_stats = ad_data.get('facebookStats', {})
    
    ad_count += 1
    total_spend += fb_stats.get('spend', 0)
    total_cash += ghl_stats.get('cashAmount', 0)
    
    if ghl_stats.get('deposits', 0) > 0 or ghl_stats.get('cashCollected', 0) > 0:
        print(f"Ad #{ad_count}: {ad_data.get('adName')[:50]}...")
        print(f"  Deposits: {ghl_stats.get('deposits', 0)}, Cash Collected: {ghl_stats.get('cashCollected', 0)}")
        print(f"  Cash Amount in Firebase: R {ghl_stats.get('cashAmount', 0):,.2f}")
        print()

print(f"\nCampaign Totals:")
print(f"  Total Ads: {ad_count}")
print(f"  Total FB Spend: R {total_spend:,.2f}")
print(f"  Total Cash Amount: R {total_cash:,.2f}")
print(f"  Total Profit: R {total_cash - total_spend:,.2f}")
print()





