#!/usr/bin/env python3
"""
Deep investigation of the 7 unmatched opportunities from last 2 months
"""

import firebase_admin
from firebase_admin import credentials, firestore
import requests
import os
import json
from datetime import datetime, timedelta

# Initialize Firebase
script_dir = os.path.dirname(os.path.abspath(__file__))
creds_path = os.path.join(script_dir, '..', 'medx-ai-firebase-adminsdk-fbsvc-a86e7bd050.json')
cred = credentials.Certificate(creds_path)

try:
    firebase_admin.get_app()
except ValueError:
    firebase_admin.initialize_app(cred)

db = firestore.client()

# GHL API credentials
GHL_API_KEY = 'pat-na-3c0a8c1c-5f1b-4c89-b2d8-f0b0c0e4f2c0'
GHL_LOCATION_ID = 'QdLXaFEqrdF0JbVbpKLw'

print("=" * 80)
print("INVESTIGATING 7 UNMATCHED OPPORTUNITIES")
print("=" * 80)
print()

# The 7 unmatched opportunity IDs from the analysis
unmatched_opp_ids = [
    '9pSST9D8T9sXbc0UE3TE',  # 2025-10-31
    'S7EIEHgGOXveSOc6oI6J',  # 2025-10-10
    'hkDLuzVBrtWvg8k6llPu',  # 2025-10-02
    '70fAPccPEMYz573hjpI2',  # 2025-09-29
    'dLujAaES4Pn2ZsBhV9QS',  # 2025-09-25
    'tXDpjz17dl4bRRJKNpbV',  # 2025-09-24
    'rlNpH8mOv2ijTJd8UD3P',  # 2025-09-16
]

