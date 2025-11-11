#!/usr/bin/env python3
"""
Update ALL opportunities in Deposit Received and Cash Collected stages
with their actual monetary values from GHL API
"""

import requests
import firebase_admin
from firebase_admin import credentials, firestore
from datetime import datetime
import time

# GHL API Configuration
GHL_API_KEY = "pit-22f8af95-3244-41e7-9a52-22c87b166f5a"
GHL_BASE_URL = "https://services.leadconnectorhq.com"
LOCATION_ID = "QdLXaFEqrdF0JbVbpKLw"

# Pipeline IDs
ANDRIES_PIPELINE_ID = "XeAGJWRnUGJ5tuhXam2g"
DAVIDE_PIPELINE_ID = "pTbNvnrXqJc9u1oxir3q"
ALTUS_PIPELINE_ID = "AUduOJBB2lxlsEaNmlJz"

# Target stages (we want Deposit Received and Cash Collected)
TARGET_STAGES = [
    "Deposit Received",
    "Cash Collected"
]

def get_ghl_headers():
    """Get headers for GHL API requests"""
    return {
        "Authorization": f"Bearer {GHL_API_KEY}",
        "Version": "2021-07-28",
        "Content-Type": "application/json"
    }

def fetch_all_opportunities(pipeline_id, pipeline_name):
    """Fetch all opportunities from a pipeline"""
    print(f"\n📋 Fetching opportunities from {pipeline_name}...")
    
    all_opportunities = []
    next_cursor = None
    page = 1
    
    while True:
        params = {
            "location_id": LOCATION_ID,
            "pipelineId": pipeline_id,
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
            time.sleep(0.5)  # Rate limiting
            
        except Exception as e:
            print(f"   ❌ Error fetching page {page}: {e}")
            break
    
    print(f"   ✅ Total: {len(all_opportunities)} opportunities")
    return all_opportunities

def filter_target_opportunities(opportunities):
    """Filter opportunities in Deposit Received or Cash Collected stages"""
    target_opps = []
    
    for opp in opportunities:
        stage_name = opp.get('pipelineStage', {}).get('name', '')
        monetary_value = float(opp.get('monetaryValue', 0))
        
        if stage_name in TARGET_STAGES and monetary_value > 0:
            target_opps.append({
                'id': opp.get('id'),
                'name': opp.get('name', 'Unknown'),
                'stage': stage_name,
                'value': monetary_value,
                'pipeline': opp.get('pipeline', {}).get('name', 'Unknown')
            })
    
    return target_opps

def update_firebase_values(target_opps, dry_run=True):
    """Update Firebase opportunityStageHistory with actual monetary values"""
    
    # Initialize Firebase
    try:
        cred = credentials.Certificate('medx-ai-firebase-adminsdk-fbsvc-a86e7bd050.json')
        firebase_admin.initialize_app(cred)
    except:
        pass
    
    db = firestore.client()
    
    print(f"\n{'🔍 DRY RUN' if dry_run else '✅ UPDATING'} - Processing {len(target_opps)} opportunities...")
    print()
    
    updated_count = 0
    not_found_count = 0
    already_correct_count = 0
    
    for opp in target_opps:
        opp_name = opp['name']
        ghl_value = opp['value']
        stage = opp['stage']
        
        # Find matching documents in Firebase
        docs = list(db.collection('opportunityStageHistory')
                   .where('opportunityName', '==', opp_name)
                   .where('newStageName', '==', stage)
                   .stream())
        
        if not docs:
            print(f"⚠️  {opp_name} ({stage})")
            print(f"     GHL Value: R {ghl_value:,.2f}")
            print(f"     ❌ No matching Firebase record found")
            print()
            not_found_count += 1
            continue
        
        # Update all matching documents
        for doc in docs:
            data = doc.to_dict()
            current_value = data.get('monetaryValue', 0)
            
            if current_value == ghl_value:
                print(f"✓  {opp_name} ({stage})")
                print(f"     Already correct: R {ghl_value:,.2f}")
                print()
                already_correct_count += 1
                continue
            
            print(f"{'📝' if dry_run else '✅'}  {opp_name} ({stage})")
            print(f"     Pipeline: {opp['pipeline']}")
            print(f"     Current: R {current_value:,.2f} → New: R {ghl_value:,.2f}")
            
            if not dry_run:
                try:
                    doc.reference.update({
                        'monetaryValue': ghl_value,
                        'lastUpdated': firestore.SERVER_TIMESTAMP
                    })
                    print(f"     ✅ Updated!")
                    updated_count += 1
                except Exception as e:
                    print(f"     ❌ Error: {e}")
            else:
                print(f"     Would update (dry run)")
            
            print()
    
    print("=" * 100)
    print("📊 SUMMARY")
    print("=" * 100)
    print(f"Total opportunities processed: {len(target_opps)}")
    print(f"Already correct: {already_correct_count}")
    print(f"Not found in Firebase: {not_found_count}")
    if dry_run:
        print(f"Would update: {len(target_opps) - already_correct_count - not_found_count}")
    else:
        print(f"Successfully updated: {updated_count}")
    print()
    
    return updated_count

def main():
    print("=" * 100)
    print("💰 UPDATE ALL DEPOSIT & CASH COLLECTED VALUES FROM GHL")
    print("=" * 100)
    
    # Fetch from all three pipelines
    all_opportunities = []
    
    for pipeline_id, pipeline_name in [
        (ANDRIES_PIPELINE_ID, "Andries Pipeline"),
        (DAVIDE_PIPELINE_ID, "Davide Pipeline"),
        (ALTUS_PIPELINE_ID, "Altus Pipeline")
    ]:
        opps = fetch_all_opportunities(pipeline_id, pipeline_name)
        all_opportunities.extend(opps)
    
    print(f"\n✅ Total opportunities fetched: {len(all_opportunities)}")
    
    # Filter for target stages with values
    target_opps = filter_target_opportunities(all_opportunities)
    
    print(f"\n🎯 Found {len(target_opps)} opportunities in target stages with values > 0:")
    print()
    
    # Group by stage
    by_stage = {}
    total_value = 0
    for opp in target_opps:
        stage = opp['stage']
        if stage not in by_stage:
            by_stage[stage] = []
        by_stage[stage].append(opp)
        total_value += opp['value']
    
    for stage, opps in by_stage.items():
        stage_total = sum(o['value'] for o in opps)
        print(f"   {stage}: {len(opps)} opportunities (R {stage_total:,.2f})")
    
    print(f"\n   💰 TOTAL VALUE: R {total_value:,.2f}")
    print()
    
    # Show top 10 by value
    print("=" * 100)
    print("TOP 10 OPPORTUNITIES BY VALUE:")
    print("=" * 100)
    sorted_opps = sorted(target_opps, key=lambda x: x['value'], reverse=True)
    for i, opp in enumerate(sorted_opps[:10], 1):
        print(f"{i:2d}. R {opp['value']:>12,.2f} - {opp['name']}")
        print(f"     Pipeline: {opp['pipeline']} | Stage: {opp['stage']}")
        print()
    
    # Dry run first
    print("=" * 100)
    print("STEP 1: DRY RUN")
    print("=" * 100)
    update_firebase_values(target_opps, dry_run=True)
    
    # Ask for confirmation
    print("=" * 100)
    print("⚠️  READY TO UPDATE FIREBASE")
    print("=" * 100)
    print(f"This will update {len(target_opps)} opportunity records in Firebase")
    print(f"Total value: R {total_value:,.2f}")
    print()
    response = input("Proceed with update? (yes/no): ").strip().lower()
    
    if response == 'yes':
        print("\n🚀 Updating Firebase...")
        updated = update_firebase_values(target_opps, dry_run=False)
        
        print("=" * 100)
        print("✅ UPDATE COMPLETE!")
        print("=" * 100)
        print(f"Updated {updated} records in Firebase")
        print()
        print("NEXT STEPS:")
        print("1. Trigger backend aggregation to update adPerformance")
        print("2. Refresh Flutter app to see new values")
    else:
        print("\n❌ Update cancelled")

if __name__ == "__main__":
    main()

