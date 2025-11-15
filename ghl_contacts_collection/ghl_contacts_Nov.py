#!/usr/bin/env python3
"""
GHL Contacts Collection - November 2025
Fetches all GHL contacts for November 2025 and stores them in Firestore collection 'ghl_contacts'
Each contact is stored with its contactId as the document ID
"""

import requests
import firebase_admin
from firebase_admin import credentials, firestore
from datetime import datetime
import time
import json

# Initialize Firebase
try:
    cred = credentials.Certificate('/Users/mac/dev/medwave/medx-ai-firebase-adminsdk-fbsvc-a86e7bd050.json')
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
START_DATE = '2025-11-01T00:00:00.000Z'
END_DATE = '2025-11-30T23:59:59.999Z'


def get_ghl_headers():
    return {
        'Authorization': f'Bearer {GHL_API_KEY}',
        'Version': GHL_API_VERSION,
        'Content-Type': 'application/json'
    }


def fetch_all_november_contacts():
    """Fetch all contacts for November 2025"""
    print('='*80)
    print('GHL CONTACTS COLLECTION - NOVEMBER 2025')
    print('='*80 + '\n')
    
    print(f'📅 Date Range: {START_DATE[:10]} to {END_DATE[:10]}')
    print(f'🎯 Location ID: {GHL_LOCATION_ID}')
    print(f'📊 API Version: {GHL_API_VERSION}\n')
    
    # Step 1: Fetch all contacts
    print('='*80)
    print('STEP 1: FETCHING ALL CONTACTS FROM GHL')
    print('='*80 + '\n')
    
    url = f'{GHL_BASE_URL}/contacts/'
    all_contacts = []
    
    # First, fetch ALL contacts (GHL Contacts API doesn't support date filtering directly)
    params = {
        'locationId': GHL_LOCATION_ID,
        'limit': 100
    }
    
    page = 1
    use_params = True
    
    while True:
        print(f'📄 Fetching page {page}...')
        
        try:
            # Only use params for first request, then use full nextPageUrl
            if use_params:
                response = requests.get(url, headers=get_ghl_headers(), params=params, timeout=30)
            else:
                response = requests.get(url, headers=get_ghl_headers(), timeout=30)
            
            # Handle rate limiting
            if response.status_code == 429:
                print(f'   ⚠️  Rate limit hit, waiting 60 seconds...')
                time.sleep(60)
                continue
            
            response.raise_for_status()
            data = response.json()
            
            contacts = data.get('contacts', [])
            
            if not contacts:
                print(f'   ✅ No more contacts found\n')
                break
            
            all_contacts.extend(contacts)
            print(f'   Found {len(contacts)} contacts on this page')
            
            # Check if we're on the last page
            meta = data.get('meta', {})
            next_page_url = meta.get('nextPageUrl')
            
            if not next_page_url:
                print(f'   ✅ Reached last page\n')
                break
            
            # Update URL for next page (use full URL, don't add params)
            url = next_page_url
            use_params = False  # Don't use params for subsequent requests
            page += 1
            
            # Be nice to the API
            time.sleep(0.5)
            
        except Exception as e:
            print(f'   ❌ Error fetching contacts: {e}')
            print(f'   Continuing with {len(all_contacts)} contacts fetched so far...\n')
            break
    
    print(f'✅ Total contacts fetched: {len(all_contacts)}\n')
    
    # Filter for November 2025 contacts
    print('='*80)
    print('STEP 2: FILTERING FOR NOVEMBER 2025 CONTACTS')
    print('='*80 + '\n')
    
    november_contacts = []
    for contact in all_contacts:
        date_added = contact.get('dateAdded', '')
        if date_added:
            # Check if dateAdded is in November 2025
            if date_added >= START_DATE and date_added <= END_DATE:
                november_contacts.append(contact)
    
    print(f'✅ Contacts in November 2025: {len(november_contacts)}')
    print(f'⚠️  Contacts outside November: {len(all_contacts) - len(november_contacts)}\n')
    
    # Verify date range
    if november_contacts:
        print(f'📅 Verifying date range of November contacts...')
        dates = []
        for contact in november_contacts[:5]:
            date_added = contact.get('dateAdded', '')
            if date_added:
                dates.append(date_added[:10])
        
        if dates:
            all_dates = [c.get('dateAdded', '')[:10] for c in november_contacts if c.get('dateAdded')]
            print(f'   Sample dates: {", ".join(dates)}')
            if all_dates:
                print(f'   Earliest: {min(all_dates)}')
                print(f'   Latest: {max(all_dates)}\n')
    
    # Step 3: Store in Firestore
    print('='*80)
    print('STEP 3: STORING IN FIRESTORE COLLECTION "ghl_contacts"')
    print('='*80 + '\n')
    
    stored_count = 0
    skipped_count = 0
    error_count = 0
    
    # Store each contact with contactId as document ID
    for contact in november_contacts:
        try:
            contact_id = contact.get('id')
            
            if not contact_id:
                skipped_count += 1
                continue
            
            # Extract key fields for easy access
            first_name = contact.get('firstName', '')
            last_name = contact.get('lastName', '')
            contact_name = contact.get('contactName', f'{first_name} {last_name}')
            email = contact.get('email', '')
            phone = contact.get('phone', '')
            date_added = contact.get('dateAdded', '')
            date_updated = contact.get('dateUpdated', '')
            contact_type = contact.get('type', 'Unknown')
            source = contact.get('source', 'Unknown')
            
            # Extract attribution data
            attributions = contact.get('attributions', [])
            last_attribution = None
            first_attribution = None
            
            for attr in attributions:
                if attr.get('isLast'):
                    last_attribution = attr
                if attr.get('isFirst'):
                    first_attribution = attr
            
            # Create document data
            doc_data = {
                'contactId': contact_id,
                'contactName': contact_name,
                'firstName': first_name,
                'lastName': last_name,
                'email': email,
                'phone': phone,
                'type': contact_type,
                'source': source,
                'dateAdded': date_added,
                'dateUpdated': date_updated,
                'lastAttribution': last_attribution,
                'firstAttribution': first_attribution,
                'fullContact': contact,  # Complete GHL contact payload
                'fetchedAt': datetime.now().isoformat(),
                'month': 'November',
                'year': 2025,
                'dateRange': {
                    'start': START_DATE,
                    'end': END_DATE
                }
            }
            
            # Store in Firestore with contactId as document ID
            doc_ref = db.collection('ghl_contacts').document(contact_id)
            doc_ref.set(doc_data)
            
            stored_count += 1
            
            # Show contact info
            display_name = contact_name[:30] if contact_name else 'Unknown'
            print(f'✅ {stored_count}. Stored {display_name} (ID: {contact_id[:20]}...) - Added: {date_added[:10] if date_added else "N/A"}')
            
        except Exception as e:
            error_count += 1
            print(f'❌ Error storing contact: {e}')
    
    # Summary
    print('\n' + '='*80)
    print('COLLECTION COMPLETE')
    print('='*80 + '\n')
    
    print(f'📊 Summary:')
    print(f'   Total contacts fetched: {len(all_contacts)}')
    print(f'   November 2025 contacts: {len(november_contacts)}')
    print(f'   Successfully stored: {stored_count}')
    print(f'   Skipped: {skipped_count}')
    print(f'   Errors: {error_count}')
    print(f'\n   Collection: ghl_contacts')
    print(f'   Document ID format: contactId (e.g., "KGMHtceu6vRhvoF24eIT")')
    print(f'   Month: November 2025')
    print(f'\n✅ All November 2025 GHL contacts stored in Firestore!\n')


if __name__ == '__main__':
    fetch_all_november_contacts()

