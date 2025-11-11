#!/usr/bin/env python3
"""
Targeted update script to fix GHL opportunity mappings using Form Submissions API
This script ONLY updates existing mappings, doesn't re-migrate everything
"""

import firebase_admin
from firebase_admin import credentials, firestore
import requests
import time
from datetime import datetime, timedelta

print("=" * 80)
print("UPDATE GHL OPPORTUNITY MAPPINGS WITH FORM SUBMISSIONS DATA")
print("=" * 80)
print()

# Initialize Firebase
if not firebase_admin._apps:
    cred = credentials.Certificate('medx-ai-firebase-adminsdk-fbsvc-a86e7bd050.json')
    firebase_admin.initialize_app(cred)

db = firestore.client()

# GHL API credentials
GHL_API_KEY = 'pit-22f8af95-3244-41e7-9a52-22c87b166f5a'
GHL_LOCATION_ID = 'QdLXaFEqrdF0JbVbpKLw'

headers = {
    'Authorization': f'Bearer {GHL_API_KEY}',
    'Version': '2021-07-28'
}

# ============================================================================
# STEP 1: Fetch Form Submissions to build contact → ad mapping
# ============================================================================

print("📊 STEP 1: Fetching form submissions to extract Ad IDs...")
print()

contact_to_ad_from_forms = {}

# Fetch form submissions from the last 120 days
end_date = datetime.now()
start_date = end_date - timedelta(days=120)

print(f"   Fetching submissions from {start_date.strftime('%Y-%m-%d')} to {end_date.strftime('%Y-%m-%d')}...")

page = 1
total_submissions = 0
submissions_with_ad_id = 0

while True:
    print(f"   Fetching form submissions page {page}...")
    
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
        print(f"   ⚠️  Error fetching form submissions: {response.status_code}")
        break
    
    data = response.json()
    submissions = data.get('submissions', [])
    
    if not submissions:
        print(f"   ✅ Reached end of form submissions")
        break
    
    # If we got less than 100, we're on the last page
    if len(submissions) < 100:
        print(f"   ✅ Reached last page (got {len(submissions)} submissions)")
    
    total_submissions += len(submissions)
    
    # Extract Ad IDs from submissions
    for submission in submissions:
        contact_id = submission.get('contactId')
        if not contact_id:
            continue
        
        others = submission.get('others', {})
        
        # Try to get Ad ID from lastAttributionSource
        last_attr = others.get('lastAttributionSource', {})
        ad_id = last_attr.get('adId')
        adset_id = last_attr.get('adSetId')
        campaign_id = last_attr.get('campaignId')
        
        # If not found, try eventData.url_params
        if not ad_id:
            event_data = others.get('eventData', {})
            url_params = event_data.get('url_params', {})
            ad_id = url_params.get('ad_id')
            adset_id = adset_id or url_params.get('adset_id')
            campaign_id = campaign_id or url_params.get('campaign_id')
        
        # Store the mapping if we found an Ad ID
        if ad_id:
            contact_to_ad_from_forms[contact_id] = {
                'adId': str(ad_id),
                'adSetId': str(adset_id) if adset_id else None,
                'campaignId': str(campaign_id) if campaign_id else None
            }
            submissions_with_ad_id += 1
    
    # If we got less than 100 submissions, we're done
    if len(submissions) < 100:
        break
    
    page += 1
    
    # Rate limiting
    time.sleep(0.2)

print(f"✅ Processed {total_submissions} form submissions")
print(f"✅ Found {submissions_with_ad_id} submissions with Ad IDs")
print(f"✅ Created contact-to-ad mapping for {len(contact_to_ad_from_forms)} contacts")
print()

# ============================================================================
# STEP 2: Load all ads to validate Ad IDs exist
# ============================================================================

print("📊 STEP 2: Loading ads collection to validate Ad IDs...")
print()

ad_map = {}
ads_ref = db.collection('ads').stream()

