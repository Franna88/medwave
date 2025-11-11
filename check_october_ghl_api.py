#!/usr/bin/env python3
"""
Check GHL API directly for October 2025 deposits in Andries and Davide pipelines.
"""

import requests
import os
from datetime import datetime

# GHL Configuration
GHL_API_KEY = os.environ.get('GHL_API_KEY', 'pit-22f8af95-3244-41e7-9a52-22c87b166f5a')
GHL_LOCATION_ID = 'QdLXaFEqrdF0JbVbpKLw'
ANDRIES_PIPELINE_ID = 'XeAGJWRnUGJ5tuhXam2g'
DAVIDE_PIPELINE_ID = 'pTbNvnrXqJc9u1oxir3q'

# Stage categories
DEPOSIT_STAGES = ['Deposit Paid', 'Deposit']
CASH_STAGES = ['Cash Collected', 'Paid', 'Completed']

def fetch_all_opportunities():
    """Fetch all opportunities from GHL API"""
    base_url = 'https://services.leadconnectorhq.com'
    headers = {
        'Authorization': f'Bearer {GHL_API_KEY}',
        'Version': '2021-07-28'
    }
    
    all_opportunities = []
    page = 1
    
    print("📊 Fetching opportunities from GHL API...")
    
    while True:
        params = {
            'location_id': GHL_LOCATION_ID,
            'limit': 100,
            'page': page
        }
        
        try:
            response = requests.get(f'{base_url}/opportunities/search', headers=headers, params=params, timeout=30)
            
            if response.status_code != 200:
                print(f"❌ Error: {response.status_code} - {response.text}")
                break
            
            data = response.json()
            opportunities = data.get('opportunities', [])
            
            if not opportunities:
                break
            
            all_opportunities.extend(opportunities)
            print(f"   Page {page}: {len(opportunities)} opportunities (Total: {len(all_opportunities)})")
            
            if len(opportunities) < 100:
                break
            
            page += 1
            
        except Exception as e:
            print(f"❌ Error on page {page}: {e}")
            break
    
    print(f"\n✅ Total fetched: {len(all_opportunities)} opportunities")
    return all_opportunities

def analyze_october():
    """Analyze October 2025 deposits"""
    
    print("=" * 80)
    print("OCTOBER 2025 GHL DEPOSITS ANALYSIS (DIRECT FROM API)")
    print("=" * 80)
    print()
    
    # Fetch all opportunities
    all_opps = fetch_all_opportunities()
    
    # Filter to Andries & Davide
    andries_davide = [opp for opp in all_opps 
                      if opp.get('pipelineId') in [ANDRIES_PIPELINE_ID, DAVIDE_PIPELINE_ID]]
    
    print(f"\n📊 Filtered to Andries & Davide: {len(andries_davide)} opportunities")
    print()
    
    # Filter to October 2025
    october_opps = []
    for opp in andries_davide:
        created_at = opp.get('createdAt') or opp.get('dateAdded', '')
        if created_at:
            try:
                date_obj = datetime.fromisoformat(created_at.replace('Z', '+00:00'))
                if date_obj.year == 2025 and date_obj.month == 10:
                    october_opps.append(opp)
            except:
                pass
    
    print(f"📅 October 2025 opportunities: {len(october_opps)}")
    print()
    
    # Analyze deposits and cash
    deposits = []
    cash_collected = []
    
    for opp in october_opps:
        status = opp.get('status', '')
        monetary_value = float(opp.get('monetaryValue', 0) or 0)
        name = opp.get('name', 'Unknown')
        pipeline_id = opp.get('pipelineId', '')
        pipeline_name = 'Andries' if pipeline_id == ANDRIES_PIPELINE_ID else 'Davide'
        created_at = opp.get('createdAt') or opp.get('dateAdded', '')
        
        # Check if deposit
        if any(stage in status for stage in DEPOSIT_STAGES):
            deposits.append({
                'name': name,
                'status': status,
                'amount': monetary_value,
                'pipeline': pipeline_name,
                'created': created_at
            })
        
        # Check if cash collected
        if any(stage in status for stage in CASH_STAGES):
            cash_collected.append({
                'name': name,
                'status': status,
                'amount': monetary_value,
                'pipeline': pipeline_name,
                'created': created_at
            })
    
    # Summary
    print("=" * 80)
    print("OCTOBER 2025 SUMMARY")
    print("=" * 80)
    print()
    print(f"Total October Opportunities: {len(october_opps)}")
    print(f"Deposits: {len(deposits)}")
    print(f"Cash Collected: {len(cash_collected)}")
    print()
    
    if deposits:
        total_deposit_amount = sum(d['amount'] for d in deposits)
        print(f"💰 DEPOSITS ({len(deposits)}):")
        print(f"   Total Amount: R{total_deposit_amount:,.2f}")
        print()
        for i, dep in enumerate(deposits, 1):
            print(f"   {i}. {dep['name'][:50]}")
            print(f"      Pipeline: {dep['pipeline']}")
            print(f"      Status: {dep['status']}")
            print(f"      Amount: R{dep['amount']:,.2f}")
            print(f"      Created: {dep['created']}")
            print()
    else:
        print("❌ No deposits found in October 2025")
        print()
    
    if cash_collected:
        total_cash_amount = sum(c['amount'] for c in cash_collected)
        print(f"💵 CASH COLLECTED ({len(cash_collected)}):")
        print(f"   Total Amount: R{total_cash_amount:,.2f}")
        print()
        for i, cash in enumerate(cash_collected, 1):
            print(f"   {i}. {cash['name'][:50]}")
            print(f"      Pipeline: {cash['pipeline']}")
            print(f"      Status: {cash['status']}")
            print(f"      Amount: R{cash['amount']:,.2f}")
            print(f"      Created: {cash['created']}")
            print()
    else:
        print("❌ No cash collected found in October 2025")
        print()
    
    # Combined total
    if deposits or cash_collected:
        total_deposit_amount = sum(d['amount'] for d in deposits)
        total_cash_amount = sum(c['amount'] for c in cash_collected)
        print(f"📊 COMBINED TOTAL: R{(total_deposit_amount + total_cash_amount):,.2f}")
    
    print()

if __name__ == "__main__":
    analyze_october()

