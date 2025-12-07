#!/usr/bin/env python3
"""
Populate GHL weekly data for ads in advertData collection
Fetches fresh data from GHL API and matches to Facebook ads via h_ad_id
"""

import firebase_admin
from firebase_admin import credentials, firestore
import requests
import os
import time
import json
from datetime import datetime, timedelta
from collections import defaultdict

print("🚀 Starting populate_ghl_data.py...", flush=True)
print("📦 Initializing Firebase...", flush=True)

# Initialize Firebase
if not firebase_admin._apps:
    # Get the directory where this script is located
    script_dir = os.path.dirname(os.path.abspath(__file__))
    
    # Try to find Firebase credentials file in common locations
    cred_paths = [
        os.path.join(script_dir, 'ghl_opp_collection', 'medx-ai-firebase-adminsdk-fbsvc-d88a6aa1a7.json'),
        os.path.join(script_dir, 'summary_collection', 'medx-ai-firebase-adminsdk-fbsvc-d88a6aa1a7.json'),
        os.path.join(script_dir, 'medx-ai-firebase-adminsdk-fbsvc-d88a6aa1a7.json')
    ]
    
    cred_path = None
    for path in cred_paths:
        if os.path.exists(path):
            cred_path = path
            break
    
    if not cred_path:
        raise FileNotFoundError(
            f"Firebase credentials file not found. Tried:\n" + 
            "\n".join(f"  - {p}" for p in cred_paths)
        )
    
    cred = credentials.Certificate(cred_path)
    firebase_admin.initialize_app(cred)

db = firestore.client()
print("✅ Firebase initialized", flush=True)

# GHL Configuration (from working syncOpportunities.py)
GHL_API_KEY = os.environ.get('GHL_API_KEY', 'pit-22f8af95-3244-41e7-9a52-22c87b166f5a')
GHL_LOCATION_ID = 'QdLXaFEqrdF0JbVbpKLw'

# Pipeline IDs (from scheduledSync function - Andries and Davide only, exclude Altus)
ANDRIES_PIPELINE_ID = 'XeAGJWRnUGJ5tuhXam2g'
DAVIDE_PIPELINE_ID = 'AUduOJBB2lxlsEaNmlJz'  # ⭐ CORRECTED: This is the REAL Davide's Pipeline
# Note: pTbNvnrXqJc9u1oxir3q is actually Erich Pipeline, not Davide

# Load stage mappings from JSON file
def load_stage_mappings():
    """Load pipeline stage ID to name mappings"""
    try:
        # Get the directory where this script is located
        script_dir = os.path.dirname(os.path.abspath(__file__))
        mappings_path = os.path.join(script_dir, 'ghl_info', 'pipeline_stage_mappings.json')
        
        if not os.path.exists(mappings_path):
            print(f'⚠️  Warning: Stage mappings file not found at {mappings_path}')
            return {}
        
        with open(mappings_path, 'r') as f:
            return json.load(f)
    except Exception as e:
        print(f'⚠️  Warning: Could not load stage mappings: {e}')
        return {}

STAGE_MAPPINGS = load_stage_mappings()

