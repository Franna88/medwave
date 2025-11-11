#!/usr/bin/env python3
"""
Check if h_ad_id is stored in contact custom fields
"""

import requests
import os
import json

# GHL Configuration
GHL_API_KEY = os.environ.get('GHL_API_KEY', 'pit-22f8af95-3244-41e7-9a52-22c87b166f5a')
GHL_LOCATION_ID = 'QdLXaFEqrdF0JbVbpKLw'

def get_contact_details(contact_id):
    """Fetch full contact details including custom fields"""
    url = f'https://services.leadconnectorhq.com/contacts/{contact_id}'
    headers = {
        'Authorization': f'Bearer {GHL_API_KEY}',
        'Version': '2021-07-28'
    }
    
    try:
        response = requests.get(url, headers=headers)
        response.raise_for_status()
        return response.json().get('contact', {})
    except Exception as e:
        print(f"❌ Error: {e}")
        return None

# Check the two contacts from our earlier examples
contacts = [
    ('marilettebester83@gmail.com', 'Marilette - HAS utmAdId'),
    ('yolandinelboerdery@gmail.com', 'Yolandi - NO utmAdId')
]

print("=" * 80)
print("CHECKING CONTACT CUSTOM FIELDS FOR h_ad_id")
print("=" * 80)
print()

for email, description in contacts:
    print(f"🔍 {description}")
    print(f"   Email: {email}")
    
    # First search for contact by email
    search_url = 'https://services.leadconnectorhq.com/contacts/search/duplicate'
    headers = {
        'Authorization': f'Bearer {GHL_API_KEY}',
        'Version': '2021-07-28',
        'Content-Type': 'application/json'
    }
    
    payload = {
        'locationId': GHL_LOCATION_ID,
        'email': email
    }
    
    try:
        response = requests.post(search_url, headers=headers, json=payload)
        response.raise_for_status()
        contacts_data = response.json().get('contact', [])
        
        if not contacts_data:
            print(f"   ❌ Contact not found\n")
            continue
        
        # Get first matching contact
        contact = contacts_data[0] if isinstance(contacts_data, list) else contacts_data
        contact_id = contact.get('id')
        
        # Get full contact details
        full_contact = get_contact_details(contact_id)
        
        if not full_contact:
            print(f"   ❌ Could not fetch full contact details\n")
            continue
        
        # Check for custom fields
        custom_fields = full_contact.get('customFields', [])
        
        print(f"   Contact ID: {contact_id}")
        print(f"   Custom Fields: {len(custom_fields)}")
        
        # Look for h_ad_id or fbc_id in custom fields
        found_ad_id = False
        for field in custom_fields:
            field_key = field.get('key', '').lower()
            field_value = field.get('value', '')
            
            if 'ad' in field_key or 'fbc' in field_key or 'utm' in field_key:
                print(f"      ✅ {field.get('key')}: {field_value}")
                found_ad_id = True
        
        if not found_ad_id:
            print(f"      ❌ No ad-related custom fields found")
        
        # Also check source attribute
        source = full_contact.get('source')
        if source:
            print(f"   Source: {source}")
        
        print()
        
    except Exception as e:
        print(f"   ❌ Error: {e}\n")

print("=" * 80)

