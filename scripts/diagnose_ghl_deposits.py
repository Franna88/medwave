#!/usr/bin/env python3
"""
Diagnostic script to query GHL API and analyze pipeline data
Focuses on Deposit Received and Cash Collected stages
"""

import os
import requests
import json
from datetime import datetime
from collections import defaultdict

# GHL API Configuration
GHL_API_KEY = os.environ.get('GHL_API_KEY')
GHL_BASE_URL = 'https://services.leadconnectorhq.com'
LOCATION_ID = 'QdLXaFEqrdF0JbVbpKLw'

# Pipeline IDs
ANDRIES_PIPELINE_ID = 'XeAGJWRnUGJ5tuhXam2g'  # Andries Pipeline - DDM
DAVIDE_PIPELINE_ID = 'AUduOJBB2lxlsEaNmlJz'   # Davide's Pipeline - DDM

# Headers for GHL API
def get_headers():
    return {
        'Authorization': f'Bearer {GHL_API_KEY}',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Version': '2021-07-28'
    }

def fetch_pipelines():
    """Fetch all pipelines to get stage information"""
    print("📋 Fetching pipelines from GHL API...")
    
    url = f"{GHL_BASE_URL}/opportunities/pipelines"
    params = {'locationId': LOCATION_ID}
    
    response = requests.get(url, headers=get_headers(), params=params)
    response.raise_for_status()
    
    data = response.json()
    pipelines = data.get('pipelines', [])
    
    print(f"✅ Found {len(pipelines)} pipelines")
    return pipelines

def fetch_opportunities(pipeline_id, pipeline_name):
    """Fetch all opportunities for a given pipeline with pagination"""
    print(f"\n🔍 Fetching opportunities for {pipeline_name}...")
    
    url = f"{GHL_BASE_URL}/opportunities/search"
    all_opportunities = []
    seen_ids = set()
    page = 1
    last_cursor = None
    
    # Initial request
    params = {
        'location_id': LOCATION_ID,
        'pipeline_id': pipeline_id,
        'limit': 100
    }
    
    # Pagination support
    while True:
        response = requests.get(url, headers=get_headers(), params=params)
        response.raise_for_status()
        
        data = response.json()
        opportunities = data.get('opportunities', [])
        
        # Filter out duplicates
        new_opportunities = []
        for opp in opportunities:
            opp_id = opp.get('id')
            if opp_id and opp_id not in seen_ids:
                seen_ids.add(opp_id)
                new_opportunities.append(opp)
        
        all_opportunities.extend(new_opportunities)
        
        print(f"  📦 Page {page}: Fetched {len(opportunities)} opportunities ({len(new_opportunities)} new, total: {len(all_opportunities)})")
        
        # Stop if no new opportunities
        if len(new_opportunities) == 0:
            print(f"  ✅ No new opportunities, pagination complete")
            break
        
        # Check for pagination
        meta = data.get('meta', {})
        next_page = meta.get('nextPage')
        
        # Stop if no next page
        if not next_page:
            print(f"  ✅ No next page, pagination complete")
            break
        
        # Get cursor values from meta
        start_after_id = meta.get('startAfterId')
        start_after = meta.get('startAfter')
        
        # Stop if no cursors or same cursors as before (loop detected)
        if not start_after_id or (last_cursor and start_after_id == last_cursor):
            break
        
        last_cursor = start_after_id
        params['startAfterId'] = start_after_id
        params['startAfter'] = start_after
        page += 1
        
        # Safety limit to prevent infinite loops
        if page > 15:
            print(f"  ⚠️  Reached page limit (15), stopping pagination")
            break
    
    print(f"✅ Total unique opportunities fetched: {len(all_opportunities)}")
    return all_opportunities

def match_stage_category(stage_name):
    """Match stage name to category"""
    if not stage_name:
        return 'other'
    
    stage_lower = stage_name.lower()
    
    # Exact matches first
    if stage_lower == 'booked appointments' or 'booked appointment' in stage_lower:
        return 'bookedAppointments'
    if stage_lower == 'call completed' or 'call completed' in stage_lower:
        return 'callCompleted'
    if stage_lower == 'no show' or 'no show' in stage_lower:
        return 'noShowCancelledDisqualified'
    if stage_lower == 'deposit received' or 'deposit received' in stage_lower:
        return 'deposits'
    if stage_lower == 'cash collected' or 'cash collected' in stage_lower:
        return 'cashCollected'
    
    # Keyword fallbacks
    if 'booked' in stage_lower or 'appointment' in stage_lower or 'scheduled' in stage_lower:
        return 'bookedAppointments'
    if 'call' in stage_lower and 'completed' in stage_lower:
        return 'callCompleted'
    if 'cancel' in stage_lower or 'disqualif' in stage_lower or 'lost' in stage_lower:
        return 'noShowCancelledDisqualified'
    if 'deposit' in stage_lower:
        return 'deposits'
    if 'cash' in stage_lower and 'collect' in stage_lower:
        return 'cashCollected'
    if 'sold' in stage_lower or 'purchased' in stage_lower or 'payment received' in stage_lower:
        return 'cashCollected'
    
    return 'other'

