#!/usr/bin/env python3
"""
GHL Contacts API Data Inspector
Connects to GHL API and displays all available data for contacts
"""

import requests
import json
from datetime import datetime

# GHL API Configuration
GHL_API_KEY = 'pit-22f8af95-3244-41e7-9a52-22c87b166f5a'
GHL_LOCATION_ID = 'QdLXaFEqrdF0JbVbpKLw'
GHL_BASE_URL = 'https://services.leadconnectorhq.com'
GHL_API_VERSION = '2021-07-28'

def print_section(title):
    """Print a formatted section header"""
    print("\n" + "="*100)
    print(f"  {title}")
    print("="*100)

def print_json(data, indent=2):
    """Pretty print JSON data"""
    print(json.dumps(data, indent=indent, default=str))

def get_headers():
    """Get GHL API headers"""
    return {
        'Authorization': f'Bearer {GHL_API_KEY}',
        'Version': GHL_API_VERSION,
        'Content-Type': 'application/json'
    }

def fetch_contacts(limit=10):
    """Fetch contacts from GHL"""
    print_section(f"FETCHING CONTACTS (Limit {limit})")
    
    url = f"{GHL_BASE_URL}/contacts/"
    
    params = {
        'locationId': GHL_LOCATION_ID,
        'limit': limit
    }
    
    try:
        response = requests.get(url, headers=get_headers(), params=params)
        response.raise_for_status()
        data = response.json()
        
        contacts = data.get('contacts', [])
        total = data.get('total', 0)
        
        print(f"\n✅ Found {len(contacts)} contacts (Total: {total})\n")
        
        # Show summary
        for i, contact in enumerate(contacts[:5], 1):
            print(f"{i}. {contact.get('firstName', '')} {contact.get('lastName', '')}")
            print(f"   ID: {contact.get('id', 'N/A')}")
            print(f"   Email: {contact.get('email', 'N/A')}")
            print(f"   Phone: {contact.get('phone', 'N/A')}")
            print(f"   Created: {contact.get('dateAdded', 'N/A')}")
            print()
        
        return contacts, data
    
    except requests.exceptions.RequestException as e:
        print(f"❌ Error fetching contacts: {e}")
        if hasattr(e, 'response') and e.response is not None:
            print(f"Response: {e.response.text}")
        return [], {}

def fetch_single_contact(contact_id):
    """Fetch a single contact with all details"""
    print_section(f"FETCHING SINGLE CONTACT: {contact_id}")
    
    url = f"{GHL_BASE_URL}/contacts/{contact_id}"
    
    try:
        response = requests.get(url, headers=get_headers())
        response.raise_for_status()
        data = response.json()
        
        contact = data.get('contact', data)  # Handle different response formats
        
        print("\n📦 COMPLETE CONTACT DATA:")
        print_json(contact)
        
        return contact
    
    except requests.exceptions.RequestException as e:
        print(f"❌ Error fetching contact: {e}")
        if hasattr(e, 'response') and e.response is not None:
            print(f"Response: {e.response.text}")
        return None

def fetch_forms_submissions(limit=10):
    """Fetch form submissions (contains attribution data)"""
    print_section(f"FETCHING FORM SUBMISSIONS (Limit {limit})")
    
    url = f"{GHL_BASE_URL}/forms/submissions"
    
    params = {
        'locationId': GHL_LOCATION_ID,
        'limit': limit
    }
    
    try:
        response = requests.get(url, headers=get_headers(), params=params)
        response.raise_for_status()
        data = response.json()
        
        submissions = data.get('submissions', [])
        
        print(f"\n✅ Found {len(submissions)} form submissions\n")
        
        # Show summary
        for i, submission in enumerate(submissions[:5], 1):
            contact_id = submission.get('contactId', 'N/A')
            form_id = submission.get('formId', 'N/A')
            
            # Check for ad_id in attribution
            ad_id = 'N/A'
            if 'others' in submission:
                others = submission['others']
                if 'lastAttributionSource' in others:
                    ad_id = others['lastAttributionSource'].get('adId', 'N/A')
                elif 'eventData' in others and 'url_params' in others['eventData']:
                    ad_id = others['eventData']['url_params'].get('ad_id', 'N/A')
            
            print(f"{i}. Contact ID: {contact_id}")
            print(f"   Form ID: {form_id}")
            print(f"   Ad ID: {ad_id}")
            print(f"   Created: {submission.get('createdAt', 'N/A')}")
            print()
        
        return submissions, data
    
    except requests.exceptions.RequestException as e:
        print(f"❌ Error fetching form submissions: {e}")
        if hasattr(e, 'response') and e.response is not None:
            print(f"Response: {e.response.text}")
        return [], {}

