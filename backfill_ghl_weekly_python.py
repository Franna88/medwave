#!/usr/bin/env python3
"""
PROPER GHL Weekly Data Backfill - Python version
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
    
    # Get Monday of the week
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
print('GHL WEEKLY DATA BACKFILL - PYTHON VERSION')
print('='*80 + '\n')

# Get all ads
print('📥 Fetching all ads from advertData...')
adverts = list(db.collection('advertData').stream())
print(f'✅ Found {len(adverts)} ads\n')

# Get 6 months cutoff
six_months_ago = datetime.now() - timedelta(days=180)

print('🔄 Processing opportunities...\n')

total_ads_updated = 0
total_weeks_written = 0
total_opportunities = 0

for i, advert in enumerate(adverts, 1):
    ad_id = advert.id
    
    # Get opportunities for this ad
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
    
    if not opp_latest_state:
        if (i % 100 == 0):
            print(f'   Progress: {i}/{len(adverts)} ads processed...')
        continue
    
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
    
    # Write to Firebase
    if weekly_data:
        ad_data = advert.to_dict()
        print(f'✅ {ad_data.get("adName", ad_id)[:50]}')
        print(f'   Opportunities: {len(opp_latest_state)}, Weeks: {len(weekly_data)}')
        
        for week_id, metrics in weekly_data.items():
            week_ref = db.collection('advertData').document(ad_id)\
                .collection('ghlWeekly').document(week_id)
            
            week_ref.set(metrics, merge=True)
            total_weeks_written += 1
        
        # Update lastGHLSync
        db.collection('advertData').document(ad_id).update({
            'lastGHLSync': firestore.SERVER_TIMESTAMP
        })
        
        total_ads_updated += 1
        total_opportunities += len(opp_latest_state)
    
    if (i % 100 == 0):
        print(f'   Progress: {i}/{len(adverts)} ads processed...')

print('\n' + '='*80)
print('BACKFILL COMPLETE')
print('='*80 + '\n')

print(f'Total ads processed: {len(adverts)}')
print(f'Ads with GHL data: {total_ads_updated}')
print(f'Total opportunities: {total_opportunities}')
print(f'Total weeks written: {total_weeks_written}')

print('\n' + '='*80 + '\n')

