#!/usr/bin/env python3
"""
Update Opportunity Monetary Values in Firebase
This script fetches the latest monetary values from GHL API and updates
the corresponding records in Firebase opportunityStageHistory collection.
Then triggers re-aggregation into adPerformance collection.
"""

import requests
import json
from datetime import datetime
from typing import Dict, List, Optional
import os
import firebase_admin
from firebase_admin import credentials, firestore
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

# Initialize Firebase
try:
    cred = credentials.Certificate('medx-ai-firebase-adminsdk-fbsvc-a86e7bd050.json')
    firebase_admin.initialize_app(cred)
except ValueError:
    # Already initialized
    pass

db = firestore.client()

# GHL API Configuration
GHL_API_BASE_URL = "https://services.leadconnectorhq.com"
GHL_API_VERSION = "2021-07-28"
GHL_ACCESS_TOKEN = os.getenv('GHL_API_KEY', 'pit-e305020a-9a42-4290-a052-daf828c3978e')
GHL_LOCATION_ID = "QdLXaFEqrdF0JbVbpKLw"
DAVIDE_PIPELINE_ID = "AUduOJBB2lxlsEaNmlJz"

def get_ghl_headers():
    return {
        "Authorization": f"Bearer {GHL_ACCESS_TOKEN}",
        "Version": GHL_API_VERSION,
        "Content-Type": "application/json"
    }

def fetch_opportunities_from_ghl(pipeline_id: str) -> List[Dict]:
    """Fetch all opportunities from GHL"""
    url = f"{GHL_API_BASE_URL}/opportunities/search"
    
    all_opportunities = []
    next_cursor = None
    
    print(f"📊 Fetching opportunities from GHL API...")
    
    while True:
        params = {
            "location_id": GHL_LOCATION_ID,
            "pipeline_id": pipeline_id,
            "limit": 100
        }
        
        if next_cursor:
            params['startAfterId'] = next_cursor
            params['startAfter'] = next_cursor
        
        try:
            response = requests.get(url, headers=get_ghl_headers(), params=params, timeout=30)
            response.raise_for_status()
            
            data = response.json()
            opportunities = data.get('opportunities', [])
            
            if not opportunities:
                break
            
            all_opportunities.extend(opportunities)
            print(f"   Fetched {len(opportunities)} opportunities (total: {len(all_opportunities)})")
            
            # Check for next cursor
            meta = data.get('meta', {})
            next_cursor = meta.get('nextStartAfterId') or meta.get('nextStartAfter')
            
            if not next_cursor or len(opportunities) < 100:
                break
                
        except Exception as e:
            print(f"❌ Error fetching opportunities: {e}")
            break
    
    print(f"✅ Fetched {len(all_opportunities)} total opportunities\n")
    return all_opportunities

def update_firebase_opportunity_values(opportunities: List[Dict], dry_run: bool = True):
    """Update monetary values in Firebase opportunityStageHistory"""
    
    print("=" * 100)
    print("🔄 UPDATING OPPORTUNITY VALUES IN FIREBASE")
    print("=" * 100)
    print()
    
    if dry_run:
        print("🔍 DRY RUN MODE - No changes will be made")
        print()
    
    stats = {
        'checked': 0,
        'updated': 0,
        'no_change': 0,
        'not_found': 0,
        'errors': 0
    }
    
    # Only update opportunities with monetary value > 0
    opps_with_value = [opp for opp in opportunities if float(opp.get('monetaryValue', 0)) > 0]
    
    print(f"Found {len(opps_with_value)} opportunities with monetary value > 0")
    print()
    
    for opp in opps_with_value:
        opp_id = opp.get('id')
        opp_name = opp.get('name', 'Unnamed')
        monetary_value = float(opp.get('monetaryValue', 0))
        stage_name = opp.get('pipelineStageName', 'Unknown')
        
        stats['checked'] += 1
        
        print(f"Processing: {opp_name} (R {monetary_value:,.2f})")
        
        try:
            # Find all records for this opportunity in Firebase
            firebase_query = db.collection('opportunityStageHistory')\
                .where('opportunityId', '==', opp_id)\
                .stream()
            
            firebase_docs = list(firebase_query)
            
            if not firebase_docs:
                print(f"   ⚠️  Not found in Firebase")
                stats['not_found'] += 1
                continue
            
            print(f"   Found {len(firebase_docs)} records in Firebase")
            
            # Update each record
            updated_count = 0
            for doc in firebase_docs:
                doc_data = doc.to_dict()
                current_value = doc_data.get('monetaryValue', 0)
                
                if current_value != monetary_value:
                    print(f"   Updating: {doc.id}")
                    print(f"     Old value: R {current_value:,.2f}")
                    print(f"     New value: R {monetary_value:,.2f}")
                    
                    if not dry_run:
                        # Update the document
                        doc.reference.update({
                            'monetaryValue': monetary_value,
                            'lastUpdated': firestore.SERVER_TIMESTAMP
                        })
                        updated_count += 1
                    else:
                        print(f"     [DRY RUN] Would update")
                        updated_count += 1
                else:
                    print(f"   ✓ Already correct: R {current_value:,.2f}")
            
            if updated_count > 0:
                stats['updated'] += updated_count
            else:
                stats['no_change'] += 1
            
            print()
            
        except Exception as e:
            print(f"   ❌ Error: {e}")
            stats['errors'] += 1
            print()
    
    print("=" * 100)
    print("📊 UPDATE SUMMARY")
    print("=" * 100)
    print(f"Opportunities checked: {stats['checked']}")
    print(f"Records updated: {stats['updated']}")
    print(f"Already correct: {stats['no_change']}")
    print(f"Not found in Firebase: {stats['not_found']}")
    print(f"Errors: {stats['errors']}")
    print()
    
    return stats

