#!/usr/bin/env python3
"""
Backfill Attribution for Opportunities with Monetary Values
This script finds opportunities that have monetary values but missing campaign attribution,
and attempts to match them to campaigns based on contact info and timing.
"""

import firebase_admin
from firebase_admin import credentials, firestore
from datetime import datetime, timedelta
from collections import defaultdict

# Initialize Firebase
try:
    cred = credentials.Certificate('medx-ai-firebase-adminsdk-fbsvc-a86e7bd050.json')
    firebase_admin.initialize_app(cred)
except ValueError:
    pass

db = firestore.client()

def get_opportunities_with_values_no_attribution():
    """Get opportunities that have monetary values but no campaign attribution"""
    
    print("🔍 Finding opportunities with values but no attribution...")
    
    # Get all opportunities with deposits or cash collected
    opp_query = db.collection('opportunityStageHistory')\
        .where('stageCategory', 'in', ['deposits', 'cashCollected'])\
        .stream()
    
    opportunities_by_contact = defaultdict(list)
    
    for opp_doc in opp_query:
        opp_data = opp_doc.to_dict()
        monetary_value = opp_data.get('monetaryValue', 0)
        campaign_name = opp_data.get('campaignName', '').strip()
        
        # If has value but no campaign attribution
        if monetary_value > 0 and not campaign_name:
            contact_id = opp_data.get('contactId', '')
            opp_id = opp_data.get('opportunityId', '')
            
            opportunities_by_contact[contact_id].append({
                'doc_id': opp_doc.id,
                'opp_id': opp_id,
                'opp_name': opp_data.get('opportunityName', ''),
                'monetary_value': monetary_value,
                'timestamp': opp_data.get('timestamp'),
                'stage': opp_data.get('newStageName', ''),
                'contact_id': contact_id
            })
    
    print(f"✅ Found {sum(len(opps) for opps in opportunities_by_contact.values())} opportunities with values but no attribution")
    print(f"   Across {len(opportunities_by_contact)} unique contacts")
    print()
    
    return opportunities_by_contact

def find_attribution_for_contact(contact_id, opp_timestamp):
    """Find attribution data for a contact by looking at their earlier opportunity records"""
    
    # Get all opportunity history for this contact (without ordering to avoid index requirement)
    contact_history = db.collection('opportunityStageHistory')\
        .where('contactId', '==', contact_id)\
        .stream()
    
    # Collect all records and sort in memory
    all_records = []
    for history_doc in contact_history:
        history_data = history_doc.to_dict()
        campaign_name = history_data.get('campaignName', '').strip()
        
        if campaign_name:
            timestamp = history_data.get('timestamp')
            all_records.append({
                'timestamp': timestamp,
                'campaignName': campaign_name,
                'campaignSource': history_data.get('campaignSource', ''),
                'campaignMedium': history_data.get('campaignMedium', ''),
                'adId': history_data.get('adId', ''),
                'adName': history_data.get('adName', ''),
                'adSetName': history_data.get('adSetName', ''),
            })
    
    # Return the earliest record with attribution
    if all_records:
        all_records.sort(key=lambda x: x['timestamp'] if x['timestamp'] else datetime.now())
        return all_records[0]
    
    return None

