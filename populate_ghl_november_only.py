#!/usr/bin/env python3
"""
Populate GHL weekly data ONLY for November 2025 ads
Modified version that filters to a specific month
"""

import firebase_admin
from firebase_admin import credentials, firestore
import requests
import os
import time
from datetime import datetime, timedelta
from collections import defaultdict

# Initialize Firebase
if not firebase_admin._apps:
    cred = credentials.Certificate('medx-ai-firebase-adminsdk-fbsvc-a86e7bd050.json')
    firebase_admin.initialize_app(cred)

db = firestore.client()

# GHL Configuration
GHL_API_KEY = os.environ.get('GHL_API_KEY', 'pit-22f8af95-3244-41e7-9a52-22c87b166f5a')
GHL_LOCATION_ID = 'QdLXaFEqrdF0JbVbpKLw'

# Pipeline IDs (Andries and Davide only)
ANDRIES_PIPELINE_ID = 'XeAGJWRnUGJ5tuhXam2g'
DAVIDE_PIPELINE_ID = 'pTbNvnrXqJc9u1oxir3q'

# ⭐ MONTH TO POPULATE - CHANGE THIS TO TARGET DIFFERENT MONTHS
TARGET_MONTH = '2025-11'  # November 2025

# Stage categories
STAGE_CATEGORIES = {
    'bookedAppointments': ['Appointment Booked', 'Booked'],
    'deposits': ['Deposit Paid', 'Deposit'],
    'cashCollected': ['Cash Collected', 'Paid', 'Completed']
}

def calculate_week_id(date_obj):
    """Calculate week ID (Monday to Sunday) for a given date"""
    if isinstance(date_obj, str):
        date_obj = datetime.fromisoformat(date_obj.replace('Z', '+00:00'))
    
    # Get Monday of the week
    day_of_week = date_obj.weekday()  # Monday = 0
    monday = date_obj - timedelta(days=day_of_week)
    monday = monday.replace(hour=0, minute=0, second=0, microsecond=0)
    
    # Get Sunday of the week
    sunday = monday + timedelta(days=6)
    sunday = sunday.replace(hour=23, minute=59, second=59, microsecond=999999)
    
    # Format as YYYY-MM-DD_YYYY-MM-DD
    monday_str = monday.strftime('%Y-%m-%d')
    sunday_str = sunday.strftime('%Y-%m-%d')
    
    return f"{monday_str}_{sunday_str}"

def get_stage_category(stage_name):
    """Determine which category a stage belongs to"""
    stage_lower = stage_name.lower()
    
    for category, keywords in STAGE_CATEGORIES.items():
        for keyword in keywords:
            if keyword.lower() in stage_lower:
                return category
    
    return None

def extract_h_ad_id_from_attributions(opp):
    """Extract h_ad_id from opportunity attributions"""
    attributions = opp.get('attributions', {})
    
    if not attributions:
        return None
    
    # Try different fields in reverse order (last attribution first)
    for attr in reversed(attributions):
        h_ad_id = attr.get('h_ad_id') or attr.get('utmAdId') or attr.get('adId')
        if h_ad_id:
            return str(h_ad_id)
    
    return None

def fetch_opportunities_from_ghl():
    """Fetch ALL opportunities from GHL API"""
    
    print(f'\n📊 Fetching opportunities from GHL API...')
    
    url = 'https://services.leadconnectorhq.com/opportunities/search'
    headers = {
        'Authorization': f'Bearer {GHL_API_KEY}',
        'Version': '2021-07-28',
        'Content-Type': 'application/json'
    }
    
    all_opportunities = []
    page = 1
    limit = 100
    max_pages = 100
    
    while page <= max_pages:
        params = {
            'location_id': GHL_LOCATION_ID,
            'limit': limit,
            'page': page
        }
        
        try:
            response = requests.get(url, headers=headers, params=params, timeout=30)
            response.raise_for_status()
            data = response.json()
            
            opportunities = data.get('opportunities', [])
            
            if not opportunities:
                break
            
            all_opportunities.extend(opportunities)
            print(f'   Page {page}: {len(opportunities)} opportunities')
            
            page += 1
            time.sleep(0.1)
            
        except requests.exceptions.RequestException as e:
            print(f'   ❌ Error on page {page}: {e}')
            break
    
    print(f'   ✅ Total fetched: {len(all_opportunities)} opportunities')
    return all_opportunities

