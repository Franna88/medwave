#!/usr/bin/env python3
"""
Check GHL API directly for deposits and monetary values in Andries and Davide pipelines.
"""

import requests
import os
from datetime import datetime
from collections import defaultdict

# GHL Configuration
GHL_API_KEY = os.environ.get('GHL_API_KEY', 'pit-22f8af95-3244-41e7-9a52-22c87b166f5a')
GHL_LOCATION_ID = 'QdLXaFEqrdF0JbVbpKLw'
ANDRIES_PIPELINE_ID = 'XeAGJWRnUGJ5tuhXam2g'
DAVIDE_PIPELINE_ID = 'pTbNvnrXqJc9u1oxir3q'

# Stage categories
DEPOSIT_STAGES = ['Deposit Paid', 'Deposit']
CASH_STAGES = ['Cash Collected', 'Paid', 'Completed']

def fetch_opportunities():
    """Fetch all opportunities from GHL API with pagination"""
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
        
        response = requests.get(f'{base_url}/opportunities/search', headers=headers, params=params)
        
        if response.status_code != 200:
            print(f"❌ Error: {response.status_code} - {response.text}")
            break
        
        data = response.json()
        opportunities = data.get('opportunities', [])
        
        if not opportunities:
            print(f"   ✅ Reached end of data (page {page-1})")
            break
        
        all_opportunities.extend(opportunities)
        print(f"   📄 Page {page}: Fetched {len(opportunities)} opportunities (Total: {len(all_opportunities)})")
        
        if len(opportunities) < 100:
            print(f"   ✅ Reached end of data (last page had {len(opportunities)} opportunities)")
            break
        
        page += 1
    
    return all_opportunities

def analyze_deposits():
    """Analyze deposits and cash from GHL opportunities"""
    
    print("=" * 80)
    print("GHL PIPELINE DEPOSITS & CASH ANALYSIS")
    print("=" * 80)
    print()
    
    # Fetch all opportunities
    all_opportunities = fetch_opportunities()
    print(f"\n   ✅ TOTAL FETCHED: {len(all_opportunities)} opportunities")
    print()
    
    # Filter to Andries & Davide
    andries_opps = [opp for opp in all_opportunities if opp.get('pipelineId') == ANDRIES_PIPELINE_ID]
    davide_opps = [opp for opp in all_opportunities if opp.get('pipelineId') == DAVIDE_PIPELINE_ID]
    
    print(f"📊 Pipeline Breakdown:")
    print(f"   Andries: {len(andries_opps)} opportunities")
    print(f"   Davide: {len(davide_opps)} opportunities")
    print(f"   Total (A+D): {len(andries_opps) + len(davide_opps)} opportunities")
    print()
    
    # Analyze each pipeline
    for pipeline_name, pipeline_opps in [('Andries', andries_opps), ('Davide', davide_opps)]:
        print("=" * 80)
        print(f"{pipeline_name.upper()} PIPELINE ANALYSIS")
        print("=" * 80)
        
        total_deposits = 0
        total_cash = 0
        deposit_amount = 0.0
        cash_amount = 0.0
        
        deposits_by_month = defaultdict(lambda: {'count': 0, 'amount': 0.0})
        cash_by_month = defaultdict(lambda: {'count': 0, 'amount': 0.0})
        
        for opp in pipeline_opps:
            status = opp.get('status', '')
            monetary_value = float(opp.get('monetaryValue', 0) or 0)
            created_at = opp.get('createdAt') or opp.get('dateAdded', '')
            
            # Determine month
            if created_at:
                try:
                    date_obj = datetime.fromisoformat(created_at.replace('Z', '+00:00'))
                    month = date_obj.strftime('%Y-%m')
                except:
                    month = 'Unknown'
            else:
                month = 'Unknown'
            
            # Check if deposit
            if any(stage in status for stage in DEPOSIT_STAGES):
                total_deposits += 1
                deposit_amount += monetary_value
                deposits_by_month[month]['count'] += 1
                deposits_by_month[month]['amount'] += monetary_value
            
            # Check if cash collected
            if any(stage in status for stage in CASH_STAGES):
                total_cash += 1
                cash_amount += monetary_value
                cash_by_month[month]['count'] += 1
                cash_by_month[month]['amount'] += monetary_value
        
        print(f"\n📊 {pipeline_name} Summary:")
        print(f"   Total Deposits: {total_deposits}")
        print(f"   Total Deposit Amount: R{deposit_amount:,.2f}")
        print(f"   Total Cash Collected: {total_cash}")
        print(f"   Total Cash Amount: R{cash_amount:,.2f}")
        print(f"   Combined Total: R{(deposit_amount + cash_amount):,.2f}")
        print()
        
        # Show monthly breakdown
        if deposits_by_month:
            print(f"💰 Deposits by Month:")
            for month in sorted(deposits_by_month.keys(), reverse=True):
                data = deposits_by_month[month]
                print(f"   {month}: {data['count']} deposits, R{data['amount']:,.2f}")
        
        if cash_by_month:
            print(f"\n💵 Cash Collected by Month:")
            for month in sorted(cash_by_month.keys(), reverse=True):
                data = cash_by_month[month]
                print(f"   {month}: {data['count']} cash, R{data['amount']:,.2f}")
        
        print()
    
    # Combined totals
    print("=" * 80)
    print("COMBINED TOTALS (ANDRIES + DAVIDE)")
    print("=" * 80)
    
    all_filtered = andries_opps + davide_opps
    
    total_deposits = 0
    total_cash = 0
    deposit_amount = 0.0
    cash_amount = 0.0
    
    october_deposits = 0
    october_deposit_amount = 0.0
    october_cash = 0
    october_cash_amount = 0.0
    
    for opp in all_filtered:
        status = opp.get('status', '')
        monetary_value = float(opp.get('monetaryValue', 0) or 0)
        created_at = opp.get('createdAt') or opp.get('dateAdded', '')
        
        # Determine month
        is_october = False
        if created_at:
            try:
                date_obj = datetime.fromisoformat(created_at.replace('Z', '+00:00'))
                month = date_obj.strftime('%Y-%m')
                is_october = (month == '2025-10')
            except:
                pass
        
        # Check if deposit
        if any(stage in status for stage in DEPOSIT_STAGES):
            total_deposits += 1
            deposit_amount += monetary_value
            if is_october:
                october_deposits += 1
                october_deposit_amount += monetary_value
        
        # Check if cash collected
        if any(stage in status for stage in CASH_STAGES):
            total_cash += 1
            cash_amount += monetary_value
            if is_october:
                october_cash += 1
                october_cash_amount += monetary_value
    
    print(f"\n📊 All Time Totals:")
    print(f"   Total Deposits: {total_deposits}")
    print(f"   Total Deposit Amount: R{deposit_amount:,.2f}")
    print(f"   Total Cash Collected: {total_cash}")
    print(f"   Total Cash Amount: R{cash_amount:,.2f}")
    print(f"   Combined Total: R{(deposit_amount + cash_amount):,.2f}")
    print()
    
    print(f"📊 October 2025 Totals:")
    print(f"   Deposits: {october_deposits}")
    print(f"   Deposit Amount: R{october_deposit_amount:,.2f}")
    print(f"   Cash Collected: {october_cash}")
    print(f"   Cash Amount: R{october_cash_amount:,.2f}")
    print(f"   Combined Total: R{(october_deposit_amount + october_cash_amount):,.2f}")
    print()

if __name__ == "__main__":
    analyze_deposits()

