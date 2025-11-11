#!/usr/bin/env python3
"""
Populate REAL data for the 10 test ads
- Facebook insights from adPerformance (if available)
- GHL data from opportunityStageHistory (last 6 months)
"""

import firebase_admin
from firebase_admin import credentials, firestore
from datetime import datetime, timedelta
from collections import defaultdict

# Initialize Firebase
try:
    cred = credentials.Certificate('medx-ai-firebase-adminsdk-fbsvc-a86e7bd050.json')
    firebase_admin.initialize_app(cred)
except:
    pass

db = firestore.client()

def calculate_week_id(timestamp):
    """Calculate week ID (Monday to Sunday)"""
    if isinstance(timestamp, str):
        date = datetime.fromisoformat(timestamp.replace('Z', '+00:00'))
    else:
        date = timestamp
    
    days_since_monday = date.weekday()
    monday = date - timedelta(days=days_since_monday)
    sunday = monday + timedelta(days=6)
    
    monday_str = monday.strftime('%Y-%m-%d')
    sunday_str = sunday.strftime('%Y-%m-%d')
    
    return f"{monday_str}_{sunday_str}"

def get_stage_category(stage_name):
    """Determine stage category"""
    stage = stage_name.lower()
    
    if 'appointment' in stage or 'booked' in stage:
        return 'bookedAppointments'
    if 'deposit' in stage:
        return 'deposits'
    if 'cash' in stage and 'collected' in stage:
        return 'cashCollected'
    
    return 'other'

print('\n' + '='*80)
print('POPULATE REAL DATA FOR 10 TEST ADS')
print('='*80 + '\n')

# Get the 10 test ads
test_ads = list(db.collection('advertData').limit(10).stream())
print(f'Found {len(test_ads)} test ads\n')

six_months_ago = datetime.now() - timedelta(days=180)

for i, ad_doc in enumerate(test_ads, 1):
    ad_id = ad_doc.id
    ad_data = ad_doc.to_dict()
    
    print(f'{i}. Processing: {ad_data.get("adName", ad_id)[:50]}')
    print(f'   Ad ID: {ad_id}')
    
    # ========================================
    # PART 1: Facebook Insights from adPerformance
    # ========================================
    ad_perf_doc = db.collection('adPerformance').document(ad_id).get()
    if ad_perf_doc.exists:
        ad_perf_data = ad_perf_doc.to_dict()
        insights_data = ad_perf_data.get('insights', {})
        
        if insights_data:
            print(f'   📊 Found {len(insights_data)} weeks of Facebook insights')
            
            # Delete placeholder
            db.collection('advertData').document(ad_id).collection('insights').document('_placeholder').delete()
            
            # Write real insights
            for week_id, week_data in insights_data.items():
                insight_ref = db.collection('advertData').document(ad_id).collection('insights').document(week_id)
                insight_ref.set({
                    'dateStart': week_data.get('dateStart', ''),
                    'dateStop': week_data.get('dateStop', ''),
                    'spend': float(week_data.get('spend', 0)),
                    'impressions': int(week_data.get('impressions', 0)),
                    'reach': int(week_data.get('reach', 0)),
                    'clicks': int(week_data.get('clicks', 0)),
                    'cpm': float(week_data.get('cpm', 0)),
                    'cpc': float(week_data.get('cpc', 0)),
                    'ctr': float(week_data.get('ctr', 0)),
                    'fetchedAt': firestore.SERVER_TIMESTAMP
                })
            print(f'   ✅ Wrote {len(insights_data)} Facebook insights')
        else:
            print(f'   ⚠️  No Facebook insights in adPerformance')
    else:
        print(f'   ⚠️  Ad not found in adPerformance')
    
    # ========================================
    # PART 2: GHL Data from opportunityStageHistory
    # ========================================
    opps_ref = db.collection('opportunityStageHistory')\
        .where('facebookAdId', '==', ad_id)\
        .stream()
    
    # Group by opportunityId and week
    opp_latest_state = {}
    weekly_data = defaultdict(lambda: {
        'leads': 0,
        'bookedAppointments': 0,
        'deposits': 0,
        'cashCollected': 0,
        'cashAmount': 0
    })
    
    for opp_doc in opps_ref:
        opp_data = opp_doc.to_dict()
        timestamp = opp_data.get('timestamp')
        
        if not timestamp:
            continue
        
        # Convert to datetime
        if hasattr(timestamp, 'to_pydatetime'):
            date = timestamp.to_pydatetime()
        else:
            date = timestamp
        
        # Skip if older than 6 months
        if date < six_months_ago:
            continue
        
        opp_id = opp_data.get('opportunityId')
        
        # Track latest state per opportunity
        if opp_id not in opp_latest_state or date > opp_latest_state[opp_id]['timestamp']:
            opp_latest_state[opp_id] = {
                'timestamp': date,
                'stageCategory': opp_data.get('stageCategory') or get_stage_category(opp_data.get('newStageName', '')),
                'monetaryValue': opp_data.get('monetaryValue', 0)
            }
    
    if opp_latest_state:
        print(f'   📈 Found {len(opp_latest_state)} opportunities')
        
        # Aggregate by week
        for opp_id, state in opp_latest_state.items():
            week_id = calculate_week_id(state['timestamp'])
            week_data = weekly_data[week_id]
            
            week_data['leads'] += 1
            
            if state['stageCategory'] == 'bookedAppointments':
                week_data['bookedAppointments'] += 1
            elif state['stageCategory'] == 'deposits':
                week_data['deposits'] += 1
                week_data['cashAmount'] += state['monetaryValue'] or 1500
            elif state['stageCategory'] == 'cashCollected':
                week_data['cashCollected'] += 1
                week_data['cashAmount'] += state['monetaryValue'] or 1500
        
        # Delete placeholder
        db.collection('advertData').document(ad_id).collection('ghlWeekly').document('_placeholder').delete()
        
        # Write real GHL data
        for week_id, metrics in weekly_data.items():
            week_ref = db.collection('advertData').document(ad_id).collection('ghlWeekly').document(week_id)
            week_ref.set(metrics)
        
        print(f'   ✅ Wrote {len(weekly_data)} weeks of GHL data')
        
        # Update lastGHLSync
        db.collection('advertData').document(ad_id).update({
            'lastGHLSync': firestore.SERVER_TIMESTAMP
        })
    else:
        print(f'   ⚠️  No GHL opportunities found')
    
    print()

print('='*80)
print('REAL DATA POPULATED!')
print('='*80 + '\n')

print('✅ Check Firebase Console to see:')
print('   - insights/ subcollection with real Facebook data')
print('   - ghlWeekly/ subcollection with real GHL data')
print('   - Placeholders removed')
print('\n📍 https://console.firebase.google.com/project/medx-ai/firestore/databases/-default-/data/~2FadvertData')
print('\n' + '='*80 + '\n')

