#!/usr/bin/env python3
"""
Enhanced GHL Opportunity Sync - WITH Custom Fields (Cash & Deposits)
This script fetches ALL opportunities AND their custom field values for accurate cash tracking
"""

import requests
import firebase_admin
from firebase_admin import credentials, firestore
import sys
import time
from datetime import datetime
from dotenv import load_dotenv
import os
from concurrent.futures import ThreadPoolExecutor, as_completed

load_dotenv()

# Initialize Firebase
try:
    cred = credentials.Certificate('../medx-ai-firebase-adminsdk-fbsvc-a86e7bd050.json')
    firebase_admin.initialize_app(cred)
except ValueError:
    pass

db = firestore.client()

# GHL Configuration
GHL_BASE_URL = 'https://services.leadconnectorhq.com'
GHL_API_KEY = os.getenv('GHL_API_KEY', 'pit-e305020a-9a42-4290-a052-daf828c3978e')
GHL_LOCATION_ID = 'QdLXaFEqrdF0JbVbpKLw'

# Pipeline IDs
ANDRIES_PIPELINE_ID = 'XeAGJWRnUGJ5tuhXam2g'
DAVIDE_PIPELINE_ID = 'AUduOJBB2lxlsEaNmlJz'
ERICH_PIPELINE_ID = 'pTbNvnrXqJc9u1oxir3q'

def get_ghl_headers():
    return {
        'Authorization': f'Bearer {GHL_API_KEY}',
        'Version': '2021-07-28',
        'Content-Type': 'application/json'
    }

def get_stage_category(stage_name):
    """Categorize stage based on name"""
    stage_lower = stage_name.lower()
    
    if 'new lead' in stage_lower or 'lead' in stage_lower:
        return 'newLeads'
    elif 'booked' in stage_lower or 'appointment' in stage_lower:
        return 'bookedAppointments'
    elif 'deposit' in stage_lower or 'cash collected' in stage_lower or 'call completed' in stage_lower:
        return 'callCompleted'
    elif 'no show' in stage_lower or 'cancel' in stage_lower or 'disqualified' in stage_lower:
        return 'noShowCancelledDisqualified'
    else:
        return 'other'

def fetch_all_opportunities_from_pipeline(pipeline_id, pipeline_name):
    """Fetch ALL opportunities from a specific pipeline (using page-based pagination)"""
    print(f"📋 Fetching ALL opportunities from {pipeline_name}...")
    
    all_opportunities = []
    page = 1
    limit = 100
    
    while True:
        try:
            response = requests.get(
                f'{GHL_BASE_URL}/opportunities/search',
                headers=get_ghl_headers(),
                params={
                    'location_id': GHL_LOCATION_ID,
                    'limit': limit,
                    'page': page
                },
                timeout=30
            )
            
            if response.status_code != 200:
                print(f"   ❌ Error: {response.status_code}")
                print(f"   {response.text}")
                break
            
            data = response.json()
            opportunities = data.get('opportunities', [])
            
            if not opportunities:
                break
            
            # Filter to this pipeline
            pipeline_opps = [o for o in opportunities if o.get('pipelineId') == pipeline_id]
            all_opportunities.extend(pipeline_opps)
            
            print(f"   Fetched page {page}: {len(pipeline_opps)} opportunities (total: {len(all_opportunities)})")
            
            page += 1
            
            # Break if we got fewer results than limit
            if len(opportunities) < limit:
                break
            
            # Safety limit
            if len(all_opportunities) >= 1000:
                print("   ⚠️  Reached safety limit of 1000 opportunities")
                break
            
            # Small delay to avoid rate limiting
            time.sleep(0.3)
                
        except Exception as e:
            print(f"   ❌ Error: {e}")
            break
    
    print(f"   ✓ Total: {len(all_opportunities)} opportunities")
    return all_opportunities

