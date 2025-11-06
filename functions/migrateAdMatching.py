#!/usr/bin/env python3
"""
Migration Script: Re-run Ad Matching with Improved Logic

This script re-runs the Facebook ad matching logic on all historical data
to fix misattributions caused by duplicate ad names across different ad sets.

The new matching logic uses:
1. Facebook Ad ID (if already populated)
2. Campaign Name + Ad Set Name + Ad Name (composite matching)
3. Campaign Name + Ad Name (fallback for old data without ad set info)

Usage:
    python3 migrateAdMatching.py [--dry-run] [--service-account PATH]

Options:
    --dry-run              Show what would be updated without making changes
    --service-account PATH Path to Firebase service account JSON file
                          (default: medx-ai-firebase-adminsdk-fbsvc-a86e7bd050.json)
"""

import sys
import argparse
import json
from datetime import datetime
from collections import defaultdict
import firebase_admin
from firebase_admin import credentials, firestore

def normalize_ad_name(name):
    """Normalize ad name for matching (lowercase, remove extra spaces)"""
    if not name:
        return ''
    return name.lower().strip().replace('  ', ' ')

def export_current_metrics(db):
    """Export current ad performance metrics for comparison"""
    print('\n📊 Exporting current ad performance metrics...\n')
    
    snapshot = db.collection('adPerformance').stream()
    current_metrics = {}
    
    matched_count = 0
    unmatched_count = 0
    total_count = 0
    
    for doc in snapshot:
        total_count += 1
        data = doc.to_dict()
        ad_id = doc.id
        ad_name = data.get('adName', 'Unknown')
        ad_set_name = data.get('adSetName', 'N/A')
        campaign_name = data.get('campaignName', 'N/A')
        
        ghl_stats = data.get('ghlStats', {})
        leads = ghl_stats.get('leads', 0)
        bookings = ghl_stats.get('bookings', 0)
        deposits = ghl_stats.get('deposits', 0)
        matching_status = data.get('matchingStatus', 'unknown')
        
        if matching_status == 'matched':
            matched_count += 1
        elif matching_status == 'unmatched':
            unmatched_count += 1
        
        current_metrics[ad_id] = {
            'adId': ad_id,
            'adName': ad_name,
            'adSetName': ad_set_name,
            'campaignName': campaign_name,
            'leads': leads,
            'bookings': bookings,
            'deposits': deposits,
            'matchingStatus': matching_status,
            'facebookSpend': data.get('facebookStats', {}).get('spend', 0)
        }
    
    print(f'✅ Exported metrics for {total_count} ads')
    print(f'   - Matched: {matched_count}')
    print(f'   - Unmatched: {unmatched_count}')
    print(f'   - Other: {total_count - matched_count - unmatched_count}')
    
    return current_metrics

