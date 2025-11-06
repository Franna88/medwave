#!/usr/bin/env python3
"""
Fix Duplicate Ad Metrics Across Ad Sets

This script identifies ads with the same name appearing in multiple ad sets
and redistributes the GHL metrics based on which ad set each opportunity belongs to.

Strategy:
1. Find all opportunities in opportunityStageHistory
2. Group by campaign + ad name + ad set name
3. Recalculate GHL metrics for each ad in each ad set
4. Update adPerformance collection with corrected metrics
"""

import sys
import firebase_admin
from firebase_admin import credentials, firestore
from collections import defaultdict
from typing import Dict, List

# Initialize Firebase Admin SDK
try:
    cred = credentials.Certificate('../medx-ai-firebase-adminsdk-fbsvc-a86e7bd050.json')
    firebase_admin.initialize_app(cred)
except ValueError:
    pass

db = firestore.client()

def normalize_name(name: str) -> str:
    """Normalize name for matching"""
    if not name:
        return ''
    return ''.join(c.lower() for c in name if c.isalnum() or c.isspace()).strip()

def get_stage_category(stage_name: str) -> str:
    """Get stage category"""
    stage_lower = stage_name.lower() if stage_name else ''
    
    if 'appointment' in stage_lower or 'booked' in stage_lower:
        return 'bookedAppointments'
    elif 'deposit' in stage_lower:
        return 'deposits'
    elif 'cash' in stage_lower and 'collected' in stage_lower:
        return 'cashCollected'
    else:
        return 'other'

def find_duplicate_ads():
    """
    Find Facebook ads that have the same name but exist in different ad sets
    Returns: Dict of {adName: [list of ad documents]}
    """
    print('🔍 Finding duplicate ads across ad sets...')
    
    ads_ref = db.collection('adPerformance')
    ads_snapshot = ads_ref.stream()
    
    # Group ads by normalized ad name
    ads_by_name = defaultdict(list)
    
    for ad_doc in ads_snapshot:
        ad_data = ad_doc.to_dict()
        ad_name = ad_data.get('adName', '')
        ad_set_name = ad_data.get('adSetName', '')
        
        if not ad_name:
            continue
        
        normalized_name = normalize_name(ad_name)
        
        ads_by_name[normalized_name].append({
            'id': ad_doc.id,
            'adName': ad_name,
            'adSetName': ad_set_name,
            'campaignName': ad_data.get('campaignName', ''),
            'currentGhlStats': ad_data.get('ghlStats', {}),
            'facebookStats': ad_data.get('facebookStats', {}),
        })
    
    # Find duplicates (same ad name in multiple ad sets)
    duplicates = {}
    for ad_name, ads in ads_by_name.items():
        # Only consider it a duplicate if there are multiple instances
        # AND they have different ad set names
        ad_sets = set(ad['adSetName'] for ad in ads if ad['adSetName'])
        if len(ads) > 1 and len(ad_sets) > 1:
            duplicates[ad_name] = ads
    
    print(f'✅ Found {len(duplicates)} duplicate ad names across multiple ad sets')
    
    return duplicates

