#!/usr/bin/env python3
"""
Match formScore from ghl_data to leads Collection
Fetches all leads from the leads collection, matches them to ghl_data documents,
and updates leads with formScore values from ghl_data.fullSubmission.formScore
"""

import firebase_admin
from firebase_admin import credentials, firestore
from datetime import datetime
import os

# Initialize Firebase
try:
    # Get the directory where this script is located
    script_dir = os.path.dirname(os.path.abspath(__file__))
    
    # Try to find Firebase credentials file in common locations
    cred_paths = [
        os.path.join(script_dir, 'ghl_opp_collection', 'medx-ai-firebase-adminsdk-fbsvc-d88a6aa1a7.json'),
        os.path.join(script_dir, 'ghl_data_collection', 'medx-ai-firebase-adminsdk-fbsvc-d88a6aa1a7.json'),
        os.path.join(script_dir, 'summary_collection', 'medx-ai-firebase-adminsdk-fbsvc-d88a6aa1a7.json'),
        os.path.join(script_dir, 'medx-ai-firebase-adminsdk-fbsvc-a86e7bd050.json'),
        os.path.join(script_dir, 'medx-ai-firebase-adminsdk-fbsvc-d88a6aa1a7.json')
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


def fetch_all_leads():
    """Fetch all documents from leads collection"""
    print('📥 Fetching all leads from leads collection...')
    leads = []
    
    try:
        leads_ref = db.collection('leads')
        docs = leads_ref.stream()
        
        for doc in docs:
            lead_data = doc.to_dict()
            lead_data['_doc_id'] = doc.id  # Store document ID
            leads.append(lead_data)
        
        print(f'   ✅ Fetched {len(leads)} leads\n')
        return leads
    except Exception as e:
        print(f'   ❌ Error fetching leads: {e}\n')
        return []


def get_formscore_from_ghl_data(ghl_doc):
    """Extract formScore from ghl_data document (from fullSubmission.formScore)"""
    if not ghl_doc:
        return None
    
    try:
        full_submission = ghl_doc.get('fullSubmission', {})
        if isinstance(full_submission, dict):
            form_score = full_submission.get('formScore')
            if form_score is not None:
                return int(form_score)
    except Exception as e:
        print(f'   ⚠️  Error extracting formScore: {e}')
    
    return None


def find_ghl_data_by_contactid(contact_id):
    """Find ghl_data document by contactId (document ID)"""
    if not contact_id:
        return None
    
    try:
        doc_ref = db.collection('ghl_data').document(contact_id)
        doc = doc_ref.get()
        
        if doc.exists:
            return doc.to_dict()
    except Exception as e:
        print(f'   ⚠️  Error finding ghl_data by contactId {contact_id}: {e}')
    
    return None


def find_ghl_data_by_email(email):
    """Find ghl_data document by email (case-insensitive query)"""
    if not email:
        return None
    
    try:
        email_lower = email.lower().strip()
        ghl_ref = db.collection('ghl_data')
        
        # Try exact match first (case-sensitive)
        docs = ghl_ref.where('email', '==', email).limit(1).stream()
        for doc in docs:
            return doc.to_dict()
        
        # If no exact match, try case-insensitive by querying with range
        # This works for most emails since they're typically lowercase
        docs = ghl_ref.where('email', '>=', email_lower).where('email', '<=', email_lower + '\uf8ff').limit(10).stream()
        
        for doc in docs:
            doc_data = doc.to_dict()
            doc_email = doc_data.get('email', '')
            if doc_email and doc_email.lower().strip() == email_lower:
                return doc_data
                
    except Exception as e:
        print(f'   ⚠️  Error finding ghl_data by email {email}: {e}')
    
    return None


def update_lead_formscore(lead_id, form_score):
    """Update lead document with formScore"""
    if not lead_id or form_score is None:
        return False
    
    try:
        lead_ref = db.collection('leads').document(lead_id)
        lead_ref.update({
            'formScore': form_score,
            'formScoreUpdatedAt': datetime.now().isoformat()
        })
        return True
    except Exception as e:
        print(f'   ❌ Error updating lead {lead_id}: {e}')
        return False


def match_formscore_to_leads():
    """Main function to match formScore from ghl_data to leads"""
    print('='*80)
    print('MATCH FORMSCORE FROM GHL_DATA TO LEADS')
    print('='*80 + '\n')
    
    # Statistics
    stats = {
        'total_leads': 0,
        'skipped_already_has_formscore': 0,
        'matched_by_contactid': 0,
        'matched_by_email': 0,
        'updated_successfully': 0,
        'not_found': 0,
        'errors': 0
    }
    
    # Step 1: Fetch all leads
    print('='*80)
    print('STEP 1: FETCHING ALL LEADS')
    print('='*80 + '\n')
    
    leads = fetch_all_leads()
    stats['total_leads'] = len(leads)
    
    if not leads:
        print('⚠️  No leads found. Exiting.\n')
        return
    
    # Step 2: Process each lead
    print('='*80)
    print('STEP 2: MATCHING LEADS TO GHL_DATA AND UPDATING FORMSCORE')
    print('='*80 + '\n')
    
    for idx, lead in enumerate(leads, 1):
        lead_id = lead.get('_doc_id') or lead.get('id')
        lead_email = lead.get('email', '')
        lead_name = f"{lead.get('firstName', '')} {lead.get('lastName', '')}".strip() or 'Unknown'
        
        # Check if lead already has formScore
        if 'formScore' in lead and lead['formScore'] is not None:
            stats['skipped_already_has_formscore'] += 1
            if idx % 100 == 0:  # Progress update every 100 leads
                print(f'   Processed {idx}/{len(leads)} leads...')
            continue
        
        # Try to find matching ghl_data by contactId first
        contact_id = lead.get('id') or lead_id
        ghl_data = None
        match_method = None
        
        if contact_id:
            ghl_data = find_ghl_data_by_contactid(contact_id)
            if ghl_data:
                match_method = 'contactId'
                stats['matched_by_contactid'] += 1
        
        # If not found by contactId, try email
        if not ghl_data and lead_email:
            ghl_data = find_ghl_data_by_email(lead_email)
            if ghl_data:
                match_method = 'email'
                stats['matched_by_email'] += 1
        
        # Extract formScore from ghl_data
        if ghl_data:
            form_score = get_formscore_from_ghl_data(ghl_data)
            
            if form_score is not None:
                # Update lead with formScore
                if update_lead_formscore(lead_id, form_score):
                    stats['updated_successfully'] += 1
                    print(f'✅ {idx}. Updated {lead_name[:30]} (ID: {lead_id[:20]}...) - Score: {form_score} (matched by {match_method})')
                else:
                    stats['errors'] += 1
            else:
                stats['not_found'] += 1
                print(f'⚠️  {idx}. No formScore found in ghl_data for {lead_name[:30]} (matched by {match_method})')
        else:
            stats['not_found'] += 1
            if idx % 50 == 0:  # Show some not found examples
                print(f'⚠️  {idx}. No ghl_data match found for {lead_name[:30]} (ID: {lead_id[:20] if lead_id else "N/A"}...)')
        
        # Progress update
        if idx % 100 == 0:
            print(f'   Progress: {idx}/{len(leads)} leads processed...')
    
    # Step 3: Summary
    print('\n' + '='*80)
    print('MATCHING COMPLETE')
    print('='*80 + '\n')
    
    print(f'📊 Summary Statistics:')
    print(f'   Total leads fetched: {stats["total_leads"]}')
    print(f'   Leads skipped (already have formScore): {stats["skipped_already_has_formscore"]}')
    print(f'   Matches found by contactId: {stats["matched_by_contactid"]}')
    print(f'   Matches found by email: {stats["matched_by_email"]}')
    print(f'   Leads updated successfully: {stats["updated_successfully"]}')
    print(f'   Leads not found (no matching ghl_data): {stats["not_found"]}')
    print(f'   Errors encountered: {stats["errors"]}')
    print(f'\n✅ FormScore matching complete!\n')


if __name__ == '__main__':
    match_formscore_to_leads()

