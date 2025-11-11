#!/usr/bin/env python3
"""
Clean up adminConfig fields from adPerformance collection
This script removes the adminConfig field from all documents in the adPerformance collection
since we no longer use product linking or budget configuration.
"""

import firebase_admin
from firebase_admin import credentials, firestore
from datetime import datetime

# Initialize Firebase
try:
    cred = credentials.Certificate('medx-ai-firebase-adminsdk-fbsvc-a86e7bd050.json')
    firebase_admin.initialize_app(cred)
except ValueError:
    # Already initialized
    pass

db = firestore.client()

def cleanup_admin_config(dry_run=True):
    """Remove adminConfig field from all adPerformance documents"""
    
    print("=" * 100)
    print("🧹 CLEANING UP ADMIN CONFIG FIELDS FROM AD PERFORMANCE")
    print("=" * 100)
    print()
    
    if dry_run:
        print("🔍 DRY RUN MODE - No changes will be made")
        print()
    
    # Get all documents from adPerformance collection
    ads_ref = db.collection('adPerformance')
    all_ads = list(ads_ref.stream())
    
    print(f"Found {len(all_ads)} ad performance documents")
    print()
    
    stats = {
        'total': len(all_ads),
        'with_admin_config': 0,
        'cleaned': 0,
        'errors': 0
    }
    
    for ad_doc in all_ads:
        try:
            ad_data = ad_doc.to_dict()
            
            # Check if document has adminConfig field
            if 'adminConfig' in ad_data:
                stats['with_admin_config'] += 1
                
                print(f"Found adminConfig in: {ad_data.get('adName', 'Unknown')} (ID: {ad_doc.id})")
                
                if not dry_run:
                    # Remove the adminConfig field
                    ad_doc.reference.update({
                        'adminConfig': firestore.DELETE_FIELD
                    })
                    stats['cleaned'] += 1
                    print(f"  ✅ Removed adminConfig")
                else:
                    print(f"  [DRY RUN] Would remove adminConfig")
                    stats['cleaned'] += 1
                
                print()
        
        except Exception as e:
            print(f"❌ Error processing {ad_doc.id}: {e}")
            stats['errors'] += 1
            print()
    
    print("=" * 100)
    print("📊 CLEANUP SUMMARY")
    print("=" * 100)
    print(f"Total documents: {stats['total']}")
    print(f"Documents with adminConfig: {stats['with_admin_config']}")
    print(f"Documents cleaned: {stats['cleaned']}")
    print(f"Errors: {stats['errors']}")
    print()
    
    return stats

def main():
    import sys
    
    dry_run = '--execute' not in sys.argv
    
    print("\n" + "=" * 100)
    print("🚀 ADMIN CONFIG CLEANUP SCRIPT")
    print("=" * 100)
    print(f"\nExecution Time: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    
    if dry_run:
        print("\n⚠️  DRY RUN MODE - Use --execute flag to apply changes")
    else:
        print("\n✅ EXECUTE MODE - Changes will be applied to Firebase")
    
    print()
    
    # Run cleanup
    stats = cleanup_admin_config(dry_run=dry_run)
    
    # Final summary
    print("\n" + "=" * 100)
    print("🎉 CLEANUP COMPLETE")
    print("=" * 100)
    print()
    
    if dry_run:
        print("This was a DRY RUN. To apply changes, run:")
        print("  python3 cleanup_admin_config.py --execute")
    else:
        print("✅ All adminConfig fields have been removed from Firebase")
        print()
        print("Next steps:")
        print("  1. Verify the Campaign Performance page still works correctly")
        print("  2. Check that profit calculations use GHL values")
        print("  3. The adPerformance collection is now clean")
    
    print()


if __name__ == "__main__":
    main()

