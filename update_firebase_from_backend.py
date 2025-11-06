#!/usr/bin/env python3
"""
Update Firebase opportunityStageHistory records with current values from GHL
by using the backend API endpoints
"""

import requests
import firebase_admin
from firebase_admin import credentials, firestore
import time
from collections import defaultdict

BACKEND_API = "https://us-central1-medx-ai.cloudfunctions.net/api"

def fetch_opportunities_from_backend(pipeline_id):
    """Fetch opportunities from GHL via backend API"""
    print(f"   Fetching opportunities from pipeline {pipeline_id}...")
    
    all_opportunities = []
    next_cursor = None
    page = 1
    
    while True:
        params = {
            "pipelineId": pipeline_id,
            "limit": 100
        }
        
        if next_cursor:
            params['startAfterId'] = next_cursor
        
        try:
            response = requests.get(
                f"{BACKEND_API}/ghl/opportunities/search",
                params=params,
                timeout=30
            )
            response.raise_for_status()
            data = response.json()
            
            opportunities = data.get('opportunities', [])
            all_opportunities.extend(opportunities)
            
            print(f"      Page {page}: {len(opportunities)} opportunities")
            
            meta = data.get('meta', {})
            next_cursor = meta.get('nextStartAfterId') or meta.get('nextStartAfter')
            
            if not next_cursor or len(opportunities) < 100:
                break
                
            page += 1
            time.sleep(0.3)  # Rate limiting
            
        except Exception as e:
            print(f"      ❌ Error: {e}")
            break
    
    print(f"      ✅ Total: {len(all_opportunities)} opportunities")
    return all_opportunities