def re_aggregate_to_ad_performance(dry_run: bool = True):
    """
    Re-aggregate GHL data from opportunityStageHistory into adPerformance collection
    This matches the logic from opportunityHistoryService.js
    """
    
    print("=" * 100)
    print("🔄 RE-AGGREGATING GHL DATA TO AD PERFORMANCE")
    print("=" * 100)
    print()
    
    if dry_run:
        print("🔍 DRY RUN MODE - No changes will be made")
        print()
    
    # Get all Facebook ads
    ads_ref = db.collection('adPerformance')
    all_ads = list(ads_ref.stream())
    
    print(f"Found {len(all_ads)} Facebook ads to process")
    print()
    
    stats = {
        'processed': 0,
        'updated': 0,
        'no_matches': 0,
        'errors': 0
    }
    
    for ad_doc in all_ads:
        try:
            ad_data = ad_doc.to_dict()
            ad_id = ad_doc.id
            ad_name = ad_data.get('adName', '')
            campaign_name = ad_data.get('campaignName', '')
            ad_set_name = ad_data.get('adSetName', '')
            
            stats['processed'] += 1
            
            if not campaign_name:
                continue
            
            # Query opportunities that match this campaign
            history_query = db.collection('opportunityStageHistory')\
                .where('campaignName', '==', campaign_name)\
                .stream()
            
            # Filter opportunities using composite matching
            matching_opportunities = []
            
            for opp_doc in history_query:
                opp_data = opp_doc.to_dict()
                opp_ad_name = (opp_data.get('adName') or '').lower().strip()
                opp_ad_set_name = (opp_data.get('adSetName') or '').lower().strip()
                normalized_ad_name = ad_name.lower().strip()
                normalized_ad_set_name = ad_set_name.lower().strip()
                
                # Priority 1: Match by Facebook Ad ID if available
                if opp_data.get('facebookAdId') and opp_data['facebookAdId'] == ad_id:
                    matching_opportunities.append(opp_data)
                    continue
                
                # Priority 2: Match by Campaign + Ad Set + Ad Name
                if opp_ad_name == normalized_ad_name:
                    # If we have ad set info from both sides, require it to match
                    if normalized_ad_set_name and opp_ad_set_name:
                        if opp_ad_set_name == normalized_ad_set_name:
                            matching_opportunities.append(opp_data)
                    else:
                        # Fallback: match by ad name only
                        matching_opportunities.append(opp_data)
            
            if not matching_opportunities:
                stats['no_matches'] += 1
                continue
            
            # Aggregate GHL metrics from matching opportunities
            # Track unique opportunities and their latest state
            opportunity_latest_state = {}
            
            for opp in matching_opportunities:
                opp_id = opp.get('opportunityId')
                opp_timestamp = opp.get('timestamp')
                
                if isinstance(opp_timestamp, datetime):
                    timestamp = opp_timestamp
                else:
                    timestamp = opp_timestamp.replace(tzinfo=None) if hasattr(opp_timestamp, 'replace') else datetime.now()
                
                if opp_id not in opportunity_latest_state or timestamp > opportunity_latest_state[opp_id]['timestamp']:
                    opportunity_latest_state[opp_id] = {
                        'stageCategory': opp.get('stageCategory', 'other'),
                        'stageName': opp.get('newStageName', ''),
                        'timestamp': timestamp,
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
            
            for opp_id, state in opportunity_latest_state.items():
                ghl_metrics['leads'] += 1
                
                if state['stageCategory'] == 'bookedAppointments':
                    ghl_metrics['bookings'] += 1
                
                if state['stageCategory'] == 'deposits':
                    ghl_metrics['deposits'] += 1
                    deposit_value = state['monetaryValue'] if state['monetaryValue'] > 0 else 1500
                    ghl_metrics['cashAmount'] += deposit_value
                
                if state['stageCategory'] == 'cashCollected':
                    ghl_metrics['cashCollected'] += 1
                    cash_value = state['monetaryValue'] if state['monetaryValue'] > 0 else 1500
                    ghl_metrics['cashAmount'] += cash_value
            
            # Only update if there's actual GHL data
            if ghl_metrics['leads'] > 0:
                if not dry_run:
                    ad_doc.reference.update({
                        'ghlStats': ghl_metrics,
                        'matchingStatus': 'matched',
                        'lastUpdated': firestore.SERVER_TIMESTAMP
                    })
                
                stats['updated'] += 1
                
                # Show significant updates
                if ghl_metrics['cashAmount'] > 0:
                    print(f"✅ Updated: {ad_name[:50]}...")
                    print(f"   Campaign: {campaign_name[:60]}...")
                    print(f"   Leads: {ghl_metrics['leads']} | Bookings: {ghl_metrics['bookings']}")
                    print(f"   Deposits: {ghl_metrics['deposits']} | Cash: {ghl_metrics['cashCollected']}")
                    print(f"   💰 Cash Amount: R {ghl_metrics['cashAmount']:,.2f}")
                    print()
        
        except Exception as e:
            print(f"❌ Error processing ad {ad_id}: {e}")
            stats['errors'] += 1
    
    print("=" * 100)
    print("📊 RE-AGGREGATION SUMMARY")
    print("=" * 100)
    print(f"Ads processed: {stats['processed']}")
    print(f"Ads updated with GHL data: {stats['updated']}")
    print(f"Ads with no matches: {stats['no_matches']}")
    print(f"Errors: {stats['errors']}")
    print()
    
    return stats

def main():
    import sys
    
    dry_run = '--execute' not in sys.argv
    
    print("\n" + "=" * 100)
    print("🚀 UPDATE OPPORTUNITY VALUES AND RE-AGGREGATE TO AD PERFORMANCE")
    print("=" * 100)
    print(f"\nPipeline ID: {DAVIDE_PIPELINE_ID}")
    print(f"Execution Time: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    
    if dry_run:
        print("\n⚠️  DRY RUN MODE - Use --execute flag to apply changes")
    else:
        print("\n✅ EXECUTE MODE - Changes will be applied to Firebase")
    
    print()
    
    # Step 1: Fetch opportunities from GHL
    opportunities = fetch_opportunities_from_ghl(DAVIDE_PIPELINE_ID)
    
    if not opportunities:
        print("\n⚠️  No opportunities found")
        return
    
    # Step 2: Update Firebase opportunityStageHistory with correct monetary values
    update_stats = update_firebase_opportunity_values(opportunities, dry_run=dry_run)
    
    # Step 3: Re-aggregate GHL data into adPerformance collection
    if update_stats['updated'] > 0 or not dry_run:
        print("\n")
        aggregate_stats = re_aggregate_to_ad_performance(dry_run=dry_run)
    else:
        print("\n⏭️  Skipping re-aggregation since no updates were made")
        aggregate_stats = None
    
    # Final summary
    print("\n" + "=" * 100)
    print("🎉 PROCESS COMPLETE")
    print("=" * 100)
    print()
    
    if dry_run:
        print("This was a DRY RUN. To apply changes, run:")
        print("  python3 update_opportunity_values.py --execute")
    else:
        print("✅ All changes have been applied to Firebase")
        print()
        print("Next steps:")
        print("  1. Check the Overview dashboard to see updated profit calculations")
        print("  2. Verify that Aayesha and Jenny's values are reflected (if matched to ads)")
        print("  3. The adPerformance collection now has updated ghlStats with correct cashAmount")
    
    print()


if __name__ == "__main__":
    main()

