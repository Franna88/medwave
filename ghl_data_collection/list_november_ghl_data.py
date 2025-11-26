#!/usr/bin/env python3
"""
List GHL Form Submissions - November 2025 (Read-Only)
Fetches all GHL form submissions for November 2025 and displays them with UTM tags
Does NOT store anything in Firebase - just lists the data
"""

import requests
from datetime import datetime
import time
import json

# GHL API Configuration
GHL_API_KEY = 'pit-22f8af95-3244-41e7-9a52-22c87b166f5a'
GHL_LOCATION_ID = 'QdLXaFEqrdF0JbVbpKLw'
GHL_BASE_URL = 'https://services.leadconnectorhq.com'
GHL_API_VERSION = '2021-07-28'

# Date range for November 2025
START_DATE = '2025-11-01T00:00:00.000Z'
END_DATE = '2025-11-30T23:59:59.999Z'


def get_ghl_headers():
    """Get GHL API headers"""
    return {
        'Authorization': f'Bearer {GHL_API_KEY}',
        'Version': GHL_API_VERSION,
        'Content-Type': 'application/json'
    }


def extract_ad_id(submission):
    """Extract adId from submission - tries multiple locations"""
    others = submission.get('others', {})
    
    # Try primary location: lastAttributionSource
    last_attr = others.get('lastAttributionSource', {})
    ad_id = last_attr.get('adId')
    
    if ad_id:
        return ad_id
    
    # Try fallback location: eventData.url_params
    event_data = others.get('eventData', {})
    url_params = event_data.get('url_params', {})
    ad_id = url_params.get('ad_id')
    
    return ad_id


def extract_attribution_data(submission):
    """Extract all attribution data from submission"""
    others = submission.get('others', {})
    last_attr = others.get('lastAttributionSource', {})
    
    if not last_attr:
        return None
    
    return {
        'campaignId': last_attr.get('campaignId'),
        'campaign': last_attr.get('campaign'),
        'adSetId': last_attr.get('adSetId'),
        'adId': last_attr.get('adId'),
        'utmContent': last_attr.get('utmContent'),
        'utmMedium': last_attr.get('utmMedium'),
        'utmSource': last_attr.get('utmSource'),
        'medium': last_attr.get('medium'),
        'source': last_attr.get('source'),
        'sessionSource': last_attr.get('sessionSource'),
        'formId': last_attr.get('formId'),
        'formName': last_attr.get('formName')
    }


