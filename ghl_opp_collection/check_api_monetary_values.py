#!/usr/bin/env python3
"""
Check GHL API directly for opportunities with monetary values in November 2025
"""

import requests
import time
from datetime import datetime

# GHL API Configuration
GHL_API_KEY = 'pit-22f8af95-3244-41e7-9a52-22c87b166f5a'
GHL_LOCATION_ID = 'QdLXaFEqrdF0JbVbpKLw'
GHL_BASE_URL = 'https://services.leadconnectorhq.com'
GHL_API_VERSION = '2021-07-28'

# Pipeline IDs
ANDRIES_PIPELINE_ID = 'XeAGJWRnUGJ5tuhXam2g'
DAVIDE_PIPELINE_ID = 'AUduOJBB2lxlsEaNmlJz'

# Date range for November 2025
START_DATE = '2025-11-01T00:00:00.000Z'
END_DATE = '2025-11-30T23:59:59.999Z'

def get_ghl_headers():
    return {
        'Authorization': f'Bearer {GHL_API_KEY}',
        'Version': GHL_API_VERSION,
        'Content-Type': 'application/json'
    }

print('='*80)
print('CHECKING GHL API FOR OPPORTUNITIES WITH MONETARY VALUES')
print('='*80 + '\n')

print(f'📅 Date Range: {START_DATE[:10]} to {END_DATE[:10]}')
print(f'🎯 Location ID: {GHL_LOCATION_ID}')
print(f'👥 Pipelines: Andries & Davide\n')

# Fetch all opportunities from API
print('='*80)
print('FETCHING OPPORTUNITIES FROM GHL API')
print('='*80 + '\n')

url = f'{GHL_BASE_URL}/opportunities/search'
all_opportunities = []

params = {
    'location_id': GHL_LOCATION_ID,
    'limit': 100,
    'page': 1
}

page = 1

while True:
    print(f'📄 Fetching page {page}...')
    
    try:
        response = requests.get(url, headers=get_ghl_headers(), params=params, timeout=30)
        
        if response.status_code == 429:
            print(f'   ⚠️  Rate limit hit, waiting 60 seconds...')
            time.sleep(60)
            continue
        
        response.raise_for_status()
        data = response.json()
        
        opportunities = data.get('opportunities', [])
        
        if not opportunities:
            print(f'   ✅ No more opportunities found\n')
            break
        
        all_opportunities.extend(opportunities)
        print(f'   Found {len(opportunities)} opportunities on this page')
        
        # Check if we're on the last page
        meta = data.get('meta', {})
        total = meta.get('total', 0)
        current_count = page * 100
        
        if current_count >= total:
            print(f'   ✅ Reached last page (Total: {total})\n')
            break
        
        params['page'] = page + 1
        page += 1
        time.sleep(0.5)
        
    except Exception as e:
        print(f'   ❌ Error fetching opportunities: {e}')
        print(f'   Continuing with {len(all_opportunities)} opportunities fetched so far...\n')
        break

print(f'✅ Total opportunities fetched: {len(all_opportunities)}\n')

# Filter for November 2025
print('='*80)
print('FILTERING FOR NOVEMBER 2025')
print('='*80 + '\n')

november_opportunities = []
for opp in all_opportunities:
    created_at = opp.get('createdAt', '')
    if created_at >= START_DATE and created_at <= END_DATE:
        november_opportunities.append(opp)

print(f'✅ November 2025 opportunities: {len(november_opportunities)}\n')

# Filter for Andries and Davide
print('='*80)
print('FILTERING FOR ANDRIES & DAVIDE PIPELINES')
print('='*80 + '\n')

andries_davide_opportunities = []
for opp in november_opportunities:
    pipeline_id = opp.get('pipelineId', '')
    if pipeline_id == ANDRIES_PIPELINE_ID or pipeline_id == DAVIDE_PIPELINE_ID:
        andries_davide_opportunities.append(opp)

print(f'✅ Andries & Davide opportunities: {len(andries_davide_opportunities)}\n')

# Check for monetary values
print('='*80)
print('CHECKING MONETARY VALUES')
print('='*80 + '\n')

with_value = []
without_value = []

for opp in andries_davide_opportunities:
    monetary_value = opp.get('monetaryValue', 0)
    
    if monetary_value and monetary_value > 0:
        with_value.append(opp)
    else:
        without_value.append(opp)

print(f'📊 Summary:')
print(f'   Total Andries & Davide opportunities: {len(andries_davide_opportunities)}')
print(f'   With monetary value (> 0): {len(with_value)}')
print(f'   Without monetary value (= 0): {len(without_value)}\n')

if with_value:
    print('='*80)
    print(f'OPPORTUNITIES WITH MONETARY VALUES ({len(with_value)} total)')
    print('='*80 + '\n')
    
    # Sort by value
    with_value.sort(key=lambda x: x.get('monetaryValue', 0), reverse=True)
    
    total_value = 0
    
    for i, opp in enumerate(with_value, 1):
        name = opp.get('name', 'Unknown')
        contact_id = opp.get('contactId', 'N/A')
        monetary_value = opp.get('monetaryValue', 0)
        pipeline_id = opp.get('pipelineId', '')
        pipeline_name = 'Andries' if pipeline_id == ANDRIES_PIPELINE_ID else 'Davide'
        stage_name = opp.get('pipelineStageName', 'Unknown')
        status = opp.get('status', 'Unknown')
        created_at = opp.get('createdAt', '')
        
        print(f'{i}. {name[:40]}')
        print(f'   Contact ID: {contact_id}')
        print(f'   💰 Value: R {monetary_value:,.2f}')
        print(f'   Pipeline: {pipeline_name}')
        print(f'   Stage: {stage_name}')
        print(f'   Status: {status}')
        print(f'   Created: {created_at[:19]}')
        print()
        
        total_value += monetary_value
    
    print(f'💵 Total Value: R {total_value:,.2f}\n')
else:
    print('⚠️  No opportunities with monetary values found in November 2025!\n')
    print('This could mean:')
    print('   1. All opportunities are in early stages (before deposit)')
    print('   2. Monetary values are added in later stages')
    print('   3. No deposits/payments received yet for November leads\n')

print('='*80)
print('API CHECK COMPLETE')
print('='*80 + '\n')

