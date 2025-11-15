#!/usr/bin/env python3
"""
Script to find adId for records in ghl_data that don't have one
by checking ghl_contacts and ghl_opportunities collections
"""

import firebase_admin
from firebase_admin import credentials, firestore

# Initialize Firebase
try:
    cred = credentials.Certificate('../medx-ai-firebase-adminsdk-fbsvc-a86e7bd050.json')
    firebase_admin.initialize_app(cred)
    print('✅ Firebase initialized successfully\n')
except Exception as e:
    print(f'⚠️  Firebase already initialized or error: {e}\n')
    pass

try:
    db = firestore.client()
except Exception as e:
    print(f'❌ Error getting Firestore client: {e}')
    print('Trying alternative initialization...\n')
    firebase_admin.delete_app(firebase_admin.get_app())
    cred = credentials.Certificate('../medx-ai-firebase-adminsdk-fbsvc-a86e7bd050.json')
    firebase_admin.initialize_app(cred)
    db = firestore.client()

print('='*80)
print('FINDING MISSING ADIDS - CROSS-COLLECTION SEARCH')
print('='*80 + '\n')

print('🔍 Search Order:')
print('   1. ghl_data (form submissions) - Find records without adId')
print('   2. ghl_contacts - Check if contact has attribution with adId')
print('   3. ghl_opportunities - Check if opportunity has attribution with adId\n')

print('='*80)
print('STEP 1: FETCHING RECORDS WITHOUT ADID FROM GHL_DATA')
print('='*80 + '\n')

ghl_data_ref = db.collection('ghl_data')
docs = ghl_data_ref.stream()

records_without_adid = []

for doc in docs:
    data = doc.to_dict()
    ad_id = data.get('adId')
    
    if not ad_id:
        records_without_adid.append({
            'contactId': data.get('contactId'),
            'name': data.get('name', 'Unknown'),
            'email': data.get('email', ''),
            'source': data.get('source', 'Unknown'),
            'productType': data.get('productType', 'Unknown'),
            'createdAt': data.get('createdAt', ''),
            'fullSubmission': data.get('fullSubmission', {})
        })

print(f'Found {len(records_without_adid)} records without adId\n')

if not records_without_adid:
    print('✅ All records have adId!\n')
    exit()

# Step 2: Take the first record and investigate
print('='*80)
print('STEP 2: INVESTIGATING FIRST RECORD FROM GHL_DATA')
print('='*80 + '\n')

first_record = records_without_adid[0]

print(f'📋 Form Submission Record (from ghl_data):')
print(f'   Name: {first_record["name"]}')
print(f'   Contact ID: {first_record["contactId"]}')
print(f'   Email: {first_record["email"]}')
print(f'   Source: {first_record["source"]}')
print(f'   Product Type: {first_record["productType"]}')
print(f'   Created: {first_record["createdAt"][:19]}')
print(f'   ❌ adId: None (missing)\n')

# Step 3: Check ghl_contacts for this contactId
print('='*80)
print('STEP 3: CHECKING GHL_CONTACTS COLLECTION')
print('='*80 + '\n')

print(f'Looking up contactId: {first_record["contactId"]} in ghl_contacts...\n')

contact_ref = db.collection('ghl_contacts').document(first_record['contactId'])
contact_doc = contact_ref.get()

if contact_doc.exists:
    contact_data = contact_doc.to_dict()
    full_contact = contact_data.get('fullContact', {})
    
    print('✅ Found contact in ghl_contacts\n')
    print('📄 Contact Data:')
    print(f'   Name: {contact_data.get("name", "Unknown")}')
    print(f'   Email: {contact_data.get("email", "")}')
    print(f'   Phone: {contact_data.get("phone", "")}')
    print(f'   Date Added: {contact_data.get("dateAdded", "")[:19]}\n')
    
    # Check for attribution data in full contact
    print('🔍 Checking for attribution data in fullContact...\n')
    
    # Check attributions array
    attributions = full_contact.get('attributions', [])
    if attributions:
        print(f'   Found {len(attributions)} attribution(s):\n')
        for i, attr in enumerate(attributions):
            print(f'   Attribution {i+1}:')
            for key, value in attr.items():
                if 'ad' in key.lower() or 'utm' in key.lower() or 'campaign' in key.lower():
                    print(f'      {key}: {value}')
            print()
    else:
        print('   ⚠️  No attributions found in fullContact\n')
    
    # Check customFields
    custom_fields = full_contact.get('customFields', [])
    if custom_fields:
        print(f'   Found {len(custom_fields)} custom field(s):\n')
        for field in custom_fields:
            field_key = field.get('fieldKey', field.get('id', 'unknown'))
            field_value = field.get('value', '')
            if 'ad' in field_key.lower() or 'utm' in field_key.lower():
                print(f'      {field_key}: {field_value}')
        print()
    
    # Check source
    source = full_contact.get('source', '')
    if source:
        print(f'   Source: {source}\n')
    
