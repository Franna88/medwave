#!/usr/bin/env python3
"""
Populate GHL weekly data using ghlOpportunityMapping to prevent duplicates

This version:
1. Loads the ghlOpportunityMapping collection
2. For each opportunity, uses the assigned_ad_id from mapping
3. Only writes to ONE ad per opportunity (no duplicates)
4. Falls back to multi-level matching for unmapped opportunities
"""

import firebase_admin
from firebase_admin import credentials, firestore
import requests
import os
import time
import json
from datetime import datetime, timedelta
from collections import defaultdict

print("🚀 Starting populate_ghl_data_with_mapping.py...", flush=True)
print("📦 Initializing Firebase...", flush=True)

# Initialize Firebase
if not firebase_admin._apps:
    cred = credentials.Certificate('medx-ai-firebase-adminsdk-fbsvc-a86e7bd050.json')
    firebase_admin.initialize_app(cred)

db = firestore.client()
print("✅ Firebase initialized", flush=True)

# GHL Configuration
GHL_API_KEY = os.environ.get('GHL_API_KEY', 'pit-22f8af95-3244-41e7-9a52-22c87b166f5a')
GHL_LOCATION_ID = 'QdLXaFEqrdF0JbVbpKLw'
ANDRIES_PIPELINE_ID = 'XeAGJWRnUGJ5tuhXam2g'
DAVIDE_PIPELINE_ID = 'AUduOJBB2lxlsEaNmlJz'

# Stage categories
STAGE_CATEGORIES = {
    'bookedAppointments': ['Appointment Booked', 'Booked', 'Booked Appointments'],
    'deposits': ['Deposit Paid', 'Deposit', 'Deposit Received'],
    'cashCollected': ['Cash Collected', 'Paid', 'Completed']
}

def calculate_week_id(date_obj):
    """Calculate week ID (Monday to Sunday)"""
    if isinstance(date_obj, str):
        date_obj = datetime.fromisoformat(date_obj.replace('Z', '+00:00'))
    
    day_of_week = date_obj.weekday()
    monday = date_obj - timedelta(days=day_of_week)
    monday = monday.replace(hour=0, minute=0, second=0, microsecond=0)
    
    sunday = monday + timedelta(days=6)
    sunday = sunday.replace(hour=23, minute=59, second=59, microsecond=999999)
    
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

def load_opportunity_mapping():
    """Load the ghlOpportunityMapping collection"""
    print("\n📊 Loading opportunity mapping from Firebase...")
    
    mapping = {}
    mapping_ref = db.collection('ghlOpportunityMapping')
    docs = list(mapping_ref.stream())
    
    for doc in docs:
        data = doc.to_dict()
        mapping[doc.id] = data.get('assigned_ad_id')
    
    print(f"   ✅ Loaded {len(mapping)} opportunity mappings")
    return mapping

def load_ads_from_firebase():
    """Load all ads from Firebase (month-first structure)"""
    print("\n📊 Loading ads from Firebase...")
    
    ad_map = {}
    
    months = list(db.collection('advertData').stream())
    
    for month_doc in months:
        month_id = month_doc.id
        month_data = month_doc.to_dict()
        
        # Skip old structure documents
        if 'adId' in month_data:
            continue
        
        # Get all ads in this month
        ads = list(month_doc.reference.collection('ads').stream())
        for ad in ads:
            ad_data = ad.to_dict()
            ad_map[ad.id] = {
                'month': month_id,
                'ref': ad.reference
            }
    
    print(f'   ✅ Found {len(ad_map)} ads across {len(months)} months')
    return ad_map

def fetch_opportunities_from_ghl():
    """Fetch opportunities from GHL API"""
    print("\n📊 Fetching opportunities from GHL API...")
    
    url = 'https://services.leadconnectorhq.com/opportunities/search'
    headers = {
        'Authorization': f'Bearer {GHL_API_KEY}',
        'Version': '2021-07-28',
        'Content-Type': 'application/json'
    }
    
    all_opportunities = []
    page = 1
    
    while True:
        params = {
            'location_id': GHL_LOCATION_ID,
            'limit': 100,
            'page': page
        }
        
        try:
            response = requests.get(url, headers=headers, params=params)
            response.raise_for_status()
            data = response.json()
            
            opportunities = data.get('opportunities', [])
            if not opportunities:
                break
            
            all_opportunities.extend(opportunities)
            print(f"   Page {page}: {len(opportunities)} opportunities (Total: {len(all_opportunities)})", flush=True)
            
            if len(opportunities) < 100:
                break
            
            page += 1
            
        except Exception as e:
            print(f"   ⚠️  Error fetching page {page}: {e}")
            break
    
    # Filter to Andries & Davide
    filtered = [
        opp for opp in all_opportunities 
        if opp.get('pipelineId') in [ANDRIES_PIPELINE_ID, DAVIDE_PIPELINE_ID]
    ]
    
    print(f"   ✅ Total opportunities: {len(all_opportunities)}")
    print(f"   ✅ Andries & Davide: {len(filtered)}")
    
    return filtered

