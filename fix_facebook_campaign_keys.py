#!/usr/bin/env python3
"""
Firebase Campaign Key Fix Script
=================================
This script updates the campaignKey field in ad_performance_costs collection
to use the correct Facebook Campaign IDs instead of campaign names.

Usage:
    python3 fix_facebook_campaign_keys.py
"""

import firebase_admin
from firebase_admin import credentials, firestore
import sys
from datetime import datetime

# Mapping of ad names to correct Facebook Campaign IDs
AD_CAMPAIGN_MAPPING = {
    "Obesity - Andries - DDM": "120234435129520335",
    "Health Providers": "120234166546100335",
    "120232883487010335": "120232882927590335",
}

def initialize_firebase():
    """Initialize Firebase Admin SDK"""
    try:
        print("🔍 Looking for Firebase credentials file...")
        # Try to use existing credentials file
        cred = credentials.Certificate('bhl-obe-firebase-adminsdk-fbsvc-68c34b6ad7.json')
        print("📄 Credentials file found, initializing Firebase...")
        firebase_admin.initialize_app(cred)
        print("✅ Firebase initialized successfully")
        print("🔗 Connecting to Firestore...")
        db = firestore.client()
        print("✅ Firestore client connected")
        return db
    except FileNotFoundError:
        print(f"❌ Error: Firebase credentials file not found")
        print("\n💡 Make sure 'bhl-obe-firebase-adminsdk-fbsvc-68c34b6ad7.json' exists in the current directory")
        sys.exit(1)
    except Exception as e:
        print(f"❌ Error initializing Firebase: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)

def get_ad_performance_costs(db):
    """Fetch all ad performance cost documents"""
    try:
        docs = db.collection('ad_performance_costs').get()
        return [(doc.id, doc.to_dict()) for doc in docs]
    except Exception as e:
        print(f"❌ Error fetching documents: {e}")
        sys.exit(1)

def update_campaign_key(db, doc_id, ad_name, new_campaign_key, old_campaign_key):
    """Update the campaignKey field for a specific document"""
    try:
        db.collection('ad_performance_costs').document(doc_id).update({
            'campaignKey': new_campaign_key,
            'updatedAt': datetime.now()
        })
        print(f"✅ Updated: {ad_name}")
        print(f"   Old: {old_campaign_key[:60]}..." if len(old_campaign_key) > 60 else f"   Old: {old_campaign_key}")
        print(f"   New: {new_campaign_key}")
        print()
        return True
    except Exception as e:
        print(f"❌ Error updating {ad_name}: {e}")
        return False

def main():
    print("=" * 70)
    print("🔧 Facebook Campaign Key Fix Script")
    print("=" * 70)
    print()
    
    # Initialize Firebase
    db = initialize_firebase()
    print()
    
    # Fetch all ad performance costs
    print("📊 Fetching ad performance costs from Firebase...")
    docs = get_ad_performance_costs(db)
    print(f"   Found {len(docs)} documents")
    print()
    
    # Find and update matching ads
    print("🔍 Searching for ads to update...")
    print()
    
    updated_count = 0
    not_found = []
    
    for ad_name, new_campaign_key in AD_CAMPAIGN_MAPPING.items():
        found = False
        
        for doc_id, data in docs:
            # Match by adName field
            if data.get('adName') == ad_name:
                old_campaign_key = data.get('campaignKey', '')
                
                if old_campaign_key == new_campaign_key:
                    print(f"⏭️  Skipped: {ad_name} (already has correct Campaign ID)")
                    print()
                else:
                    if update_campaign_key(db, doc_id, ad_name, new_campaign_key, old_campaign_key):
                        updated_count += 1
                
                found = True
                break
        
        if not found:
            not_found.append(ad_name)
    
    # Summary
    print("=" * 70)
    print("📋 Summary")
    print("=" * 70)
    print(f"✅ Updated: {updated_count} ads")
    
    if not_found:
        print(f"⚠️  Not found: {len(not_found)} ads")
        for ad_name in not_found:
            print(f"   - {ad_name}")
    
    print()
    
    if updated_count > 0:
        print("🎉 SUCCESS! Campaign keys have been updated.")
        print()
        print("Next steps:")
        print("1. Go to your Superadmin Web Portal")
        print("2. Navigate to 'Advertisement Performance'")
        print("3. Click the Refresh button (🔄) in the 'Add Performance Cost' header")
        print("4. Your ads should now appear with live Facebook data!")
    else:
        print("ℹ️  No changes were needed.")
    
    print()
    print("=" * 70)

if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\n\n⚠️  Script interrupted by user")
        sys.exit(0)
    except Exception as e:
        print(f"\n❌ Unexpected error: {e}")
        sys.exit(1)

