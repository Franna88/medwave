#!/usr/bin/env python3
"""
Backfill historical opportunities to Firebase
Populates missing Deposit Received and Cash Collected opportunities
"""

import os
import requests
import firebase_admin
from firebase_admin import credentials, firestore
import json
from datetime import datetime
import time

# Configuration
GHL_API_KEY = os.environ.get('GHL_API_KEY')
GHL_BASE_URL = 'https://services.leadconnectorhq.com'
LOCATION_ID = 'QdLXaFEqrdF0JbVbpKLw'
FIREBASE_CRED_PATH = os.environ.get('FIREBASE_CRED_PATH', 'medx-ai-firebase-adminsdk-fbsvc-a86e7bd050.json')

# Pipeline IDs
ANDRIES_PIPELINE_ID = 'XeAGJWRnUGJ5tuhXam2g'  # Andries Pipeline - DDM
DAVIDE_PIPELINE_ID = 'AUduOJBB2lxlsEaNmlJz'   # Davide's Pipeline - DDM

# Dry run mode (set to False to actually write to Firebase)
DRY_RUN = False

def get_headers():
    """Get GHL API headers"""
    return {
        'Authorization': f'Bearer {GHL_API_KEY}',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Version': '2021-07-28'
    }

def init_firebase():
    """Initialize Firebase Admin SDK"""
    print("🔥 Initializing Firebase Admin SDK...")
    
    if not firebase_admin._apps:
        cred = credentials.Certificate(FIREBASE_CRED_PATH)
        firebase_admin.initialize_app(cred)
    
    db = firestore.client()
    print("✅ Firebase initialized")
    return db

def match_stage_category(stage_name):
    """Match stage name to category"""
    if not stage_name:
        return 'other'
    
    stage_lower = stage_name.lower()
    
    # Exact matches
    if stage_lower == 'booked appointments' or stage_lower == 'booked appointment':
        return 'bookedAppointments'
    if stage_lower == 'call completed':
        return 'callCompleted'
    if stage_lower == 'no show':
        return 'noShowCancelledDisqualified'
    if stage_lower == 'deposit received':
        return 'deposits'
    if stage_lower == 'cash collected':
        return 'cashCollected'
    
    # Keyword fallbacks
    if 'booked' in stage_lower or 'appointment' in stage_lower or 'scheduled' in stage_lower:
        return 'bookedAppointments'
    if 'call' in stage_lower and 'completed' in stage_lower:
        return 'callCompleted'
    if 'cancel' in stage_lower or 'disqualif' in stage_lower or 'lost' in stage_lower or 'no show' in stage_lower:
        return 'noShowCancelledDisqualified'
    if 'deposit' in stage_lower:
        return 'deposits'
    if ('cash' in stage_lower and 'collect' in stage_lower) or 'sold' in stage_lower or 'purchased' in stage_lower:
        return 'cashCollected'
    
    return 'other'

def load_missing_opportunities():
    """Load ALL opportunities in Deposit and Cash stages from GHL diagnostic report"""
    print("\n📂 Loading GHL diagnostic report...")
    
    import glob
    ghl_reports = sorted(glob.glob('ghl_diagnostic_report_*.json'), reverse=True)
    
    if not ghl_reports:
        print("❌ No GHL diagnostic report found. Run diagnose_ghl_deposits.py first.")
        return None
    
    with open(ghl_reports[0], 'r') as f:
        ghl_data = json.load(f)
    
    print(f"✅ Loaded GHL report: {ghl_reports[0]}")
    print("ℹ️  Will backfill ALL opportunities in Deposit and Cash stages")
    print("   (Existing records in Firebase will be updated with latest data)")
    
    # We don't need Firebase analysis - we'll backfill ALL opps
    # The Cloud Function will handle deduplication by using deterministic document IDs
    fb_opp_ids = set()  # Empty set means all are "missing"
    
    # Find missing opportunities
    missing_opps = []
    
    for pipeline_key in ['andries', 'davide']:
        ghl_stats = ghl_data.get(pipeline_key, {})
        
        # Check deposits
        for opp in ghl_stats.get('deposits', []):
            if opp['id'] not in fb_opp_ids:
                missing_opps.append({
                    'pipeline_key': pipeline_key,
                    'stage_category': 'deposits',
                    **opp
                })
        
        # Check cash collected
        for opp in ghl_stats.get('cashCollected', []):
            if opp['id'] not in fb_opp_ids:
                missing_opps.append({
                    'pipeline_key': pipeline_key,
                    'stage_category': 'cashCollected',
                    **opp
                })
    
    print(f"\n🔍 Found {len(missing_opps)} missing opportunities to backfill")
    return missing_opps

