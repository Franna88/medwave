#!/usr/bin/env python3
"""
Quick verification script to confirm GHL data accuracy fix
Run this after backfill to verify everything is working correctly
"""

import firebase_admin
from firebase_admin import credentials, firestore
import os
from collections import defaultdict

FIREBASE_CRED_PATH = os.environ.get('FIREBASE_CRED_PATH', 'medx-ai-firebase-adminsdk-fbsvc-a86e7bd050.json')

# Expected counts from GHL
EXPECTED_COUNTS = {
    'andries': {
        'deposits': 26,
        'cashCollected': 20
    },
    'davide': {
        'deposits': 6,
        'cashCollected': 10
    }
}

# Pipeline ID mapping
PIPELINE_MAP = {
    'XeAGJWRnUGJ5tuhXam2g': 'andries',
    'pTbNvnrXqJc9u1oxir3q': 'davide'
}

def init_firebase():
    """Initialize Firebase Admin SDK"""
    if not firebase_admin._apps:
        cred = credentials.Certificate(FIREBASE_CRED_PATH)
        firebase_admin.initialize_app(cred)
    return firestore.client()

def get_latest_stage_counts(db):
    """Get latest stage for each opportunity and count"""
    print("📊 Analyzing opportunityStageHistory collection...")
    
    collection = db.collection('opportunityStageHistory')
    docs = collection.stream()
    
    # Track latest state per opportunity
    latest_states = {}
    
    for doc in docs:
        data = doc.data()
        opp_id = data.get('opportunityId')
        pipeline_id = data.get('pipelineId')
        stage_category = data.get('stageCategory')
        timestamp = data.get('timestamp')
        
        if not opp_id or not pipeline_id:
            continue
        
        # Convert timestamp
        if hasattr(timestamp, 'timestamp'):
            timestamp_dt = timestamp.timestamp()
        else:
            timestamp_dt = 0
        
        # Update if this is the latest state
        if opp_id not in latest_states or timestamp_dt > latest_states[opp_id]['timestamp']:
            latest_states[opp_id] = {
                'pipeline_id': pipeline_id,
                'stage_category': stage_category,
                'timestamp': timestamp_dt
            }
    
    # Count by pipeline and stage
    counts = defaultdict(lambda: defaultdict(int))
    
    for opp_id, state in latest_states.items():
        pipeline_key = PIPELINE_MAP.get(state['pipeline_id'])
        if pipeline_key and state['stage_category'] in ['deposits', 'cashCollected']:
            counts[pipeline_key][state['stage_category']] += 1
    
    return counts

def verify_counts(actual_counts):
    """Verify actual counts match expected"""
    print("\n" + "=" * 80)
    print("VERIFICATION RESULTS")
    print("=" * 80)
    
    all_pass = True
    
    for pipeline_key, expected in EXPECTED_COUNTS.items():
        pipeline_name = "Andries Pipeline" if pipeline_key == 'andries' else "Davide Pipeline"
        actual = actual_counts.get(pipeline_key, {})
        
        print(f"\n📊 {pipeline_name}:")
        
        # Check deposits
        expected_deposits = expected['deposits']
        actual_deposits = actual.get('deposits', 0)
        deposits_pass = expected_deposits == actual_deposits
        
        if deposits_pass:
            print(f"  ✅ Deposits: {actual_deposits}/{expected_deposits} - PASS")
        else:
            print(f"  ❌ Deposits: {actual_deposits}/{expected_deposits} - FAIL (Missing: {expected_deposits - actual_deposits})")
            all_pass = False
        
        # Check cash collected
        expected_cash = expected['cashCollected']
        actual_cash = actual.get('cashCollected', 0)
        cash_pass = expected_cash == actual_cash
        
        if cash_pass:
            print(f"  ✅ Cash Collected: {actual_cash}/{expected_cash} - PASS")
        else:
            print(f"  ❌ Cash Collected: {actual_cash}/{expected_cash} - FAIL (Missing: {expected_cash - actual_cash})")
            all_pass = False
    
    print("\n" + "=" * 80)
    if all_pass:
        print("✅ VERIFICATION PASSED - All counts match expected values!")
    else:
        print("❌ VERIFICATION FAILED - Some counts don't match")
        print("\nNext steps:")
        print("1. Re-run diagnostic scripts to check current GHL state")
        print("2. Verify backfill script completed successfully")
        print("3. Check Cloud Function logs for sync errors")
    print("=" * 80)
    
    return all_pass

def check_backfilled_records(db):
    """Check how many backfilled records exist"""
    print("\n📦 Checking backfilled records...")
    
    collection = db.collection('opportunityStageHistory')
    docs = collection.where('isBackfilled', '==', True).stream()
    
    backfilled_count = 0
    backfilled_by_pipeline = defaultdict(int)
    
    for doc in docs:
        backfilled_count += 1
        data = doc.data()
        pipeline_id = data.get('pipelineId')
        pipeline_key = PIPELINE_MAP.get(pipeline_id, 'unknown')
        backfilled_by_pipeline[pipeline_key] += 1
    
    print(f"  Total backfilled records: {backfilled_count}")
    for pipeline_key, count in backfilled_by_pipeline.items():
        pipeline_name = "Andries" if pipeline_key == 'andries' else "Davide" if pipeline_key == 'davide' else pipeline_key
        print(f"  {pipeline_name}: {count}")
    
    return backfilled_count

def check_product_config(db):
    """Check Product configuration"""
    print("\n💰 Checking Product configuration...")
    
    try:
        products = db.collection('products').limit(1).get()
        if products:
            product_data = products[0].to_dict()
            deposit_amount = product_data.get('depositAmount', 0)
            print(f"  Default deposit amount: R{deposit_amount}")
            
            if deposit_amount == 1500:
                print(f"  ✅ Deposit amount correctly configured")
            else:
                print(f"  ⚠️  Expected R1500, got R{deposit_amount}")
        else:
            print("  ⚠️  No product configuration found")
    except Exception as e:
        print(f"  ❌ Error checking product: {e}")

def main():
    """Main verification function"""
    print("=" * 80)
    print("GHL DATA ACCURACY FIX - VERIFICATION")
    print("=" * 80)
    
    try:
        # Initialize Firebase
        db = init_firebase()
        
        # Check product config
        check_product_config(db)
        
        # Check backfilled records
        backfilled_count = check_backfilled_records(db)
        
        # Get actual counts
        actual_counts = get_latest_stage_counts(db)
        
        # Verify against expected
        verification_passed = verify_counts(actual_counts)
        
        # Summary
        print("\n" + "=" * 80)
        print("SUMMARY")
        print("=" * 80)
        print(f"Backfilled Records: {backfilled_count}")
        print(f"Verification Status: {'✅ PASSED' if verification_passed else '❌ FAILED'}")
        print("=" * 80)
        
        if verification_passed:
            print("\n🎉 Success! The GHL data accuracy fix is working correctly.")
            print("\nNext steps:")
            print("1. Deploy Cloud Functions: firebase deploy --only functions")
            print("2. Trigger manual sync in the app")
            print("3. Verify dashboard displays correct counts")
        else:
            print("\n⚠️  Verification failed. Please review the issues above.")
        
    except Exception as e:
        print(f"\n❌ ERROR: {e}")
        import traceback
        traceback.print_exc()

if __name__ == '__main__':
    main()