def process_opportunities():
    """Main function - populate ONLY the target month"""
    
    print('\n' + '='*80)
    print(f'POPULATE GHL DATA FOR {TARGET_MONTH} ONLY')
    print('='*80)
    
    # Step 1: Get ads from TARGET MONTH ONLY
    print(f'\n📱 Step 1: Loading ads from {TARGET_MONTH}...')
    
    ad_map = {}
    
    try:
        month_ref = db.collection('advertData').document(TARGET_MONTH)
        month_doc = month_ref.get()
        
        if not month_doc.exists:
            print(f'   ❌ Month {TARGET_MONTH} does not exist in advertData!')
            return
        
        # Get all ads in this month
        ads = list(month_ref.collection('ads').stream())
        for ad in ads:
            ad_map[ad.id] = {
                'month': TARGET_MONTH,
                'ref': ad.reference
            }
        
        print(f'   ✅ Found {len(ad_map)} ads in {TARGET_MONTH}')
        
    except Exception as e:
        print(f'   ❌ Error loading ads: {e}')
        return
    
    if not ad_map:
        print(f'   ⚠️  No ads found in {TARGET_MONTH}')
        return
    
    ad_ids = set(ad_map.keys())
    
    # Step 2: Fetch opportunities from GHL API
    print('\n📊 Step 2: Fetching opportunities from GHL API...')
    
    all_opportunities = fetch_opportunities_from_ghl()
    print(f'   ✅ Total opportunities: {len(all_opportunities)}')
    
    # Filter to Andries and Davide pipelines
    filtered_opps = [opp for opp in all_opportunities 
                     if opp.get('pipelineId') in [ANDRIES_PIPELINE_ID, DAVIDE_PIPELINE_ID]]
    print(f'   ✅ Filtered to Andries & Davide: {len(filtered_opps)} opportunities')
    
    # Step 3: Process and match to ads
    print(f'\n🔄 Step 3: Matching opportunities to {TARGET_MONTH} ads...')
    
    weekly_data = defaultdict(lambda: defaultdict(lambda: {
        'leads': 0,
        'bookedAppointments': 0,
        'deposits': 0,
        'cashCollected': 0,
        'cashAmount': 0
    }))
    
    matched_count = 0
    unmatched_count = 0
    
    for opp in filtered_opps:
        h_ad_id = extract_h_ad_id_from_attributions(opp)
        
        # Only process if ad is in our target month
        if not h_ad_id or h_ad_id not in ad_ids:
            unmatched_count += 1
            continue
        
        matched_count += 1
        
        # Get opportunity details
        created_at = opp.get('createdAt') or opp.get('dateAdded')
        stage_name = opp.get('status', '')
        monetary_value = float(opp.get('monetaryValue', 0) or 0)
        
        # Calculate week
        week_id = calculate_week_id(created_at)
        
        # Determine stage category
        stage_category = get_stage_category(stage_name)
        
        # Update weekly data
        weekly_data[h_ad_id][week_id]['leads'] += 1
        
        if stage_category == 'bookedAppointments':
            weekly_data[h_ad_id][week_id]['bookedAppointments'] += 1
        elif stage_category == 'deposits':
            weekly_data[h_ad_id][week_id]['deposits'] += 1
            weekly_data[h_ad_id][week_id]['cashAmount'] += monetary_value or 1500
        elif stage_category == 'cashCollected':
            weekly_data[h_ad_id][week_id]['cashCollected'] += 1
            weekly_data[h_ad_id][week_id]['cashAmount'] += monetary_value or 1500
    
    print(f'   ✅ Matched: {matched_count} opportunities to {TARGET_MONTH} ads')
    print(f'   ⚠️ Unmatched: {unmatched_count} opportunities')
    print(f'   📊 Ads with data: {len(weekly_data)}')
    
    # Step 4: Write to Firebase
    print(f'\n💾 Step 4: Writing to Firebase ({TARGET_MONTH})...')
    
    total_weeks = 0
    ads_updated = 0
    
    for ad_id, weeks in weekly_data.items():
        ad_ref = ad_map[ad_id]['ref']
        
        for week_id, data in weeks.items():
            week_ref = ad_ref.collection('ghlWeekly').document(week_id)
            
            week_ref.set({
                'leads': data['leads'],
                'bookedAppointments': data['bookedAppointments'],
                'deposits': data['deposits'],
                'cashCollected': data['cashCollected'],
                'cashAmount': data['cashAmount'],
                'lastUpdated': firestore.SERVER_TIMESTAMP
            }, merge=True)
            
            total_weeks += 1
        
        # Update ad document
        ad_ref.update({
            'lastGHLSync': firestore.SERVER_TIMESTAMP,
            'hasGHLData': True
        })
        
        ads_updated += 1
        print(f'   ✅ {ad_id}: {len(weeks)} weeks')
    
    # Update month summary
    print(f'\n📊 Updating {TARGET_MONTH} summary...')
    month_ref = db.collection('advertData').document(TARGET_MONTH)
    month_ref.update({
        'adsWithGHLData': firestore.Increment(ads_updated),
        'lastUpdated': firestore.SERVER_TIMESTAMP
    })
    
    print(f'\n' + '='*80)
    print(f'GHL DATA POPULATED FOR {TARGET_MONTH}!')
    print('='*80)
    print(f'\n📊 Summary:')
    print(f'   Target Month: {TARGET_MONTH}')
    print(f'   Ads updated: {ads_updated}')
    print(f'   Total weeks: {total_weeks}')
    print(f'   Matched opportunities: {matched_count}')
    print(f'   Structure: advertData/{TARGET_MONTH}/ads/{{adId}}/ghlWeekly/{{weekId}}')
    print('\n' + '='*80)

if __name__ == '__main__':
    process_opportunities()