def fetch_opportunity_details(opp_id):
    """Fetch full opportunity details from GHL API"""
    url = f"{GHL_BASE_URL}/opportunities/{opp_id}"
    
    try:
        response = requests.get(url, headers=get_headers())
        response.raise_for_status()
        data = response.json()
        return data.get('opportunity') or data
    except Exception as e:
        print(f"  ⚠️  Could not fetch details for {opp_id}: {e}")
        return None

def fetch_users():
    """Fetch users to get agent names"""
    print("\n👥 Fetching users...")
    
    url = f"{GHL_BASE_URL}/users/"
    params = {'locationId': LOCATION_ID}
    
    response = requests.get(url, headers=get_headers(), params=params)
    response.raise_for_status()
    
    users_data = response.json().get('users', [])
    users = {}
    for user in users_data:
        users[user['id']] = user
    
    print(f"✅ Loaded {len(users)} users")
    return users

def fetch_pipelines():
    """Fetch pipelines to get stage info"""
    print("\n📋 Fetching pipelines...")
    
    url = f"{GHL_BASE_URL}/opportunities/pipelines"
    params = {'locationId': LOCATION_ID}
    
    response = requests.get(url, headers=get_headers(), params=params)
    response.raise_for_status()
    
    pipelines_data = response.json().get('pipelines', [])
    pipelines = {}
    stage_id_to_name = {}
    
    for pipeline in pipelines_data:
        pipelines[pipeline['id']] = pipeline
        for stage in pipeline.get('stages', []):
            stage_id_to_name[stage['id']] = stage['name']
    
    print(f"✅ Loaded {len(pipelines)} pipelines")
    return pipelines, stage_id_to_name

def backfill_opportunity(db, opp_data, pipelines, stage_id_to_name, users):
    """Backfill a single opportunity to Firebase"""
    opp_id = opp_data['id']
    
    # Fetch full opportunity details
    print(f"\n  📦 Fetching details for: {opp_data['name']}")
    full_opp = fetch_opportunity_details(opp_id)
    
    if not full_opp:
        return False
    
    # Extract data
    pipeline_id = full_opp.get('pipelineId', '')
    pipeline = pipelines.get(pipeline_id, {})
    pipeline_name = pipeline.get('name', '')
    
    stage_id = full_opp.get('pipelineStageId', '')
    stage_name = stage_id_to_name.get(stage_id, opp_data['stage_name'])
    
    # Get campaign attribution
    attributions = full_opp.get('attributions', [])
    last_attribution = None
    
    for attr in attributions:
        if attr.get('isLast'):
            last_attribution = attr
            break
    
    if not last_attribution and attributions:
        last_attribution = attributions[-1]
    
    campaign_name = last_attribution.get('utmCampaign', '') if last_attribution else ''
    campaign_source = last_attribution.get('utmSource', '') if last_attribution else ''
    campaign_medium = last_attribution.get('utmMedium', '') if last_attribution else ''
    ad_id = last_attribution.get('utmAdId') or last_attribution.get('utmContent', '') if last_attribution else ''
    ad_name = last_attribution.get('utmContent', ad_id) if last_attribution else ''
    
    # Get assigned user
    assigned_to = full_opp.get('assignedTo', 'unassigned')
    assigned_to_name = 'Unassigned'
    if assigned_to and assigned_to != 'unassigned':
        user = users.get(assigned_to, {})
        assigned_to_name = user.get('name') or user.get('email', assigned_to)
    
    # Get timestamp (use last status change or date added)
    last_status_change = full_opp.get('lastStatusChangeAt')
    date_added = full_opp.get('dateAdded')
    
    if last_status_change:
        # Parse ISO timestamp
        try:
            timestamp = datetime.fromisoformat(last_status_change.replace('Z', '+00:00'))
        except:
            timestamp = datetime.now()
    elif date_added:
        try:
            timestamp = datetime.fromisoformat(date_added.replace('Z', '+00:00'))
        except:
            timestamp = datetime.now()
    else:
        timestamp = datetime.now()
    
    # Get monetary value
    monetary_value = full_opp.get('monetaryValue', 0)
    
    # Prepare document
    stage_category = match_stage_category(stage_name)
    
    doc_data = {
        'opportunityId': opp_id,
        'opportunityName': full_opp.get('name', ''),
        'contactId': full_opp.get('contact', {}).get('id', ''),
        'pipelineId': pipeline_id,
        'pipelineName': pipeline_name,
        'previousStageId': '',  # Unknown for backfilled data
        'previousStageName': '',
        'newStageId': stage_id,
        'newStageName': stage_name,
        'campaignName': campaign_name,
        'campaignSource': campaign_source,
        'campaignMedium': campaign_medium,
        'adId': ad_id,
        'adName': ad_name,
        'assignedTo': assigned_to,
        'assignedToName': assigned_to_name,
        'timestamp': firestore.SERVER_TIMESTAMP if not DRY_RUN else timestamp,
        'monetaryValue': monetary_value,
        'stageCategory': stage_category,
        'year': timestamp.year,
        'month': timestamp.month,
        'week': timestamp.isocalendar()[1],
        'isBackfilled': True
    }
    
    # Document ID
    doc_id = f"{opp_id}_{int(timestamp.timestamp() * 1000)}"
    
    if DRY_RUN:
        print(f"  🔍 DRY RUN - Would create document: {doc_id}")
        print(f"     Stage: {stage_name} ({stage_category})")
        print(f"     Campaign: {campaign_name}")
        print(f"     Value: R{monetary_value}")
        print(f"     Timestamp: {timestamp}")
    else:
        # Write to Firestore
        db.collection('opportunityStageHistory').document(doc_id).set(doc_data)
        print(f"  ✅ Created document: {doc_id}")
    
    return True