# Stage categories for tracking (now includes "Deposit Received")
STAGE_CATEGORIES = {
    'bookedAppointments': ['Appointment Booked', 'Booked', 'Booked Appointments'],
    'deposits': ['Deposit Paid', 'Deposit', 'Deposit Received'],  # ⭐ ADDED "Deposit Received"
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

def fetch_opportunities_from_ghl():
    """Fetch ALL opportunities from GHL API (all pipelines) - with full pagination"""
    
    print(f'\n📊 Fetching ALL opportunities from GHL API (with pagination)...')
    
    url = 'https://services.leadconnectorhq.com/opportunities/search'
    headers = {
        'Authorization': f'Bearer {GHL_API_KEY}',
        'Version': '2021-07-28',
        'Content-Type': 'application/json'
    }
    
    all_opportunities = []
    page = 1
    limit = 100
    max_pages = 100  # Safety limit to prevent infinite loops
    
    while page <= max_pages:
        params = {
            'location_id': GHL_LOCATION_ID,
            'limit': limit,
            'page': page  # Use page-based pagination instead of cursor
        }
        
        try:
            response = requests.get(url, headers=headers, params=params, timeout=30)
            response.raise_for_status()
            data = response.json()
            
            opportunities = data.get('opportunities', [])
            
            # If no opportunities returned, we've reached the end
            if not opportunities:
                print(f'   📄 Page {page}: No more opportunities (end of data)')
                break
            
            all_opportunities.extend(opportunities)
            print(f'   📄 Page {page}: Fetched {len(opportunities)} opportunities (Total: {len(all_opportunities)})')
            
            # If we got fewer results than limit, this is the last page
            if len(opportunities) < limit:
                print(f'   ✅ Reached end of data (last page had {len(opportunities)} opportunities)')
                break
            
            page += 1
            time.sleep(0.5)  # Rate limiting to avoid API throttling
            
        except requests.exceptions.RequestException as e:
            print(f'   ❌ Error fetching page {page}: {e}')
            print(f'   ⚠️  Continuing with {len(all_opportunities)} opportunities fetched so far')
            break
    
    if page > max_pages:
        print(f'   ⚠️  Reached maximum page limit ({max_pages})')
    
    print(f'\n   ✅ TOTAL FETCHED: {len(all_opportunities)} opportunities across {page} pages')
    return all_opportunities

def extract_h_ad_id_from_attributions(opportunity):
    """Extract h_ad_id or campaign_id from opportunity attributions"""
    attributions = opportunity.get('attributions', [])
    
    # Look for last attribution with h_ad_id, utmAdId, or utmCampaignId
    for attr in reversed(attributions):
        # First try to get Ad ID (most specific)
        h_ad_id = (attr.get('h_ad_id') or 
                  attr.get('utmAdId') or
                  attr.get('adId'))
        
        if h_ad_id:
            return h_ad_id
        
        # Fallback to Campaign ID if no Ad ID found
        campaign_id = attr.get('utmCampaignId')
        if campaign_id:
            return campaign_id
    
    return None

def get_contact_details(contact_id):
    """Fetch contact details from GHL API"""
    
    url = f'https://services.leadconnectorhq.com/contacts/{contact_id}'
    headers = {
        'Authorization': f'Bearer {GHL_API_KEY}',
        'Version': '2021-07-28'
    }
    
    try:
        response = requests.get(url, headers=headers)
        response.raise_for_status()
        return response.json().get('contact', {})
    except requests.exceptions.RequestException as e:
        print(f'   ⚠️ Error fetching contact {contact_id}: {e}')
        return {}

def process_opportunities():
    """Main function to process opportunities and populate advertData"""
    
    print('\n' + '='*80, flush=True)
    print('POPULATE GHL DATA FROM API', flush=True)
    print('='*80, flush=True)
    
    # Step 1: Get all ads from NEW month-first structure
    print('\n📱 Step 1: Loading ads from advertData (month-first structure)...', flush=True)
    
    # Build multiple lookup maps for flexible matching
    ad_map = {}
    campaign_to_ads = defaultdict(list)  # Map campaign_id -> list of ad_ids
    ad_name_to_ads = defaultdict(list)  # Map ad_name -> list of ad_ids
    adset_name_to_ads = defaultdict(list)  # Map adset_name -> list of ad_ids
    
    # Get all month documents
    print('   Loading month documents...', flush=True)
    months = list(db.collection('advertData').stream())
    print(f'   Found {len(months)} month documents', flush=True)
    for month_doc in months:
        month_id = month_doc.id
        # Skip if this is an old structure document (has adId field)
        month_data = month_doc.to_dict()
        if 'adId' in month_data:
            continue  # This is old structure, skip
        
        # Get all ads in this month
        ads = list(month_doc.reference.collection('ads').stream())
        for ad in ads:
            ad_data = ad.to_dict()
            campaign_id = ad_data.get('campaignId', '')
            ad_name = ad_data.get('adName', '').strip()
            adset_name = ad_data.get('adSetName', '').strip()
            
            ad_map[ad.id] = {
                'month': month_id,
                'ref': ad.reference,
                'campaign_id': campaign_id,
                'ad_name': ad_name,
                'adset_name': adset_name
            }
            
            # Build lookup maps (case-insensitive)
            if campaign_id:
                campaign_to_ads[campaign_id].append(ad.id)
            if ad_name:
                ad_name_to_ads[ad_name.lower()].append(ad.id)
            if adset_name:
                adset_name_to_ads[adset_name.lower()].append(ad.id)
    
    ad_ids = set(ad_map.keys())
    print(f'   ✅ Found {len(ad_ids)} ads across {len(months)} months', flush=True)
    print(f'   ✅ Found {len(campaign_to_ads)} unique campaigns', flush=True)
    print(f'   ✅ Found {len(ad_name_to_ads)} unique ad names', flush=True)
    print(f'   ✅ Found {len(adset_name_to_ads)} unique adset names', flush=True)
    
    # Step 2: Fetch opportunities from GHL API (all pipelines)
    print('\n📊 Step 2: Fetching opportunities from GHL API...', flush=True)
    
    all_opportunities = fetch_opportunities_from_ghl()
    print(f'\n   ✅ Total opportunities: {len(all_opportunities)}', flush=True)
    
    # Filter to only Andries and Davide pipelines
    filtered_opps = [opp for opp in all_opportunities 
                     if opp.get('pipelineId') in [ANDRIES_PIPELINE_ID, DAVIDE_PIPELINE_ID]]
    print(f'   ✅ Filtered to Andries & Davide: {len(filtered_opps)} opportunities')
    all_opportunities = filtered_opps
    
    # Step 3: Load opportunity -> ad ID mappings from Firebase
    print('\n📊 Step 3: Loading opportunity mappings from Firebase...', flush=True)
    
    opportunity_mappings = {}
    mapping_docs = list(db.collection('ghlOpportunityMapping').stream())
    print(f'   ✅ Found {len(mapping_docs)} mapping documents', flush=True)
    
    for idx, doc in enumerate(mapping_docs, 1):
        if idx % 100 == 0:
            print(f'   Processing mapping {idx}/{len(mapping_docs)}...', flush=True)
        data = doc.to_dict()
        opportunity_mappings[doc.id] = data.get('assigned_ad_id')
    
    print(f'   ✅ Loaded {len(opportunity_mappings)} opportunity mappings', flush=True)
    
    # Step 4: Process each opportunity and match to ads using mapping
    print('\n🔄 Step 4: Processing opportunities and matching to ads...')
    
    # Track weekly data per ad
    weekly_data = defaultdict(lambda: defaultdict(lambda: {
        'leads': 0,
        'bookedAppointments': 0,
        'deposits': 0,
        'cashCollected': 0,
        'cashAmount': 0
    }))
    
    matched_count = 0
    unmatched_count = 0
    total_opps = len(all_opportunities)
    
    # Track matching methods
    match_stats = {
        'from_mapping': 0,
        'unmatched': 0
    }
    
    for idx, opp in enumerate(all_opportunities, 1):
        # Show progress every 100 opportunities
        if idx % 100 == 0 or idx == total_opps:
            print(f'   Processing: {idx}/{total_opps} opportunities...', flush=True)
        
        opp_id = opp.get('id')
        
        # Check if we have a mapping for this opportunity
        assigned_ad_id = opportunity_mappings.get(opp_id)
        
        if not assigned_ad_id or assigned_ad_id not in ad_ids:
            match_stats['unmatched'] += 1
            unmatched_count += 1
            continue
        
        # Use the assigned ad ID (1:1 mapping - no duplicates!)
        target_ad_id = assigned_ad_id
        match_stats['from_mapping'] += 1
        matched_count += 1
        
        # Get opportunity details
        created_at = opp.get('createdAt') or opp.get('dateAdded')
        pipeline_id = opp.get('pipelineId')
        stage_id = opp.get('pipelineStageId')
        monetary_value = float(opp.get('monetaryValue', 0) or 0)
        
        # Get stage name from stage ID using our mapping
        stage_name = ''
        if pipeline_id == ANDRIES_PIPELINE_ID and STAGE_MAPPINGS.get('andries'):
            stage_name = STAGE_MAPPINGS['andries']['stages'].get(stage_id, '')
        elif pipeline_id == DAVIDE_PIPELINE_ID and STAGE_MAPPINGS.get('davide'):
            stage_name = STAGE_MAPPINGS['davide']['stages'].get(stage_id, '')
        
        # Calculate week
        week_id = calculate_week_id(created_at)
        
        # Determine stage category
        stage_category = get_stage_category(stage_name)
        
        # Update weekly data for THIS SINGLE ad (1:1 mapping - no duplicates!)
        weekly_data[target_ad_id][week_id]['leads'] += 1
        
        if stage_category == 'bookedAppointments':
            weekly_data[target_ad_id][week_id]['bookedAppointments'] += 1
        elif stage_category == 'deposits':
            weekly_data[target_ad_id][week_id]['deposits'] += 1
            weekly_data[target_ad_id][week_id]['cashAmount'] += monetary_value
        elif stage_category == 'cashCollected':
            weekly_data[target_ad_id][week_id]['cashCollected'] += 1
            weekly_data[target_ad_id][week_id]['cashAmount'] += monetary_value
    
    print(f'   ✅ Matched: {matched_count} opportunities', flush=True)
    print(f'      - From mapping: {match_stats["from_mapping"]}', flush=True)
    print(f'   ⚠️  Unmatched: {unmatched_count} opportunities', flush=True)
    print(f'   📊 Ads with data: {len(weekly_data)}', flush=True)
    
    # Step 5: Write to NEW month-first structure
    print('\n💾 Step 5: Writing to Firebase (month-first structure)...', flush=True)
    
    total_weeks = 0
    ads_updated = 0
    month_updates = defaultdict(int)
    
    for ad_id, weeks in weekly_data.items():
        # Check if ad exists in our map
        if ad_id not in ad_map:
            print(f'   ⚠️  Ad {ad_id} not found in advertData, skipping')
            continue
        
        month = ad_map[ad_id]['month']
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
        
        # Update ad document with lastGHLSync and hasGHLData flag
        ad_ref.update({
            'lastGHLSync': firestore.SERVER_TIMESTAMP,
            'hasGHLData': True
        })
        
        # Track month updates
        month_updates[month] += 1
        
        ads_updated += 1
        print(f'   ✅ {ad_id} ({month}): {len(weeks)} weeks')
    
    # Update month summaries
    print('\n📊 Updating month summaries...')
    for month, count in month_updates.items():
        month_ref = db.collection('advertData').document(month)
        month_ref.update({
            'adsWithGHLData': firestore.Increment(count),
            'lastUpdated': firestore.SERVER_TIMESTAMP
        })
        print(f'   ✅ {month}: +{count} ads with GHL data')
    
    print(f'\n' + '='*80)
    print('GHL DATA POPULATED!')
    print('='*80)
    print(f'\n📊 Summary:')
    print(f'   Ads updated: {ads_updated}')
    print(f'   Total weeks: {total_weeks}')
    print(f'   Matched opportunities: {matched_count}')
    print(f'   Months updated: {len(month_updates)}')
    print(f'   Structure: advertData/{{month}}/ads/{{adId}}/ghlWeekly/{{weekId}}')
    print('\n' + '='*80)

if __name__ == '__main__':
    process_opportunities()

