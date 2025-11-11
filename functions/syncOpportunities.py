#!/usr/bin/env python3
"""
Sync Opportunities from GoHighLevel API to Firebase
This script fetches opportunities from GHL and stores them in Firebase with proper UTM mapping
"""

import os
import sys
import requests
import firebase_admin
from firebase_admin import credentials, firestore
from datetime import datetime
from typing import Dict, List, Optional
import time
from dotenv import load_dotenv

# Load environment variables from .env file
load_dotenv()

# Initialize Firebase Admin SDK
try:
    cred = credentials.Certificate('../medx-ai-firebase-adminsdk-fbsvc-a86e7bd050.json')
    firebase_admin.initialize_app(cred)
except ValueError:
    # Already initialized
    pass

db = firestore.client()

# GHL API Configuration
GHL_BASE_URL = 'https://services.leadconnectorhq.com'
# Use the same API key as Cloud Functions
GHL_API_KEY = os.getenv('GHL_API_KEY', 'pit-22f8af95-3244-41e7-9a52-22c87b166f5a')
GHL_LOCATION_ID = 'QdLXaFEqrdF0JbVbpKLw'

# Pipeline IDs
ALTUS_PIPELINE_ID = 'EHPUGMqmaJU3xTunqhiH'
ANDRIES_PIPELINE_ID = 'peiM8W7lPOQkeLCGBRzP'

def get_ghl_headers():
    """Get headers for GHL API requests"""
    return {
        'Authorization': f'Bearer {GHL_API_KEY}',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Version': '2021-07-28'
    }

def normalize_name(name: str) -> str:
    """Normalize name for matching (lowercase, remove special chars)"""
    if not name:
        return ''
    return ''.join(c.lower() for c in name if c.isalnum() or c.isspace()).strip()

def extract_utm_params(opportunity: dict) -> dict:
    """
    Extract UTM parameters from opportunity attributions
    
    Client's UTM structure (NEW):
    - utm_source={{campaign.name}}
    - utm_medium={{adset.name}}
    - utm_campaign={{ad.name}}
    - fbc_id={{adset.id}}
    - h_ad_id={{ad.id}}
    
    OLD structure (backward compatibility):
    - utm_campaign={{campaign.name}}
    - utm_content={{ad.name}}
    """
    attributions = opportunity.get('attributions', [])
    if not attributions:
        return {}
    
    # Get last attribution
    last_attribution = None
    for attr in attributions:
        if attr.get('isLast'):
            last_attribution = attr
            break
    
    if not last_attribution and attributions:
        last_attribution = attributions[-1]
    
    if not last_attribution:
        return {}
    
    # Try NEW structure first, fallback to OLD
    campaign_name = last_attribution.get('utmSource') or last_attribution.get('utmCampaign') or ''
    campaign_source = last_attribution.get('utmSource') or ''
    campaign_medium = last_attribution.get('utmMedium') or ''
    ad_set_name = last_attribution.get('utmMedium') or last_attribution.get('utmAdset') or last_attribution.get('adset') or ''
    ad_id = last_attribution.get('h_ad_id') or last_attribution.get('utmAdId') or last_attribution.get('utmContent') or ''
    ad_name = last_attribution.get('utmCampaign') or last_attribution.get('utmContent') or ad_id
    
    return {
        'campaignName': campaign_name,
        'campaignSource': campaign_source,
        'campaignMedium': campaign_medium,
        'adSetName': ad_set_name,
        'adId': ad_id,
        'adName': ad_name,
        'fbclid': last_attribution.get('fbclid', ''),
        'gclid': last_attribution.get('gclid', '')
    }

def get_stage_category(stage_name: str) -> str:
    """Categorize stage based on name"""
    stage_lower = stage_name.lower()
    
    if 'appointment' in stage_lower or 'booked' in stage_lower:
        return 'bookedAppointments'
    elif 'call' in stage_lower and 'completed' in stage_lower:
        return 'callCompleted'
    elif 'deposit' in stage_lower:
        return 'deposits'
    elif 'cash' in stage_lower and 'collected' in stage_lower:
        return 'cashCollected'
    elif any(x in stage_lower for x in ['no show', 'cancelled', 'disqualified', 'lost']):
        return 'noShowCancelledDisqualified'
    else:
        return 'other'

def fetch_pipelines() -> Dict[str, dict]:
    """Fetch pipeline information from GHL"""
    print('📋 Fetching pipeline information...')
    
    try:
        response = requests.get(
            f'{GHL_BASE_URL}/opportunities/pipelines',
            headers=get_ghl_headers(),
            params={'locationId': GHL_LOCATION_ID},
            timeout=30
        )
        response.raise_for_status()
        
        pipelines_data = response.json().get('pipelines', [])
        pipelines = {}
        
        for pipeline in pipelines_data:
            pipelines[pipeline['id']] = {
                'name': pipeline['name'],
                'stages': pipeline.get('stages', [])
            }
        
        print(f'✅ Loaded {len(pipelines)} pipelines')
        return pipelines
        
    except Exception as e:
        print(f'❌ Error fetching pipelines: {e}')
        raise