def get_opportunity_details(opportunity_id):
    """Fetch full opportunity details including custom fields"""
    try:
        response = requests.get(
            f'{GHL_BASE_URL}/opportunities/{opportunity_id}',
            headers=get_ghl_headers(),
            timeout=15
        )
        
        if response.status_code == 200:
            data = response.json()
            return data.get('opportunity', {})
        else:
            print(f"   ⚠️  Error fetching details for {opportunity_id}: {response.status_code}")
            return None
            
    except Exception as e:
        print(f"   ⚠️  Error fetching details for {opportunity_id}: {e}")
        return None

def extract_custom_field_value(custom_fields, field_name_partial):
    """Extract custom field value by partial name match (case-insensitive)"""
    if not custom_fields:
        return None
    
    field_name_lower = field_name_partial.lower()
    
    for field in custom_fields:
        if field_name_lower in field.get('name', '').lower():
            value = field.get('value', '')
            if value:
                # Try to parse as number (remove currency symbols, commas)
                try:
                    # Remove R, $, commas, and spaces
                    clean_value = str(value).replace('R', '').replace('$', '').replace(',', '').replace(' ', '').strip()
                    return float(clean_value) if clean_value else 0
                except:
                    return 0
    return 0

def enrich_opportunity_with_custom_fields(opportunity):
    """Fetch full details and add custom field values to opportunity"""
    opp_id = opportunity.get('id')
    
    # Fetch full details
    full_details = get_opportunity_details(opp_id)
    
    if not full_details:
        return opportunity
    
    # Extract custom fields from contact
    contact = full_details.get('contact', {})
    custom_fields = contact.get('customFields', [])
    
    # Extract cash and deposit values
    cash_collected = extract_custom_field_value(custom_fields, 'cash collected')
    contract_value = extract_custom_field_value(custom_fields, 'contract value')
    
    # Add to opportunity
    opportunity['cashCollected'] = cash_collected
    opportunity['contractValue'] = contract_value
    opportunity['customFieldsLoaded'] = True
    
    return opportunity

def enrich_opportunities_batch(opportunities, max_workers=5):
    """Enrich multiple opportunities with custom fields using threading"""
    print(f"\n🔍 Fetching custom fields for {len(opportunities)} opportunities...")
    print(f"   Using {max_workers} concurrent workers...")
    
    enriched = []
    errors = 0
    
    with ThreadPoolExecutor(max_workers=max_workers) as executor:
        # Submit all tasks
        future_to_opp = {
            executor.submit(enrich_opportunity_with_custom_fields, opp): opp 
            for opp in opportunities
        }
        
        # Process completed tasks
        for i, future in enumerate(as_completed(future_to_opp), 1):
            try:
                result = future.result()
                enriched.append(result)
                
                if i % 10 == 0:
                    print(f"   Progress: {i}/{len(opportunities)} opportunities enriched...")
                    
            except Exception as e:
                errors += 1
                print(f"   ⚠️  Error enriching opportunity: {e}")
                # Add original opportunity without enrichment
                original_opp = future_to_opp[future]
                original_opp['cashCollected'] = 0
                original_opp['contractValue'] = 0
                original_opp['customFieldsLoaded'] = False
                enriched.append(original_opp)
    
    print(f"   ✓ Enriched {len(enriched)} opportunities")
    if errors > 0:
        print(f"   ⚠️  {errors} errors during enrichment")
    
    return enriched

def get_existing_opportunity_ids():
    """Get all existing opportunity IDs from Firebase to avoid duplicates"""
    print("📋 Loading existing opportunities from Firebase...")
    
    existing_ids = set()
    opps_ref = db.collection('opportunityStageHistory')
    
    # Get all unique opportunityIds
    docs = opps_ref.stream()
    for doc in docs:
        data = doc.to_dict()
        opp_id = data.get('opportunityId')
        if opp_id:
            existing_ids.add(opp_id)
    
    print(f"   ✓ Found {len(existing_ids)} existing opportunity IDs")
    return existing_ids

