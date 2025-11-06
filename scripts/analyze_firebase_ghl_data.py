#!/usr/bin/env python3
"""
Analyze Firebase opportunityStageHistory collection
Compare with GHL API results to identify discrepancies
"""

import firebase_admin
from firebase_admin import credentials, firestore
import json
from datetime import datetime
from collections import defaultdict
import os

# Initialize Firebase Admin
FIREBASE_CRED_PATH = os.environ.get('FIREBASE_CRED_PATH', 'medx-ai-firebase-adminsdk-fbsvc-a86e7bd050.json')

def init_firebase():
    """Initialize Firebase Admin SDK"""
    print("🔥 Initializing Firebase Admin SDK...")
    
    if not firebase_admin._apps:
        cred = credentials.Certificate(FIREBASE_CRED_PATH)
        firebase_admin.initialize_app(cred)
    
    db = firestore.client()
    print("✅ Firebase initialized")
    return db

def analyze_opportunity_history(db):
    """Analyze opportunityStageHistory collection"""
    print("\n📊 Analyzing opportunityStageHistory collection...")
    
    collection = db.collection('opportunityStageHistory')
    docs = collection.stream()
    
    # Track unique opportunities per stage category
    opportunities_by_stage = defaultdict(set)
    opportunities_by_pipeline = defaultdict(lambda: defaultdict(set))
    all_transitions = []
    
    # Pipeline ID to name mapping
    pipeline_names = {
        'XeAGJWRnUGJ5tuhXam2g': 'Andries Pipeline',
        'pTbNvnrXqJc9u1oxir3q': 'Davide Pipeline',
        'AUduOJBB2lxlsEaNmlJz': 'Altus Pipeline'
    }
    
    total_docs = 0
    for doc in docs:
        total_docs += 1
        data = doc.to_dict()
        
        opp_id = data.get('opportunityId')
        stage_category = data.get('stageCategory')
        pipeline_id = data.get('pipelineId')
        timestamp = data.get('timestamp')
        
        transition_info = {
            'doc_id': doc.id,
            'opportunity_id': opp_id,
            'opportunity_name': data.get('opportunityName'),
            'pipeline_id': pipeline_id,
            'pipeline_name': data.get('pipelineName'),
            'stage_category': stage_category,
            'new_stage_name': data.get('newStageName'),
            'timestamp': timestamp,
            'is_backfilled': data.get('isBackfilled', False),
            'campaign_name': data.get('campaignName', '')
        }
        
        all_transitions.append(transition_info)
        
        if opp_id and stage_category:
            opportunities_by_stage[stage_category].add(opp_id)
            
            if pipeline_id:
                opportunities_by_pipeline[pipeline_id][stage_category].add(opp_id)
    
    print(f"✅ Analyzed {total_docs} stage transition records")
    
    return opportunities_by_stage, opportunities_by_pipeline, all_transitions, pipeline_names

def get_latest_stage_per_opportunity(all_transitions):
    """Get the latest stage for each unique opportunity"""
    print("\n🔍 Determining latest stage for each opportunity...")
    
    latest_stages = {}
    
    for transition in all_transitions:
        opp_id = transition['opportunity_id']
        timestamp = transition['timestamp']
        
        # Convert Firestore timestamp to datetime if needed
        if hasattr(timestamp, 'timestamp'):
            timestamp_dt = timestamp.timestamp()
        else:
            timestamp_dt = timestamp
        
        if opp_id not in latest_stages or timestamp_dt > latest_stages[opp_id]['timestamp_dt']:
            latest_stages[opp_id] = {
                'opportunity_id': opp_id,
                'opportunity_name': transition['opportunity_name'],
                'pipeline_id': transition['pipeline_id'],
                'pipeline_name': transition['pipeline_name'],
                'stage_category': transition['stage_category'],
                'stage_name': transition['new_stage_name'],
                'timestamp': transition['timestamp'],
                'timestamp_dt': timestamp_dt,
                'is_backfilled': transition['is_backfilled']
            }
    
    print(f"✅ Found {len(latest_stages)} unique opportunities")
    return latest_stages

