#!/usr/bin/env python3
"""
Fetch fresh opportunities from GHL API and populate advertData
"""

import firebase_admin
from firebase_admin import credentials, firestore
import requests
from datetime import datetime, timedelta
from collections import defaultdict
import time

# Initialize Firebase
try:
    cred = credentials.Certificate('medx-ai-firebase-adminsdk-fbsvc-a86e7bd050.json')
    firebase_admin.initialize_app(cred)
except:
    pass

db = firestore.client()

# GHL API Configuration
GHL_API_KEY = "pit-22f8af95-3244-41e7-9a52-22c87b166f5a"
GHL_BASE_URL = "https://services.leadconnectorhq.com"
GHL_LOCATION_ID = "QdLXaFEqrdF0JbVbpKLw"

# Pipeline IDs (Andries and Davide only, excluding Altus)
PIPELINE_IDS = {
    "Andries": "peiM8W7lPOQkeLCGBRzP",
    "Davide": "zJz6NZHPXVMGoXrXN9Ks"
}

def calculate_week_id(date):
    """Calculate week ID in format YYYY-MM-DD_YYYY-MM-DD (Monday to Sunday)"""
    if isinstance(date, str):
        date = datetime.fromisoformat(date.replace('Z', '+00:00'))
    
    # Get Monday of the week
    days_since_monday = date.weekday()
    monday = date - timedelta(days=days_since_monday)
    sunday = monday + timedelta(days=6)
    
    # Format as YYYY-MM-DD
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

def fetch_ghl_opportunities(pipeline_id, pipeline_name):
    """Fetch opportunities from GHL API"""
    print(f'\n📥 Fetching opportunities from {pipeline_name} pipeline...')
    
    headers = {
        "Authorization": f"Bearer {GHL_API_KEY}",
        "Version": "2021-07-28"
    }
    
    # Get opportunities from last 6 months
    six_months_ago = datetime.now() - timedelta(days=180)
    
    url = f"{GHL_BASE_URL}/opportunities/search"
    params = {
        "location_id": GHL_LOCATION_ID,
        "pipeline_id": pipeline_id,
        "limit": 100,
        "offset": 0
    }
    
    all_opportunities = []
    
    while True:
        try:
            response = requests.get(url, headers=headers, params=params)
            response.raise_for_status()
            
            data = response.json()
            opportunities = data.get('opportunities', [])
            
            if not opportunities:
                break
            
            all_opportunities.extend(opportunities)
            print(f'   Fetched {len(all_opportunities)} opportunities so far...')
            
            # Check for next page
            if 'meta' in data and 'nextPageUrl' in data['meta']:
                url = data['meta']['nextPageUrl']
            else:
                break
            
            time.sleep(0.5)  # Rate limiting
            
        except Exception as e:
            print(f'   ❌ Error fetching opportunities: {e}')
            break
    
    print(f'   ✅ Total opportunities fetched: {len(all_opportunities)}')
    return all_opportunities

def extract_utm_data(contact):
    """Extract UTM data from contact"""
    if not contact:
        return {}
    
    # Check various possible locations for UTM data
    utm_data = {}
    
    # Check customFields
    custom_fields = contact.get('customFields', [])
    for field in custom_fields:
        field_key = field.get('key', '').lower()
        if 'utm' in field_key or 'h_ad_id' in field_key or 'fbc_id' in field_key:
            utm_data[field_key] = field.get('value', '')
    
    # Check tags or other fields
    tags = contact.get('tags', [])
    for tag in tags:
        if 'h_ad_id' in tag.lower():
            parts = tag.split('=')
            if len(parts) == 2:
                utm_data['h_ad_id'] = parts[1]
    
    # Check source
    source = contact.get('source', '')
    if source:
        utm_data['source'] = source
    
    return utm_data