def backfill_attribution(opportunities_by_contact, dry_run=True):
    """Backfill attribution data for opportunities"""
    
    print("=" * 100)
    print("🔄 BACKFILLING ATTRIBUTION DATA")
    print("=" * 100)
    print()
    
    if dry_run:
        print("🔍 DRY RUN MODE - No changes will be made")
        print()
    
    stats = {
        'total_opportunities': 0,
        'found_attribution': 0,
        'updated': 0,
        'no_attribution_found': 0,
        'errors': 0
    }
    
    for contact_id, opportunities in opportunities_by_contact.items():
        stats['total_opportunities'] += len(opportunities)
        
        # Get the earliest opportunity for this contact to find attribution
        earliest_opp = min(opportunities, key=lambda x: x['timestamp'] if x['timestamp'] else datetime.now())
        
        print(f"Contact: {earliest_opp['opp_name']}")
        print(f"  Opportunities with values: {len(opportunities)}")
        
        # Find attribution from earlier records
        attribution = find_attribution_for_contact(contact_id, earliest_opp['timestamp'])
        
        if attribution:
            stats['found_attribution'] += len(opportunities)
            
            print(f"  ✅ Found attribution:")
            print(f"     Campaign: {attribution['campaignName']}")
            print(f"     Ad Name: {attribution['adName']}")
            print(f"     Ad Set: {attribution['adSetName']}")
            print()
            
            # Update all opportunities for this contact
            for opp in opportunities:
                print(f"  Updating: {opp['opp_name']} (R {opp['monetary_value']:,.2f})")
                
                if not dry_run:
                    try:
                        # Update the document
                        db.collection('opportunityStageHistory').document(opp['doc_id']).update({
                            'campaignName': attribution['campaignName'],
                            'campaignSource': attribution['campaignSource'],
                            'campaignMedium': attribution['campaignMedium'],
                            'adId': attribution['adId'],
                            'adName': attribution['adName'],
                            'adSetName': attribution['adSetName'],
                        })
                        stats['updated'] += 1
                        print(f"    ✅ Updated")
                    except Exception as e:
                        print(f"    ❌ Error: {e}")
                        stats['errors'] += 1
                else:
                    print(f"    [DRY RUN] Would update with campaign: {attribution['campaignName']}")
                    stats['updated'] += 1
            
            print()
        else:
            stats['no_attribution_found'] += len(opportunities)
            print(f"  ⚠️  No attribution found for this contact")
            print(f"     Total value: R {sum(o['monetary_value'] for o in opportunities):,.2f}")
            print()
    
    print("=" * 100)
    print("📊 BACKFILL SUMMARY")
    print("=" * 100)
    print(f"Total opportunities processed: {stats['total_opportunities']}")
    print(f"Found attribution for: {stats['found_attribution']}")
    print(f"Updated: {stats['updated']}")
    print(f"No attribution found: {stats['no_attribution_found']}")
    print(f"Errors: {stats['errors']}")
    print()
    
    return stats

def re_aggregate_after_backfill(dry_run=True):
    """Re-run the aggregation to update adPerformance with new attribution"""
    
    print("=" * 100)
    print("🔄 RE-AGGREGATING AD PERFORMANCE DATA")
    print("=" * 100)
    print()
    
    if dry_run:
        print("🔍 DRY RUN MODE - Skipping re-aggregation")
        return
    
    print("This will trigger the Cloud Function to re-aggregate GHL data...")
    print("You should run: python3 update_opportunity_values.py --execute")
    print("Or trigger the Cloud Function manually")
    print()

def main():
    import sys
    
    dry_run = '--execute' not in sys.argv
    
    print("\n" + "=" * 100)
    print("🚀 BACKFILL OPPORTUNITY ATTRIBUTION")
    print("=" * 100)
    print(f"\nExecution Time: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    
    if dry_run:
        print("\n⚠️  DRY RUN MODE - Use --execute flag to apply changes")
    else:
        print("\n✅ EXECUTE MODE - Changes will be applied to Firebase")
    
    print()
    
    # Step 1: Find opportunities with values but no attribution
    opportunities_by_contact = get_opportunities_with_values_no_attribution()
    
    if not opportunities_by_contact:
        print("✅ All opportunities with monetary values already have attribution!")
        return
    
    # Step 2: Backfill attribution
    stats = backfill_attribution(opportunities_by_contact, dry_run=dry_run)
    
    # Step 3: Re-aggregate
    if not dry_run and stats['updated'] > 0:
        print()
        re_aggregate_after_backfill(dry_run=False)
    
    # Final summary
    print("\n" + "=" * 100)
    print("🎉 BACKFILL COMPLETE")
    print("=" * 100)
    print()
    
    if dry_run:
        print("This was a DRY RUN. To apply changes, run:")
        print("  python3 backfill_opportunity_attribution.py --execute")
        print()
        print("After running with --execute, you should also run:")
        print("  python3 update_opportunity_values.py --execute")
        print("  to re-aggregate the data into adPerformance collection")
    else:
        print("✅ Attribution has been backfilled!")
        print()
        print("IMPORTANT: Now run the re-aggregation script:")
        print("  python3 update_opportunity_values.py --execute")
        print()
        print("This will update the adPerformance collection with the correct monetary values.")
    
    print()


if __name__ == "__main__":
    main()

