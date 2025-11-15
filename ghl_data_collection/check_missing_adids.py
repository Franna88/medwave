#!/usr/bin/env python3
"""
Quick script to check submissions without adId
"""

import os
import requests
import json
from datetime import datetime
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

# Configuration
GHL_API_KEY = os.getenv('GHL_API_KEY')
GHL_LOCATION_ID = os.getenv('GHL_LOCATION_ID')
GHL_API_VERSION = '2021-07-28'

# Date range for November 2025
START_DATE = '2025-11-01T00:00:00.000Z'
END_DATE = '2025-11-30T23:59:59.999Z'

def get_ghl_headers():
    return {
        'Authorization': f'Bearer {GHL_API_KEY}',
        'Version': GHL_API_VERSION,
        'Content-Type': 'application/json'
    }

def extract_ad_id(submission):
    """Extract adId from submission"""
    others = submission.get('others', {})
    last_attr = others.get('lastAttributionSource', {})
    ad_id = last_attr.get('adId')
    
    if ad_id:
        return ad_id
    
    event_data = others.get('eventData', {})
    url_params = event_data.get('url_params', {})
    ad_id = url_params.get('ad_id')
    
    return ad_id

# Fetch submissions
url = 'https://services.leadconnectorhq.com/forms/submissions'
params = {
    'locationId': GHL_LOCATION_ID,
    'limit': 100,
    'startAt': START_DATE,
    'endAt': END_DATE,
    'page': 1
}

print('Fetching submissions to check for missing adIds...\n')

all_submissions = []
page = 1

while True:
    params['page'] = page
    response = requests.get(url, headers=get_ghl_headers(), params=params, timeout=30)
    response.raise_for_status()
    data = response.json()
    
    submissions = data.get('submissions', [])
    if not submissions:
        break
    
    all_submissions.extend(submissions)
    
    meta = data.get('meta', {})
    if not meta.get('nextPage'):
        break
    
    page += 1

print(f'Total submissions fetched: {len(all_submissions)}\n')

# Find submissions without adId
submissions_without_ad_id = []
for submission in all_submissions:
    ad_id = extract_ad_id(submission)
    if not ad_id:
        submissions_without_ad_id.append(submission)

print(f'Submissions without adId: {len(submissions_without_ad_id)}\n')
print('='*80)
print('SAMPLE SUBMISSIONS WITHOUT ADID:')
print('='*80 + '\n')

# Show first 5 submissions without adId
for i, submission in enumerate(submissions_without_ad_id[:5], 1):
    print(f'\n--- Submission {i} ---')
    print(f'ID: {submission.get("id")}')
    print(f'Name: {submission.get("name")}')
    print(f'Email: {submission.get("email")}')
    print(f'Form ID: {submission.get("formId")}')
    print(f'Created: {submission.get("createdAt")}')
    
    others = submission.get('others', {})
    print(f'Source: {others.get("source", "Unknown")}')
    print(f'Product Type: {others.get("productType", "Unknown")}')
    
    # Check lastAttributionSource
    last_attr = others.get('lastAttributionSource', {})
    if last_attr:
        print(f'\nAttribution Source:')
        print(f'  - Medium: {last_attr.get("medium")}')
        print(f'  - Source: {last_attr.get("source")}')
        print(f'  - Campaign: {last_attr.get("campaign")}')
        print(f'  - AdId: {last_attr.get("adId", "MISSING")}')
    else:
        print('\nNo attribution source found')
    
    # Check eventData
    event_data = others.get('eventData', {})
    if event_data:
        print(f'\nEvent Data:')
        print(f'  - Source: {event_data.get("source")}')
        url_params = event_data.get('url_params', {})
        if url_params:
            print(f'  - URL Params: {json.dumps(url_params, indent=4)}')
    
    print('-' * 80)

print(f'\n\n📊 Summary:')
print(f'   Total: {len(all_submissions)}')
print(f'   With adId: {len(all_submissions) - len(submissions_without_ad_id)}')
print(f'   Without adId: {len(submissions_without_ad_id)}')
print(f'\n   Percentage without adId: {(len(submissions_without_ad_id)/len(all_submissions)*100):.1f}%')

