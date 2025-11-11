#!/usr/bin/env python3
"""
Sync all opportunities from GHL to Firebase using the new API token
"""

import requests
import firebase_admin
from firebase_admin import credentials, firestore
import time
from collections import defaultdict

# New GHL API token
GHL_API_KEY = "pit-22f8af95-3244-41e7-9a52-22c87b166f5a"
GHL_BASE_URL = "https://services.leadconnectorhq.com"
LOCATION_ID = "QdLXaFEqrdF0JbVbpKLw"

# Pipeline IDs
PIPELINES = {
    "XeAGJWRnUGJ5tuhXam2g": "Andries Pipeline - DDM",
    "pTbNvnrXqJc9u1oxir3q": "Davide Pipeline",
    "AUduOJBB2lxlsEaNmlJz": "Altus Pipeline"
}

def get_ghl_headers():
    """Get headers for GHL API requests"""
    return {
        "Authorization": f"Bearer {GHL_API_KEY}",
        "Version": "2021-07-28",
        "Content-Type": "application/json"
    }

def fetch_opportunities(pipeline_id, pipeline_name):
    """Fetch all opportunities from a pipeline"""
    print(f"\n🔄 Fetching from {pipeline_name}...")
    
    all_opportunities = []
    next_cursor = None
    page = 1
    
    while True:
        params = {
            "location_id": LOCATION_ID,
            "pipeline_id": pipeline_id,
            "limit": 100
        }
        
        if next_cursor:
            params['startAfterId'] = next_cursor
        
        try:
            response = requests.get(
                f"{GHL_BASE_URL}/opportunities/search",
                headers=get_ghl_headers(),
                params=params,
                timeout=30
            )
            response.raise_for_status()
            data = response.json()
            
            opportunities = data.get('opportunities', [])
            all_opportunities.extend(opportunities)
            
            print(f"   Page {page}: {len(opportunities)} opportunities")
            
            meta = data.get('meta', {})
            next_cursor = meta.get('nextStartAfterId') or meta.get('nextStartAfter')
            
            if not next_cursor or len(opportunities) < 100:
                break
                
            page += 1
            time.sleep(0.3)
            
        except Exception as e:
            print(f"   ❌ Error: {e}")
            break
    
    print(f"   ✅ Total: {len(all_opportunities)} opportunities")
    return all_opportunities

def update_firebase(all_opportunities):
    """Update Firebase with opportunity values"""
    print("\n" + "=" * 100)
    print("📝 UPDATING FIREBASE")
    print("=" * 100)
    
    # Initialize Firebase
    try:
        cred = credentials.Certificate('medx-ai-firebase-adminsdk-fbsvc-a86e7bd050.json')
        firebase_admin.initialize_app(cred)
    except:
        pass
    
    db = firestore.client()
    
    # Build lookup of GHL opportunities
    ghl_lookup = {}
    for opp in all_opportunities:
        opp_id = opp.get('id')
        if opp_id:
            ghl_lookup[opp_id] = {
                'name': opp.get('name', 'Unknown'),
                'stage': opp.get('pipelineStage', {}).get('name', 'Unknown'),
                'value': float(opp.get('monetaryValue', 0)),
                'pipeline': opp.get('pipeline', {}).get('name', 'Unknown')
            }
    
    print(f"\n✅ Loaded {len(ghl_lookup)} opportunities from GHL")
    
    # Show value distribution
    high_value = [o for o in ghl_lookup.values() if o['value'] > 100000]
    medium_value = [o for o in ghl_lookup.values() if 10000 < o['value'] <= 100000]
    low_value = [o for o in ghl_lookup.values() if 1000 < o['value'] <= 10000]
    
    print(f"\n   > R100,000: {len(high_value)} opportunities")
    print(f"   R10,000 - R100,000: {len(medium_value)} opportunities")
    print(f"   R1,000 - R10,000: {len(low_value)} opportunities")
    
    # Show top opportunities
    sorted_opps = sorted(ghl_lookup.values(), key=lambda x: x['value'], reverse=True)
    print(f"\n📊 TOP 15 OPPORTUNITIES BY VALUE:")
    print()
    for i, opp in enumerate(sorted_opps[:15], 1):
        print(f"   {i:2d}. R {opp['value']:>12,.2f} - {opp['name']}")
        print(f"       Stage: {opp['stage']} | Pipeline: {opp['pipeline']}")
    
    total_value = sum(o['value'] for o in ghl_lookup.values())
    print(f"\n   💰 TOTAL VALUE: R {total_value:,.2f}")
    
    # Update Firebase records
    print("\n" + "=" * 100)
    print("🔄 MATCHING AND UPDATING FIREBASE RECORDS")
    print("=" * 100)
    print()
    
    updated_count = 0
    already_correct = 0
    significant_updates = []
    
    for doc in db.collection('opportunityStageHistory').stream():
        data = doc.to_dict()
        opp_id = data.get('opportunityId')
        
        if not opp_id or opp_id not in ghl_lookup:
            continue
        
        ghl_opp = ghl_lookup[opp_id]
        current_value = data.get('monetaryValue', 0)
        new_value = ghl_opp['value']
        
        if current_value == new_value:
            already_correct += 1
            continue
        
        # Track significant updates
        if new_value > 10000 or current_value > 10000:
            significant_updates.append({
                'name': ghl_opp['name'],
                'stage': data.get('newStageName', 'Unknown'),
                'old': current_value,
                'new': new_value
            })
        
        # Update Firebase
        try:
            doc.reference.update({
                'monetaryValue': new_value,
                'lastUpdated': firestore.SERVER_TIMESTAMP
            })
            updated_count += 1
        except Exception as e:
            print(f"❌ Error updating {doc.id}: {e}")
    
    # Show significant updates
    if significant_updates:
        print(f"✅ SIGNIFICANT UPDATES (> R10,000):")
        print()
        for upd in significant_updates[:20]:
            print(f"   {upd['name']} ({upd['stage']})")
            print(f"      R {upd['old']:,.2f} → R {upd['new']:,.2f}")
            print()
    
    print("=" * 100)
    print("📊 UPDATE SUMMARY")
    print("=" * 100)
    print(f"   Already correct: {already_correct}")
    print(f"   Updated: {updated_count}")
    print(f"   Significant updates: {len(significant_updates)}")
    print()
    
    return updated_count

