#!/usr/bin/env python3
"""
Analyze unmatched opportunities to see how many deposits/cash we're missing
"""

import requests
import os
from datetime import datetime

# GHL Configuration
GHL_API_KEY = os.environ.get('GHL_API_KEY', 'pit-22f8af95-3244-41e7-9a52-22c87b166f5a')
GHL_LOCATION_ID = 'QdLXaFEqrdF0JbVbpKLw'
ANDRIES_PIPELINE_ID = 'XeAGJWRnUGJ5tuhXam2g'
DAVIDE_PIPELINE_ID = 'AUduOJBB2lxlsEaNmlJz'

def extract_h_ad_id_from_attributions(attributions):
    """Extract h_ad_id from opportunity attributions"""
    if not attributions:
        return None
    
    # Check each attribution in reverse order (most recent first)
    for attr in reversed(attributions):
        # Try different possible field names
        h_ad_id = attr.get('h_ad_id') or attr.get('utmAdId') or attr.get('adId')
        if h_ad_id:
            return h_ad_id
    
    return None

def fetch_all_opportunities():
    """Fetch all opportunities from GHL API"""
    url = 'https://services.leadconnectorhq.com/opportunities/search'
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
            response = requests.get(url, headers=headers, params=params, timeout=30)
            
            if response.status_code != 200:
                print(f"❌ Error: {response.status_code}")
                break
            
            data = response.json()
            opportunities = data.get('opportunities', [])
            
            if not opportunities:
                break
            
            all_opportunities.extend(opportunities)
            
            if len(opportunities) < 100:
                break
            
            page += 1
            
            if page % 10 == 0:
                print(f"   Page {page}... ({len(all_opportunities)} total)")
            
        except Exception as e:
            print(f"❌ Error: {e}")
            break
    
    print(f"✅ Fetched {len(all_opportunities)} opportunities")
    return all_opportunities

def analyze():
    """Analyze deposits and cash in matched vs unmatched opportunities"""
    
    print("=" * 80)
    print("ANALYZING UNMATCHED DEPOSITS & CASH")
    print("=" * 80)
    print()
    
    # Fetch all opportunities
    all_opps = fetch_all_opportunities()
    
    # Filter to Andries & Davide
    filtered_opps = [opp for opp in all_opps 
                     if opp.get('pipelineId') in [ANDRIES_PIPELINE_ID, DAVIDE_PIPELINE_ID]]
    
    print(f"\n📊 Andries & Davide opportunities: {len(filtered_opps)}")
    print()
    
    # Categorize opportunities
    matched_opps = []
    unmatched_opps = []
    
    for opp in filtered_opps:
        attributions = opp.get('attributions', {})
        if isinstance(attributions, dict):
            attributions = attributions.get('attributions', [])
        
        h_ad_id = extract_h_ad_id_from_attributions(attributions)
        
        if h_ad_id:
            matched_opps.append(opp)
        else:
            unmatched_opps.append(opp)
    
    print(f"✅ Matched (have h_ad_id): {len(matched_opps)}")
    print(f"⚠️  Unmatched (no h_ad_id): {len(unmatched_opps)}")
    print()
    
    # Analyze deposits and cash in each group
    def analyze_group(opps, group_name):
        deposits = []
        cash_collected = []
        
        for opp in opps:
            status = opp.get('status', '')
            monetary_value = float(opp.get('monetaryValue', 0) or 0)
            
            if 'deposit' in status.lower() and 'received' in status.lower():
                deposits.append({
                    'name': opp.get('name', 'Unknown'),
                    'value': monetary_value,
                    'status': status,
                    'pipeline': 'Andries' if opp.get('pipelineId') == ANDRIES_PIPELINE_ID else 'Davide'
                })
            
            if 'cash collected' in status.lower():
                cash_collected.append({
                    'name': opp.get('name', 'Unknown'),
                    'value': monetary_value,
                    'status': status,
                    'pipeline': 'Andries' if opp.get('pipelineId') == ANDRIES_PIPELINE_ID else 'Davide'
                })
        
        total_deposit_value = sum(d['value'] for d in deposits)
        total_cash_value = sum(c['value'] for c in cash_collected)
        
        print(f"📊 {group_name}:")
        print(f"   Deposits: {len(deposits)} (R{total_deposit_value:,.2f})")
        print(f"   Cash Collected: {len(cash_collected)} (R{total_cash_value:,.2f})")
        print(f"   TOTAL: R{(total_deposit_value + total_cash_value):,.2f}")
        print()
        
        return deposits, cash_collected, total_deposit_value, total_cash_value
    
    print("=" * 80)
    print("MATCHED OPPORTUNITIES (with h_ad_id - tracked in Firebase)")
    print("=" * 80)
    matched_deposits, matched_cash, matched_dep_val, matched_cash_val = analyze_group(matched_opps, "MATCHED")
    
    print("=" * 80)
    print("UNMATCHED OPPORTUNITIES (no h_ad_id - NOT tracked in Firebase)")
    print("=" * 80)
    unmatched_deposits, unmatched_cash, unmatched_dep_val, unmatched_cash_val = analyze_group(unmatched_opps, "UNMATCHED")
    
    print("=" * 80)
    print("SUMMARY")
    print("=" * 80)
    print()
    print(f"💰 TOTAL DEPOSITS:")
    print(f"   Matched: {len(matched_deposits)} (R{matched_dep_val:,.2f})")
    print(f"   Unmatched: {len(unmatched_deposits)} (R{unmatched_dep_val:,.2f}) ⚠️  MISSING!")
    print(f"   TOTAL: {len(matched_deposits) + len(unmatched_deposits)} (R{(matched_dep_val + unmatched_dep_val):,.2f})")
    print()
    print(f"💵 TOTAL CASH COLLECTED:")
    print(f"   Matched: {len(matched_cash)} (R{matched_cash_val:,.2f})")
    print(f"   Unmatched: {len(unmatched_cash)} (R{unmatched_cash_val:,.2f}) ⚠️  MISSING!")
    print(f"   TOTAL: {len(matched_cash) + len(unmatched_cash)} (R{(matched_cash_val + unmatched_cash_val):,.2f})")
    print()
    print(f"📊 GRAND TOTAL:")
    print(f"   Tracked in Firebase: R{(matched_dep_val + matched_cash_val):,.2f}")
    print(f"   Missing from Firebase: R{(unmatched_dep_val + unmatched_cash_val):,.2f} ⚠️")
    print(f"   TOTAL in GHL: R{(matched_dep_val + matched_cash_val + unmatched_dep_val + unmatched_cash_val):,.2f}")
    print()
    
    if unmatched_deposits or unmatched_cash:
        print("⚠️  WARNING: Significant deposits/cash are NOT being tracked!")
        print("   These opportunities don't have Facebook ad IDs (h_ad_id)")
        print("   They came from sources other than Facebook ads, or UTM tracking failed")
        print()
        
        print("Sample unmatched deposits:")
        for i, dep in enumerate(unmatched_deposits[:5], 1):
            print(f"   {i}. {dep['name']} - {dep['pipeline']} - R{dep['value']:,.2f}")
        print()

if __name__ == "__main__":
    analyze()

