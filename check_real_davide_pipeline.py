#!/usr/bin/env python3
"""
Check the REAL Davide's Pipeline - DDM (AUduOJBB2lxlsEaNmlJz)
"""

import requests
import json

# GHL Configuration
GHL_API_KEY = 'pit-22f8af95-3244-41e7-9a52-22c87b166f5a'
GHL_LOCATION_ID = 'QdLXaFEqrdF0JbVbpKLw'
ANDRIES_PIPELINE_ID = 'XeAGJWRnUGJ5tuhXam2g'
REAL_DAVIDE_PIPELINE_ID = 'AUduOJBB2lxlsEaNmlJz'  # The REAL Davide's Pipeline
ERICH_PIPELINE_ID = 'pTbNvnrXqJc9u1oxir3q'  # This is actually Erich's pipeline
GHL_BASE_URL = 'https://services.leadconnectorhq.com'

def get_ghl_headers():
    return {
        'Authorization': f'Bearer {GHL_API_KEY}',
        'Version': '2021-07-28',
        'Content-Type': 'application/json'
    }

def fetch_pipelines():
    """Fetch all pipelines"""
    url = f'{GHL_BASE_URL}/opportunities/pipelines'
    response = requests.get(url, headers=get_ghl_headers(), params={'locationId': GHL_LOCATION_ID}, timeout=30)
    
    if response.status_code == 200:
        return response.json().get('pipelines', [])
    return []

def check_pipeline(pipeline_id, pipeline_name):
    """Check a specific pipeline's stages"""
    
    print('=' * 80)
    print(f'CHECKING: {pipeline_name}')
    print(f'ID: {pipeline_id}')
    print('=' * 80)
    print()
    
    pipelines = fetch_pipelines()
    target_pipeline = None
    
    for p in pipelines:
        if p.get('id') == pipeline_id:
            target_pipeline = p
            break
    
    if not target_pipeline:
        print(f'❌ Pipeline not found!')
        return None
    
    stages = target_pipeline.get('stages', [])
    print(f'✅ Found {len(stages)} stages')
    print()
    
    print(f'{"Stage Name":<40} {"Stage ID":<40}')
    print('-' * 85)
    
    stage_mapping = {}
    for stage in stages:
        stage_id = stage.get('id')
        stage_name = stage.get('name')
        stage_mapping[stage_id] = stage_name
        print(f'{stage_name:<40} {stage_id:<40}')
    
    print()
    
    # Check for critical stages
    critical_stages = ['Deposit Received', 'Cash Collected', 'Booked Appointments', 'Call Completed']
    found_critical = {}
    
    print('🔍 CRITICAL STAGES:')
    for critical in critical_stages:
        found = False
        for stage_id, stage_name in stage_mapping.items():
            if critical.lower() in stage_name.lower():
                found_critical[critical] = stage_id
                print(f'   ✅ {critical}: {stage_id}')
                found = True
                break
        if not found:
            print(f'   ❌ {critical}: NOT FOUND')
    
    print()
    return stage_mapping, found_critical

def fetch_sample_opportunities(pipeline_id, pipeline_name):
    """Fetch sample opportunities from a pipeline"""
    
    print('=' * 80)
    print(f'SAMPLE OPPORTUNITIES FROM: {pipeline_name}')
    print('=' * 80)
    print()
    
    url = f'{GHL_BASE_URL}/opportunities/search'
    response = requests.get(
        url,
        headers=get_ghl_headers(),
        params={'location_id': GHL_LOCATION_ID, 'limit': 100, 'page': 1},
        timeout=30
    )
    
    if response.status_code == 200:
        opportunities = response.json().get('opportunities', [])
        pipeline_opps = [o for o in opportunities if o.get('pipelineId') == pipeline_id]
        
        print(f'✅ Found {len(pipeline_opps)} opportunities')
        print()
        
        if pipeline_opps:
            print(f'{"Name":<30} {"Stage ID":<40} {"Monetary Value"}')
            print('-' * 85)
            
            for opp in pipeline_opps[:10]:
                name = opp.get('name', 'N/A')[:28]
                stage_id = opp.get('pipelineStageId', 'N/A')
                value = f"R {opp.get('monetaryValue', 0):,.2f}"
                print(f'{name:<30} {stage_id:<40} {value}')
            
            print()
            
            # Count by monetary value
            with_value = [o for o in pipeline_opps if o.get('monetaryValue', 0) > 0]
            print(f'💰 Opportunities with monetary value > 0: {len(with_value)}')
            
            if with_value:
                total_value = sum(o.get('monetaryValue', 0) for o in with_value)
                print(f'💵 Total monetary value: R {total_value:,.2f}')
                print()
                print('   Top opportunities by value:')
                sorted_opps = sorted(with_value, key=lambda x: x.get('monetaryValue', 0), reverse=True)
                for opp in sorted_opps[:5]:
                    print(f'   - {opp.get("name")}: R {opp.get("monetaryValue", 0):,.2f} (Stage: {opp.get("pipelineStageId")})')

