#!/usr/bin/env python3
"""
Verify Davide Pipeline Stage IDs and compare with Andries Pipeline
Check if stage IDs differ between pipelines
"""

import requests
import json

# GHL Configuration
GHL_API_KEY = 'pit-22f8af95-3244-41e7-9a52-22c87b166f5a'
GHL_LOCATION_ID = 'QdLXaFEqrdF0JbVbpKLw'
ANDRIES_PIPELINE_ID = 'XeAGJWRnUGJ5tuhXam2g'
DAVIDE_PIPELINE_ID = 'pTbNvnrXqJc9u1oxir3q'  # From your code
DAVIDE_PIPELINE_ID_ALT = 'AUduOJBB2lxlsEaNmlJz'  # From API response
GHL_BASE_URL = 'https://services.leadconnectorhq.com'

def get_ghl_headers():
    return {
        'Authorization': f'Bearer {GHL_API_KEY}',
        'Version': '2021-07-28',
        'Content-Type': 'application/json'
    }

def fetch_all_pipelines():
    """Fetch all pipelines to find Davide's pipeline"""
    
    print('=' * 80)
    print('FETCHING ALL PIPELINES TO FIND DAVIDE')
    print('=' * 80)
    print()
    
    url = f'{GHL_BASE_URL}/opportunities/pipelines'
    
    try:
        response = requests.get(
            url, 
            headers=get_ghl_headers(),
            params={'locationId': GHL_LOCATION_ID},
            timeout=30
        )
        
        if response.status_code == 200:
            data = response.json()
            pipelines = data.get('pipelines', [])
            
            print(f'✅ Found {len(pipelines)} pipelines\n')
            
            # Find all pipelines with "Davide" in the name
            davide_pipelines = []
            for pipeline in pipelines:
                pipeline_id = pipeline.get('id')
                pipeline_name = pipeline.get('name', '')
                
                if 'davide' in pipeline_name.lower():
                    davide_pipelines.append(pipeline)
                    print(f'🔍 FOUND DAVIDE PIPELINE:')
                    print(f'   Name: {pipeline_name}')
                    print(f'   ID: {pipeline_id}')
                    print()
            
            return pipelines, davide_pipelines
            
        else:
            print(f'❌ Error: {response.status_code}')
            print(f'Response: {response.text}')
            return [], []
            
    except Exception as e:
        print(f'❌ Exception: {e}')
        return [], []

