#!/usr/bin/env python3
"""
Trigger the backend to sync all opportunities from GHL to Firebase,
then update adPerformance with the aggregated values
"""

import requests
import firebase_admin
from firebase_admin import credentials, firestore
import time

def trigger_backend_sync():
    """Trigger the backend API to sync opportunities"""
    print("=" * 100)
    print("🔄 TRIGGERING BACKEND OPPORTUNITY SYNC")
    print("=" * 100)
    print()
    
    # The backend API endpoint that syncs opportunities
    url = "https://us-central1-medx-ai.cloudfunctions.net/api/opportunities/sync"
    
    print("Calling backend API to sync all opportunities from GHL...")
    print("This will fetch all opportunities and update Firebase with current values...")
    print()
    
    try:
        response = requests.post(url, json={}, timeout=300)
        print(f"Status Code: {response.status_code}")
        print()
        
        if response.status_code == 200:
            result = response.json()
            print("✅ SYNC SUCCESS!")
            print(f"   Synced: {result.get('stats', {}).get('synced', 0)}")
            print(f"   Skipped: {result.get('stats', {}).get('skipped', 0)}")
            print(f"   Errors: {result.get('stats', {}).get('errors', 0)}")
            return True
        else:
            print(f"❌ ERROR: {response.status_code}")
            print(response.text[:500])
            return False
    except Exception as e:
        print(f"❌ EXCEPTION: {e}")
        return False

def trigger_ghl_matching():
    """Trigger the backend to match GHL data to Facebook ads"""
    print()
    print("=" * 100)
    print("🔄 TRIGGERING GHL TO FACEBOOK MATCHING")
    print("=" * 100)
    print()
    
    url = "https://us-central1-medx-ai.cloudfunctions.net/api/facebook/match-ghl"
    
    print("Aggregating GHL data into adPerformance collection...")
    print()
    
    try:
        response = requests.post(url, json={}, timeout=300)
        print(f"Status Code: {response.status_code}")
        print()
        
        if response.status_code == 200:
            result = response.json()
            print("✅ MATCHING SUCCESS!")
            print(f"   Matched: {result.get('stats', {}).get('matched', 0)}")
            print(f"   Unmatched: {result.get('stats', {}).get('unmatched', 0)}")
            print(f"   Errors: {result.get('stats', {}).get('errors', 0)}")
            return True
        else:
            print(f"❌ ERROR: {response.status_code}")
            print(response.text[:500])
            return False
    except Exception as e:
        print(f"❌ EXCEPTION: {e}")
        return False

def check_results():
    """Check the results in Firebase"""
    print()
    print("=" * 100)
    print("📊 CHECKING RESULTS IN FIREBASE")
    print("=" * 100)
    print()
    
    try:
        cred = credentials.Certificate('medx-ai-firebase-adminsdk-fbsvc-a86e7bd050.json')
        firebase_admin.initialize_app(cred)
    except:
        pass
    
    db = firestore.client()
    
    # Check opportunities with high values
    print("🔍 Checking opportunityStageHistory for high-value opportunities...")
    print()
    
    high_value_opps = []
    for doc in db.collection('opportunityStageHistory').stream():
        data = doc.to_dict()
        value = data.get('monetaryValue', 0)
        if value > 10000:  # Over R10k
            high_value_opps.append({
                'name': data.get('opportunityName', 'Unknown'),
                'stage': data.get('newStageName', 'Unknown'),
                'value': value,
                'campaign': data.get('campaignName', '')
            })
    
    if high_value_opps:
        high_value_opps.sort(key=lambda x: x['value'], reverse=True)
        print(f"Found {len(high_value_opps)} opportunities with value > R10,000:")
        print()
        for opp in high_value_opps[:15]:
            print(f"   R {opp['value']:>12,.2f} - {opp['name']}")
            print(f"      Stage: {opp['stage']}")
            if opp['campaign']:
                print(f"      Campaign: {opp['campaign'][:70]}")
            print()
    else:
        print("   No opportunities found with value > R10,000")
        print()
    
    # Check adPerformance
    print("🔍 Checking adPerformance for cashAmount...")
    print()
    
    ads_with_cash = []
    total_revenue = 0
    total_spend = 0
    
    for doc in db.collection('adPerformance').stream():
        ad_data = doc.to_dict()
        ghl_stats = ad_data.get('ghlStats', {})
        fb_stats = ad_data.get('facebookStats', {})
        
        cash_amount = ghl_stats.get('cashAmount', 0) if ghl_stats else 0
        fb_spend = fb_stats.get('spend', 0) if fb_stats else 0
        
        if cash_amount > 0:
            ads_with_cash.append({
                'ad_name': ad_data.get('adName', ''),
                'campaign': ad_data.get('campaignName', ''),
                'cash_amount': cash_amount,
                'fb_spend': fb_spend,
                'profit': cash_amount - fb_spend
            })
            total_revenue += cash_amount
            total_spend += fb_spend
    
    if ads_with_cash:
        ads_with_cash.sort(key=lambda x: x['cash_amount'], reverse=True)
        print(f"Found {len(ads_with_cash)} ads with cashAmount > 0:")
        print()
        for ad in ads_with_cash[:10]:
            print(f"   R {ad['cash_amount']:>12,.2f} - {ad['ad_name'][:60]}")
            print(f"      Campaign: {ad['campaign'][:70]}")
            print(f"      FB Spend: ${ad['fb_spend']:,.2f} | Profit: R {ad['profit']:,.2f}")
            print()
        
        print("=" * 100)
        print(f"📈 TOTALS:")
        print(f"   Total Revenue: R {total_revenue:,.2f}")
        print(f"   Total FB Spend: ${total_spend:,.2f}")
        print(f"   💰 TOTAL PROFIT: R {total_revenue - total_spend:,.2f}")
    else:
        print("   No ads found with cashAmount > 0")
    
    print()
    print("=" * 100)
    print("✅ COMPLETE!")
    print("=" * 100)
    print()
    print("NEXT STEPS:")
    print("1. Do a HOT RESTART in Flutter (not hot reload)")
    print("2. Navigate to Advertisement Performance > Overview")
    print("3. You should see the updated profit values")
    print()

def main():
    print()
    print("╔" + "═" * 98 + "╗")
    print("║" + " " * 30 + "SYNC ALL OPPORTUNITIES FROM GHL" + " " * 37 + "║")
    print("╚" + "═" * 98 + "╝")
    print()
    
    # Step 1: Sync opportunities from GHL
    if not trigger_backend_sync():
        print("\n❌ Failed to sync opportunities. Aborting.")
        return
    
    print("\n⏳ Waiting 3 seconds for sync to complete...")
    time.sleep(3)
    
    # Step 2: Match GHL data to Facebook ads
    if not trigger_ghl_matching():
        print("\n❌ Failed to match GHL data. Aborting.")
        return
    
    print("\n⏳ Waiting 2 seconds for matching to complete...")
    time.sleep(2)
    
    # Step 3: Check results
    check_results()

if __name__ == "__main__":
    main()