def main():
    print("=" * 100)
    print("💰 UPDATE FIREBASE WITH CURRENT GHL VALUES")
    print("=" * 100)
    print()
    
    # Initialize Firebase
    try:
        cred = credentials.Certificate('medx-ai-firebase-adminsdk-fbsvc-a86e7bd050.json')
        firebase_admin.initialize_app(cred)
    except:
        pass
    
    db = firestore.client()
    
    # Pipeline IDs
    pipelines = {
        "XeAGJWRnUGJ5tuhXam2g": "Andries Pipeline",
        "pTbNvnrXqJc9u1oxir3q": "Davide Pipeline",
        "AUduOJBB2lxlsEaNmlJz": "Altus Pipeline"
    }
    
    # Fetch all opportunities from GHL via backend
    print("📋 STEP 1: FETCH OPPORTUNITIES FROM GHL")
    print("=" * 100)
    print()
    
    all_ghl_opportunities = {}
    
    for pipeline_id, pipeline_name in pipelines.items():
        print(f"🔄 {pipeline_name}...")
        opportunities = fetch_opportunities_from_backend(pipeline_id)
        
        for opp in opportunities:
            opp_id = opp.get('id')
            if opp_id:
                all_ghl_opportunities[opp_id] = {
                    'id': opp_id,
                    'name': opp.get('name', 'Unknown'),
                    'stage': opp.get('pipelineStage', {}).get('name', 'Unknown'),
                    'value': float(opp.get('monetaryValue', 0)),
                    'pipeline': pipeline_name
                }
        print()
    
    print(f"✅ Total opportunities fetched from GHL: {len(all_ghl_opportunities)}")
    print()
    
    # Count by value ranges
    high_value = [o for o in all_ghl_opportunities.values() if o['value'] > 100000]
    medium_value = [o for o in all_ghl_opportunities.values() if 10000 < o['value'] <= 100000]
    low_value = [o for o in all_ghl_opportunities.values() if 1000 < o['value'] <= 10000]
    zero_value = [o for o in all_ghl_opportunities.values() if o['value'] == 0]
    
    print(f"   > R100,000: {len(high_value)} opportunities")
    print(f"   R10,000 - R100,000: {len(medium_value)} opportunities")
    print(f"   R1,000 - R10,000: {len(low_value)} opportunities")
    print(f"   R0: {len(zero_value)} opportunities")
    print()
    
    # Show top 10 by value
    sorted_opps = sorted(all_ghl_opportunities.values(), key=lambda x: x['value'], reverse=True)
    print("TOP 10 OPPORTUNITIES BY VALUE:")
    for i, opp in enumerate(sorted_opps[:10], 1):
        print(f"   {i:2d}. R {opp['value']:>12,.2f} - {opp['name']}")
        print(f"       Pipeline: {opp['pipeline']} | Stage: {opp['stage']}")
    print()
    
    # Now update Firebase
    print("=" * 100)
    print("📝 STEP 2: UPDATE FIREBASE RECORDS")
    print("=" * 100)
    print()
    
    print("Fetching existing Firebase records...")
    firebase_records = {}
    for doc in db.collection('opportunityStageHistory').stream():
        data = doc.to_dict()
        opp_id = data.get('opportunityId')
        if opp_id:
            if opp_id not in firebase_records:
                firebase_records[opp_id] = []
            firebase_records[opp_id].append({
                'doc_id': doc.id,
                'doc_ref': doc.reference,
                'name': data.get('opportunityName', 'Unknown'),
                'stage': data.get('newStageName', 'Unknown'),
                'current_value': data.get('monetaryValue', 0)
            })
    
    print(f"✅ Found {len(firebase_records)} unique opportunities in Firebase")
    print()
    
    # Match and update
    print("=" * 100)
    print("🔄 MATCHING AND UPDATING...")
    print("=" * 100)
    print()
    
    updated_count = 0
    already_correct = 0
    not_in_firebase = 0
    
    for opp_id, ghl_opp in all_ghl_opportunities.items():
        ghl_value = ghl_opp['value']
        
        if opp_id not in firebase_records:
            if ghl_value > 0:
                not_in_firebase += 1
            continue
        
        # Update all Firebase records for this opportunity
        for fb_record in firebase_records[opp_id]:
            current_value = fb_record['current_value']
            
            if current_value == ghl_value:
                already_correct += 1
                continue
            
            # Only show updates for significant values
            if ghl_value > 1000 or current_value > 1000:
                print(f"✅ {ghl_opp['name']}")
                print(f"   Stage: {fb_record['stage']}")
                print(f"   Current: R {current_value:,.2f} → New: R {ghl_value:,.2f}")
                print()
            
            # Update Firebase
            try:
                fb_record['doc_ref'].update({
                    'monetaryValue': ghl_value,
                    'lastUpdated': firestore.SERVER_TIMESTAMP
                })
                updated_count += 1
            except Exception as e:
                print(f"   ❌ Error updating {fb_record['doc_id']}: {e}")
    
    print("=" * 100)
    print("📊 UPDATE SUMMARY")
    print("=" * 100)
    print(f"Total GHL opportunities: {len(all_ghl_opportunities)}")
    print(f"Already correct: {already_correct}")
    print(f"Updated: {updated_count}")
    print(f"Not in Firebase: {not_in_firebase}")
    print()
    
    if updated_count > 0:
        print("=" * 100)
        print("🔄 STEP 3: TRIGGER AGGREGATION")
        print("=" * 100)
        print()
        
        print("Waiting 2 seconds for Firebase to sync...")
        time.sleep(2)
        
        print("Triggering GHL to Facebook matching...")
        try:
            response = requests.post(
                f"{BACKEND_API}/facebook/match-ghl",
                json={},
                timeout=300
            )
            if response.status_code == 200:
                result = response.json()
                print("✅ Aggregation complete!")
                print(f"   Matched: {result.get('stats', {}).get('matched', 0)}")
                print(f"   Unmatched: {result.get('stats', {}).get('unmatched', 0)}")
            else:
                print(f"❌ Error: {response.status_code}")
        except Exception as e:
            print(f"❌ Error: {e}")
        
        print()
        print("=" * 100)
        print("✅ COMPLETE!")
        print("=" * 100)
        print()
        print(f"Updated {updated_count} records in Firebase")
        print()
        print("NEXT STEPS:")
        print("1. Wait 10 seconds for aggregation to complete")
        print("2. Do a HOT RESTART in Flutter")
        print("3. Navigate to Advertisement Performance > Overview")
        print("4. You should see the updated profit values with real opportunity amounts")
    else:
        print("✅ All records are already up to date!")

if __name__ == "__main__":
    main()

