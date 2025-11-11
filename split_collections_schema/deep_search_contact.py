#!/usr/bin/env python3
"""
Deep search script to find Ad ID anywhere in Yolandi's contact object
"""

import requests
import json

# GHL API credentials
GHL_API_KEY = 'pit-22f8af95-3244-41e7-9a52-22c87b166f5a'
GHL_LOCATION_ID = 'QdLXaFEqrdF0JbVbpKLw'

headers = {
    'Authorization': f'Bearer {GHL_API_KEY}',
    'Version': '2021-07-28'
}

print("=" * 80)
print("DEEP SEARCH: Looking for Ad ID 120235560268260335 in Yolandi's Contact")
print("=" * 80)
print()

target_ad_id = '120235560268260335'

# Step 1: Search for contact
print("📞 Fetching Yolandi's contact...")
search_response = requests.get(
    f'https://services.leadconnectorhq.com/contacts/',
    headers=headers,
    params={
        'locationId': GHL_LOCATION_ID,
        'query': 'yolandi1712@gmail.com'
    }
)

if search_response.status_code != 200:
    print(f"❌ Error: {search_response.status_code}")
    exit(1)

contacts = search_response.json().get('contacts', [])
if not contacts:
    print("❌ Contact not found")
    exit(1)

contact_id = contacts[0].get('id')
print(f"✅ Found contact ID: {contact_id}")
print()

# Step 2: Fetch full contact
print("📞 Fetching full contact object...")
contact_response = requests.get(
    f'https://services.leadconnectorhq.com/contacts/{contact_id}',
    headers=headers
)

if contact_response.status_code != 200:
    print(f"❌ Error: {contact_response.status_code}")
    exit(1)

contact = contact_response.json().get('contact', {})
print(f"✅ Contact fetched")
print()

# Step 3: Deep search function
def deep_search(obj, target, path="", results=None):
    """Recursively search for target value in nested dict/list"""
    if results is None:
        results = []
    
    if isinstance(obj, dict):
        for key, value in obj.items():
            current_path = f"{path}.{key}" if path else key
            
            # Check if value matches target
            if str(value) == target:
                results.append({
                    'path': current_path,
                    'value': value,
                    'type': type(value).__name__
                })
            
            # Recurse into nested structures
            if isinstance(value, (dict, list)):
                deep_search(value, target, current_path, results)
    
    elif isinstance(obj, list):
        for i, item in enumerate(obj):
            current_path = f"{path}[{i}]"
            
            # Check if item matches target
            if str(item) == target:
                results.append({
                    'path': current_path,
                    'value': item,
                    'type': type(item).__name__
                })
            
            # Recurse into nested structures
            if isinstance(item, (dict, list)):
                deep_search(item, target, current_path, results)
    
    return results

# Step 4: Search for the Ad ID
print(f"🔍 Searching for Ad ID: {target_ad_id}")
print()

results = deep_search(contact, target_ad_id)

if results:
    print(f"✅ FOUND {len(results)} occurrence(s) of Ad ID {target_ad_id}:")
    print()
    for i, result in enumerate(results, 1):
        print(f"   {i}. Path: {result['path']}")
        print(f"      Value: {result['value']}")
        print(f"      Type: {result['type']}")
        print()
else:
    print(f"❌ Ad ID {target_ad_id} NOT FOUND in contact object")
    print()

# Step 5: Also search for partial matches (in case it's embedded in a string)
print("🔍 Searching for partial matches (Ad ID embedded in strings)...")
print()

def find_in_strings(obj, target, path="", results=None):
    """Find target value embedded in string values"""
    if results is None:
        results = []
    
    if isinstance(obj, dict):
        for key, value in obj.items():
            current_path = f"{path}.{key}" if path else key
            
            # Check if target is in string value
            if isinstance(value, str) and target in value:
                results.append({
                    'path': current_path,
                    'value': value,
                    'contains': target
                })
            
            # Recurse
            if isinstance(value, (dict, list)):
                find_in_strings(value, target, current_path, results)
    
    elif isinstance(obj, list):
        for i, item in enumerate(obj):
            current_path = f"{path}[{i}]"
            
            # Check if target is in string item
            if isinstance(item, str) and target in item:
                results.append({
                    'path': current_path,
                    'value': item,
                    'contains': target
                })
            
            # Recurse
            if isinstance(item, (dict, list)):
                find_in_strings(item, target, current_path, results)
    
    return results

string_results = find_in_strings(contact, target_ad_id)

if string_results:
    print(f"✅ FOUND {len(string_results)} string(s) containing Ad ID:")
    print()
    for i, result in enumerate(string_results, 1):
        print(f"   {i}. Path: {result['path']}")
        print(f"      Value: {result['value']}")
        print()
else:
    print(f"❌ Ad ID not found in any string values")
    print()

# Step 6: Show all top-level keys in contact
print("📋 Top-level keys in Contact object:")
print()
for key in sorted(contact.keys()):
    value = contact[key]
    value_type = type(value).__name__
    
    if isinstance(value, dict):
        print(f"   - {key}: {value_type} ({len(value)} keys)")
    elif isinstance(value, list):
        print(f"   - {key}: {value_type} ({len(value)} items)")
    else:
        print(f"   - {key}: {value_type}")

print()
print("=" * 80)
print("DEEP SEARCH COMPLETE")
print("=" * 80)
print()

# Step 7: Save full contact object to file for manual inspection
output_file = 'yolandi_contact_full.json'
with open(output_file, 'w') as f:
    json.dump(contact, f, indent=2, default=str)

print(f"💾 Full contact object saved to: {output_file}")
print(f"   You can manually inspect this file to find the Ad ID")
print()

