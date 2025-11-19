#!/usr/bin/env python3
"""
Update Navbar Settings in Firebase

Quick script to toggle Forms and Leads visibility in the navbar.

Usage:
    # Hide both Forms and Leads
    python scripts/update_navbar_settings.py --forms=false --leads=false
    
    # Show Forms, hide Leads
    python scripts/update_navbar_settings.py --forms=true --leads=false
    
    # Show both (default)
    python scripts/update_navbar_settings.py --forms=true --leads=true
"""

import firebase_admin
from firebase_admin import credentials, firestore
import os
import sys

# Path to your Firebase service account key
FIREBASE_CRED_PATH = os.path.join(os.path.dirname(__file__), '..', 'medx-ai-firebase-adminsdk-fbsvc-a86e7bd050.json')

def init_firebase():
    """Initialize Firebase Admin SDK"""
    if not firebase_admin._apps:
        cred = credentials.Certificate(FIREBASE_CRED_PATH)
        firebase_admin.initialize_app(cred)
    return firestore.client()

def parse_bool(value):
    """Parse boolean from string"""
    if isinstance(value, bool):
        return value
    return value.lower() in ('true', 't', 'yes', 'y', '1')

def update_settings(db, show_forms=None, show_leads=None):
    """Update navbar visibility settings"""
    settings_ref = db.collection('app_settings').document('feature_flags')
    
    # Get current settings
    doc = settings_ref.get()
    if doc.exists:
        current = doc.to_dict()
        print(f"📋 Current settings:")
        print(f"   showFormsInNavbar: {current.get('showFormsInNavbar', True)}")
        print(f"   showLeadsInNavbar: {current.get('showLeadsInNavbar', True)}")
        print()
    else:
        current = {'showFormsInNavbar': True, 'showLeadsInNavbar': True}
    
    # Prepare updates
    updates = {}
    if show_forms is not None:
        updates['showFormsInNavbar'] = show_forms
    if show_leads is not None:
        updates['showLeadsInNavbar'] = show_leads
    
    if not updates:
        print("❌ No changes specified. Use --forms=true/false or --leads=true/false")
        return
    
    # Apply updates
    settings_ref.set(updates, merge=True)
    
    print(f"✅ Settings updated successfully!")
    if show_forms is not None:
        print(f"   showFormsInNavbar: {show_forms}")
    if show_leads is not None:
        print(f"   showLeadsInNavbar: {show_leads}")
    print("\n🔄 Changes will be reflected in the app immediately!")

def main():
    """Main function"""
    print("="*80)
    print("UPDATE NAVBAR SETTINGS")
    print("="*80)
    
    # Parse command line arguments
    show_forms = None
    show_leads = None
    
    for arg in sys.argv[1:]:
        if arg.startswith('--forms='):
            show_forms = parse_bool(arg.split('=')[1])
        elif arg.startswith('--leads='):
            show_leads = parse_bool(arg.split('=')[1])
        elif arg in ['--help', '-h']:
            print(__doc__)
            return
    
    # Initialize Firebase
    db = init_firebase()
    
    # Update settings
    update_settings(db, show_forms, show_leads)
    
    print("\n" + "="*80)

if __name__ == '__main__':
    main()