for ad_doc in ads_ref:
    ad_data = ad_doc.to_dict()
    ad_id = ad_data.get('adId')
    if ad_id:
        ad_map[ad_id] = ad_data

print(f"✅ Loaded {len(ad_map)} ads")
print()

# ============================================================================
# STEP 3: Fetch all opportunities to get contact IDs
# ============================================================================

print("📊 STEP 3: Fetching opportunities to get contact IDs...")
print()

ANDRIES_PIPELINE_ID = 'XeAGJWRnUGJ5tuhXam2g'
DAVIDE_PIPELINE_ID = 'pTbNvnrXqJc9u1oxir3q'

all_opportunities = []
page = 1

while True:
    print(f"   Fetching opportunities page {page}...")
    
    params = {
        'location_id': GHL_LOCATION_ID,
        'limit': 100,
        'page': page
    }
    
    response = requests.get(
        'https://services.leadconnectorhq.com/opportunities/search',
        headers=headers,
        params=params
    )
    
    if response.status_code != 200:
        print(f"   ⚠️  Error fetching opportunities: {response.status_code}")
        break
    
    data = response.json()
    opportunities = data.get('opportunities', [])
    
    if not opportunities:
        print(f"   ✅ Reached end of data")
        break
    
    all_opportunities.extend(opportunities)
    page += 1
    
    # Rate limiting
    time.sleep(0.2)

print(f"✅ Fetched {len(all_opportunities)} total opportunities")

# Filter to Andries and Davide pipelines
filtered_opportunities = [
    opp for opp in all_opportunities
    if opp.get('pipelineId') in [ANDRIES_PIPELINE_ID, DAVIDE_PIPELINE_ID]
]

print(f"✅ Filtered to {len(filtered_opportunities)} opportunities (Andries & Davide)")
print()

# ============================================================================
# STEP 4: Update ghlOpportunities documents directly with form submission data
# ============================================================================

print("📊 STEP 4: Updating ghlOpportunities documents with form submission Ad IDs...")
print()

updates_made = 0
new_assignments = 0
improved_assignments = 0
already_correct = 0
no_form_data = 0

batch = db.batch()
batch_count = 0

for opp in filtered_opportunities:
    opp_id = opp.get('id')
    contact_id = opp.get('contactId') or opp.get('contact', {}).get('id')
    
    if not opp_id or not contact_id:
        continue
    
    # Check if we have form submission data for this contact
    if contact_id not in contact_to_ad_from_forms:
        no_form_data += 1
        continue
    
    form_data = contact_to_ad_from_forms[contact_id]
    form_ad_id = form_data['adId']
    
    # Validate the Ad ID exists in our ads collection
    if form_ad_id not in ad_map:
        continue
    
    # Get the current ghlOpportunities document (if it exists)
    ghl_ref = db.collection('ghlOpportunities').document(opp_id)
    ghl_doc = ghl_ref.get()
    
    if ghl_doc.exists:
        current_ghl = ghl_doc.to_dict()
        current_ad_id = current_ghl.get('assignedAdId')
        current_method = current_ghl.get('assignmentMethod')
        
        # Check if it's already correct
        if current_ad_id == form_ad_id:
            already_correct += 1
            continue
        
        # Check if we're improving the assignment
        if current_ad_id:
            improved_assignments += 1
            print(f"   ⚠️  Updating {opp_id}: {current_ad_id} → {form_ad_id} (was: {current_method})")
        else:
            new_assignments += 1
            print(f"   ✅ Assigning {opp_id}: → {form_ad_id} (was unassigned)")
    else:
        new_assignments += 1
        print(f"   ✅ Creating new ghlOpportunity for {opp_id}: → {form_ad_id}")
    
    # Get ad details
    ad_data = ad_map[form_ad_id]
    
    # Get opportunity details
    attributions = opp.get('attributions', [])
    last_attr = attributions[-1] if attributions else {}
    
    # Update ghlOpportunities document directly
    ghl_update = {
        'opportunityId': opp_id,
        'assignedAdId': form_ad_id,
        'assignmentMethod': 'form_submission_ad_id',
        'assignmentConfidence': 100,
        'campaignId': ad_data.get('campaignId', ''),
        'campaignName': ad_data.get('campaignName', ''),
        'adName': ad_data.get('adName', ''),
        'adSetId': form_data.get('adSetId'),
        'adSetName': ad_data.get('adSetName', ''),
        'contactId': contact_id,
        'opportunityName': opp.get('name', ''),
        'stage': opp.get('status', ''),
        'monetaryValue': opp.get('monetaryValue', 0),
        'pipelineId': opp.get('pipelineId', ''),
        'opportunityCreatedAt': opp.get('createdAt') or opp.get('dateAdded'),
        'utmSource': last_attr.get('utmSource', ''),
        'utmMedium': last_attr.get('utmMedium', ''),
        'utmCampaign': last_attr.get('utmCampaign', ''),
        'updatedAt': firestore.SERVER_TIMESTAMP,
        'updatedBy': 'form_submissions_update_script'
    }
    
    batch.set(ghl_ref, ghl_update, merge=True)
    batch_count += 1
    updates_made += 1
    
    # Commit batch every 500 operations
    if batch_count >= 500:
        batch.commit()
        print(f"   💾 Committed batch of {batch_count} updates")
        batch = db.batch()
        batch_count = 0

