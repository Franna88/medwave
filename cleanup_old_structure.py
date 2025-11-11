#!/usr/bin/env python3
"""
Cleanup old advertData structure after migration
WARNING: This will DELETE all ads in the old structure
Only run after verifying migration success!
"""

import firebase_admin
from firebase_admin import credentials, firestore

# Initialize Firebase
if not firebase_admin._apps:
    cred = credentials.Certificate('medx-ai-firebase-adminsdk-fbsvc-a86e7bd050.json')
    firebase_admin.initialize_app(cred)

db = firestore.client()

def delete_old_structure():
    """Delete ads from old structure (advertData/{adId})"""
    
    print('\n' + '='*80)
    print('CLEANUP OLD ADVERTDATA STRUCTURE')
    print('='*80)
    
    print('\n⚠️  WARNING: This will DELETE all ads in the old structure!')
    print('   Old structure: advertData/{adId}')
    print('   This action CANNOT be undone!')
    
    # Get old ads (documents with adId field)
    print('\n📊 Checking old structure...')
    old_ads = list(db.collection('advertData').where('adId', '!=', '').stream())
    
    if len(old_ads) == 0:
        print('   ✅ No ads found in old structure. Nothing to delete.')
        return
    
    print(f'   Found {len(old_ads)} ads in old structure')
    print(f'\n   Sample IDs: {[ad.id for ad in old_ads[:5]]}')
    
    # Confirmation
    print('\n' + '='*80)
    print('CONFIRMATION REQUIRED')
    print('='*80)
    print(f'\nYou are about to DELETE {len(old_ads)} ads from the old structure.')
    print('This will remove:')
    print('  - Main ad documents')
    print('  - insights subcollections')
    print('  - ghlWeekly subcollections')
    print('\nThe NEW month-first structure will NOT be affected.')
    print('\n⚠️  Make sure you have:')
    print('  1. Run migrate_to_month_structure.py successfully')
    print('  2. Run verify_migration.py and confirmed all data copied')
    print('  3. Tested the new structure with test_new_structure.py')
    print('  4. Updated facebookAdsSync.js and populate_ghl_data.py')
    
    confirm = input('\nType "DELETE OLD STRUCTURE" to confirm: ')
    
    if confirm != 'DELETE OLD STRUCTURE':
        print('\n❌ Cancelled. No data was deleted.')
        return
    
    # Delete old ads
    print('\n🗑️  Deleting old structure...')
    
    batch = db.batch()
    deleted_count = 0
    batch_count = 0
    
    for ad in old_ads:
        ad_id = ad.id
        ad_ref = ad.reference
        
        print(f'   Deleting ad: {ad_id}')
        
        # Delete insights subcollection
        insights = list(ad_ref.collection('insights').stream())
        for insight in insights:
            batch.delete(insight.reference)
            batch_count += 1
        
        # Delete ghlWeekly subcollection
        ghl_weeks = list(ad_ref.collection('ghlWeekly').stream())
        for week in ghl_weeks:
            batch.delete(week.reference)
            batch_count += 1
        
        # Delete main document
        batch.delete(ad_ref)
        batch_count += 1
        deleted_count += 1
        
        # Commit batch every 500 operations (Firestore limit)
        if batch_count >= 450:  # Leave some margin
            print(f'   Committing batch ({deleted_count} ads deleted so far)...')
            batch.commit()
            batch = db.batch()
            batch_count = 0
    
    # Commit remaining operations
    if batch_count > 0:
        print(f'   Committing final batch...')
        batch.commit()
    
    print(f'\n' + '='*80)
    print('CLEANUP COMPLETE!')
    print('='*80)
    print(f'\n✅ Deleted {deleted_count} ads from old structure')
    print(f'\n📊 New structure remains intact:')
    print(f'   advertData/{{month}}/ads/{{adId}}')
    print(f'\n✅ Migration complete! Old structure removed.')
    print('\n' + '='*80)

def main():
    try:
        delete_old_structure()
    except Exception as e:
        print(f'\n❌ Error during cleanup: {e}')
        print('   Old structure may be partially deleted.')
        print('   Run verify_migration.py to check current state.')

if __name__ == '__main__':
    main()