def compare_with_ghl_report(latest_stages, ghl_report_file=None):
    """Compare Firebase data with GHL diagnostic report"""
    print("\n🔄 Comparing Firebase with GHL API data...")
    
    if ghl_report_file and os.path.exists(ghl_report_file):
        print(f"📂 Loading GHL report: {ghl_report_file}")
        with open(ghl_report_file, 'r') as f:
            ghl_data = json.load(f)
    else:
        print("⚠️  No GHL report file provided. Run diagnose_ghl_deposits.py first.")
        return None
    
    # Count Firebase opportunities by stage and pipeline
    firebase_counts = {
        'andries': defaultdict(set),
        'davide': defaultdict(set)
    }
    
    pipeline_id_map = {
        'XeAGJWRnUGJ5tuhXam2g': 'andries',
        'pTbNvnrXqJc9u1oxir3q': 'davide'
    }
    
    for opp_id, opp_data in latest_stages.items():
        pipeline_key = pipeline_id_map.get(opp_data['pipeline_id'])
        if pipeline_key:
            stage_category = opp_data['stage_category']
            firebase_counts[pipeline_key][stage_category].add(opp_id)
    
    # Compare counts
    print("\n" + "=" * 80)
    print("COMPARISON: GHL API vs Firebase")
    print("=" * 80)
    
    discrepancies = []
    
    for pipeline_key in ['andries', 'davide']:
        pipeline_name = "Andries Pipeline" if pipeline_key == 'andries' else "Davide Pipeline"
        
        print(f"\n📊 {pipeline_name}:")
        
        # Get GHL counts
        ghl_stats = ghl_data.get(pipeline_key, {})
        ghl_deposits = len(ghl_stats.get('deposits', []))
        ghl_cash = len(ghl_stats.get('cashCollected', []))
        ghl_booked = len(ghl_stats.get('bookedAppointments', []))
        ghl_call = len(ghl_stats.get('callCompleted', []))
        ghl_no_show = len(ghl_stats.get('noShowCancelledDisqualified', []))
        
        # Get Firebase counts
        fb_deposits = len(firebase_counts[pipeline_key]['deposits'])
        fb_cash = len(firebase_counts[pipeline_key]['cashCollected'])
        fb_booked = len(firebase_counts[pipeline_key]['bookedAppointments'])
        fb_call = len(firebase_counts[pipeline_key]['callCompleted'])
        fb_no_show = len(firebase_counts[pipeline_key]['noShowCancelledDisqualified'])
        
        print(f"  Booked Appointments:  GHL={ghl_booked:3d}  Firebase={fb_booked:3d}  {'✅' if ghl_booked == fb_booked else '❌ MISMATCH'}")
        print(f"  Call Completed:       GHL={ghl_call:3d}  Firebase={fb_call:3d}  {'✅' if ghl_call == fb_call else '❌ MISMATCH'}")
        print(f"  No Show/Cancelled:    GHL={ghl_no_show:3d}  Firebase={fb_no_show:3d}  {'✅' if ghl_no_show == fb_no_show else '❌ MISMATCH'}")
        print(f"  🎯 Deposit Received:  GHL={ghl_deposits:3d}  Firebase={fb_deposits:3d}  {'✅' if ghl_deposits == fb_deposits else '❌ MISMATCH'}")
        print(f"  🎯 Cash Collected:    GHL={ghl_cash:3d}  Firebase={fb_cash:3d}  {'✅' if ghl_cash == fb_cash else '❌ MISMATCH'}")
        
        # Track discrepancies
        if ghl_deposits != fb_deposits:
            discrepancies.append({
                'pipeline': pipeline_name,
                'stage': 'Deposit Received',
                'ghl_count': ghl_deposits,
                'firebase_count': fb_deposits,
                'missing': ghl_deposits - fb_deposits
            })
        
        if ghl_cash != fb_cash:
            discrepancies.append({
                'pipeline': pipeline_name,
                'stage': 'Cash Collected',
                'ghl_count': ghl_cash,
                'firebase_count': fb_cash,
                'missing': ghl_cash - fb_cash
            })
    
    # Identify missing opportunities
    if discrepancies:
        print("\n" + "=" * 80)
        print("MISSING OPPORTUNITIES (in GHL but not in Firebase)")
        print("=" * 80)
        
        for pipeline_key in ['andries', 'davide']:
            ghl_stats = ghl_data.get(pipeline_key, {})
            
            # Get opportunity IDs from GHL
            ghl_deposit_ids = {opp['id'] for opp in ghl_stats.get('deposits', [])}
            ghl_cash_ids = {opp['id'] for opp in ghl_stats.get('cashCollected', [])}
            
            # Get opportunity IDs from Firebase
            fb_deposit_ids = firebase_counts[pipeline_key]['deposits']
            fb_cash_ids = firebase_counts[pipeline_key]['cashCollected']
            
            # Find missing
            missing_deposits = ghl_deposit_ids - fb_deposit_ids
            missing_cash = ghl_cash_ids - fb_cash_ids
            
            pipeline_name = "Andries" if pipeline_key == 'andries' else "Davide"
            
            if missing_deposits:
                print(f"\n❌ {pipeline_name} - Missing Deposits ({len(missing_deposits)}):")
                for opp in ghl_stats.get('deposits', []):
                    if opp['id'] in missing_deposits:
                        print(f"  • {opp['name']}")
                        print(f"    ID: {opp['id']}")
                        print(f"    Stage: {opp['stage_name']}")
                        print()
            
            if missing_cash:
                print(f"\n❌ {pipeline_name} - Missing Cash Collected ({len(missing_cash)}):")
                for opp in ghl_stats.get('cashCollected', []):
                    if opp['id'] in missing_cash:
                        print(f"  • {opp['name']}")
                        print(f"    ID: {opp['id']}")
                        print(f"    Stage: {opp['stage_name']}")
                        print()
    
    return discrepancies