def trigger_aggregation():
    """Trigger the backend to aggregate GHL data to Facebook ads"""
    print("=" * 100)
    print("🔄 TRIGGERING AGGREGATION")
    print("=" * 100)
    print()
    
    url = "https://us-central1-medx-ai.cloudfunctions.net/api/facebook/match-ghl"
    
    try:
        response = requests.post(url, json={}, timeout=300)
        if response.status_code == 200:
            result = response.json()
            print("✅ Aggregation complete!")
            print(f"   Matched: {result.get('stats', {}).get('matched', 0)}")
            print(f"   Unmatched: {result.get('stats', {}).get('unmatched', 0)}")
            return True
        else:
            print(f"❌ Error: {response.status_code}")
            return False
    except Exception as e:
        print(f"❌ Error: {e}")
        return False

def check_final_results():
    """Check the final results in adPerformance"""
    print("\n" + "=" * 100)
    print("📊 FINAL RESULTS IN AD PERFORMANCE")
    print("=" * 100)
    print()
    
    try:
        cred = credentials.Certificate('medx-ai-firebase-adminsdk-fbsvc-a86e7bd050.json')
        firebase_admin.initialize_app(cred)
    except:
        pass
    
    db = firestore.client()
    
    ads_with_cash = []
    for doc in db.collection('adPerformance').stream():
        ad_data = doc.to_dict()
        ghl_stats = ad_data.get('ghlStats', {})
        fb_stats = ad_data.get('facebookStats', {})
        
        cash_amount = ghl_stats.get('cashAmount', 0) if ghl_stats else 0
        if cash_amount > 0:
            ads_with_cash.append({
                'ad_name': ad_data.get('adName', ''),
                'campaign': ad_data.get('campaignName', ''),
                'cash_amount': cash_amount,
                'fb_spend': fb_stats.get('spend', 0) if fb_stats else 0,
            })
    
    ads_with_cash.sort(key=lambda x: x['cash_amount'], reverse=True)
    
    print(f"Found {len(ads_with_cash)} ads with cashAmount > 0")
    print()
    
    total_revenue = 0
    total_spend = 0
    
    for ad in ads_with_cash[:15]:
        print(f"R {ad['cash_amount']:>12,.2f} - {ad['ad_name'][:60]}")
        print(f"   Campaign: {ad['campaign'][:70]}")
        print(f"   FB Spend: ${ad['fb_spend']:,.2f} | Profit: R {ad['cash_amount'] - ad['fb_spend']:,.2f}")
        print()
        total_revenue += ad['cash_amount']
        total_spend += ad['fb_spend']
    
    if len(ads_with_cash) > 15:
        for ad in ads_with_cash[15:]:
            total_revenue += ad['cash_amount']
            total_spend += ad['fb_spend']
    
    print("=" * 100)
    print(f"💰 GRAND TOTALS ({len(ads_with_cash)} ads):")
    print(f"   Total Revenue: R {total_revenue:,.2f}")
    print(f"   Total FB Spend: ${total_spend:,.2f}")
    print(f"   💰 TOTAL PROFIT: R {total_revenue - total_spend:,.2f}")

def main():
    print("\n" + "╔" + "═" * 98 + "╗")
    print("║" + " " * 25 + "SYNC ALL OPPORTUNITIES WITH NEW TOKEN" + " " * 36 + "║")
    print("╚" + "═" * 98 + "╝")
    
    # Step 1: Fetch all opportunities from GHL
    print("\n" + "=" * 100)
    print("📋 STEP 1: FETCH FROM GHL")
    print("=" * 100)
    
    all_opportunities = []
    for pipeline_id, pipeline_name in PIPELINES.items():
        opps = fetch_opportunities(pipeline_id, pipeline_name)
        all_opportunities.extend(opps)
    
    print(f"\n✅ Total opportunities fetched: {len(all_opportunities)}")
    
    if not all_opportunities:
        print("\n❌ No opportunities fetched. Check API token and permissions.")
        return
    
    # Step 2: Update Firebase
    updated_count = update_firebase(all_opportunities)
    
    if updated_count > 0:
        print("\n⏳ Waiting 3 seconds for Firebase to sync...")
        time.sleep(3)
        
        # Step 3: Trigger aggregation
        trigger_aggregation()
        
        print("\n⏳ Waiting 2 seconds for aggregation...")
        time.sleep(2)
        
        # Step 4: Check results
        check_final_results()
    
    print("\n" + "=" * 100)
    print("✅ COMPLETE!")
    print("=" * 100)
    print()
    print("NEXT STEPS:")
    print("1. Do a HOT RESTART in Flutter (not hot reload)")
    print("2. Navigate to Advertisement Performance > Overview")
    print("3. You should see updated profit values with real opportunity amounts")
    print()

if __name__ == "__main__":
    main()

