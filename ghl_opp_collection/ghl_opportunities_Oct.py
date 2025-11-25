#!/usr/bin/env python3
"""
GHL Opportunities Collection - October 2025
Fetches all GHL opportunities for October 2025 and stores them in Firestore collection 'ghl_opportunities'
Each opportunity is stored with its contactId as the document ID
"""

import requests
import firebase_admin
from firebase_admin import credentials, firestore
from datetime import datetime
import time
import json

# Initialize Firebase
try:
    cred = credentials.Certificate('/Users/mac/dev/medwave/medx-ai-firebase-adminsdk-fbsvc-a86e7bd050.json')
    firebase_admin.initialize_app(cred)
    print('✅ Firebase initialized successfully\n')
except Exception as e:
    print(f'⚠️  Firebase already initialized or error: {e}\n')
    pass

db = firestore.client()

# GHL API Configuration
GHL_API_KEY = 'pit-22f8af95-3244-41e7-9a52-22c87b166f5a'
GHL_LOCATION_ID = 'QdLXaFEqrdF0JbVbpKLw'
GHL_BASE_URL = 'https://services.leadconnectorhq.com'
GHL_API_VERSION = '2021-07-28'

# Pipeline IDs (Only Andries and Davide)
ANDRIES_PIPELINE_ID = 'XeAGJWRnUGJ5tuhXam2g'
DAVIDE_PIPELINE_ID = 'AUduOJBB2lxlsEaNmlJz'

# Date range for October 2025
START_DATE = '2025-10-01T00:00:00.000Z'
END_DATE = '2025-10-31T23:59:59.999Z'

# Stage mappings
STAGE_MAPPINGS = {
    'andries': {
        "9861ef30-81b6-49dc-ba4b-061ef194dcf9": "Booked Appointments",
        "00567f7d-293b-4438-8172-76531a225b76": "Call Completed",
        "0c0295b4-de16-41c1-94a2-e10ba396b55f": "No Show",
        "e1fc9820-f8b2-47b2-94d1-e245735cb2af": "Reschedule",
        "4bb7f632-aafc-4583-acd1-4e2875b590e3": "Follow Up Day 1",
        "a948f859-581e-48cf-b4d1-9ddd153bcdb5": "Follow Up Day 2",
        "dfa4be3d-d313-40b5-9ce9-6fac713d75c0": "Follow Up Day 3",
        "c2c86962-4d3e-42de-892e-b413e32f4f81": "Follow Up Day 4",
        "895d3cdd-b7a3-489d-9431-cc2b3d96b3fa": "Follow Up Day 5",
        "7b5cbe61-76ff-4776-9144-c71942daeaed": "Follow Up Day 6",
        "22c12a3a-a131-458c-b5a4-132ce568e105": "Follow Up Day 7",
        "b008f699-0ebf-43f6-9dc4-14efd430be48": "Follow Up Day 8",
        "e73275e7-7527-497e-b449-91ee245b5bf9": "Follow Up Day 9",
        "3eae3984-2343-43d8-96a4-6502e7f37af7": "Follow Up Day 10",
        "6e763bab-3ffb-4f5b-902f-a3dba5cc39c8": "Follow Up Day 11",
        "98afdd3c-2865-4015-a24c-692ac7daa220": "Follow Up Day 12",
        "0aa7f895-557d-4f53-a3d8-29b4f9805238": "Follow Up Day 13",
        "77c46b81-5a95-40ee-a7a9-36a5d5fdf7ae": "Follow Up Day 14",
        "190ec8c7-7673-4d8d-8ab4-b4cd6952f926": "Follow Up Day 15",
        "c861b50f-b0cc-4ee2-b8e7-03d81b32f53b": "Follow Up Day 16",
        "b4dbc120-12e2-4215-b4fa-3f51be8591cb": "Follow Up Day 17",
        "405640a0-2ba6-4025-828d-212347aede66": "Follow Up Day 18",
        "0700f5c9-0b70-420c-b52b-4107e30a850c": "Follow Up Day 19",
        "8ff3ec64-2058-422a-a52f-8a1ce9451a8f": "Follow Up Day 20",
        "4df5b2d3-b6fb-478c-96b4-a8c565c69940": "9. Long Term Leads (Twice Per Week)",
        "f82c7a4f-aceb-4657-9007-76c1c92641d2": "10. Andries Upfront Disqualified",
        "52a076ca-851f-43fc-a57d-309403a4b208": "Deposit Received",
        "3a8ead84-92b0-4796-aaf8-6594c3217a2c": "Cash Collected",
        "0b3e496e-cb24-4fdb-8d4f-7c5c84e94aae": "12. DND Leads👎",
        "89c988f9-f8af-4b3d-8109-66984a81d1f7": "13. USA Sales Calls Completed"
    },
    'davide': {
        "003d5559-d057-4e9b-8a77-525acecfb6c8": "Booked Appointments",
        "f38bbbc9-93e2-4e74-8238-f8bb456aaa92": "Call Completed",
        "90057d46-3e3a-4e6a-8134-e823c2a9cbea": "No Show/Cancelled/Disqualified",
        "246be3bc-ecc8-4981-ab33-d08842b5fdf9": "Follow Up Day 1",
        "6765b763-f44b-4f20-bb19-7df3b22dbf3f": "Follow Up Day 2",
        "099fa206-a8a1-4a1b-96bb-d03779846148": "Follow Up Day 3",
        "11876e11-62c6-4b3c-bc24-042515209273": "Follow Up Day 4",
        "3d5e8c67-c469-404c-adf5-dce22cc09dba": "Follow Up Day 5",
        "d30da05d-995d-406f-8ccc-974290eb4aa8": "Follow Up Day 6",
        "b545d3e1-8a20-4f1d-98b7-d1d58d7a4aaf": "Follow Up Day 7",
        "4048b4c4-91c4-49e0-9238-e39963739b38": "(DD) FU - Long Term",
        "13d54d18-d1e7-476b-aad8-cb4767b8b979": "Deposit Received",
        "3c89afba-9797-4b0f-947c-ba00b60468c6": "Cash Collected",
        "bf84e424-6e90-46a7-886f-a90eed27bbe6": "(DD) Leads",
        "c9c5cdfb-23c4-45d1-bd66-b11cbe33b449": "Lost"
    }
}