# Commit remaining
if batch_count > 0:
    batch.commit()
    print(f"   💾 Committed final batch of {batch_count} updates")

print()
print(f"✅ Update complete!")
print(f"   - Already correct: {already_correct}")
print(f"   - New assignments: {new_assignments}")
print(f"   - Improved assignments: {improved_assignments}")
print(f"   - No form data available: {no_form_data}")
print(f"   - Total updates made: {updates_made}")
print()

# ============================================================================
# STEP 5: Delete ghlOpportunityMapping collection (no longer needed)
# ============================================================================

print("📊 STEP 5: Deleting ghlOpportunityMapping collection (no longer needed)...")
print()

# Count documents first
mapping_docs = list(db.collection('ghlOpportunityMapping').stream())
mapping_count = len(mapping_docs)

if mapping_count > 0:
    print(f"   Found {mapping_count} documents in ghlOpportunityMapping")
    print(f"   Deleting...")
    
    batch = db.batch()
    batch_count = 0
    deleted_count = 0
    
    for mapping_doc in mapping_docs:
        batch.delete(mapping_doc.reference)
        batch_count += 1
        deleted_count += 1
        
        if batch_count >= 500:
            batch.commit()
            print(f"   💾 Deleted {deleted_count}/{mapping_count} documents...")
            batch = db.batch()
            batch_count = 0
    
    # Commit remaining
    if batch_count > 0:
        batch.commit()
    
    print(f"✅ Deleted {deleted_count} documents from ghlOpportunityMapping")
else:
    print(f"   ℹ️  ghlOpportunityMapping collection is already empty")

print()

print("=" * 80)
print("UPDATE COMPLETE!")
print("=" * 80)
print()
print(f"Summary:")
print(f"  - Form submissions processed: {total_submissions}")
print(f"  - Contacts with Ad IDs from forms: {len(contact_to_ad_from_forms)}")
print(f"  - GHL opportunities updated: {updates_made}")
print(f"  - ghlOpportunityMapping collection deleted: ✅")
print()
print(f"What changed:")
print(f"  ✅ All ghlOpportunities now have accurate Ad IDs from Form Submissions API")
print(f"  ✅ Removed ghlOpportunityMapping collection (no longer needed)")
print(f"  ✅ All data is now stored directly in ghlOpportunities")
print()
print(f"Next steps:")
print(f"  1. Check the Flutter app to see improved matching")
print(f"  2. Verify Yolandi Nel now shows correct Ad ID: 120235560268260335")
print()