def main():
    """Main analysis function"""
    print("=" * 80)
    print("FIREBASE GHL DATA ANALYSIS")
    print("=" * 80)
    
    try:
        # Initialize Firebase
        db = init_firebase()
        
        # Analyze Firebase data
        opportunities_by_stage, opportunities_by_pipeline, all_transitions, pipeline_names = analyze_opportunity_history(db)
        
        # Get latest stage for each opportunity
        latest_stages = get_latest_stage_per_opportunity(all_transitions)
        
        # Print Firebase summary
        print("\n" + "=" * 80)
        print("FIREBASE SUMMARY (Latest Stage per Opportunity)")
        print("=" * 80)
        
        for pipeline_id, stages in opportunities_by_pipeline.items():
            pipeline_name = pipeline_names.get(pipeline_id, pipeline_id)
            print(f"\n📊 {pipeline_name}:")
            print(f"  Booked Appointments: {len(stages['bookedAppointments'])}")
            print(f"  Call Completed: {len(stages['callCompleted'])}")
            print(f"  No Show/Cancelled: {len(stages['noShowCancelledDisqualified'])}")
            print(f"  🎯 Deposit Received: {len(stages['deposits'])}")
            print(f"  🎯 Cash Collected: {len(stages['cashCollected'])}")
        
        # Look for most recent GHL diagnostic report
        import glob
        ghl_reports = sorted(glob.glob('ghl_diagnostic_report_*.json'), reverse=True)
        
        if ghl_reports:
            latest_report = ghl_reports[0]
            print(f"\n📂 Found GHL diagnostic report: {latest_report}")
            compare_with_ghl_report(latest_stages, latest_report)
        else:
            print("\n⚠️  No GHL diagnostic report found.")
            print("   Run 'python scripts/diagnose_ghl_deposits.py' first to generate a report.")
        
        # Save Firebase analysis
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        output_file = f"firebase_analysis_report_{timestamp}.json"
        
        # Convert sets to lists for JSON serialization
        serializable_latest = {}
        for opp_id, data in latest_stages.items():
            serializable_latest[opp_id] = {
                **data,
                'timestamp': str(data['timestamp'])
            }
        
        with open(output_file, 'w') as f:
            json.dump(serializable_latest, f, indent=2, default=str)
        
        print("\n" + "=" * 80)
        print(f"✅ Firebase analysis saved to: {output_file}")
        print("=" * 80)
        
    except Exception as e:
        print(f"\n❌ ERROR: {e}")
        import traceback
        traceback.print_exc()

if __name__ == '__main__':
    main()