def fetch_opportunities(pipeline_id: str, pipeline_name: str) -> List[dict]:
    """Fetch opportunities from a specific pipeline"""
    print(f'🔍 Fetching opportunities from {pipeline_name}...')
    
    opportunities = []
    offset = 0
    limit = 100
    
    while True:
        try:
            response = requests.get(
                f'{GHL_BASE_URL}/opportunities/search',
                headers=get_ghl_headers(),
                params={
                    'location_id': GHL_LOCATION_ID,
                    'pipeline_id': pipeline_id,
                    'limit': limit,
                    'offset': offset
                },
                timeout=30
            )
            response.raise_for_status()
            
            data = response.json()
            batch = data.get('opportunities', [])
            
            if not batch:
                break
            
            opportunities.extend(batch)
            print(f'   Fetched {len(batch)} opportunities (total: {len(opportunities)})')
            
            # Check if there are more
            if len(batch) < limit:
                break
            
            offset += limit
            time.sleep(0.5)  # Rate limiting
            
        except Exception as e:
            print(f'❌ Error fetching opportunities: {e}')
            break
    
    print(f'✅ Fetched {len(opportunities)} total opportunities from {pipeline_name}')
    return opportunities

def store_opportunity_stage(opportunity: dict, pipelines: dict) -> bool:
    """Store opportunity stage transition in Firebase"""
    try:
        opportunity_id = opportunity.get('id')
        opportunity_name = opportunity.get('name', 'Unnamed')
        pipeline_id = opportunity.get('pipelineId')
        stage_id = opportunity.get('pipelineStageId') or opportunity.get('stageId')
        
        # Get pipeline and stage info
        pipeline = pipelines.get(pipeline_id, {})
        pipeline_name = pipeline.get('name', 'Unknown Pipeline')
        
        stage = None
        for s in pipeline.get('stages', []):
            if s['id'] == stage_id:
                stage = s
                break
        
        stage_name = stage['name'] if stage else opportunity.get('pipelineStageName', 'Unknown Stage')
        stage_category = get_stage_category(stage_name)
        
        # Extract UTM parameters
        utm_params = extract_utm_params(opportunity)
        
        # Skip opportunities without campaign tracking
        if not utm_params.get('campaignName'):
            return False
        
        # Get contact and user info
        contact_id = opportunity.get('contact', {}).get('id', '')
        assigned_to = opportunity.get('assignedTo', '')
        monetary_value = float(opportunity.get('monetaryValue', 0))
        
        # Create document data
        doc_data = {
            'opportunityId': opportunity_id,
            'opportunityName': opportunity_name,
            'contactId': contact_id,
            'pipelineId': pipeline_id,
            'pipelineName': pipeline_name,
            'newStageId': stage_id,
            'newStageName': stage_name,
            'stageCategory': stage_category,
            'assignedTo': assigned_to,
            'monetaryValue': monetary_value,
            'timestamp': firestore.SERVER_TIMESTAMP,
            
            # UTM parameters
            'campaignName': utm_params.get('campaignName', ''),
            'campaignSource': utm_params.get('campaignSource', ''),
            'campaignMedium': utm_params.get('campaignMedium', ''),
            'adSetName': utm_params.get('adSetName', ''),
            'adId': utm_params.get('adId', ''),
            'adName': utm_params.get('adName', ''),
            
            # These will be populated by matching function
            'facebookAdId': '',
            'matchedAdSetId': '',
            'matchedAdSetName': '',
            
            # Status
            'status': opportunity.get('status', ''),
            'source': opportunity.get('source', '')
        }
        
        # Check if already exists
        existing = db.collection('opportunityStageHistory')\
            .where('opportunityId', '==', opportunity_id)\
            .where('newStageId', '==', stage_id)\
            .limit(1)\
            .get()
        
        if existing:
            # Already exists, skip
            return False
        
        # Store in Firebase
        db.collection('opportunityStageHistory').add(doc_data)
        return True
        
    except Exception as e:
        print(f'❌ Error storing opportunity {opportunity.get("id")}: {e}')
        return False

def main():
    """Main sync function"""
    print()
    print('=' * 80)
    print('  GOHIGHLEVEL OPPORTUNITIES SYNC')
    print('=' * 80)
    print()
    
    try:
        # Fetch pipeline information
        pipelines = fetch_pipelines()
        
        # Fetch opportunities from both pipelines
        print()
        print('🔄 Fetching opportunities from all pipelines...')
        print()
        
        all_opportunities = []
        
        # Altus Pipeline
        altus_opps = fetch_opportunities(ALTUS_PIPELINE_ID, 'Altus (Weight Loss)')
        all_opportunities.extend(altus_opps)
        
        # Andries Pipeline
        andries_opps = fetch_opportunities(ANDRIES_PIPELINE_ID, 'Andries (Wound Care)')
        all_opportunities.extend(andries_opps)
        
        print()
        print(f'📊 Total opportunities fetched: {len(all_opportunities)}')
        print()
        
        # Process and store opportunities
        print('💾 Storing opportunities in Firebase...')
        stored_count = 0
        skipped_count = 0
        
        for opp in all_opportunities:
            if store_opportunity_stage(opp, pipelines):
                stored_count += 1
                if stored_count % 10 == 0:
                    print(f'   Stored {stored_count} opportunities...')
            else:
                skipped_count += 1
        
        print()
        print('=' * 80)
        print('✅ SYNC COMPLETED!')
        print(f'   - Stored: {stored_count} new records')
        print(f'   - Skipped: {skipped_count} (duplicates or non-ad leads)')
        print(f'   - Total: {len(all_opportunities)} opportunities')
        print('=' * 80)
        print()
        
    except Exception as e:
        print()
        print('=' * 80)
        print('❌ SYNC FAILED!')
        print(f'   Error: {e}')
        print('=' * 80)
        print()
        import traceback
        traceback.print_exc()
        sys.exit(1)

if __name__ == '__main__':
    main()