def match_opportunities_to_ads(db, dry_run=False):
    """
    Re-run the matching logic with improved composite matching
    """
    print('\n🔄 Running improved ad matching logic...\n')
    
    # Get all Facebook ads
    ad_docs = list(db.collection('adPerformance').stream())
    
    if not ad_docs:
        print('⚠️  No Facebook ads found in adPerformance collection')
        return {'matched': 0, 'unmatched': 0, 'errors': 0}
    
    print(f'📊 Found {len(ad_docs)} Facebook ads')
    
    stats = {
        'matched': 0,
        'unmatched': 0,
        'errors': 0,
        'back_populated': 0
    }
    
    # Process each Facebook ad
    for ad_doc in ad_docs:
        try:
            ad_data = ad_doc.to_dict()
            ad_id = ad_doc.id
            ad_name = ad_data.get('adName', '')
            campaign_name = ad_data.get('campaignName', '')
            ad_set_name = ad_data.get('adSetName', '')
            ad_set_id = ad_data.get('adSetId', '')
            
            # Normalize names for matching
            normalized_ad_name = normalize_ad_name(ad_name)
            normalized_campaign_name = normalize_ad_name(campaign_name)
            normalized_ad_set_name = normalize_ad_name(ad_set_name)
            
            # Query opportunities that match this campaign
            history_query = db.collection('opportunityStageHistory')\
                .where('campaignName', '==', campaign_name)\
                .stream()
            
            # Filter opportunities using improved composite matching
            matching_opportunities = []
            
            print(f'🔍 Matching ad: {ad_name} (ID: {ad_id}) in ad set: {ad_set_name}')
            
            for opp_doc in history_query:
                opp_data = opp_doc.to_dict()
                opp_ad_name = normalize_ad_name(opp_data.get('adName', ''))
                opp_ad_set_name = normalize_ad_name(opp_data.get('adSetName', ''))
                
                # Priority 1: Match by Facebook Ad ID if available
                if opp_data.get('facebookAdId') and opp_data['facebookAdId'] == ad_id:
                    matching_opportunities.append({
                        'doc_id': opp_doc.id,
                        'data': opp_data
                    })
                    continue
                
                # Priority 2: Match by Campaign + Ad Set + Ad Name (composite matching)
                if opp_ad_name == normalized_ad_name:
                    # If we have ad set info from both sides, require it to match
                    if normalized_ad_set_name and opp_ad_set_name:
                        if opp_ad_set_name == normalized_ad_set_name:
                            matching_opportunities.append({
                                'doc_id': opp_doc.id,
                                'data': opp_data
                            })
                    else:
                        # Fallback: match by ad name only (backward compatibility)
                        matching_opportunities.append({
                            'doc_id': opp_doc.id,
                            'data': opp_data
                        })
            
            print(f'   Found {len(matching_opportunities)} matching opportunities')
            if matching_opportunities:
                opp_ids = [opp['data'].get('opportunityId', 'N/A') for opp in matching_opportunities[:5]]
                print(f'   Matched IDs: {", ".join(opp_ids)}{" ..." if len(matching_opportunities) > 5 else ""}')
            
            # Aggregate GHL metrics from matching opportunities
            ghl_metrics = {
                'leads': 0,
                'bookings': 0,
                'deposits': 0,
                'cashCollected': 0,
                'cashAmount': 0
            }
            
            # Track unique opportunities and their latest stage
            opportunity_latest_state = {}
            
            # Find the latest state for each unique opportunity
            for opp in matching_opportunities:
                opp_data = opp['data']
                opp_id = opp_data.get('opportunityId')
                timestamp = opp_data.get('timestamp')
                
                if timestamp:
                    timestamp_date = timestamp.replace(tzinfo=None) if hasattr(timestamp, 'replace') else timestamp
                else:
                    timestamp_date = datetime.now()
                
                if opp_id not in opportunity_latest_state or timestamp_date > opportunity_latest_state[opp_id]['timestamp']:
                    opportunity_latest_state[opp_id] = {
                        'stageCategory': opp_data.get('stageCategory', ''),
                        'stageName': opp_data.get('newStageName', ''),
                        'timestamp': timestamp_date,
                        'monetaryValue': opp_data.get('monetaryValue', 0)
                    }
            
            # Count opportunities by stage category
            default_deposit_amount = 1500
            for opp_id, state in opportunity_latest_state.items():
                ghl_metrics['leads'] += 1
                
                stage_category = state['stageCategory']
                if stage_category == 'bookedAppointments':
                    ghl_metrics['bookings'] += 1
                if stage_category == 'deposits':
                    ghl_metrics['deposits'] += 1
                    deposit_value = state['monetaryValue'] if state['monetaryValue'] > 0 else default_deposit_amount
                    ghl_metrics['cashAmount'] += deposit_value
                if stage_category == 'cashCollected':
                    ghl_metrics['cashCollected'] += 1
                    cash_value = state['monetaryValue'] if state['monetaryValue'] > 0 else default_deposit_amount
                    ghl_metrics['cashAmount'] += cash_value
            
            # Update ad performance document
            if not dry_run:
                update_data = {
                    'lastUpdated': firestore.SERVER_TIMESTAMP
                }
                
                if ghl_metrics['leads'] > 0:
                    # Has GHL data - mark as matched
                    update_data['ghlStats'] = {
                        'campaignKey': campaign_name,
                        'leads': ghl_metrics['leads'],
                        'bookings': ghl_metrics['bookings'],
                        'deposits': ghl_metrics['deposits'],
                        'cashCollected': ghl_metrics['cashCollected'],
                        'cashAmount': ghl_metrics['cashAmount'],
                        'lastSync': firestore.SERVER_TIMESTAMP
                    }
                    update_data['matchingStatus'] = 'matched'
                    stats['matched'] += 1
                    
                    print(f'✅ Matched: {ad_name} → {ghl_metrics["leads"]} leads, {ghl_metrics["bookings"]} bookings, {ghl_metrics["deposits"]} deposits')
                    
                    # Back-populate Facebook Ad ID into opportunity history
                    back_populate_count = 0
                    for opp in matching_opportunities:
                        opp_data = opp['data']
                        # Only update if the opportunity doesn't already have the correct Facebook Ad ID
                        if not opp_data.get('facebookAdId') or opp_data['facebookAdId'] != ad_id:
                            try:
                                db.collection('opportunityStageHistory').document(opp['doc_id']).update({
                                    'facebookAdId': ad_id,
                                    'matchedAdSetId': ad_set_id or '',
                                    'matchedAdSetName': ad_set_name or '',
                                    'lastMatched': firestore.SERVER_TIMESTAMP
                                })
                                back_populate_count += 1
                            except Exception as e:
                                print(f'⚠️  Failed to back-populate ad ID for opportunity: {e}')
                    
                    if back_populate_count > 0:
                        print(f'   📝 Back-populated Facebook Ad ID to {back_populate_count} opportunities')
                        stats['back_populated'] += back_populate_count
                    
                else:
                    # No GHL data - remains unmatched
                    update_data['matchingStatus'] = 'unmatched'
                    update_data['ghlStats'] = firestore.DELETE_FIELD
                    stats['unmatched'] += 1
                
                # Update the ad performance document
                db.collection('adPerformance').document(ad_id).update(update_data)
            else:
                # Dry run - just count
                if ghl_metrics['leads'] > 0:
                    stats['matched'] += 1
                else:
                    stats['unmatched'] += 1
            
        except Exception as e:
            print(f'❌ Error matching ad {ad_doc.id}: {e}')
            stats['errors'] += 1
    
    print(f'\n✅ GHL matching complete: {stats["matched"]} matched, {stats["unmatched"]} unmatched, {stats["errors"]} errors')
    if not dry_run and stats['back_populated'] > 0:
        print(f'📝 Back-populated Facebook Ad IDs to {stats["back_populated"]} opportunity records')
    
    return stats

