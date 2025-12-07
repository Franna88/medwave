#!/usr/bin/env python3
"""
GHL Form Submissions Collection - November 2025
Fetches all GHL form submissions for November 2025 and stores them in Firestore collection 'ghl_data'
Each submission is stored with its adId as the document ID
"""

import requests
import firebase_admin
from firebase_admin import credentials, firestore
from datetime import datetime
import time
import json
import os

# Initialize Firebase
try:
    # Get the directory where this script is located
    script_dir = os.path.dirname(os.path.abspath(__file__))
    
    # Try to find Firebase credentials file in common locations
    cred_paths = [
        os.path.join(script_dir, '..', 'ghl_opp_collection', 'medx-ai-firebase-adminsdk-fbsvc-d88a6aa1a7.json'),
        os.path.join(script_dir, '..', 'summary_collection', 'medx-ai-firebase-adminsdk-fbsvc-d88a6aa1a7.json'),
        os.path.join(script_dir, '..', 'medx-ai-firebase-adminsdk-fbsvc-a86e7bd050.json'),
        os.path.join(script_dir, '..', 'medx-ai-firebase-adminsdk-fbsvc-d88a6aa1a7.json')
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
    print('✅ Firebase initialized successfully\n')
except Exception as e:
    print(f'⚠️  Firebase already initialized or error: {e}\n')
    pass

db = firestore.client()

# GHL API Configuration
GHL_API_KEY = 'pit-22f8af95-3244-41e7-9a52-22c87b166f5a'
GHL_LOCATION_ID = 'QdLXaFEqrdF0JbVbpKLw'
GHL_BASE_URL = 'https://services.leadconnectorhq.com'
GHL_API_VERSION = '2021-07-28'

# Date range for November 2025
START_DATE = '2025-11-27T00:00:00.000Z'
END_DATE = '2025-12-07T23:59:59.999Z'

# Test mode flag - set to True to fetch only 1 submission for testing
TEST_MODE = False


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


def calculate_form_score(submission):
    """
    Calculate form score based on customFields values.
    Scoring rules:
    - 10 Points: MD, General Practitioner, Chiropractor, Physical Therapist, Specialist, Yes, 51-100, 101-200, 200+
    - 5 Points: Wellness Spa, Nurse Practitioner, Beauty Spa, Sports Recovery, 1-50
    - 0 Points: Any other answer (not matching above)
    
    Returns the cumulative total score.
    """
    # Define scoring rules (already lowercase for case-insensitive matching)
    score_10_points = [
        'md', 'general practitioner', 'chiropractor', 'physical therapist', 
        'specialist', 'yes', '51-100', '101-200', '200+'
    ]
    
    score_5_points = [
        'wellness spa', 'nurse practitioner', 'beauty spa', 
        'sports recovery', '1-50'
    ]
    
    # Extract customFields from submission
    others = submission.get('others', {})
    custom_fields = others.get('customFields', [])
    
    total_score = 0
    
    # Check each custom field value
    for field in custom_fields:
        field_value = field.get('field_value', '').strip()
        
        if not field_value:
            continue
        
        # Convert to lowercase for case-insensitive matching
        field_value_lower = field_value.lower()
        
        # Check against scoring rules
        if field_value_lower in score_10_points:
            total_score += 10
        elif field_value_lower in score_5_points:
            total_score += 5
        else:
            # Default to 0 points for any other answer (not matching above)
            total_score += 0
    
    return total_score


def fetch_all_november_submissions():
    """Fetch all form submissions for November 2025"""
    print('='*80)
    print('GHL FORM SUBMISSIONS COLLECTION - NOVEMBER 2025')
    print('='*80 + '\n')
    
    if TEST_MODE:
        print('⚠️  TEST MODE ENABLED - Fetching only 1 submission\n')
    
    print(f'📅 Date Range: {START_DATE[:10]} to {END_DATE[:10]}')
    print(f'🎯 Location ID: {GHL_LOCATION_ID}')
    print(f'📊 API Version: {GHL_API_VERSION}\n')
    
    print('='*80)
    print('STEP 1: FETCHING ALL FORM SUBMISSIONS FROM GHL')
    print('='*80 + '\n')
    
    url = f'{GHL_BASE_URL}/forms/submissions'
    all_submissions = []
    page = 1
    
    while True:
        print(f'📄 Fetching page {page}...')
        
        # Use limit=1 in test mode, otherwise 100
        limit = 1 if TEST_MODE else 100
        
        params = {
            'locationId': GHL_LOCATION_ID,
            'limit': limit,
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
            
            # In test mode, break after fetching 1 submission
            if TEST_MODE and len(all_submissions) >= 1:
                print(f'   ✅ Test mode: Fetched 1 submission, stopping\n')
                break
            
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
            print(f'   Earliest: {min(dates)}')
            print(f'   Latest: {max(dates)}\n')
    
    # Step 2: Process all submissions
    print('='*80)
    print('STEP 2: PROCESSING ALL SUBMISSIONS')
    print('='*80 + '\n')
    
    submissions_with_contact_id = []
    submissions_without_contact_id = []
    
    for submission in all_submissions:
        contact_id = submission.get('contactId')
        
        if contact_id:
            submissions_with_contact_id.append(submission)
        else:
            submissions_without_contact_id.append(submission)
    
    print(f'✅ Submissions with contactId: {len(submissions_with_contact_id)}')
    print(f'⚠️  Submissions without contactId: {len(submissions_without_contact_id)}\n')
    
    # Step 3: Store in Firestore
    print('='*80)
    print('STEP 3: STORING IN FIRESTORE COLLECTION "ghl_data"')
    print('='*80 + '\n')
    
    stored_count = 0
    skipped_count = 0
    error_count = 0
    
    # Store each submission with contactId as document ID
    for submission in submissions_with_contact_id:
        try:
            contact_id = submission.get('contactId')
            
            if not contact_id:
                skipped_count += 1
                continue
            
            # Extract key fields
            submission_id = submission.get('id')
            name = submission.get('name', 'Unknown')
            email = submission.get('email', '')
            form_id = submission.get('formId', '')
            created_at = submission.get('createdAt', '')
            external = submission.get('external', False)
            
            # Extract attribution data
            attribution = extract_attribution_data(submission)
            ad_id = extract_ad_id(submission)
            
            # Get source information
            others = submission.get('others', {})
            source = others.get('source', 'Unknown')
            product_type = others.get('productType', 'Unknown')
            
            # Calculate form score based on customFields
            form_score = calculate_form_score(submission)
            
            # Add formScore to the submission object (fullSubmission)
            # Create a copy to avoid modifying the original
            submission_with_score = submission.copy()
            submission_with_score['formScore'] = form_score
            
            # Create document data
            doc_data = {
                'contactId': contact_id,
                'submissionId': submission_id,
                'name': name,
                'email': email,
                'formId': form_id,
                'createdAt': created_at,
                'external': external,
                'source': source,
                'productType': product_type,
                'adId': ad_id,  # Will be None if not from Facebook
                'attribution': attribution,  # Will be None if no attribution
                'fullSubmission': submission_with_score,  # Complete GHL payload with formScore
                'fetchedAt': datetime.now().isoformat(),
                'month': 'November',
                'year': 2025,
                'dateRange': {
                    'start': START_DATE,
                    'end': END_DATE
                }
            }
            
            # Store in Firestore with contactId as document ID
            doc_ref = db.collection('ghl_data').document(contact_id)
            doc_ref.set(doc_data)
            
            stored_count += 1
            
            # Show ad info if available
            if ad_id:
                print(f'✅ {stored_count}. Stored {name[:30]} (contactId: {contact_id[:20]}...) - Ad: {ad_id} - Score: {form_score}')
            else:
                print(f'✅ {stored_count}. Stored {name[:30]} (contactId: {contact_id[:20]}...) - Source: {source} - Score: {form_score}')
            
        except Exception as e:
            error_count += 1
            print(f'❌ Error storing submission: {e}')
    
    # Summary
    print('\n' + '='*80)
    print('COLLECTION COMPLETE')
    print('='*80 + '\n')
    
    print(f'📊 Summary:')
    print(f'   Total submissions fetched: {len(all_submissions)}')
    print(f'   Submissions with contactId: {len(submissions_with_contact_id)}')
    print(f'   Submissions without contactId: {len(submissions_without_contact_id)}')
    print(f'   Successfully stored: {stored_count}')
    print(f'   Skipped: {skipped_count}')
    print(f'   Errors: {error_count}')
    print(f'\n   Collection: ghl_data')
    print(f'   Document ID format: contactId (e.g., "ziJ4rSgkJA5qIqIXzD0X")')
    print(f'   Month: November 2025')
    print(f'\n✅ All November 2025 GHL form submissions stored in Firestore!\n')
    
    # Show some stats
    if submissions_without_contact_id:
        print(f'\n📝 Note: {len(submissions_without_contact_id)} submissions without contactId were not stored.\n')


if __name__ == '__main__':
    fetch_all_november_submissions()