def analyze_contact_fields(contact):
    """Analyze and categorize all fields in a contact"""
    print_section("CONTACT FIELD ANALYSIS")
    
    if not contact:
        print("❌ No contact data to analyze")
        return
    
    print("\n✅ AVAILABLE FIELDS:\n")
    
    # Categorize fields
    basic_fields = []
    contact_info_fields = []
    address_fields = []
    attribution_fields = []
    custom_fields = []
    date_fields = []
    tag_fields = []
    other_fields = []
    
    for key, value in contact.items():
        if key in ['id', 'firstName', 'lastName', 'name', 'email', 'phone']:
            basic_fields.append((key, type(value).__name__, value))
        elif key in ['address1', 'city', 'state', 'country', 'postalCode']:
            address_fields.append((key, type(value).__name__, value))
        elif 'source' in key.lower() or 'attribution' in key.lower() or 'utm' in key.lower():
            attribution_fields.append((key, type(value).__name__, value))
        elif 'custom' in key.lower():
            custom_fields.append((key, type(value).__name__, value))
        elif 'date' in key.lower() or 'time' in key.lower() or 'At' in key:
            date_fields.append((key, type(value).__name__, value))
        elif 'tag' in key.lower():
            tag_fields.append((key, type(value).__name__, value))
        else:
            other_fields.append((key, type(value).__name__, value))
    
    # Print categorized fields
    if basic_fields:
        print("📋 BASIC CONTACT INFO:")
        for field, field_type, value in basic_fields:
            if isinstance(value, (dict, list)):
                print(f"   - {field} ({field_type})")
            else:
                print(f"   - {field} ({field_type}): {value}")
    
    if contact_info_fields:
        print("\n📞 CONTACT DETAILS:")
        for field, field_type, value in contact_info_fields:
            if isinstance(value, (dict, list)):
                print(f"   - {field} ({field_type})")
            else:
                print(f"   - {field} ({field_type}): {value}")
    
    if address_fields:
        print("\n📍 ADDRESS FIELDS:")
        for field, field_type, value in address_fields:
            if isinstance(value, (dict, list)):
                print(f"   - {field} ({field_type})")
            else:
                print(f"   - {field} ({field_type}): {value}")
    
    if attribution_fields:
        print("\n🎯 ATTRIBUTION FIELDS:")
        for field, field_type, value in attribution_fields:
            if isinstance(value, (dict, list)):
                print(f"   - {field} ({field_type})")
                if isinstance(value, list) and len(value) > 0:
                    print(f"     Sample: {value[0]}")
                elif isinstance(value, dict):
                    for k, v in list(value.items())[:3]:
                        print(f"     - {k}: {v}")
            else:
                print(f"   - {field} ({field_type}): {value}")
    
    if custom_fields:
        print("\n⚙️  CUSTOM FIELDS:")
        for field, field_type, value in custom_fields:
            if isinstance(value, (dict, list)):
                print(f"   - {field} ({field_type})")
            else:
                print(f"   - {field} ({field_type}): {value}")
    
    if tag_fields:
        print("\n🏷️  TAG FIELDS:")
        for field, field_type, value in tag_fields:
            if isinstance(value, (dict, list)):
                print(f"   - {field} ({field_type})")
                if isinstance(value, list):
                    print(f"     Count: {len(value)}")
            else:
                print(f"   - {field} ({field_type}): {value}")
    
    if date_fields:
        print("\n📅 DATE/TIME FIELDS:")
        for field, field_type, value in date_fields:
            print(f"   - {field} ({field_type}): {value}")
    
    if other_fields:
        print("\n📦 OTHER FIELDS:")
        for field, field_type, value in other_fields:
            if isinstance(value, (dict, list)):
                print(f"   - {field} ({field_type})")
            else:
                print(f"   - {field} ({field_type}): {value}")