def compare_pipelines(pipelines):
    """Compare Andries and Davide pipeline stages"""
    
    print('=' * 80)
    print('COMPARING ANDRIES AND DAVIDE PIPELINE STAGES')
    print('=' * 80)
    print()
    
    andries_pipeline = None
    davide_pipeline = None
    
    for pipeline in pipelines:
        pipeline_id = pipeline.get('id')
        if pipeline_id == ANDRIES_PIPELINE_ID:
            andries_pipeline = pipeline
        elif pipeline_id in [DAVIDE_PIPELINE_ID, DAVIDE_PIPELINE_ID_ALT]:
            davide_pipeline = pipeline
    
    if not andries_pipeline:
        print('❌ Andries Pipeline not found!')
        return
    
    if not davide_pipeline:
        print('❌ Davide Pipeline not found!')
        print(f'   Tried IDs: {DAVIDE_PIPELINE_ID}, {DAVIDE_PIPELINE_ID_ALT}')
        return
    
    print(f'✅ ANDRIES PIPELINE: {andries_pipeline.get("name")}')
    print(f'   ID: {andries_pipeline.get("id")}')
    print(f'   Stages: {len(andries_pipeline.get("stages", []))}')
    print()
    
    print(f'✅ DAVIDE PIPELINE: {davide_pipeline.get("name")}')
    print(f'   ID: {davide_pipeline.get("id")}')
    print(f'   Stages: {len(davide_pipeline.get("stages", []))}')
    print()
    
    # Extract stages
    andries_stages = {s.get('name'): s.get('id') for s in andries_pipeline.get('stages', [])}
    davide_stages = {s.get('name'): s.get('id') for s in davide_pipeline.get('stages', [])}
    
    # Find common stage names
    common_names = set(andries_stages.keys()) & set(davide_stages.keys())
    andries_only = set(andries_stages.keys()) - set(davide_stages.keys())
    davide_only = set(davide_stages.keys()) - set(andries_stages.keys())
    
    print('=' * 80)
    print('STAGE COMPARISON RESULTS')
    print('=' * 80)
    print()
    
    if common_names:
        print(f'🔍 COMMON STAGE NAMES ({len(common_names)}):')
        print()
        print(f'{"Stage Name":<40} {"Andries ID":<40} {"Davide ID":<40} {"Same?"}')
        print('-' * 125)
        
        for stage_name in sorted(common_names):
            andries_id = andries_stages[stage_name]
            davide_id = davide_stages[stage_name]
            same = '✅ YES' if andries_id == davide_id else '❌ NO - DIFFERENT!'
            
            print(f'{stage_name:<40} {andries_id:<40} {davide_id:<40} {same}')
        
        print()
    
    if andries_only:
        print(f'\n📊 STAGES ONLY IN ANDRIES ({len(andries_only)}):')
        print(f'{"Stage Name":<40} {"Stage ID":<40}')
        print('-' * 85)
        for stage_name in sorted(andries_only):
            print(f'{stage_name:<40} {andries_stages[stage_name]:<40}')
        print()
    
    if davide_only:
        print(f'\n📊 STAGES ONLY IN DAVIDE ({len(davide_only)}):')
        print(f'{"Stage Name":<40} {"Stage ID":<40}')
        print('-' * 85)
        for stage_name in sorted(davide_only):
            print(f'{stage_name:<40} {davide_stages[stage_name]:<40}')
        print()
    
    # Check critical stages
    print('=' * 80)
    print('CRITICAL STAGES CHECK (Deposit Received, Cash Collected)')
    print('=' * 80)
    print()
    
    critical_stages = ['Deposit Received', 'Cash Collected', 'Booked Appointments', 'Call Completed']
    
    for stage_name in critical_stages:
        andries_id = andries_stages.get(stage_name, 'NOT FOUND')
        davide_id = davide_stages.get(stage_name, 'NOT FOUND')
        
        print(f'🔍 {stage_name}:')
        print(f'   Andries: {andries_id}')
        print(f'   Davide:  {davide_id}')
        
        if andries_id != 'NOT FOUND' and davide_id != 'NOT FOUND':
            if andries_id == davide_id:
                print(f'   ✅ SAME ID - Can use single mapping')
            else:
                print(f'   ❌ DIFFERENT IDs - Must use separate mappings!')
        elif andries_id == 'NOT FOUND':
            print(f'   ⚠️  Not found in Andries')
        elif davide_id == 'NOT FOUND':
            print(f'   ⚠️  Not found in Davide')
        
        print()
    
    # Return the correct Davide pipeline ID
    return davide_pipeline.get('id')

