#!/usr/bin/env python3
"""
Diagnostic script to verify specific opportunities from Andries Pipeline
Checks: NADIA HARRIS (R 300,000) and Sashnie Naicker (R 125,000)
Also finds ALL opportunities in Deposit stages
"""

import json
import requests
from collections import defaultdict

# GHL Configuration
GHL_API_KEY = 'pit-22f8af95-3244-41e7-9a52-22c87b166f5a'
GHL_LOCATION_ID = 'QdLXaFEqrdF0JbVbpKLw'
ANDRIES_PIPELINE_ID = 'XeAGJWRnUGJ5tuhXam2g'
DAVIDE_PIPELINE_ID = 'pTbNvnrXqJc9u1oxir3q'
GHL_BASE_URL = 'https://services.leadconnectorhq.com'

def get_ghl_headers():
    return {
        'Authorization': f'Bearer {GHL_API_KEY}',
        'Version': '2021-07-28',
        'Content-Type': 'application/json'
    }

def fetch_all_opportunities():
    """Fetch ALL opportunities from GHL API"""
    print('=' * 80)
    print('FETCHING ALL OPPORTUNITIES FROM GHL API')
    print('=' * 80)
    print()
    
    all_opportunities = []
    page = 1
    
    while page <= 70:
        response = requests.get(
            f'{GHL_BASE_URL}/opportunities/search',
            headers=get_ghl_headers(),
            params={
                'location_id': GHL_LOCATION_ID,
                'limit': 100,
                'page': page
            },
            timeout=30
        )
        
        if response.status_code != 200:
            print(f'❌ Error: {response.status_code}')
            break
        
        data = response.json()
        opportunities = data.get('opportunities', [])
        
        if not opportunities:
            break
        
        all_opportunities.extend(opportunities)
        
        if page % 10 == 0:
            print(f'   Page {page}: {len(all_opportunities)} total opportunities')
        
        if len(opportunities) < 100:
            break
        
        page += 1
    
    print(f'\n✅ Total opportunities fetched: {len(all_opportunities)}\n')
    return all_opportunities

def analyze_opportunities(opportunities):
    """Analyze opportunities for Andries pipeline and deposit stages"""
    
    # Filter to Andries pipeline
    andries_opps = [o for o in opportunities if o.get('pipelineId') == ANDRIES_PIPELINE_ID]
    print(f'📊 Andries Pipeline opportunities: {len(andries_opps)}')
    print()
    
    # Find all unique stage names
    stage_names = defaultdict(int)
    for opp in andries_opps:
        stage = opp.get('pipelineStageName', 'Unknown')
        stage_names[stage] += 1
    
    print('=' * 80)
    print('ALL STAGE NAMES IN ANDRIES PIPELINE')
    print('=' * 80)
    for stage, count in sorted(stage_names.items(), key=lambda x: x[1], reverse=True):
        print(f'   {stage}: {count} opportunities')
    print()
    
    # Find opportunities with "Deposit" in stage name
    deposit_opps = [o for o in andries_opps if 'deposit' in o.get('pipelineStageName', '').lower()]
    
    print('=' * 80)
    print(f'OPPORTUNITIES IN DEPOSIT STAGES: {len(deposit_opps)}')
    print('=' * 80)
    print()
    
    if deposit_opps:
        print(f'{"Name":<35} {"Stage":<25} {"Value":>15} {"Created"}')
        print('-' * 95)
        
        for opp in deposit_opps[:50]:  # Show first 50
            name = opp.get('name', 'N/A')[:33]
            stage = opp.get('pipelineStageName', 'N/A')[:23]
            value = f"R {opp.get('monetaryValue', 0):,.2f}"
            created = opp.get('createdAt', 'N/A')[:10]
            
            print(f'{name:<35} {stage:<25} {value:>15} {created}')
        
        if len(deposit_opps) > 50:
            print(f'\n... and {len(deposit_opps) - 50} more')
    else:
        print('❌ NO opportunities found with "Deposit" in stage name')
    
    print()
    
    # Find specific opportunities
    print('=' * 80)
    print('SEARCHING FOR SPECIFIC OPPORTUNITIES')
    print('=' * 80)
    print()
    
    target_names = ['NADIA HARRIS', 'Sashnie Naicker']
    found = []
    
    for opp in andries_opps:
        opp_name = opp.get('name', '')
        if any(target.lower() in opp_name.lower() for target in target_names):
            found.append(opp)
    
    if found:
        for opp in found:
            print(f'✅ FOUND: {opp.get("name")}')
            print(f'   ID: {opp.get("id")}')
            print(f'   Stage: {opp.get("pipelineStageName")}')
            print(f'   Status: {opp.get("status")}')
            print(f'   💰 Monetary Value: R {opp.get("monetaryValue", 0):,.2f}')
            print(f'   Created: {opp.get("createdAt")}')
            
            # Check attributions
            attributions = opp.get('attributions', [])
            if attributions:
                print(f'   📍 Attributions: {len(attributions)}')
                for attr in attributions:
                    h_ad_id = attr.get('h_ad_id') or attr.get('adId') or attr.get('utmAdId')
                    if h_ad_id:
                        print(f'      h_ad_id: {h_ad_id}')
            else:
                print(f'   ⚠️  No attributions (no Facebook Ad tracking)')
            
            print()
            print('   FULL JSON:')
            print('   ' + '-' * 76)
            print(json.dumps(opp, indent=4))
            print()
    else:
        print('❌ Could not find NADIA HARRIS or Sashnie Naicker')
        print()
        print('📋 Showing first 10 Andries opportunities:')
        for i, opp in enumerate(andries_opps[:10], 1):
            print(f'   {i}. {opp.get("name")} - {opp.get("pipelineStageName")} - R {opp.get("monetaryValue", 0):,.2f}')

if __name__ == '__main__':
    opportunities = fetch_all_opportunities()
    analyze_opportunities(opportunities)