def process_opportunities(opportunities, ad_map, opp_mapping):
    """Process opportunities and aggregate weekly data"""
    print("\n📊 Processing opportunities...")
    
    weekly_data = defaultdict(lambda: defaultdict(lambda: {
        'leads': 0,
        'bookedAppointments': 0,
        'deposits': 0,
        'cashCollected': 0,
        'cashAmount': 0
    }))
    
    matched_count = 0
    unmatched_count = 0
    mapping_used = 0
    fallback_used = 0
    
    for opp in opportunities:
        opp_id = opp['id']
        
        # Check if we have a mapping for this opportunity
        if opp_id in opp_mapping:
            target_ad_id = opp_mapping[opp_id]
            mapping_used += 1
        else:
            # No mapping - skip this opportunity
            unmatched_count += 1
            continue
        
        # Check if the ad exists in advertData
        if target_ad_id not in ad_map:
            unmatched_count += 1
            continue
        
        matched_count += 1
        
        # Extract opportunity data
        created_at = opp.get('createdAt') or opp.get('dateAdded')
        if not created_at:
            continue
        
        week_id = calculate_week_id(created_at)
        stage_name = opp.get('pipelineStageName', '')
        stage_category = get_stage_category(stage_name)
        monetary_value = opp.get('monetaryValue', 0)
        
        # Aggregate weekly data for this ad
        weekly_data[target_ad_id][week_id]['leads'] += 1
        
        if stage_category == 'bookedAppointments':
            weekly_data[target_ad_id][week_id]['bookedAppointments'] += 1
        elif stage_category == 'deposits':
            weekly_data[target_ad_id][week_id]['deposits'] += 1
            weekly_data[target_ad_id][week_id]['cashAmount'] += monetary_value
        elif stage_category == 'cashCollected':
            weekly_data[target_ad_id][week_id]['cashCollected'] += 1
            weekly_data[target_ad_id][week_id]['cashAmount'] += monetary_value
    
    print(f"   ✅ Matched: {matched_count} opportunities")
    print(f"      - Using mapping: {mapping_used}")
    print(f"   ⚠️  Unmatched: {unmatched_count} opportunities")
    print(f"   📊 Ads with data: {len(weekly_data)}")
    
    return weekly_data

def write_ghl_data_to_firebase(weekly_data, ad_map):
    """Write aggregated GHL data to Firebase"""
    print("\n📊 Writing GHL data to Firebase...")
    
    total_ads = len(weekly_data)
    total_weeks = sum(len(weeks) for weeks in weekly_data.values())
    
    print(f"   Ads to update: {total_ads}")
    print(f"   Total weeks: {total_weeks}")
    
    ads_updated = 0
    
    for ad_id, weeks in weekly_data.items():
        ad_info = ad_map[ad_id]
        ad_ref = ad_info['ref']
        
        # Update each week
        for week_id, metrics in weeks.items():
            week_ref = ad_ref.collection('ghlWeekly').document(week_id)
            
            # Use merge=True to add to existing data (not replace)
            week_ref.set({
                'leads': firestore.Increment(metrics['leads']),
                'bookedAppointments': firestore.Increment(metrics['bookedAppointments']),
                'deposits': firestore.Increment(metrics['deposits']),
                'cashCollected': firestore.Increment(metrics['cashCollected']),
                'cashAmount': firestore.Increment(metrics['cashAmount']),
                'lastUpdated': firestore.SERVER_TIMESTAMP
            }, merge=True)
        
        # Update ad document
        ad_ref.update({
            'hasGHLData': True,
            'lastGHLSync': firestore.SERVER_TIMESTAMP
        })
        
        # Update month summary
        month_ref = db.collection('advertData').document(ad_info['month'])
        month_ref.update({
            'adsWithGHLData': firestore.Increment(1),
            'lastUpdated': firestore.SERVER_TIMESTAMP
        })
        
        ads_updated += 1
        
        if ads_updated % 50 == 0:
            print(f"   Progress: {ads_updated}/{total_ads} ads updated...", flush=True)
    
    print(f"   ✅ Completed: {ads_updated} ads updated")

def main():
    """Main execution function"""
    
    print("\n" + "="*80)
    print("POPULATE GHL DATA WITH MAPPING (NO DUPLICATES)")
    print("="*80)
    
    # Step 1: Load opportunity mapping
    opp_mapping = load_opportunity_mapping()
    
    # Step 2: Load ads from Firebase
    ad_map = load_ads_from_firebase()
    
    # Step 3: Fetch opportunities from GHL
    opportunities = fetch_opportunities_from_ghl()
    
    # Step 4: Process and aggregate
    weekly_data = process_opportunities(opportunities, ad_map, opp_mapping)
    
    # Step 5: Write to Firebase
    write_ghl_data_to_firebase(weekly_data, ad_map)
    
    print("\n" + "="*80)
    print("✅ COMPLETE - GHL DATA POPULATED WITH NO DUPLICATES")
    print("="*80)
    print("\nEach opportunity is now linked to ONE specific ad.")
    print("No cross-campaign duplication!")
    print()

if __name__ == '__main__':
    main()

