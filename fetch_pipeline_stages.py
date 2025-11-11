#!/usr/bin/env python3
"""
Fetch pipeline stages from GHL API to map stage IDs to stage names
"""

import requests
import json

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

def fetch_pipeline_stages(pipeline_id, pipeline_name):
    """Fetch all stages for a specific pipeline"""
    
    print(f'\n{"=" * 80}')
    print(f'FETCHING STAGES FOR: {pipeline_name}')
    print(f'Pipeline ID: {pipeline_id}')
    print(f'{"=" * 80}\n')
    
    # Try the pipelines endpoint
    url = f'{GHL_BASE_URL}/opportunities/pipelines/{pipeline_id}'
    
    try:
        response = requests.get(url, headers=get_ghl_headers(), timeout=30)
        
        if response.status_code == 200:
            data = response.json()
            print(f'✅ Successfully fetched pipeline data\n')
            
            # Print full response for debugging
            print('📄 FULL API RESPONSE:')
            print(json.dumps(data, indent=2))
            print()
            
            # Extract stages
            pipeline = data.get('pipeline', data)
            stages = pipeline.get('stages', [])
            
            if stages:
                print(f'\n✅ FOUND {len(stages)} STAGES:\n')
                print(f'{"Stage ID":<40} {"Stage Name":<30}')
                print('-' * 80)
                
                stage_mapping = {}
                for stage in stages:
                    stage_id = stage.get('id') or stage.get('_id')
                    stage_name = stage.get('name')
                    stage_mapping[stage_id] = stage_name
                    print(f'{stage_id:<40} {stage_name:<30}')
                
                return stage_mapping
            else:
                print('⚠️  No stages found in response')
                return {}
                
        else:
            print(f'❌ Error: {response.status_code}')
            print(f'Response: {response.text}')
            return {}
            
    except Exception as e:
        print(f'❌ Exception: {e}')
        return {}

def fetch_all_pipelines():
    """Fetch all pipelines to see available data"""
    
    print(f'\n{"=" * 80}')
    print('FETCHING ALL PIPELINES')
    print(f'{"=" * 80}\n')
    
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
            print(f'✅ Successfully fetched pipelines\n')
            
            print('📄 FULL API RESPONSE:')
            print(json.dumps(data, indent=2))
            print()
            
            pipelines = data.get('pipelines', [])
            
            if pipelines:
                print(f'\n✅ FOUND {len(pipelines)} PIPELINES:\n')
                
                for pipeline in pipelines:
                    pipeline_id = pipeline.get('id') or pipeline.get('_id')
                    pipeline_name = pipeline.get('name')
                    stages = pipeline.get('stages', [])
                    
                    print(f'\n📊 Pipeline: {pipeline_name}')
                    print(f'   ID: {pipeline_id}')
                    print(f'   Stages: {len(stages)}')
                    
                    if stages:
                        print(f'\n   {"Stage ID":<40} {"Stage Name":<30}')
                        print('   ' + '-' * 78)
                        for stage in stages:
                            stage_id = stage.get('id') or stage.get('_id')
                            stage_name = stage.get('name')
                            print(f'   {stage_id:<40} {stage_name:<30}')
            
            return data
            
        else:
            print(f'❌ Error: {response.status_code}')
            print(f'Response: {response.text}')
            return None
            
    except Exception as e:
        print(f'❌ Exception: {e}')
        return None

if __name__ == '__main__':
    print('=' * 80)
    print('GHL PIPELINE STAGES FETCHER')
    print('=' * 80)
    
    # First, try to fetch all pipelines
    all_pipelines_data = fetch_all_pipelines()
    
    print('\n\n')
    
    # Then try individual pipeline fetches
    andries_stages = fetch_pipeline_stages(ANDRIES_PIPELINE_ID, 'Andries Pipeline - DDM')
    
    print('\n\n')
    
    davide_stages = fetch_pipeline_stages(DAVIDE_PIPELINE_ID, 'Davide Pipeline')
    
    # Save the mappings to a file
    if andries_stages or davide_stages:
        print('\n' + '=' * 80)
        print('SAVING STAGE MAPPINGS TO FILE')
        print('=' * 80)
        
        mappings = {
            'andries': {
                'pipeline_id': ANDRIES_PIPELINE_ID,
                'pipeline_name': 'Andries Pipeline - DDM',
                'stages': andries_stages
            },
            'davide': {
                'pipeline_id': DAVIDE_PIPELINE_ID,
                'pipeline_name': 'Davide Pipeline',
                'stages': davide_stages
            }
        }
        
        with open('/Users/mac/dev/medwave/ghl_info/pipeline_stage_mappings.json', 'w') as f:
            json.dump(mappings, f, indent=2)
        
        print('\n✅ Saved to: /Users/mac/dev/medwave/ghl_info/pipeline_stage_mappings.json')
    
    print('\n' + '=' * 80)
    print('COMPLETE')
    print('=' * 80)

