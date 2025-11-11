#!/usr/bin/env python3
"""
Test script to check GHL Forms Submissions API for Ad ID
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
print("TESTING: GHL Forms Submissions API for Ad ID")
print("=" * 80)
print()

# Yolandi's data
yolandi_email = 'yolandi1712@gmail.com'
yolandi_contact_id = 'Itp8xcPYfTXFyWDp1pms'
expected_ad_id = '120235560268260335'
form_id = '1168700714593335'  # From the contact data

# Step 1: Get form submissions for this contact
print(f"📋 STEP 1: Fetching form submissions for contact {yolandi_contact_id}...")
print()

# Try different date ranges to find the submission
end_date = datetime.now()
start_date = end_date - timedelta(days=30)  # Last 30 days

params = {
    'locationId': GHL_LOCATION_ID,
    'startAt': start_date.strftime('%Y-%m-%dT00:00:00.000Z'),
    'endAt': end_date.strftime('%Y-%m-%dT23:59:59.999Z'),
    'limit': 100,
    'page': 1
}

response = requests.get(
    'https://services.leadconnectorhq.com/forms/submissions',
    headers=headers,
    params=params
)

print(f"Response Status: {response.status_code}")
print()

if response.status_code == 200:
    data = response.json()
    submissions = data.get('submissions', [])
    
    print(f"✅ Found {len(submissions)} form submission(s)")
    print()
    
    if submissions:
        for i, submission in enumerate(submissions, 1):
            print(f"{'='*80}")
            print(f"SUBMISSION #{i}")
            print(f"{'='*80}")
            print()
            
            print(f"Submission ID: {submission.get('id')}")
            print(f"Form ID: {submission.get('formId')}")
            print(f"Contact ID: {submission.get('contactId')}")
            print(f"Created At: {submission.get('createdAt')}")
            print()
            
            # Check for Ad ID in submission data
            print("🔍 Searching for Ad ID in submission...")
            
            # Check all fields
            submission_data = submission.get('submissionData', {})
            others = submission.get('others', {})
            
            # Search in submissionData
            if submission_data:
                print(f"\n📊 Submission Data ({len(submission_data)} fields):")
                for key, value in submission_data.items():
                    print(f"   {key}: {value}")
                    if str(value) == expected_ad_id:
                        print(f"   ✅ FOUND AD ID HERE!")
            
            # Search in others
            if others:
                print(f"\n📊 Others ({len(others)} fields):")
                for key, value in others.items():
                    print(f"   {key}: {value}")
                    if str(value) == expected_ad_id:
                        print(f"   ✅ FOUND AD ID HERE!")
            
            # Deep search entire submission object
            print(f"\n🔍 Deep searching entire submission object...")
            
            def deep_search(obj, target, path=""):
                results = []
                if isinstance(obj, dict):
                    for key, value in obj.items():
                        current_path = f"{path}.{key}" if path else key
                        if str(value) == target:
                            results.append(current_path)
                        if isinstance(value, (dict, list)):
                            results.extend(deep_search(value, target, current_path))
                elif isinstance(obj, list):
                    for idx, item in enumerate(obj):
                        current_path = f"{path}[{idx}]"
                        if str(item) == target:
                            results.append(current_path)
                        if isinstance(item, (dict, list)):
                            results.extend(deep_search(item, target, current_path))
                return results
            
            found_paths = deep_search(submission, expected_ad_id)
            
            if found_paths:
                print(f"✅ FOUND Ad ID at {len(found_paths)} location(s):")
                for path in found_paths:
                    print(f"   - {path}")
            else:
                print(f"❌ Ad ID {expected_ad_id} not found in submission")
            
            # Show full submission object
            print(f"\n📄 FULL SUBMISSION OBJECT:")
            print(json.dumps(submission, indent=3, default=str))
            print()
    else:
        print("⚠️  No submissions found for this contact")
        print()
        print("Trying to get ALL recent submissions for the location...")
        
        # Try getting all submissions
        params2 = {
            'locationId': GHL_LOCATION_ID,
            'startAt': start_date.strftime('%Y-%m-%dT00:00:00.000Z'),
            'endAt': end_date.strftime('%Y-%m-%dT23:59:59.999Z'),
            'limit': 10,
            'page': 1
        }
        
        response2 = requests.get(
            'https://services.leadconnectorhq.com/forms/submissions',
            headers=headers,
            params=params2
        )
        
        if response2.status_code == 200:
            data2 = response2.json()
            all_submissions = data2.get('submissions', [])
            print(f"✅ Found {len(all_submissions)} recent submission(s) in location")
            
            # Check if any match Yolandi's email
            for sub in all_submissions:
                sub_data = sub.get('submissionData', {})
                if yolandi_email in str(sub_data):
                    print(f"\n✅ Found submission with Yolandi's email!")
                    print(json.dumps(sub, indent=3, default=str))
else:
    print(f"❌ Error: {response.status_code}")
    print(f"Response: {response.text}")

print()
print("=" * 80)
print("TEST COMPLETE")
print("=" * 80)