def analyze_pipeline(pipeline_id, pipeline_name, stage_id_to_name):
    """Analyze a single pipeline's opportunities"""
    opportunities = fetch_opportunities(pipeline_id, pipeline_name)
    
    # Stats by stage category
    stats = defaultdict(list)
    
    for opp in opportunities:
        stage_id = opp.get('pipelineStageId', '')
        stage_name = stage_id_to_name.get(stage_id, 'Unknown')
        category = match_stage_category(stage_name)
        
        opp_info = {
            'id': opp.get('id'),
            'name': opp.get('name'),
            'stage_id': stage_id,
            'stage_name': stage_name,
            'contact_id': opp.get('contact', {}).get('id'),
            'assigned_to': opp.get('assignedTo'),
            'monetary_value': opp.get('monetaryValue', 0),
            'last_status_change': opp.get('lastStatusChangeAt'),
            'date_added': opp.get('dateAdded'),
            'source': opp.get('source')
        }
        
        stats[category].append(opp_info)
    
    return stats

def main():
    """Main diagnostic function"""
    print("=" * 80)
    print("GHL DEPOSITS & CASH COLLECTED DIAGNOSTIC")
    print("=" * 80)
    
    if not GHL_API_KEY:
        print("❌ ERROR: GHL_API_KEY environment variable not set!")
        print("   Set it with: export GHL_API_KEY='your_api_key_here'")
        return
    
    try:
        # Fetch pipelines to get stage mappings
        pipelines = fetch_pipelines()
        
        # Build stage ID to name mapping
        stage_id_to_name = {}
        andries_pipeline = None
        davide_pipeline = None
        
        for pipeline in pipelines:
            if pipeline['id'] == ANDRIES_PIPELINE_ID:
                andries_pipeline = pipeline
            elif pipeline['id'] == DAVIDE_PIPELINE_ID:
                davide_pipeline = pipeline
            
            for stage in pipeline.get('stages', []):
                stage_id_to_name[stage['id']] = stage['name']
        
        print(f"\n✅ Built stage mapping with {len(stage_id_to_name)} stages")
        
        # Analyze both pipelines
        results = {}
        
        if andries_pipeline:
            print("\n" + "=" * 80)
            print(f"ANALYZING: {andries_pipeline['name']}")
            print("=" * 80)
            results['andries'] = analyze_pipeline(
                ANDRIES_PIPELINE_ID,
                andries_pipeline['name'],
                stage_id_to_name
            )
        else:
            print(f"\n⚠️  Warning: Andries Pipeline not found!")
        
        if davide_pipeline:
            print("\n" + "=" * 80)
            print(f"ANALYZING: {davide_pipeline['name']}")
            print("=" * 80)
            results['davide'] = analyze_pipeline(
                DAVIDE_PIPELINE_ID,
                davide_pipeline['name'],
                stage_id_to_name
            )
        else:
            print(f"\n⚠️  Warning: Davide Pipeline not found!")
        
        # Generate summary report
        print("\n" + "=" * 80)
        print("SUMMARY REPORT")
        print("=" * 80)
        
        for pipeline_key, stats in results.items():
            pipeline_name = "Andries Pipeline" if pipeline_key == 'andries' else "Davide Pipeline"
            print(f"\n📊 {pipeline_name}:")
            print(f"  Total Opportunities: {sum(len(opps) for opps in stats.values())}")
            print(f"  Booked Appointments: {len(stats['bookedAppointments'])}")
            print(f"  Call Completed: {len(stats['callCompleted'])}")
            print(f"  No Show/Cancelled: {len(stats['noShowCancelledDisqualified'])}")
            print(f"  🎯 Deposit Received: {len(stats['deposits'])}")
            print(f"  🎯 Cash Collected: {len(stats['cashCollected'])}")
            print(f"  Other stages: {len(stats['other'])}")
        
        # Detailed deposit and cash information
        print("\n" + "=" * 80)
        print("DETAILED: DEPOSIT RECEIVED")
        print("=" * 80)
        
        for pipeline_key, stats in results.items():
            pipeline_name = "Andries" if pipeline_key == 'andries' else "Davide"
            deposits = stats['deposits']
            
            if deposits:
                print(f"\n📋 {pipeline_name} Pipeline - {len(deposits)} Deposits:")
                for opp in deposits:
                    print(f"  • {opp['name']}")
                    print(f"    ID: {opp['id']}")
                    print(f"    Stage: {opp['stage_name']}")
                    print(f"    Value: R{opp['monetary_value']}")
                    print(f"    Last Changed: {opp['last_status_change']}")
                    print()
        
        print("\n" + "=" * 80)
        print("DETAILED: CASH COLLECTED")
        print("=" * 80)
        
        for pipeline_key, stats in results.items():
            pipeline_name = "Andries" if pipeline_key == 'andries' else "Davide"
            cash = stats['cashCollected']
            
            if cash:
                print(f"\n📋 {pipeline_name} Pipeline - {len(cash)} Cash Collected:")
                for opp in cash:
                    print(f"  • {opp['name']}")
                    print(f"    ID: {opp['id']}")
                    print(f"    Stage: {opp['stage_name']}")
                    print(f"    Value: R{opp['monetary_value']}")
                    print(f"    Last Changed: {opp['last_status_change']}")
                    print()
        
        # Save results to JSON file
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        output_file = f"ghl_diagnostic_report_{timestamp}.json"
        
        with open(output_file, 'w') as f:
            json.dump(results, f, indent=2, default=str)
        
        print("\n" + "=" * 80)
        print(f"✅ Report saved to: {output_file}")
        print("=" * 80)
        
    except Exception as e:
        print(f"\n❌ ERROR: {e}")
        import traceback
        traceback.print_exc()

if __name__ == '__main__':
    main()

