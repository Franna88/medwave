#!/usr/bin/env python3
"""
Search ALL form submissions to find Yolandi Nel's submission with Ad ID
"""

import requests
import json
from datetime import datetime, timedelta

# GHL API credentials
GHL_API_KEY = 'pit-22f8af95-3244-41e7-9a52-22c87b166f5a'
GHL_LOCATION_ID = 'QdLXaFEqrdF0JbVbpKLw'

headers = {
    'Authorization': f'Bearer {GHL_API_KEY}',
    'Version': '2021-07-28'
}

print("=" * 80)
print("SEARCHING FOR YOLANDI NEL'S FORM SUBMISSION")
print("=" * 80)
print()

yolandi_email = 'yolandi1712@gmail.com'
yolandi_contact_id = 'Itp8xcPYfTXFyWDp1pms'
expected_ad_id = '120235560268260335'

# Search through multiple date ranges
date_ranges = [
    (datetime.now() - timedelta(days=7), datetime.now(), "Last 7 days"),
    (datetime.now() - timedelta(days=14), datetime.now() - timedelta(days=7), "7-14 days ago"),
    (datetime.now() - timedelta(days=30), datetime.now() - timedelta(days=14), "14-30 days ago"),
    (datetime.now() - timedelta(days=60), datetime.now() - timedelta(days=30), "30-60 days ago"),
]

total_submissions_checked = 0
found = False

for start_date, end_date, label in date_ranges:
    if found:
        break
        
    print(f"🔍 Searching {label}...")
    
    page = 1
    while True:
        params = {
            'locationId': GHL_LOCATION_ID,
            'startAt': start_date.strftime('%Y-%m-%dT00:00:00.000Z'),
            'endAt': end_date.strftime('%Y-%m-%dT23:59:59.999Z'),
            'limit': 100,
            'page': page
        }
        
        response = requests.get(
            'https://services.leadconnectorhq.com/forms/submissions',
            headers=headers,
            params=params
        )
        
        if response.status_code != 200:
            print(f"   ⚠️  Error: {response.status_code}")
            break
        
        data = response.json()
        submissions = data.get('submissions', [])
        
        if not submissions:
            break
        
        total_submissions_checked += len(submissions)
        print(f"   Page {page}: Checking {len(submissions)} submissions... (Total checked: {total_submissions_checked})")
        
        # Search for Yolandi in this batch
        for submission in submissions:
            email = submission.get('email', '').lower()
            contact_id = submission.get('contactId', '')
            
            # Check if this is Yolandi
            if email == yolandi_email.lower() or contact_id == yolandi_contact_id:
                print()
                print("=" * 80)
                print("🎉 FOUND YOLANDI'S SUBMISSION!")
                print("=" * 80)
                print()
                
                print(f"Submission ID: {submission.get('id')}")
                print(f"Contact ID: {submission.get('contactId')}")
                print(f"Email: {submission.get('email')}")
                print(f"Name: {submission.get('name')}")
                print(f"Created At: {submission.get('createdAt')}")
                print()
                
                # Extract Ad ID from all possible locations
                others = submission.get('others', {})
                
                # Location 1: lastAttributionSource
                last_attr = others.get('lastAttributionSource', {})
                ad_id_1 = last_attr.get('adId')
                adset_id_1 = last_attr.get('adSetId')
                campaign_id_1 = last_attr.get('campaignId')
                
                print("📊 From lastAttributionSource:")
                print(f"   Ad ID: {ad_id_1}")
                print(f"   Ad Set ID: {adset_id_1}")
                print(f"   Campaign ID: {campaign_id_1}")
                print()
                
                # Location 2: eventData.url_params
                event_data = others.get('eventData', {})
                url_params = event_data.get('url_params', {})
                ad_id_2 = url_params.get('ad_id')
                adset_id_2 = url_params.get('adset_id')
                campaign_id_2 = url_params.get('campaign_id')
                
                print("📊 From eventData.url_params:")
                print(f"   ad_id: {ad_id_2}")
                print(f"   adset_id: {adset_id_2}")
                print(f"   campaign_id: {campaign_id_2}")
                print()
                
                # Check if we found the expected Ad ID
                if ad_id_1 == expected_ad_id or ad_id_2 == expected_ad_id:
                    print(f"✅ SUCCESS! Found expected Ad ID: {expected_ad_id}")
                elif ad_id_1 or ad_id_2:
                    print(f"⚠️  Found Ad ID but it doesn't match expected:")
                    print(f"   Found: {ad_id_1 or ad_id_2}")
                    print(f"   Expected: {expected_ad_id}")
                else:
                    print(f"❌ Ad ID is NULL in form submission")
                
                print()
                print("📄 FULL SUBMISSION OBJECT:")
                print(json.dumps(submission, indent=3, default=str))
                
                found = True
                break
        
        # Check if there are more pages
        total = data.get('total', 0)
        if page * 100 >= total:
            break
        
        page += 1
    
    if found:
        break
    
    print(f"   ✅ Checked {total_submissions_checked} submissions in {label}")
    print()

if not found:
    print()
    print("=" * 80)
    print(f"❌ Yolandi's submission not found in {total_submissions_checked} submissions")
    print("=" * 80)
    print()
    print("Possible reasons:")
    print("1. Submission is older than 60 days")
    print("2. Submission was deleted")
    print("3. Contact was created through a different method (not form submission)")
    print()
    print("Let's check Yolandi's contact creation date...")
    
    # Fetch contact to see when it was created
    contact_response = requests.get(
        f'https://services.leadconnectorhq.com/contacts/{yolandi_contact_id}',
        headers=headers
    )
    
    if contact_response.status_code == 200:
        contact = contact_response.json().get('contact', {})
        date_added = contact.get('dateAdded')
        print(f"   Contact created: {date_added}")
        
        if date_added:
            created_date = datetime.fromisoformat(date_added.replace('Z', '+00:00'))
            days_ago = (datetime.now(created_date.tzinfo) - created_date).days
            print(f"   That was {days_ago} days ago")
            
            if days_ago > 60:
                print(f"   ⚠️  Contact is older than our search range!")
                print(f"   Searching {days_ago} days back...")
                
                # Search with extended date range
                extended_start = datetime.now() - timedelta(days=days_ago + 5)
                extended_end = datetime.now()
                
                params = {
                    'locationId': GHL_LOCATION_ID,
                    'startAt': extended_start.strftime('%Y-%m-%dT00:00:00.000Z'),
                    'endAt': extended_end.strftime('%Y-%m-%dT23:59:59.999Z'),
                    'limit': 100,
                    'page': 1
                }
                
                print(f"   Fetching submissions from {extended_start.strftime('%Y-%m-%d')}...")
                
                response = requests.get(
                    'https://services.leadconnectorhq.com/forms/submissions',
                    headers=headers,
                    params=params
                )
                
                if response.status_code == 200:
                    data = response.json()
                    total = data.get('total', 0)
                    print(f"   Found {total} total submissions in extended range")
                    print(f"   This would require checking {(total // 100) + 1} pages")

print()
print("=" * 80)
print("SEARCH COMPLETE")
print("=" * 80)