def list_november_submissions():
    """Fetch and list all form submissions for November 2025"""
    print('='*80)
    print('GHL FORM SUBMISSIONS LIST - NOVEMBER 2025 (READ-ONLY)')
    print('='*80 + '\n')
    
    print(f'📅 Date Range: {START_DATE[:10]} to {END_DATE[:10]}')
    print(f'🎯 Location ID: {GHL_LOCATION_ID}')
    print(f'📊 API Version: {GHL_API_VERSION}\n')
    
    print('='*80)
    print('FETCHING ALL FORM SUBMISSIONS FROM GHL')
    print('='*80 + '\n')
    
    url = f'{GHL_BASE_URL}/forms/submissions'
    all_submissions = []
    page = 1
    
    while True:
        print(f'📄 Fetching page {page}...')
        
        params = {
            'locationId': GHL_LOCATION_ID,
            'limit': 100,
            'startAt': START_DATE,
            'endAt': END_DATE,
            'page': page
        }
        
        try:
            response = requests.get(url, headers=get_ghl_headers(), params=params, timeout=30)
            
            # Handle rate limiting
            if response.status_code == 429:
                print(f'   ⚠️  Rate limit hit, waiting 60 seconds...')
                time.sleep(60)
                continue
            
            response.raise_for_status()
            data = response.json()
            
            submissions = data.get('submissions', [])
            
            if not submissions:
                print(f'   ✅ No more submissions found\n')
                break
            
            all_submissions.extend(submissions)
            print(f'   Found {len(submissions)} submissions on this page')
            
            # Check if we're on the last page
            meta = data.get('meta', {})
            next_page = meta.get('nextPage')
            
            if not next_page:
                print(f'   ✅ Reached last page\n')
                break
            
            page += 1
            time.sleep(0.5)  # Rate limiting
            
        except requests.exceptions.RequestException as e:
            print(f'\n❌ Error fetching submissions: {e}')
            break
    
    print(f'✅ Total submissions fetched: {len(all_submissions)}\n')
    
    # Verify date range
    if all_submissions:
        print('📅 Verifying date range of fetched submissions...')
        dates = []
        for sub in all_submissions[:10]:  # Check first 10
            created_at = sub.get('createdAt', '')
            if created_at:
                dates.append(created_at[:10])  # Just the date part
        
        if dates:
            print(f'   Sample dates: {", ".join(dates[:5])}')
            if dates:
                print(f'   Earliest: {min(dates)}')
                print(f'   Latest: {max(dates)}\n')
    
    # Process and display submissions
    print('='*80)
    print('LISTING ALL SUBMISSIONS WITH UTM TAG INFORMATION')
    print('='*80 + '\n')
    
    submissions_with_utm = []
    submissions_without_utm = []
    submissions_with_ad_id = []
    
    for idx, submission in enumerate(all_submissions, 1):
        contact_id = submission.get('contactId', 'No ContactId')
        name = submission.get('name', 'Unknown')
        email = submission.get('email', 'No Email')
        created_at = submission.get('createdAt', '')[:10]  # Just date
        
        # Extract attribution data
        attribution = extract_attribution_data(submission)
        ad_id = extract_ad_id(submission)
        
        print(f'\n{"─"*80}')
        print(f'#{idx} | {name} | {created_at}')
        print(f'{"─"*80}')
        print(f'📧 Email: {email}')
        print(f'🆔 Contact ID: {contact_id}')
        
        if attribution:
            # Has attribution data
            submissions_with_utm.append(submission)
            
            print(f'\n✅ ATTRIBUTION DATA FOUND:')
            print(f'   📍 Campaign: {attribution.get("campaign", "N/A")}')
            print(f'   🎯 Campaign ID: {attribution.get("campaignId", "N/A")}')
            print(f'   📦 Ad Set ID: {attribution.get("adSetId", "N/A")}')
            print(f'   🎬 Ad ID: {attribution.get("adId", "N/A")}')
            print(f'\n   🏷️  UTM TAGS:')
            print(f'      • UTM Source: {attribution.get("utmSource", "N/A")}')
            print(f'      • UTM Medium: {attribution.get("utmMedium", "N/A")}')
            print(f'      • UTM Content: {attribution.get("utmContent", "N/A")}')
            print(f'\n   📊 OTHER ATTRIBUTION:')
            print(f'      • Source: {attribution.get("source", "N/A")}')
            print(f'      • Medium: {attribution.get("medium", "N/A")}')
            print(f'      • Session Source: {attribution.get("sessionSource", "N/A")}')
            print(f'      • Form ID: {attribution.get("formId", "N/A")}')
            print(f'      • Form Name: {attribution.get("formName", "N/A")}')
            
            if ad_id:
                submissions_with_ad_id.append(submission)
        else:
            # No attribution data
            submissions_without_utm.append(submission)
            print(f'\n⚠️  NO ATTRIBUTION DATA')
            
            # Check for source in others
            others = submission.get('others', {})
            source = others.get('source', 'Unknown')
            product_type = others.get('productType', 'Unknown')
            print(f'   Source: {source}')
            print(f'   Product Type: {product_type}')
    
    # Summary
    print('\n\n' + '='*80)
    print('SUMMARY - UTM TAG VISIBILITY')
    print('='*80 + '\n')
    
    print(f'📊 Total Submissions: {len(all_submissions)}')
    print(f'\n✅ WITH Attribution/UTM Data: {len(submissions_with_utm)} ({len(submissions_with_utm)/len(all_submissions)*100:.1f}%)')
    print(f'   └─ With Ad ID: {len(submissions_with_ad_id)} ({len(submissions_with_ad_id)/len(all_submissions)*100:.1f}%)')
    print(f'\n⚠️  WITHOUT Attribution/UTM Data: {len(submissions_without_utm)} ({len(submissions_without_utm)/len(all_submissions)*100:.1f}%)')
    
    # Show sample UTM values if available
    if submissions_with_utm:
        print(f'\n📋 SAMPLE UTM VALUES FOUND:')
        utm_sources = set()
        utm_mediums = set()
        utm_contents = set()
        
        for sub in submissions_with_utm:
            attr = extract_attribution_data(sub)
            if attr:
                if attr.get('utmSource'):
                    utm_sources.add(attr.get('utmSource'))
                if attr.get('utmMedium'):
                    utm_mediums.add(attr.get('utmMedium'))
                if attr.get('utmContent'):
                    utm_contents.add(attr.get('utmContent'))
        
        if utm_sources:
            print(f'\n   UTM Sources: {", ".join(list(utm_sources)[:5])}')
        if utm_mediums:
            print(f'   UTM Mediums: {", ".join(list(utm_mediums)[:5])}')
        if utm_contents:
            print(f'   UTM Contents: {", ".join(list(utm_contents)[:5])}')
    
    print(f'\n✅ Data listing complete - no data was stored in Firebase\n')


if __name__ == '__main__':
    list_november_submissions()