if __name__ == '__main__':
    print('=' * 80)
    print('CHECKING ALL THREE PIPELINES')
    print('=' * 80)
    print()
    
    # Check Andries
    print('\n📊 PIPELINE 1: ANDRIES')
    andries_stages, andries_critical = check_pipeline(ANDRIES_PIPELINE_ID, 'Andries Pipeline - DDM')
    fetch_sample_opportunities(ANDRIES_PIPELINE_ID, 'Andries Pipeline - DDM')
    
    # Check REAL Davide
    print('\n\n📊 PIPELINE 2: REAL DAVIDE')
    davide_stages, davide_critical = check_pipeline(REAL_DAVIDE_PIPELINE_ID, "Davide's Pipeline - DDM")
    fetch_sample_opportunities(REAL_DAVIDE_PIPELINE_ID, "Davide's Pipeline - DDM")
    
    # Check Erich (what was thought to be Davide)
    print('\n\n📊 PIPELINE 3: ERICH (Previously thought to be Davide)')
    erich_stages, erich_critical = check_pipeline(ERICH_PIPELINE_ID, 'Erich Pipeline -DDM')
    fetch_sample_opportunities(ERICH_PIPELINE_ID, 'Erich Pipeline -DDM')
    
    # Final summary
    print('\n\n' + '=' * 80)
    print('FINAL SUMMARY')
    print('=' * 80)
    print()
    print('✅ ANDRIES PIPELINE:')
    print(f'   ID: {ANDRIES_PIPELINE_ID}')
    print(f'   Has Deposit Received: {"✅ YES" if "Deposit Received" in andries_critical else "❌ NO"}')
    print(f'   Has Cash Collected: {"✅ YES" if "Cash Collected" in andries_critical else "❌ NO"}')
    print()
    
    print('✅ REAL DAVIDE PIPELINE:')
    print(f'   ID: {REAL_DAVIDE_PIPELINE_ID}')
    print(f'   Has Deposit Received: {"✅ YES" if "Deposit Received" in davide_critical else "❌ NO"}')
    print(f'   Has Cash Collected: {"✅ YES" if "Cash Collected" in davide_critical else "❌ NO"}')
    print()
    
    print('✅ ERICH PIPELINE (was incorrectly labeled as Davide):')
    print(f'   ID: {ERICH_PIPELINE_ID}')
    print(f'   Has Deposit Received: {"✅ YES" if "Deposit Received" in erich_critical else "❌ NO"}')
    print(f'   Has Cash Collected: {"✅ YES" if "Cash Collected" in erich_critical else "❌ NO"}')
    print()
    
    print('⚠️  RECOMMENDED PIPELINE IDs FOR populate_ghl_data.py:')
    print(f'   ANDRIES_PIPELINE_ID = "{ANDRIES_PIPELINE_ID}"')
    print(f'   DAVIDE_PIPELINE_ID = "{REAL_DAVIDE_PIPELINE_ID}"  # ⭐ UPDATE THIS!')
    print(f'   # ERICH_PIPELINE_ID = "{ERICH_PIPELINE_ID}"  # Optional: if you want to track Erich too')

