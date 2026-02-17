#!/usr/bin/env python3
"""
GHL Pipeline IDs Fetcher
Fetches all pipelines from GoHighLevel API and displays their IDs and names
"""

import requests
import time

# GHL API Configuration
GHL_API_KEY = 'pit-22f8af95-3244-41e7-9a52-22c87b166f5a'
GHL_LOCATION_ID = 'QdLXaFEqrdF0JbVbpKLw'
GHL_BASE_URL = 'https://services.leadconnectorhq.com'
GHL_API_VERSION = '2021-07-28'


def get_ghl_headers():
    return {
        'Authorization': f'Bearer {GHL_API_KEY}',
        'Version': GHL_API_VERSION,
        'Content-Type': 'application/json'
    }


def fetch_all_pipelines():
    """Fetch all pipelines from GHL API and display their IDs and names"""
    print('='*80)
    print('FETCHING ALL PIPELINES FROM GHL API')
    print('='*80 + '\n')
    
    url = f'{GHL_BASE_URL}/opportunities/pipelines'
    
    try:
        response = requests.get(
            url,
            headers=get_ghl_headers(),
            params={'locationId': GHL_LOCATION_ID},
            timeout=30
        )
        
        if response.status_code == 429:
            print('⚠️  Rate limit hit, waiting 60 seconds...')
            time.sleep(60)
            return fetch_all_pipelines()  # Retry after waiting
        
        response.raise_for_status()
        data = response.json()
        
        pipelines = data.get('pipelines', [])
        
        if pipelines:
            print(f'✅ Successfully fetched {len(pipelines)} pipelines\n')
            print('='*80)
            print('PIPELINE IDs AND NAMES')
            print('='*80 + '\n')
            
            # Display pipeline ID and name
            for idx, pipeline in enumerate(pipelines, 1):
                pipeline_id = pipeline.get('id') or pipeline.get('_id', 'N/A')
                pipeline_name = pipeline.get('name', 'Unnamed Pipeline')
                
                print(f'{idx}. {pipeline_name}')
                print(f'   ID: {pipeline_id}\n')
            
            print('='*80)
            print(f'Total pipelines: {len(pipelines)}')
            print('='*80)
            
            return pipelines
        else:
            print('⚠️  No pipelines found in response')
            return []
            
    except requests.exceptions.RequestException as e:
        print(f'❌ Error fetching pipelines: {e}')
        if hasattr(e, 'response') and e.response is not None:
            print(f'   Status Code: {e.response.status_code}')
            print(f'   Response: {e.response.text}')
        return []
    except Exception as e:
        print(f'❌ Unexpected error: {e}')
        return []


if __name__ == '__main__':
    fetch_all_pipelines()