def compare_metrics(db, before_metrics):
    """Compare metrics before and after migration"""
    print('\n📈 Analyzing changes...\n')
    
    after_snapshot = db.collection('adPerformance').stream()
    changes = []
    
    for doc in after_snapshot:
        ad_id = doc.id
        after_data = doc.to_dict()
        before_data = before_metrics.get(ad_id)
        
        if before_data:
            before_leads = before_data['leads']
            after_leads = after_data.get('ghlStats', {}).get('leads', 0)
            
            if before_leads != after_leads:
                changes.append({
                    'adId': ad_id,
                    'adName': after_data.get('adName', 'Unknown'),
                    'adSetName': after_data.get('adSetName', 'N/A'),
                    'campaignName': after_data.get('campaignName', 'N/A'),
                    'beforeLeads': before_leads,
                    'afterLeads': after_leads,
                    'difference': after_leads - before_leads
                })
    
    if changes:
        print(f'⚠️  Found {len(changes)} ads with changed metrics:\n')
        
        # Sort by absolute difference (largest changes first)
        changes.sort(key=lambda x: abs(x['difference']), reverse=True)
        
        # Show top 20 changes
        display_count = min(len(changes), 20)
        for i, change in enumerate(changes[:display_count]):
            arrow = '⬆️ ' if change['difference'] > 0 else '⬇️ '
            print(f"{i + 1}. {arrow}{change['adName']}")
            print(f"   Campaign: {change['campaignName']}")
            print(f"   Ad Set: {change['adSetName']}")
            diff_str = f"+{change['difference']}" if change['difference'] > 0 else str(change['difference'])
            print(f"   Leads: {change['beforeLeads']} → {change['afterLeads']} ({diff_str})")
            print()
        
        if len(changes) > display_count:
            print(f"   ... and {len(changes) - display_count} more changes\n")
        
        # Summary statistics
        increased_leads = len([c for c in changes if c['difference'] > 0])
        decreased_leads = len([c for c in changes if c['difference'] < 0])
        total_leads_added = sum(max(0, c['difference']) for c in changes)
        total_leads_removed = sum(abs(min(0, c['difference'])) for c in changes)
        
        print('📊 Change Summary:')
        print(f'   - Ads with increased leads: {increased_leads} (+{total_leads_added} total)')
        print(f'   - Ads with decreased leads: {decreased_leads} (-{total_leads_removed} total)')
        print(f'   - Net change: {total_leads_added - total_leads_removed} leads')
    else:
        print('✅ No changes detected in ad metrics')

def run_migration(service_account_path, dry_run=False):
    """Main migration function"""
    print('\n🚀 Starting Ad Matching Migration\n')
    print('=' * 80)
    
    if dry_run:
        print('⚠️  DRY RUN MODE - No changes will be made\n')
    
    try:
        # Initialize Firebase Admin SDK
        if not firebase_admin._apps:
            cred = credentials.Certificate(service_account_path)
            firebase_admin.initialize_app(cred)
        
        db = firestore.client()
        
        # Step 1: Export current metrics for comparison
        before_metrics = export_current_metrics(db)
        
        # Step 2: Run the improved matching logic
        results = match_opportunities_to_ads(db, dry_run)
        
        # Step 3: Compare before and after (only if not dry run)
        if not dry_run:
            compare_metrics(db, before_metrics)
        
        print('\n' + '=' * 80)
        print('✅ Migration completed successfully!\n')
        
        if dry_run:
            print('ℹ️  This was a dry run. Run without --dry-run to apply changes.\n')
        
        return True
        
    except Exception as error:
        print(f'\n❌ Migration failed: {error}')
        import traceback
        traceback.print_exc()
        return False

def main():
    """Main entry point"""
    parser = argparse.ArgumentParser(
        description='Re-run Facebook ad matching with improved logic',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__
    )
    parser.add_argument(
        '--dry-run',
        action='store_true',
        help='Show what would be updated without making changes'
    )
    parser.add_argument(
        '--service-account',
        default='medx-ai-firebase-adminsdk-fbsvc-a86e7bd050.json',
        help='Path to Firebase service account JSON file'
    )
    
    args = parser.parse_args()
    
    success = run_migration(args.service_account, args.dry_run)
    
    print('🏁 Done!')
    sys.exit(0 if success else 1)

if __name__ == '__main__':
    main()

