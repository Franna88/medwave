#!/usr/bin/env python3
"""
Initialize App Settings in Firebase

This script creates the initial app_settings document in Firestore
with default feature flags for Forms and Leads navbar visibility.

Usage:
    python scripts/init_app_settings.py

You can also manually set these in Firebase Console:
    Collection: app_settings
    Document ID: feature_flags
    Fields:
        - showFormsInNavbar: boolean (true/false)
        - showLeadsInNavbar: boolean (true/false)
"""

import firebase_admin
from firebase_admin import credentials, firestore
import os

# Path to your Firebase service account key
FIREBASE_CRED_PATH = os.path.join(os.path.dirname(__file__), '..', 'medx-ai-firebase-adminsdk-fbsvc-a86e7bd050.json')

def init_firebase():
    """Initialize Firebase Admin SDK"""
    if not firebase_admin._apps:
        cred = credentials.Certificate(FIREBASE_CRED_PATH)
        firebase_admin.initialize_app(cred)
    return firestore.client()

def initialize_app_settings(db, show_forms=True, show_leads=True):
    """
    Initialize app settings with feature flags
    
    Args:
        db: Firestore client
        show_forms: Whether to show Forms in navbar (default: True)
        show_leads: Whether to show Leads in navbar (default: True)
    """
    settings_ref = db.collection('app_settings').document('feature_flags')
    
    # Check if settings already exist
    doc = settings_ref.get()
    if doc.exists:
        print("⚠️  App settings already exist:")
        print(f"   Current values: {doc.to_dict()}")
        response = input("\nDo you want to update them? (y/n): ")
        if response.lower() != 'y':
            print("❌ Cancelled. No changes made.")
            return
    
    # Set the settings
    settings_data = {
        'showFormsInNavbar': show_forms,
        'showLeadsInNavbar': show_leads,
    }
    
    settings_ref.set(settings_data)
    print("✅ App settings initialized successfully!")
    print(f"   showFormsInNavbar: {show_forms}")
    print(f"   showLeadsInNavbar: {show_leads}")
    print("\n📝 You can manually change these values in Firebase Console:")
    print("   1. Go to Firestore Database")
    print("   2. Navigate to 'app_settings' collection")
    print("   3. Edit the 'feature_flags' document")
    print("   4. Toggle 'showFormsInNavbar' or 'showLeadsInNavbar' to true/false")
    print("\n🔄 Changes will be reflected in the app immediately (real-time updates)")

def main():
    """Main function"""
    print("="*80)
    print("INITIALIZE APP SETTINGS")
    print("="*80)
    
    # Initialize Firebase
    db = init_firebase()
    
    # Get user input for initial values
    print("\nSet initial values for feature flags:")
    print("(You can change these later in Firebase Console)")
    
    show_forms_input = input("\nShow Forms in navbar? (y/n, default: y): ").strip().lower()
    show_forms = show_forms_input != 'n'
    
    show_leads_input = input("Show Leads in navbar? (y/n, default: y): ").strip().lower()
    show_leads = show_leads_input != 'n'
    
    # Initialize settings
    initialize_app_settings(db, show_forms, show_leads)
    
    print("\n" + "="*80)
    print("DONE!")
    print("="*80)

if __name__ == '__main__':
    main()