def analyze_form_submission(submission):
    """Analyze form submission structure"""
    print_section("FORM SUBMISSION FIELD ANALYSIS")
    
    if not submission:
        print("❌ No submission data to analyze")
        return
    
    print("\n✅ FORM SUBMISSION STRUCTURE:\n")
    
    for key in sorted(submission.keys()):
        value = submission[key]
        if isinstance(value, dict):
            print(f"📦 {key} (dict):")
            for sub_key in list(value.keys())[:10]:
                sub_value = value[sub_key]
                if isinstance(sub_value, (dict, list)):
                    print(f"   - {sub_key}: {type(sub_value).__name__}")
                else:
                    print(f"   - {sub_key}: {sub_value}")
            if len(value.keys()) > 10:
                print(f"   ... and {len(value.keys()) - 10} more fields")
        elif isinstance(value, list):
            print(f"📦 {key} (list): {len(value)} items")
            if len(value) > 0:
                print(f"   Sample: {value[0]}")
        else:
            print(f"📋 {key}: {value}")

def main():
    """Main execution"""
    print_section("GHL CONTACTS & FORMS API DATA INSPECTOR")
    print(f"API Base URL: {GHL_BASE_URL}")
    print(f"Location ID: {GHL_LOCATION_ID}")
    print(f"API Version: {GHL_API_VERSION}")
    print(f"Timestamp: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    
    # Step 1: Fetch recent contacts
    contacts, contacts_response = fetch_contacts(limit=10)
    
    if not contacts:
        print("\n❌ No contacts found")
        return
    
    # Step 2: Show complete contacts response structure
    print_section("COMPLETE CONTACTS RESPONSE STRUCTURE")
    print("\n📦 CONTACTS RESPONSE KEYS:")
    for key in contacts_response.keys():
        print(f"   - {key}")
    
    # Step 3: Fetch single contact with all details
    selected_contact_id = contacts[0]['id']
    complete_contact = fetch_single_contact(selected_contact_id)
    
    # Step 4: Analyze contact fields
    if complete_contact:
        analyze_contact_fields(complete_contact)
    
    # Step 5: Fetch form submissions (contains attribution)
    submissions, submissions_response = fetch_forms_submissions(limit=10)
    
    # Step 6: Analyze form submission structure
    if submissions:
        print_section("FORM SUBMISSIONS RESPONSE STRUCTURE")
        print("\n📦 SUBMISSIONS RESPONSE KEYS:")
        for key in submissions_response.keys():
            print(f"   - {key}")
        
        # Analyze first submission
        if len(submissions) > 0:
            analyze_form_submission(submissions[0])
    
    # Step 7: Show sample contact from list
    print_section("SAMPLE CONTACT FROM LIST")
    if contacts:
        print("\n📦 FIRST CONTACT (from list endpoint):")
        print_json(contacts[0])
    
    # Step 8: Show sample form submission
    if submissions:
        print_section("SAMPLE FORM SUBMISSION")
        print("\n📦 FIRST SUBMISSION (from forms endpoint):")
        print_json(submissions[0])
    
    # Step 9: Summary
    print_section("DATA SUMMARY")
    
    if complete_contact:
        print("\n✅ COMPLETE CONTACT FIELD LIST:")
        for key in sorted(complete_contact.keys()):
            value = complete_contact[key]
            if isinstance(value, (dict, list)):
                print(f"   - {key}: {type(value).__name__}")
            else:
                print(f"   - {key}")
    
    print_section("INSPECTION COMPLETE")
    print("\n✅ All available contact and form submission data has been retrieved")
    print("📝 Review the complete payloads to see what data GHL API provides")
    print("\n💡 KEY FINDINGS:")
    print("   - Contacts include: basic info, contact details, address, tags, custom fields")
    print("   - Form submissions contain: attribution data, ad_id, UTM parameters")
    print("   - Attribution data in 'others.lastAttributionSource' or 'others.eventData.url_params'")
    print("   - Form submissions are the SOURCE OF TRUTH for Facebook ad attribution")

if __name__ == '__main__':
    main()