def recalculate_metrics_for_ad(ad_id: str, ad_name: str, ad_set_name: str, campaign_name: str):
    """
    Recalculate GHL metrics for a specific ad in a specific ad set
    by matching opportunities that have the exact same campaign + ad + ad set
    """
    normalized_ad_name = normalize_name(ad_name)
    normalized_ad_set = normalize_name(ad_set_name)
    normalized_campaign = normalize_name(campaign_name)
    
    # Query opportunities that match this specific ad in this specific ad set
    opps_ref = db.collection('opportunityStageHistory')\
        .where('campaignName', '==', campaign_name)
    
    opps_snapshot = opps_ref.stream()
    
    # Filter opportunities by composite match: campaign + ad + ad set
    matching_opportunities = []
    
    for opp_doc in opps_snapshot:
        opp_data = opp_doc.to_dict()
        opp_ad_name = normalize_name(opp_data.get('adName', ''))
        opp_ad_set = normalize_name(opp_data.get('adSetName', ''))
        
        # Priority 1: Match by Facebook Ad ID (if available)
        if opp_data.get('facebookAdId') == ad_id:
            matching_opportunities.append(opp_data)
            continue
        
        # Priority 2: Match by campaign + ad name + ad set name
        if opp_ad_name == normalized_ad_name:
            # If we have ad set info from both sides, require exact match
            if normalized_ad_set and opp_ad_set:
                if opp_ad_set == normalized_ad_set:
                    matching_opportunities.append(opp_data)
            # If no ad set info on either side, match by ad name only (old data)
            elif not normalized_ad_set and not opp_ad_set:
                matching_opportunities.append(opp_data)
    
    # Calculate metrics from matching opportunities
    # Track unique opportunities and their latest state
    opportunity_latest_state = {}
    
    for opp in matching_opportunities:
        opp_id = opp.get('opportunityId')
        timestamp = opp.get('timestamp')
        
        if isinstance(timestamp, str):
            continue
        
        # Convert Firestore timestamp to datetime for comparison
        try:
            opp_time = timestamp.replace(tzinfo=None) if hasattr(timestamp, 'replace') else timestamp
        except:
            opp_time = timestamp
        
        # Keep only the latest state for each opportunity
        if opp_id not in opportunity_latest_state or opp_time > opportunity_latest_state[opp_id]['timestamp']:
            opportunity_latest_state[opp_id] = {
                'stageCategory': opp.get('stageCategory', ''),
                'stageName': opp.get('newStageName', ''),
                'timestamp': opp_time,
                'monetaryValue': float(opp.get('monetaryValue', 0))
            }
    
    # Calculate metrics
    ghl_metrics = {
        'leads': 0,
        'bookings': 0,
        'deposits': 0,
        'cashCollected': 0,
        'cashAmount': 0
    }
    
    default_deposit_amount = 1500
    
    for opp_id, state in opportunity_latest_state.items():
        ghl_metrics['leads'] += 1
        
        category = state.get('stageCategory', '')
        if category == 'bookedAppointments':
            ghl_metrics['bookings'] += 1
        elif category == 'deposits':
            ghl_metrics['deposits'] += 1
            value = state.get('monetaryValue', 0) or default_deposit_amount
            ghl_metrics['cashAmount'] += value
        elif category == 'cashCollected':
            ghl_metrics['cashCollected'] += 1
            value = state.get('monetaryValue', 0) or default_deposit_amount
            ghl_metrics['cashAmount'] += value
    
    return ghl_metrics, len(matching_opportunities)