def fetch_sample_davide_opportunities(correct_davide_id):
    """Fetch sample opportunities from Davide pipeline to verify stage IDs"""
    
    print('=' * 80)
    print('FETCHING SAMPLE OPPORTUNITIES FROM DAVIDE PIPELINE')
    print('=' * 80)
    print()
    
    url = f'{GHL_BASE_URL}/opportunities/search'
    
    try:
        response = requests.get(
            url,
            headers=get_ghl_headers(),
            params={
                'location_id': GHL_LOCATION_ID,
                'limit': 100,
                'page': 1
            },
            timeout=30
        )
        
        if response.status_code == 200:
            data = response.json()
            opportunities = data.get('opportunities', [])
            
            # Filter to Davide pipeline
            davide_opps = [o for o in opportunities if o.get('pipelineId') == correct_davide_id]
            
            print(f'✅ Found {len(davide_opps)} Davide opportunities in first 100')
            print()
            
            if davide_opps:
                print('📊 SAMPLE DAVIDE OPPORTUNITIES:')
                print(f'{"Name":<30} {"Stage ID":<40} {"Monetary Value"}')
                print('-' * 85)
                
                for opp in davide_opps[:10]:  # Show first 10
                    name = opp.get('name', 'N/A')[:28]
                    stage_id = opp.get('pipelineStageId', 'N/A')
                    value = f"R {opp.get('monetaryValue', 0):,.2f}"
                    
                    print(f'{name:<30} {stage_id:<40} {value}')
                
                print()
                
                # Check if any are in Deposit Received or Cash Collected
                deposit_stage_ids = ['13d54d18-d1e7-476b-aad8-cb4767b8b979']  # From API
                cash_stage_ids = ['3c89afba-9797-4b0f-947c-ba00b60468c6']  # From API
                
                deposits = [o for o in davide_opps if o.get('pipelineStageId') in deposit_stage_ids]
                cash_collected = [o for o in davide_opps if o.get('pipelineStageId') in cash_stage_ids]
                
                print(f'💰 Opportunities in "Deposit Received": {len(deposits)}')
                print(f'💵 Opportunities in "Cash Collected": {len(cash_collected)}')
                
                if deposits:
                    print(f'\n   Sample Deposits:')
                    for opp in deposits[:3]:
                        print(f'   - {opp.get("name")}: R {opp.get("monetaryValue", 0):,.2f}')
                
                if cash_collected:
                    print(f'\n   Sample Cash Collected:')
                    for opp in cash_collected[:3]:
                        print(f'   - {opp.get("name")}: R {opp.get("monetaryValue", 0):,.2f}')
            
            else:
                print('⚠️  No Davide opportunities found in first 100')
                print(f'   Pipeline ID used: {correct_davide_id}')
        
        else:
            print(f'❌ Error: {response.status_code}')
            
    except Exception as e:
        print(f'❌ Exception: {e}')

if __name__ == '__main__':
    print('=' * 80)
    print('DAVIDE PIPELINE STAGE VERIFICATION')
    print('=' * 80)
    print()
    
    # Step 1: Fetch all pipelines
    all_pipelines, davide_pipelines = fetch_all_pipelines()
    
    if not all_pipelines:
        print('❌ Failed to fetch pipelines')
        exit(1)
    
    # Step 2: Compare Andries and Davide stages
    correct_davide_id = compare_pipelines(all_pipelines)
    
    if not correct_davide_id:
        print('❌ Could not find Davide pipeline')
        exit(1)
    
    print()
    print('=' * 80)
    print(f'✅ CORRECT DAVIDE PIPELINE ID: {correct_davide_id}')
    print('=' * 80)
    print()
    
    # Step 3: Fetch sample opportunities
    fetch_sample_davide_opportunities(correct_davide_id)
    
    print()
    print('=' * 80)
    print('VERIFICATION COMPLETE')
    print('=' * 80)
    print()
    
    # Summary
    print('📋 SUMMARY:')
    print(f'   Andries Pipeline ID: {ANDRIES_PIPELINE_ID}')
    print(f'   Davide Pipeline ID:  {correct_davide_id}')
    print()
    print('⚠️  ACTION REQUIRED:')
    print(f'   Update populate_ghl_data.py if Davide ID is: {DAVIDE_PIPELINE_ID_ALT}')
    print(f'   Current value in code: {DAVIDE_PIPELINE_ID}')
    
    if correct_davide_id != DAVIDE_PIPELINE_ID:
        print()
        print('   ❌ MISMATCH DETECTED!')
        print(f'   Change DAVIDE_PIPELINE_ID from:')
        print(f'   OLD: {DAVIDE_PIPELINE_ID}')
        print(f'   NEW: {correct_davide_id}')