else:
    print('⚠️  Contact NOT found in ghl_contacts\n')

# Step 4: Check ghl_opportunities for this contactId
print('='*80)
print('STEP 4: CHECKING GHL_OPPORTUNITIES COLLECTION')
print('='*80 + '\n')

print(f'Looking up contactId: {first_record["contactId"]} in ghl_opportunities...\n')

opp_ref = db.collection('ghl_opportunities').document(first_record['contactId'])
opp_doc = opp_ref.get()

if opp_doc.exists:
    opp_data = opp_doc.to_dict()
    full_opp = opp_data.get('fullOpportunity', {})
    
    print('✅ Found opportunity in ghl_opportunities\n')
    print('📄 Opportunity Data:')
    print(f'   Name: {opp_data.get("name", "Unknown")}')
    print(f'   Pipeline: {"Andries" if opp_data.get("pipelineId") == "XeAGJWRnUGJ5tuhXam2g" else "Davide"}')
    print(f'   Stage: {opp_data.get("stageName", "Unknown")}')
    print(f'   Value: R {opp_data.get("monetaryValue", 0):,.2f}')
    print(f'   Created: {opp_data.get("createdAt", "")[:19]}\n')
    
    # Check for attribution data in opportunity
    print('🔍 Checking for attribution data in fullOpportunity...\n')
    
    attributions = opp_data.get('attributions', [])
    if attributions:
        print(f'   Found {len(attributions)} attribution(s):\n')
        for i, attr in enumerate(attributions):
            print(f'   Attribution {i+1}:')
            for key, value in attr.items():
                if 'ad' in key.lower() or 'utm' in key.lower() or 'campaign' in key.lower():
                    print(f'      {key}: {value}')
            print()
    else:
        print('   ⚠️  No attributions found in opportunity\n')
    
else:
    print('⚠️  Opportunity NOT found in ghl_opportunities\n')

# Step 5: Deep dive into the original form submission
print('='*80)
print('STEP 5: DEEP DIVE - ORIGINAL FORM SUBMISSION (from ghl_data)')
print('='*80 + '\n')

full_submission = first_record.get('fullSubmission', {})

print('🔍 Checking ALL fields in form submission for any ad-related data...\n')

# Check attributions
attributions = full_submission.get('attributions', [])
if attributions:
    print(f'   Found {len(attributions)} attribution(s):\n')
    for i, attr in enumerate(attributions):
        print(f'   Attribution {i+1}:')
        for key, value in attr.items():
            print(f'      {key}: {value}')
        print()
else:
    print('   ⚠️  No attributions array in form submission\n')

# Check others object
others = full_submission.get('others', {})
if others:
    print('   Others object:')
    for key, value in others.items():
        print(f'      {key}: {value}')
    print()

# Check contact object
contact = full_submission.get('contact', {})
if contact:
    contact_attributions = contact.get('attributions', [])
    if contact_attributions:
        print(f'   Found {len(contact_attributions)} attribution(s) in contact object:\n')
        for i, attr in enumerate(contact_attributions):
            print(f'   Contact Attribution {i+1}:')
            for key, value in attr.items():
                print(f'      {key}: {value}')
            print()

print('='*80)
print('INVESTIGATION COMPLETE')
print('='*80 + '\n')

print(f'📊 Summary:')
print(f'   Total records without adId: {len(records_without_adid)}')
print(f'   Investigated: {first_record["name"]} ({first_record["contactId"]})')
print(f'   Source: {first_record["source"]}')
print(f'\n   Next steps: Review the attribution data above to see if adId')
print(f'   can be found in contacts or opportunities collections.\n')