def extract_attribution(opportunity):
    """Extract Facebook attribution from opportunity"""
    attributions = opportunity.get('attributions', [])
    if not attributions:
        return None
    
    # Get last attribution
    last_attr = None
    for attr in attributions:
        if attr.get('isLast'):
            last_attr = attr
            break
    
    if not last_attr and attributions:
        last_attr = attributions[-1]
    
    if not last_attr:
        return None
    
    # Extract using NEW UTM structure
    return {
        'campaignName': last_attr.get('utmSource', '') or last_attr.get('utmCampaign', ''),
        'campaignSource': last_attr.get('utmSource', ''),
        'campaignMedium': last_attr.get('utmMedium', ''),
        'adSetName': last_attr.get('utmMedium', ''),
        'adId': last_attr.get('adId', '') or last_attr.get('utmAdId', ''),
        'adName': last_attr.get('utmContent', '') or last_attr.get('utmCampaign', ''),
    }

def sync_opportunity_to_firebase(opportunity, pipeline_name, pipeline_id, existing_ids, dry_run=True):
    """Sync a single opportunity to Firebase (only if it doesn't exist)"""
    opp_id = opportunity.get('id')
    
    # Check if already exists
    if opp_id in existing_ids:
        return 'skipped'
    
    # Extract data
    opp_name = opportunity.get('name', 'Unnamed')
    contact_id = opportunity.get('contact', {}).get('id', '') if isinstance(opportunity.get('contact'), dict) else opportunity.get('contactId', '')
    stage_id = opportunity.get('pipelineStageId', '')
    stage_name = opportunity.get('pipelineStageName', '')
    monetary_value = opportunity.get('monetaryValue', 0) or 0
    assigned_to = opportunity.get('assignedTo', '')
    
    # NEW: Get custom field values
    cash_collected = opportunity.get('cashCollected', 0)
    contract_value = opportunity.get('contractValue', 0)
    
    # Get attribution
    attr = extract_attribution(opportunity)
    
    # Create document
    timestamp = datetime.now()
    doc_id = f"{opp_id}_{int(timestamp.timestamp() * 1000)}"
    
    history_doc = {
        'opportunityId': opp_id,
        'opportunityName': opp_name,
        'contactId': contact_id,
        'pipelineId': pipeline_id,
        'pipelineName': pipeline_name,
        'previousStageId': '',
        'previousStageName': '',
        'newStageId': stage_id,
        'newStageName': stage_name,
        'stageName': stage_name,
        'stageCategory': get_stage_category(stage_name),
        'campaignName': attr['campaignName'] if attr else '',
        'campaignSource': attr['campaignSource'] if attr else '',
        'campaignMedium': attr['campaignMedium'] if attr else '',
        'adId': attr['adId'] if attr else '',
        'adName': attr['adName'] if attr else '',
        'adSetName': attr['adSetName'] if attr else '',
        'facebookAdId': '',
        'matchedAdSetId': '',
        'matchedAdSetName': '',
        'assignedTo': assigned_to,
        'assignedToName': '',
        'timestamp': timestamp,
        'monetaryValue': monetary_value,
        # NEW: Add custom field values
        'cashCollected': cash_collected,
        'contractValue': contract_value,
        'customFieldsLoaded': opportunity.get('customFieldsLoaded', False),
        'year': timestamp.year,
        'month': timestamp.month,
        'week': timestamp.isocalendar()[1],
        'isBackfilled': True
    }
    
    if not dry_run:
        try:
            db.collection('opportunityStageHistory').document(doc_id).set(history_doc)
            return 'created'
        except Exception as e:
            print(f"   ❌ Error creating {opp_id}: {e}")
            return 'error'
    else:
        return 'would_create'