def populate_advertdata_from_ghl():
    """Main function to populate advertData from fresh GHL data"""
    
    print('\n' + '='*80)
    print('POPULATE ADVERTDATA FROM FRESH GHL API DATA')
    print('='*80 + '\n')
    
    # Aggregate data by ad ID and week
    ad_weekly_data = defaultdict(lambda: defaultdict(lambda: {
        'leads': 0,
        'bookedAppointments': 0,
        'deposits': 0,
        'cashCollected': 0,
        'cashAmount': 0
    }))
    
    # Fetch from both pipelines
    for pipeline_name, pipeline_id in PIPELINE_IDS.items():
        opportunities = fetch_ghl_opportunities(pipeline_id, pipeline_name)
        
        print(f'\n📊 Processing {len(opportunities)} opportunities from {pipeline_name}...')
        
        for opp in opportunities:
            # Get contact to extract UTM data
            contact_id = opp.get('contactId')
            
            if not contact_id:
                continue
            
            # Fetch contact details
            try:
                headers = {
                    "Authorization": f"Bearer {GHL_API_KEY}",
                    "Version": "2021-07-28"
                }
                contact_response = requests.get(
                    f"{GHL_BASE_URL}/contacts/{contact_id}",
                    headers=headers
                )
                contact_response.raise_for_status()
                contact = contact_response.json().get('contact', {})
                
                # Extract h_ad_id from UTM data
                utm_data = extract_utm_data(contact)
                facebook_ad_id = utm_data.get('h_ad_id', '')
                
                if not facebook_ad_id:
                    continue
                
                # Get opportunity details
                stage_name = opp.get('status', '')
                stage_category = get_stage_category(stage_name)
                monetary_value = float(opp.get('monetaryValue', 0))
                
                # Get date
                date_added = opp.get('dateAdded', datetime.now().isoformat())
                week_id = calculate_week_id(date_added)
                
                # Aggregate data
                week_data = ad_weekly_data[facebook_ad_id][week_id]
                week_data['leads'] += 1
                
                if stage_category == 'bookedAppointments':
                    week_data['bookedAppointments'] += 1
                elif stage_category == 'deposits':
                    week_data['deposits'] += 1
                    week_data['cashAmount'] += monetary_value or 1500
                elif stage_category == 'cashCollected':
                    week_data['cashCollected'] += 1
                    week_data['cashAmount'] += monetary_value or 1500
                
                time.sleep(0.1)  # Rate limiting
                
            except Exception as e:
                print(f'   ⚠️  Error processing opportunity {opp.get("id")}: {e}')
                continue
    
    # Write to Firebase
    print(f'\n\n📝 Writing data to Firebase...')
    print(f'   Total ads with data: {len(ad_weekly_data)}')
    
    total_weeks = 0
    total_leads = 0
    
    for ad_id, weeks in ad_weekly_data.items():
        # Check if ad exists in advertData
        ad_ref = db.collection('advertData').document(ad_id)
        if not ad_ref.get().exists:
            print(f'   ⚠️  Ad {ad_id} not in advertData collection, skipping...')
            continue
        
        # Write each week
        for week_id, metrics in weeks.items():
            week_ref = ad_ref.collection('ghlData').document('weekly').collection('weekly').document(week_id)
            week_ref.set(metrics, merge=True)
            total_weeks += 1
            total_leads += metrics['leads']
        
        # Update lastGHLSync
        ad_ref.update({'lastGHLSync': firestore.SERVER_TIMESTAMP})
        
        print(f'   ✅ Updated ad {ad_id}: {len(weeks)} weeks')
    
    print('\n' + '='*80)
    print('POPULATION COMPLETE')
    print('='*80 + '\n')
    
    print(f'Ads updated: {len(ad_weekly_data)}')
    print(f'Total weeks: {total_weeks}')
    print(f'Total leads: {total_leads}')
    
    print('\n' + '='*80)

if __name__ == '__main__':
    populate_advertdata_from_ghl()

