#!/usr/bin/env python3
"""
FRESH START - Populate advertData with correct structure
Step 1: Migrate ads from adPerformance
Step 2: Backfill GHL weekly data
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
print('FRESH START - POPULATE ADVERTDATA WITH CORRECT STRUCTURE')
print('='*80 + '\n')

# STEP 1: Migrate ads from adPerformance
print('📥 STEP 1: Migrating ads from adPerformance...\n')

ad_perf_docs = list(db.collection('adPerformance').stream())
print(f'Found {len(ad_perf_docs)} ads in adPerformance\n')

migrated_ads = 0

for ad_doc in ad_perf_docs:
    ad_id = ad_doc.id
    ad_data = ad_doc.to_dict()
    
    # Create clean advertData document
    advert_ref = db.collection('advertData').document(ad_id)
    advert_ref.set({
        'campaignId': ad_data.get('campaignId', ''),
        'campaignName': ad_data.get('campaignName', ''),
        'adSetId': ad_data.get('adSetId', ''),
        'adSetName': ad_data.get('adSetName', ''),
        'adId': ad_id,
        'adName': ad_data.get('adName', ''),
        'lastUpdated': firestore.SERVER_TIMESTAMP,
        'lastFacebookSync': ad_data.get('lastFacebookSync'),
        'createdAt': firestore.SERVER_TIMESTAMP
    })
    
    migrated_ads += 1
    
    if migrated_ads % 100 == 0:
        print(f'   Migrated {migrated_ads}/{len(ad_perf_docs)} ads...')

print(f'\n✅ Migrated {migrated_ads} ads to advertData\n')

# STEP 2: Backfill GHL weekly data
print('📊 STEP 2: Backfilling GHL weekly data...\n')

six_months_ago = datetime.now() - timedelta(days=180)

total_ads_updated = 0
total_weeks_written = 0
total_opportunities = 0

adverts = list(db.collection('advertData').stream())

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
    
    # Write to Firebase with CLEAN structure
    if weekly_data:
        ad_data = advert.to_dict()
        print(f'✅ {ad_data.get("adName", ad_id)[:50]}')
        print(f'   Opportunities: {len(opp_latest_state)}, Weeks: {len(weekly_data)}')
        
        for week_id, metrics in weekly_data.items():
            # CLEAN STRUCTURE: advertData/{adId}/ghlWeekly/{weekId}
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
print('FRESH START COMPLETE!')
print('='*80 + '\n')

print('📊 Summary:')
print(f'   Total ads migrated: {migrated_ads}')
print(f'   Ads with GHL data: {total_ads_updated}')
print(f'   Total opportunities: {total_opportunities}')
print(f'   Total weeks written: {total_weeks_written}')

print('\n✅ Structure:')
print('   advertData/{adId}/ (main document)')
print('   advertData/{adId}/ghlWeekly/{weekId} (GHL weekly data)')
print('   advertData/{adId}/insights/{weekId} (Facebook insights - to be populated)')

print('\n' + '='*80 + '\n')