def fix_duplicates(duplicates: dict, dry_run: bool = True):
    """
    Fix duplicate ad metrics by recalculating for each ad set
    """
    print()
    print(f'🔧 {"DRY RUN: " if dry_run else ""}Fixing duplicate ad metrics...')
    print()
    
    stats = {
        'processed': 0,
        'updated': 0,
        'unchanged': 0,
        'errors': 0,
        'skipped_no_data': 0
    }
    
    for ad_name, ads in duplicates.items():
        # Skip if NO ads in this group have any GHL data
        has_data = any(ad.get('currentGhlStats', {}).get('leads', 0) > 0 for ad in ads)
        if not has_data:
            stats['skipped_no_data'] += len(ads)
            continue
        print(f'📋 Processing: {ads[0]["adName"]}')
        print(f'   Found in {len(ads)} ad sets:')
        
        for ad in ads:
            stats['processed'] += 1
            
            ad_set = ad['adSetName'] or '(No Ad Set)'
            current_ghl = ad['currentGhlStats']
            current_leads = current_ghl.get('leads', 0) if current_ghl else 0
            
            print(f'\n   • Ad Set: {ad_set}')
            print(f'     Ad ID: {ad["id"]}')
            print(f'     Current: {current_leads} leads')
            
            # Recalculate metrics for this specific ad in this specific ad set
            new_metrics, opp_count = recalculate_metrics_for_ad(
                ad['id'],
                ad['adName'],
                ad['adSetName'],
                ad['campaignName']
            )
            
            print(f'     Recalculated: {new_metrics["leads"]} leads, {new_metrics["bookings"]} bookings, {new_metrics["deposits"]} deposits')
            print(f'     Based on: {opp_count} opportunity records')
            
            # Check if metrics changed
            metrics_changed = (
                current_leads != new_metrics['leads'] or
                current_ghl.get('bookings', 0) != new_metrics['bookings'] or
                current_ghl.get('deposits', 0) != new_metrics['deposits']
            )
            
            if metrics_changed:
                stats['updated'] += 1
                
                if not dry_run:
                    # Update in Firebase
                    update_data = {}
                    
                    if new_metrics['leads'] > 0:
                        update_data['ghlStats'] = {
                            'campaignKey': ad['campaignName'],
                            'leads': new_metrics['leads'],
                            'bookings': new_metrics['bookings'],
                            'deposits': new_metrics['deposits'],
                            'cashCollected': new_metrics['cashCollected'],
                            'cashAmount': new_metrics['cashAmount'],
                            'lastSync': firestore.SERVER_TIMESTAMP
                        }
                        update_data['matchingStatus'] = 'matched'
                    else:
                        update_data['ghlStats'] = firestore.DELETE_FIELD
                        update_data['matchingStatus'] = 'unmatched'
                    
                    update_data['lastUpdated'] = firestore.SERVER_TIMESTAMP
                    
                    try:
                        db.collection('adPerformance').document(ad['id']).update(update_data)
                        print(f'     ✅ Updated in Firebase')
                    except Exception as e:
                        print(f'     ❌ Error updating: {e}')
                        stats['errors'] += 1
                else:
                    print(f'     📝 Would update (dry run)')
            else:
                stats['unchanged'] += 1
                print(f'     ✓ No change needed')
        
        print()
    
    return stats

def main():
    """Main function"""
    print()
    print('=' * 80)
    print('  FIX DUPLICATE AD METRICS')
    print('=' * 80)
    print()
    
    # Check for dry run flag
    dry_run = '--dry-run' in sys.argv or '-d' in sys.argv
    
    if dry_run:
        print('ℹ️  Running in DRY RUN mode (no changes will be made)')
        print('   Remove --dry-run flag to apply changes')
        print()
    else:
        print('⚠️  LIVE MODE: Changes will be applied to Firebase!')
        print()
    
    try:
        # Find duplicate ads
        duplicates = find_duplicate_ads()
        
        if not duplicates:
            print()
            print('✅ No duplicate ads found! All ads are unique within their ad sets.')
            print()
            return
        
        # Fix duplicates
        stats = fix_duplicates(duplicates, dry_run=dry_run)
        
        # Print summary
        print()
        print('=' * 80)
        print('📊 SUMMARY')
        print('=' * 80)
        print(f'   Processed: {stats["processed"]} ads')
        print(f'   Updated: {stats["updated"]} ads')
        print(f'   Unchanged: {stats["unchanged"]} ads')
        print(f'   Skipped (no data): {stats["skipped_no_data"]} ads')
        print(f'   Errors: {stats["errors"]} ads')
        print()
        
        if dry_run:
            print('ℹ️  This was a DRY RUN. Run without --dry-run to apply changes.')
        else:
            print('✅ Changes have been applied to Firebase!')
            print('   Refresh your UI to see the corrected metrics.')
        
        print('=' * 80)
        print()
        
    except Exception as e:
        print()
        print('=' * 80)
        print('❌ ERROR')
        print('=' * 80)
        print(f'   {e}')
        print()
        import traceback
        traceback.print_exc()
        sys.exit(1)

if __name__ == '__main__':
    main()