def get_ghl_headers():
    return {
        'Authorization': f'Bearer {GHL_API_KEY}',
        'Version': GHL_API_VERSION,
        'Content-Type': 'application/json'
    }

def get_stage_name(pipeline_id, stage_id):
    """Get the stage name based on pipeline and stage ID"""
    if pipeline_id == ANDRIES_PIPELINE_ID:
        return STAGE_MAPPINGS['andries'].get(stage_id, 'Unknown Stage')
    elif pipeline_id == DAVIDE_PIPELINE_ID:
        return STAGE_MAPPINGS['davide'].get(stage_id, 'Unknown Stage')
    else:
        return 'Unknown Stage'


def fetch_all_october_opportunities():
    """Fetch all opportunities for October 2025 (Andries and Davide only)"""
    print('='*80)
    print('GHL OPPORTUNITIES COLLECTION - OCTOBER 2025')
    print('='*80 + '\n')
    
    print(f'📅 Date Range: {START_DATE[:10]} to {END_DATE[:10]}')
    print(f'🎯 Location ID: {GHL_LOCATION_ID}')
    print(f'📊 API Version: {GHL_API_VERSION}')
    print(f'👥 Pipelines: Andries & Davide ONLY\n')
    
    # Step 1: Fetch all opportunities
    print('='*80)
    print('STEP 1: FETCHING ALL OPPORTUNITIES FROM GHL')
    print('='*80 + '\n')
    
    url = f'{GHL_BASE_URL}/opportunities/search'
    all_opportunities = []
    
    # GHL Opportunities API uses page-based pagination
    params = {
        'location_id': GHL_LOCATION_ID,
        'limit': 100,
        'page': 1
    }
    
    page = 1
    
    while True:
        print(f'📄 Fetching page {page}...')
        params['page'] = page
        
        try:
            response = requests.get(url, headers=get_ghl_headers(), params=params, timeout=30)
            
            # Handle rate limiting
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
            
            # Check if there are more pages
            meta = data.get('meta', {})
            total = meta.get('total', 0)
            current_count = page * 100
            
            if current_count >= total:
                print(f'   ✅ Reached last page (Total: {total})\n')
                break
            
            page += 1
            
            # Be nice to the API
            time.sleep(0.5)
            
        except Exception as e:
            print(f'   ❌ Error fetching opportunities: {e}')
            print(f'   Continuing with {len(all_opportunities)} opportunities fetched so far...\n')
            break
    
    print(f'✅ Total opportunities fetched: {len(all_opportunities)}\n')
    
    # Filter for October 2025 opportunities
    print('='*80)
    print('STEP 2: FILTERING FOR OCTOBER 2025 OPPORTUNITIES')
    print('='*80 + '\n')
    
    october_opportunities = []
    for opportunity in all_opportunities:
        created_at = opportunity.get('createdAt', '')
        if created_at:
            # Check if createdAt is in October 2025
            if created_at >= START_DATE and created_at <= END_DATE:
                october_opportunities.append(opportunity)
    
    print(f'✅ Opportunities in October 2025: {len(october_opportunities)}')
    print(f'⚠️  Opportunities outside October: {len(all_opportunities) - len(october_opportunities)}\n')
    
    # Filter for Andries and Davide pipelines only
    print('='*80)
    print('STEP 3: FILTERING FOR ANDRIES & DAVIDE PIPELINES')
    print('='*80 + '\n')
    
    andries_davide_opportunities = []
    other_pipeline_count = 0
    
    for opp in october_opportunities:
        pipeline_id = opp.get('pipelineId', '')
        if pipeline_id == ANDRIES_PIPELINE_ID or pipeline_id == DAVIDE_PIPELINE_ID:
            andries_davide_opportunities.append(opp)
        else:
            other_pipeline_count += 1
    
    print(f'✅ Andries opportunities: {sum(1 for o in andries_davide_opportunities if o.get("pipelineId") == ANDRIES_PIPELINE_ID)}')
    print(f'✅ Davide opportunities: {sum(1 for o in andries_davide_opportunities if o.get("pipelineId") == DAVIDE_PIPELINE_ID)}')
    print(f'⚠️  Other pipelines (excluded): {other_pipeline_count}')
    print(f'📊 Total to store: {len(andries_davide_opportunities)}\n')
    
    # Verify date range
    if andries_davide_opportunities:
        print(f'📅 Verifying date range of filtered opportunities...')
        dates = []
        for opp in andries_davide_opportunities[:5]:
            created_at = opp.get('createdAt', '')
            if created_at:
                dates.append(created_at[:10])
        
        if dates:
            all_dates = [o.get('createdAt', '')[:10] for o in andries_davide_opportunities if o.get('createdAt')]
            print(f'   Sample dates: {", ".join(dates)}')
            if all_dates:
                print(f'   Earliest: {min(all_dates)}')
                print(f'   Latest: {max(all_dates)}\n')
    
    # Step 4: Store in Firestore
    print('='*80)
    print('STEP 4: STORING IN FIRESTORE COLLECTION "ghl_opportunities"')
    print('='*80 + '\n')
    
    stored_count = 0
    skipped_count = 0
    error_count = 0
    
    # Store each opportunity with contactId as document ID
    for opportunity in andries_davide_opportunities:
        try:
            contact_id = opportunity.get('contactId')
            
            if not contact_id:
                skipped_count += 1
                print(f'⚠️  Skipped opportunity without contactId: {opportunity.get("id", "Unknown")}')
                continue
            
            # Extract key fields for easy access
            opportunity_id = opportunity.get('id')
            name = opportunity.get('name', 'Unknown')
            monetary_value = opportunity.get('monetaryValue', 0)
            pipeline_id = opportunity.get('pipelineId', '')
            pipeline_stage_id = opportunity.get('pipelineStageId', '')
            status = opportunity.get('status', 'Unknown')
            created_at = opportunity.get('createdAt', '')
            updated_at = opportunity.get('updatedAt', '')
            source = opportunity.get('source', 'Unknown')
            
            # Extract contact info
            contact = opportunity.get('contact', {})
            contact_name = contact.get('name', name)
            contact_email = contact.get('email', '')
            contact_phone = contact.get('phone', '')
            
            # Extract attribution data
            attributions = opportunity.get('attributions', [])
            
            # Get stage name based on pipeline and stage ID
            stage_name = get_stage_name(pipeline_id, pipeline_stage_id)
            
            # Create document data
            doc_data = {
                'opportunityId': opportunity_id,
                'contactId': contact_id,
                'name': name,
                'contactName': contact_name,
                'contactEmail': contact_email,
                'contactPhone': contact_phone,
                'monetaryValue': monetary_value,
                'pipelineId': pipeline_id,
                'pipelineStageId': pipeline_stage_id,
                'stageName': stage_name,  # Human-readable stage name
                'status': status,
                'source': source,
                'createdAt': created_at,
                'updatedAt': updated_at,
                'attributions': attributions,
                'fullOpportunity': opportunity,  # Complete GHL opportunity payload
                'fetchedAt': datetime.now().isoformat(),
                'month': 'October',
                'year': 2025,
                'dateRange': {
                    'start': START_DATE,
                    'end': END_DATE
                }
            }
            
            # Store in Firestore with contactId as document ID
            doc_ref = db.collection('ghl_opportunities').document(contact_id)
            doc_ref.set(doc_data)
            
            stored_count += 1
            
            # Show opportunity info
            display_name = name[:30] if name else 'Unknown'
            value_display = f'R {monetary_value:,.2f}' if monetary_value else 'R 0.00'
            pipeline_name = 'Andries' if pipeline_id == ANDRIES_PIPELINE_ID else 'Davide'
            print(f'✅ {stored_count}. Stored {display_name} ({pipeline_name}) - Stage: {stage_name} - Value: {value_display}')
            
        except Exception as e:
            error_count += 1
            print(f'❌ Error storing opportunity: {e}')
    
    # Summary
    print('\n' + '='*80)
    print('COLLECTION COMPLETE')
    print('='*80 + '\n')
    
    print(f'📊 Summary:')
    print(f'   Total opportunities fetched: {len(all_opportunities)}')
    print(f'   October 2025 opportunities: {len(october_opportunities)}')
    print(f'   Andries & Davide opportunities: {len(andries_davide_opportunities)}')
    print(f'   Successfully stored: {stored_count}')
    print(f'   Skipped (no contactId): {skipped_count}')
    print(f'   Errors: {error_count}')
    print(f'\n   Collection: ghl_opportunities')
    print(f'   Document ID format: contactId (e.g., "srKrKjdbJeF9LG5LEK5b")')
    print(f'   Pipelines: Andries & Davide ONLY')
    print(f'   Month: October 2025')
    print(f'   Fields include: stageName (human-readable stage)')
    print(f'\n✅ All October 2025 Andries & Davide opportunities stored in Firestore!\n')


if __name__ == '__main__':
    fetch_all_october_opportunities()