def main():
    dry_run = '--dry-run' not in sys.argv
    skip_enrichment = '--skip-enrichment' in sys.argv
    
    print("=" * 80)
    print("🔄 ENHANCED GHL OPPORTUNITY SYNC - WITH CUSTOM FIELDS")
    print("=" * 80)
    print()
    
    if dry_run:
        print("⚠️  DRY RUN MODE - No changes will be made")
        print("   Run with --dry-run to apply changes")
        print()
    
    if skip_enrichment:
        print("⚠️  SKIPPING CUSTOM FIELD ENRICHMENT")
        print("   Custom fields will NOT be fetched (faster but no cash values)")
        print()
    
    # Get existing IDs first
    existing_ids = get_existing_opportunity_ids()
    print()
    
    # Fetch all opportunities from all pipelines
    pipelines = [
        (ANDRIES_PIPELINE_ID, 'Andries Pipeline - DDM'),
        (DAVIDE_PIPELINE_ID, "Davide's Pipeline - DDM"),
        (ERICH_PIPELINE_ID, 'Erich Pipeline -DDM')
    ]
    
    all_stats = {
        'total_fetched': 0,
        'already_exists': 0,
        'created': 0,
        'errors': 0,
        'cash_total': 0,
        'contract_total': 0
    }
    
    for pipeline_id, pipeline_name in pipelines:
        print()
        print("=" * 80)
        print(f"📊 {pipeline_name.upper()}")
        print("=" * 80)
        print()
        
        opportunities = fetch_all_opportunities_from_pipeline(pipeline_id, pipeline_name)
        all_stats['total_fetched'] += len(opportunities)
        
        if not opportunities:
            print("   ⚠️  No opportunities found")
            continue
        
        # Enrich with custom fields (unless skipped)
        if not skip_enrichment:
            opportunities = enrich_opportunities_batch(opportunities, max_workers=5)
            
            # Calculate totals
            cash_total = sum(o.get('cashCollected', 0) for o in opportunities)
            contract_total = sum(o.get('contractValue', 0) for o in opportunities)
            
            print(f"\n💰 Custom Field Summary:")
            print(f"   Total Cash Collected: R {cash_total:,.2f}")
            print(f"   Total Contract Value: R {contract_total:,.2f}")
            print()
            
            all_stats['cash_total'] += cash_total
            all_stats['contract_total'] += contract_total
        
        print(f"💾 Syncing {len(opportunities)} opportunities...")
        
        stats = {'skipped': 0, 'created': 0, 'would_create': 0, 'error': 0}
        
        for i, opp in enumerate(opportunities, 1):
            result = sync_opportunity_to_firebase(
                opp, 
                pipeline_name, 
                pipeline_id, 
                existing_ids,
                dry_run
            )
            stats[result] += 1
            
            if i % 50 == 0:
                print(f"   Processed {i}/{len(opportunities)}...")
        
        print()
        print(f"   ✅ Synced: {stats.get('created', 0)}")
        print(f"   📝 Would create: {stats.get('would_create', 0)}")
        print(f"   ⏭️  Skipped (already exists): {stats['skipped']}")
        print(f"   ❌ Errors: {stats.get('error', 0)}")
        
        all_stats['already_exists'] += stats['skipped']
        all_stats['created'] += stats.get('created', 0)
        all_stats['errors'] += stats.get('error', 0)
    
    # Final summary
    print()
    print("=" * 80)
    print("📊 FINAL SUMMARY")
    print("=" * 80)
    print()
    print(f"Total Opportunities Fetched: {all_stats['total_fetched']}")
    print(f"Already in Firebase: {all_stats['already_exists']}")
    print(f"New Opportunities Created: {all_stats['created']}")
    print(f"Errors: {all_stats['errors']}")
    
    if not skip_enrichment:
        print()
        print(f"💰 Total Cash Collected: R {all_stats['cash_total']:,.2f}")
        print(f"💼 Total Contract Value: R {all_stats['contract_total']:,.2f}")
    
    print()
    
    if dry_run:
        print("ℹ️  This was a DRY RUN. Add --dry-run flag to apply changes.")
        print("   Example: python3 fullGHLSync_with_custom_fields.py --dry-run")
    else:
        print("✅ Sync completed!")
    print()

if __name__ == '__main__':
    main()