for i, opp_id in enumerate(unmatched_opp_ids, 1):
    print("=" * 80)
    print(f"OPPORTUNITY {i}/7: {opp_id}")
    print("=" * 80)
    print()
    
    # Get opportunity from Firestore
    opp_doc = db.collection('ghlOpportunities').document(opp_id).get()
    if not opp_doc.exists:
        print(f"❌ Opportunity not found in Firestore")
        print()
        continue
    
    opp_data = opp_doc.to_dict()
    contact_id = opp_data.get('contactId')
    name = opp_data.get('name', 'Unknown')
    created_at = opp_data.get('createdAt')
    
    print(f"📋 Name: {name}")
    print(f"📋 Contact ID: {contact_id}")
    print(f"📋 Created: {created_at}")
    print()
    
    if not contact_id:
        print("❌ No contact ID - cannot investigate further")
        print()
        continue
    
    # Fetch full opportunity from GHL API
    print("🔍 STEP 1: Fetching full opportunity from GHL API...")
    opp_url = f'https://services.leadconnectorhq.com/opportunities/{opp_id}'
    headers = {
        'Authorization': f'Bearer {GHL_API_KEY}',
        'Version': '2021-07-28'
    }
    
    opp_response = requests.get(opp_url, headers=headers)
    if opp_response.status_code == 200:
        full_opp = opp_response.json().get('opportunity', {})
        print(f"✅ Opportunity fetched")
        print(f"   Name: {full_opp.get('name', 'N/A')}")
        print(f"   Pipeline: {full_opp.get('source', 'N/A')}")
        
        # Check attributions
        attributions = full_opp.get('attributions', [])
        if attributions:
            print(f"   Found {len(attributions)} attribution(s)")
            for j, attr in enumerate(attributions, 1):
                print(f"   Attribution {j}: {json.dumps(attr, indent=6)}")
        else:
            print(f"   ⚠️  No attributions in opportunity")
    else:
        print(f"❌ Failed to fetch opportunity: {opp_response.status_code}")
    print()
    
    # Fetch contact from GHL API
    print("🔍 STEP 2: Fetching contact from GHL API...")
    contact_url = f'https://services.leadconnectorhq.com/contacts/{contact_id}'
    
    contact_response = requests.get(contact_url, headers=headers)
    if contact_response.status_code == 200:
        contact = contact_response.json().get('contact', {})
        print(f"✅ Contact fetched")
        print(f"   Name: {contact.get('firstName', '')} {contact.get('lastName', '')}")
        print(f"   Email: {contact.get('email', 'N/A')}")
        print(f"   Phone: {contact.get('phone', 'N/A')}")
        print(f"   Source: {contact.get('source', 'N/A')}")
        
        # Check attribution sources
        attr_source = contact.get('attributionSource', {})
        last_attr_source = contact.get('lastAttributionSource', {})
        
        if attr_source:
            print(f"   Attribution Source:")
            print(f"      adId: {attr_source.get('adId', 'N/A')}")
            print(f"      adSetId: {attr_source.get('adSetId', 'N/A')}")
            print(f"      campaignId: {attr_source.get('campaignId', 'N/A')}")
            print(f"      medium: {attr_source.get('medium', 'N/A')}")
            print(f"      source: {attr_source.get('source', 'N/A')}")
        
        if last_attr_source:
            print(f"   Last Attribution Source:")
            print(f"      adId: {last_attr_source.get('adId', 'N/A')}")
            print(f"      adSetId: {last_attr_source.get('adSetId', 'N/A')}")
            print(f"      campaignId: {last_attr_source.get('campaignId', 'N/A')}")
            print(f"      medium: {last_attr_source.get('medium', 'N/A')}")
            print(f"      source: {last_attr_source.get('source', 'N/A')}")
        
        if not attr_source and not last_attr_source:
            print(f"   ⚠️  No attribution data in contact")
    else:
        print(f"❌ Failed to fetch contact: {contact_response.status_code}")
    print()
    
    # Search for form submissions by contact ID
    print("🔍 STEP 3: Searching for form submissions...")
    
    # Parse the created date to search around that time
    try:
        created_date = datetime.fromisoformat(created_at.replace('Z', '+00:00'))
        # Search 7 days before and after
        start_date = (created_date - timedelta(days=7)).strftime('%Y-%m-%d')
        end_date = (created_date + timedelta(days=7)).strftime('%Y-%m-%d')
        
        print(f"   Searching from {start_date} to {end_date}")
        
        submissions_url = 'https://services.leadconnectorhq.com/forms/submissions'
        params = {
            'locationId': GHL_LOCATION_ID,
            'startAt': start_date,
            'endAt': end_date,
            'limit': 100
        }
        
        submissions_response = requests.get(submissions_url, headers=headers, params=params)
        if submissions_response.status_code == 200:
            submissions_data = submissions_response.json()
            all_submissions = submissions_data.get('submissions', [])
            
            # Filter by contact ID
            contact_submissions = [s for s in all_submissions if s.get('contactId') == contact_id]
            
            if contact_submissions:
                print(f"   ✅ Found {len(contact_submissions)} form submission(s) for this contact!")
                for j, sub in enumerate(contact_submissions, 1):
                    print(f"   Submission {j}:")
                    print(f"      Form ID: {sub.get('formId', 'N/A')}")
                    print(f"      Submitted At: {sub.get('createdAt', 'N/A')}")
                    
                    # Check for Ad ID in submission
                    others = sub.get('others', {})
                    last_attr = others.get('lastAttributionSource', {})
                    event_data = others.get('eventData', {})
                    url_params = event_data.get('url_params', {})
                    
                    ad_id = last_attr.get('adId') or url_params.get('ad_id')
                    adset_id = last_attr.get('adSetId') or url_params.get('adset_id')
                    campaign_id = last_attr.get('campaignId') or url_params.get('campaign_id')
                    
                    if ad_id:
                        print(f"      🎯 Ad ID: {ad_id}")
                        print(f"      🎯 Ad Set ID: {adset_id}")
                        print(f"      🎯 Campaign ID: {campaign_id}")
                    else:
                        print(f"      ⚠️  No Ad ID in submission")
                        print(f"      Full 'others' data:")
                        print(json.dumps(others, indent=10))
            else:
                print(f"   ❌ No form submissions found for this contact in that date range")
                print(f"   Trying wider search (30 days before)...")
                
                # Try wider search
                start_date_wide = (created_date - timedelta(days=30)).strftime('%Y-%m-%d')
                params['startAt'] = start_date_wide
                
                submissions_response = requests.get(submissions_url, headers=headers, params=params)
                if submissions_response.status_code == 200:
                    submissions_data = submissions_response.json()
                    all_submissions = submissions_data.get('submissions', [])
                    contact_submissions = [s for s in all_submissions if s.get('contactId') == contact_id]
                    
                    if contact_submissions:
                        print(f"   ✅ Found {len(contact_submissions)} form submission(s) in wider search!")
                        for j, sub in enumerate(contact_submissions, 1):
                            print(f"   Submission {j}:")
                            print(f"      Submitted At: {sub.get('createdAt', 'N/A')}")
                            others = sub.get('others', {})
                            last_attr = others.get('lastAttributionSource', {})
                            ad_id = last_attr.get('adId')
                            if ad_id:
                                print(f"      🎯 Ad ID: {ad_id}")
                    else:
                        print(f"   ❌ Still no form submissions found")
        else:
            print(f"   ❌ Failed to fetch form submissions: {submissions_response.status_code}")
    except Exception as e:
        print(f"   ❌ Error searching form submissions: {e}")
    
    print()

print("=" * 80)
print("INVESTIGATION COMPLETE")
print("=" * 80)

