#!/usr/bin/env python3
"""
Check what stage IDs the deposit opportunities actually have in GHL
"""

import requests
import os
import json

# GHL Configuration
GHL_API_KEY = os.environ.get('GHL_API_KEY', 'pit-22f8af95-3244-41e7-9a52-22c87b166f5a')
GHL_LOCATION_ID = 'QdLXaFEqrdF0JbVbpKLw'
ANDRIES_PIPELINE_ID = 'XeAGJWRnUGJ5tuhXam2g'
DAVIDE_PIPELINE_ID = 'AUduOJBB2lxlsEaNmlJz'

# Expected stage IDs
ANDRIES_DEPOSIT_STAGE = "52a076ca-851f-43fc-a57d-309403a4b208"
ANDRIES_CASH_STAGE = "3a8ead84-92b0-4796-aaf8-6594c3217a2c"
DAVIDE_DEPOSIT_STAGE = "13d54d18-d1e7-476b-aad8-cb4767b8b979"
DAVIDE_CASH_STAGE = "3c89afba-9797-4b0f-947c-ba00b60468c6"

def fetch_opportunities():
    """Fetch opportunities from GHL API"""
    url = 'https://services.leadconnectorhq.com/opportunities/search'
    headers = {
        'Authorization': f'Bearer {GHL_API_KEY}',
        'Version': '2021-07-28'
    }
    
    all_opportunities = []
    page = 1
    
    print("📊 Fetching opportunities...")
    
    while page <= 70:  # Fetch all pages
        params = {
            'location_id': GHL_LOCATION_ID,
            'limit': 100,
            'page': page
        }
        
        try:
            response = requests.get(url, headers=headers, params=params, timeout=30)
            
            if response.status_code != 200:
                break
            
            data = response.json()
            opportunities = data.get('opportunities', [])
            
            if not opportunities:
                break
            
            all_opportunities.extend(opportunities)
            
            if len(opportunities) < 100:
                break
            
            page += 1
            
        except Exception as e:
            print(f"Error: {e}")
            break
    
    print(f"✅ Fetched {len(all_opportunities)} opportunities")
    return all_opportunities

def analyze():
    """Analyze stage IDs for deposit/cash opportunities"""
    
    print("=" * 80)
    print("CHECKING ACTUAL STAGE IDs IN GHL")
    print("=" * 80)
    print()
    
    all_opps = fetch_opportunities()
    
    # Filter to Andries & Davide
    filtered_opps = [opp for opp in all_opps 
                     if opp.get('pipelineId') in [ANDRIES_PIPELINE_ID, DAVIDE_PIPELINE_ID]]
    
    print(f"📊 Andries & Davide opportunities: {len(filtered_opps)}")
    print()
    
    # Check for deposit/cash stages
    andries_deposits = []
    andries_cash = []
    davide_deposits = []
    davide_cash = []
    
    for opp in filtered_opps:
        pipeline_id = opp.get('pipelineId')
        stage_id = opp.get('pipelineStageId')
        monetary_value = float(opp.get('monetaryValue', 0) or 0)
        
        if pipeline_id == ANDRIES_PIPELINE_ID:
            if stage_id == ANDRIES_DEPOSIT_STAGE:
                andries_deposits.append({
                    'name': opp.get('name'),
                    'value': monetary_value,
                    'stage_id': stage_id
                })
            elif stage_id == ANDRIES_CASH_STAGE:
                andries_cash.append({
                    'name': opp.get('name'),
                    'value': monetary_value,
                    'stage_id': stage_id
                })
        
        elif pipeline_id == DAVIDE_PIPELINE_ID:
            if stage_id == DAVIDE_DEPOSIT_STAGE:
                davide_deposits.append({
                    'name': opp.get('name'),
                    'value': monetary_value,
                    'stage_id': stage_id
                })
            elif stage_id == DAVIDE_CASH_STAGE:
                davide_cash.append({
                    'name': opp.get('name'),
                    'value': monetary_value,
                    'stage_id': stage_id
                })
    
    # Results
    print("=" * 80)
    print("ANDRIES PIPELINE")
    print("=" * 80)
    print(f"Deposits (stage {ANDRIES_DEPOSIT_STAGE[:8]}...): {len(andries_deposits)}")
    if andries_deposits:
        total = sum(d['value'] for d in andries_deposits)
        print(f"   Total Value: R{total:,.2f}")
        print("   Sample:")
        for d in andries_deposits[:5]:
            print(f"      - {d['name']}: R{d['value']:,.2f}")
    else:
        print("   ❌ NONE FOUND!")
    
    print()
    print(f"Cash Collected (stage {ANDRIES_CASH_STAGE[:8]}...): {len(andries_cash)}")
    if andries_cash:
        total = sum(c['value'] for c in andries_cash)
        print(f"   Total Value: R{total:,.2f}")
        print("   Sample:")
        for c in andries_cash[:5]:
            print(f"      - {c['name']}: R{c['value']:,.2f}")
    else:
        print("   ❌ NONE FOUND!")
    
    print()
    print("=" * 80)
    print("DAVIDE PIPELINE")
    print("=" * 80)
    print(f"Deposits (stage {DAVIDE_DEPOSIT_STAGE[:8]}...): {len(davide_deposits)}")
    if davide_deposits:
        total = sum(d['value'] for d in davide_deposits)
        print(f"   Total Value: R{total:,.2f}")
        print("   Sample:")
        for d in davide_deposits[:5]:
            print(f"      - {d['name']}: R{d['value']:,.2f}")
    else:
        print("   ❌ NONE FOUND!")
    
    print()
    print(f"Cash Collected (stage {DAVIDE_CASH_STAGE[:8]}...): {len(davide_cash)}")
    if davide_cash:
        total = sum(c['value'] for c in davide_cash)
        print(f"   Total Value: R{total:,.2f}")
        print("   Sample:")
        for c in davide_cash[:5]:
            print(f"      - {c['name']}: R{c['value']:,.2f}")
    else:
        print("   ❌ NONE FOUND!")
    
    print()
    print("=" * 80)
    print("SUMMARY")
    print("=" * 80)
    
    total_deposits = len(andries_deposits) + len(davide_deposits)
    total_cash = len(andries_cash) + len(davide_cash)
    total_deposit_value = sum(d['value'] for d in andries_deposits + davide_deposits)
    total_cash_value = sum(c['value'] for c in andries_cash + davide_cash)
    
    print(f"Total Deposits: {total_deposits} (R{total_deposit_value:,.2f})")
    print(f"Total Cash: {total_cash} (R{total_cash_value:,.2f})")
    print(f"GRAND TOTAL: R{(total_deposit_value + total_cash_value):,.2f})")
    print()
    
    if total_deposits == 0 and total_cash == 0:
        print("⚠️  WARNING: NO DEPOSITS OR CASH FOUND!")
        print()
        print("This means the opportunities in GHL are NOT in these stages.")
        print("They might be in different stages. Let's check what stages they ARE in...")
        print()
        
        # Show stage distribution
        stage_counts = {}
        for opp in filtered_opps:
            stage_id = opp.get('pipelineStageId')
            stage_counts[stage_id] = stage_counts.get(stage_id, 0) + 1
        
        print("Top 10 stages by opportunity count:")
        for stage_id, count in sorted(stage_counts.items(), key=lambda x: x[1], reverse=True)[:10]:
            print(f"   {stage_id[:20]}...: {count} opportunities")

if __name__ == "__main__":
    analyze()