def main():
    """Main backfill function"""
    print("=" * 80)
    print("GHL HISTORICAL OPPORTUNITIES BACKFILL")
    print("=" * 80)
    
    if DRY_RUN:
        print("\n⚠️  DRY RUN MODE - No data will be written to Firebase")
        print("   Set DRY_RUN=False in the script to perform actual backfill")
    
    if not GHL_API_KEY:
        print("\n❌ ERROR: GHL_API_KEY environment variable not set!")
        return
    
    try:
        # Load missing opportunities
        missing_opps = load_missing_opportunities()
        
        if not missing_opps:
            print("\n✅ No missing opportunities to backfill!")
            return
        
        # Initialize Firebase
        db = init_firebase()
        
        # Fetch supporting data
        users = fetch_users()
        pipelines, stage_id_to_name = fetch_pipelines()
        
        # Backfill opportunities
        print("\n" + "=" * 80)
        print(f"BACKFILLING {len(missing_opps)} OPPORTUNITIES")
        print("=" * 80)
        
        success_count = 0
        error_count = 0
        backfilled_ids = []
        
        for i, opp in enumerate(missing_opps, 1):
            print(f"\n[{i}/{len(missing_opps)}] {opp['name']}")
            print(f"  Pipeline: {opp['pipeline_key'].capitalize()}")
            print(f"  Stage: {opp['stage_category']}")
            
            try:
                if backfill_opportunity(db, opp, pipelines, stage_id_to_name, users):
                    success_count += 1
                    backfilled_ids.append(opp['id'])
                else:
                    error_count += 1
                
                # Rate limiting
                time.sleep(0.5)
                
            except Exception as e:
                print(f"  ❌ Error: {e}")
                error_count += 1
        
        # Summary
        print("\n" + "=" * 80)
        print("BACKFILL SUMMARY")
        print("=" * 80)
        print(f"Total opportunities: {len(missing_opps)}")
        print(f"✅ Successfully backfilled: {success_count}")
        print(f"❌ Errors: {error_count}")
        
        if DRY_RUN:
            print("\n⚠️  This was a DRY RUN - no data was written")
            print("   Set DRY_RUN=False to perform actual backfill")
        else:
            # Save backfilled IDs for rollback purposes
            timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
            rollback_file = f"backfilled_opps_{timestamp}.json"
            
            with open(rollback_file, 'w') as f:
                json.dump(backfilled_ids, f, indent=2)
            
            print(f"\n💾 Backfilled opportunity IDs saved to: {rollback_file}")
            print("   (Keep this file for rollback purposes)")
        
    except Exception as e:
        print(f"\n❌ ERROR: {e}")
        import traceback
        traceback.print_exc()

if __name__ == '__main__':
    main()

