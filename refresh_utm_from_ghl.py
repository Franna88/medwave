#!/usr/bin/env python3
"""
Refresh UTM Attribution from GHL
This script fetches ALL opportunities from GHL with their complete UTM data
and updates Firebase opportunityStageHistory with the full attribution.
"""

import requests
import firebase_admin
from firebase_admin import credentials, firestore
from datetime import datetime
from typing import Dict, List
import os
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

# Initialize Firebase
try:
    cred = credentials.Certificate('medx-ai-firebase-adminsdk-fbsvc-a86e7bd050.json')
    firebase_admin.initialize_app(cred)
except ValueError:
    pass

db = firestore.client()

# GHL API Configuration
GHL_API_BASE_URL = "https://services.leadconnectorhq.com"
GHL_API_VERSION = "2021-07-28"
GHL_ACCESS_TOKEN = os.getenv('GHL_API_KEY', 'pit-22f8af95-3244-41e7-9a52-22c87b166f5a')
GHL_LOCATION_ID = "QdLXaFEqrdF0JbVbpKLw"

# Pipeline IDs
ANDRIES_PIPELINE_ID = "XeAGJWRnUGJ5tuhXam2g"  # Andries Pipeline - DDM
DAVIDE_PIPELINE_ID = "AUduOJBB2lxlsEaNmlJz"   # Davide's Pipeline - DDM

PIPELINES = {
    ANDRIES_PIPELINE_ID: "Andries Pipeline - DDM",
    DAVIDE_PIPELINE_ID: "Davide's Pipeline - DDM"
}

def get_ghl_headers():
    return {
        "Authorization": f"Bearer {GHL_ACCESS_TOKEN}",
        "Version": GHL_API_VERSION,
        "Content-Type": "application/json"
    }

def get_contact_attribution(contact_id: str) -> Dict:
    """Fetch contact and extract attribution data"""
    
    url = f"{GHL_API_BASE_URL}/contacts/{contact_id}"
    
    try:
        response = requests.get(url, headers=get_ghl_headers(), timeout=10)
        response.raise_for_status()
        
        contact = response.json().get('contact', {})
        
        # Extract from lastAttributionSource (most complete)
        last_attr = contact.get('lastAttributionSource', {})
        
        if last_attr and last_attr.get('utmCampaign'):
            return {
                'campaignName': last_attr.get('utmCampaign', '') or last_attr.get('campaign', ''),
                'campaignSource': last_attr.get('utmSource', '') or last_attr.get('source', ''),
                'campaignMedium': last_attr.get('utmMedium', ''),
                'adId': last_attr.get('utmAdId', '') or last_attr.get('adId', ''),
                'adName': last_attr.get('utmContent', ''),
                'adSetName': last_attr.get('utmMedium', ''),  # GHL stores ad set name in utmMedium
                'adSetId': last_attr.get('adSetId', ''),
            }
    except Exception as e:
        print(f"     ⚠️  Error fetching contact {contact_id}: {e}")
    
    return None

def extract_full_attribution(opportunity):
    """Extract COMPLETE attribution data from GHL opportunity"""
    
    attribution = {
        'campaignName': '',
        'campaignSource': '',
        'campaignMedium': '',
        'adId': '',
        'adName': '',
        'adSetName': '',
        'adSetId': '',
    }
    
    # Method 1: Check opportunity.attributions array (NEW - most reliable!)
    attributions = opportunity.get('attributions', [])
    if attributions:
        # Get the last attribution (most recent)
        last_attr = None
        for attr in attributions:
            if attr.get('isLast'):
                last_attr = attr
                break
        
        if not last_attr and attributions:
            last_attr = attributions[-1]
        
        if last_attr:
            attribution['campaignName'] = last_attr.get('utmCampaign', '')
            attribution['campaignSource'] = last_attr.get('utmSource', '')
            attribution['campaignMedium'] = last_attr.get('utmMedium', '')
            attribution['adId'] = last_attr.get('utmAdId', '')
            attribution['adName'] = last_attr.get('utmContent', '')
            attribution['adSetName'] = last_attr.get('utmMedium', '')  # GHL stores ad set name in utmMedium
            attribution['adSetId'] = last_attr.get('utmAdSetId', '')
    
    # Method 2: If no attribution in opportunity, fetch from contact
    if not attribution['campaignName']:
        contact_id = opportunity.get('contactId')
        if contact_id:
            contact_attr = get_contact_attribution(contact_id)
            if contact_attr:
                attribution = contact_attr
    
    return attribution

def fetch_opportunities_from_ghl(pipeline_id: str, pipeline_name: str) -> List[Dict]:
    """Fetch all opportunities from GHL with full attribution"""
    
    url = f"{GHL_API_BASE_URL}/opportunities/search"
    
    all_opportunities = []
    next_cursor = None
    
    print(f"📊 Fetching opportunities from {pipeline_name}...")
    
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
    
    print(f"✅ Fetched {len(all_opportunities)} total opportunities from {pipeline_name}\n")
    return all_opportunities

def update_firebase_utm_data(opportunities: List[Dict], dry_run: bool = True):
    """Update Firebase opportunityStageHistory with complete UTM data from GHL"""
    
    print("=" * 100)
    print("🔄 UPDATING UTM ATTRIBUTION IN FIREBASE")
    print("=" * 100)
    print()
    
    if dry_run:
        print("🔍 DRY RUN MODE - No changes will be made")
        print()
    
    stats = {
        'total_opportunities': len(opportunities),
        'with_attribution': 0,
        'firebase_records_found': 0,
        'firebase_records_updated': 0,
        'no_firebase_records': 0,
        'already_correct': 0,
        'errors': 0
    }
    
    for opp in opportunities:
        opp_id = opp.get('id')
        opp_name = opp.get('name', 'Unnamed')
        monetary_value = float(opp.get('monetaryValue', 0))
        
        # Extract full attribution from GHL
        attribution = extract_full_attribution(opp)
        
        if attribution['campaignName']:
            stats['with_attribution'] += 1
            
            # Find all Firebase records for this opportunity
            firebase_query = db.collection('opportunityStageHistory')\
                .where('opportunityId', '==', opp_id)\
                .stream()
            
            firebase_docs = list(firebase_query)
            
            if not firebase_docs:
                stats['no_firebase_records'] += 1
                continue
            
            stats['firebase_records_found'] += len(firebase_docs)
            
            # Check if update is needed
            needs_update = False
            for doc in firebase_docs:
                doc_data = doc.to_dict()
                current_campaign = doc_data.get('campaignName', '').strip()
                
                if current_campaign != attribution['campaignName']:
                    needs_update = True
                    break
            
            if needs_update:
                if monetary_value > 0:
                    print(f"💰 {opp_name} (R {monetary_value:,.2f})")
                else:
                    print(f"📝 {opp_name}")
                
                print(f"   GHL Attribution:")
                print(f"     Campaign: {attribution['campaignName']}")
                print(f"     Source: {attribution['campaignSource']}")
                print(f"     Ad Name: {attribution['adName']}")
                print(f"     Ad Set: {attribution['adSetName']}")
                print(f"   Updating {len(firebase_docs)} Firebase records...")
                
                # Update all Firebase records for this opportunity
                for doc in firebase_docs:
                    if not dry_run:
                        try:
                            doc.reference.update({
                                'campaignName': attribution['campaignName'],
                                'campaignSource': attribution['campaignSource'],
                                'campaignMedium': attribution['campaignMedium'],
                                'adId': attribution['adId'],
                                'adName': attribution['adName'],
                                'adSetName': attribution['adSetName'],
                            })
                            stats['firebase_records_updated'] += 1
                        except Exception as e:
                            print(f"     ❌ Error updating {doc.id}: {e}")
                            stats['errors'] += 1
                    else:
                        stats['firebase_records_updated'] += 1
                
                if not dry_run:
                    print(f"   ✅ Updated {len(firebase_docs)} records")
                else:
                    print(f"   [DRY RUN] Would update {len(firebase_docs)} records")
                print()
            else:
                stats['already_correct'] += 1
    
    print("=" * 100)
    print("📊 UPDATE SUMMARY")
    print("=" * 100)
    print(f"Total GHL opportunities: {stats['total_opportunities']}")
    print(f"With attribution in GHL: {stats['with_attribution']}")
    print(f"Firebase records found: {stats['firebase_records_found']}")
    print(f"Firebase records updated: {stats['firebase_records_updated']}")
    print(f"Already correct: {stats['already_correct']}")
    print(f"No Firebase records: {stats['no_firebase_records']}")
    print(f"Errors: {stats['errors']}")
    print()
    
    return stats

def main():
    import sys
    
    dry_run = '--execute' not in sys.argv
    
    print("\n" + "=" * 100)
    print("🚀 REFRESH UTM ATTRIBUTION FROM GHL")
    print("=" * 100)
    print(f"\nPipelines: Andries & Davide")
    print(f"Execution Time: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    
    if dry_run:
        print("\n⚠️  DRY RUN MODE - Use --execute flag to apply changes")
    else:
        print("\n✅ EXECUTE MODE - Changes will be applied to Firebase")
    
    print()
    
    # Step 1: Fetch ALL opportunities from both pipelines
    all_opportunities = []
    for pipeline_id, pipeline_name in PIPELINES.items():
        print(f"{'='*80}")
        print(f"Processing: {pipeline_name}")
        print(f"{'='*80}\n")
        
        opportunities = fetch_opportunities_from_ghl(pipeline_id, pipeline_name)
        
        if opportunities:
            all_opportunities.extend(opportunities)
        else:
            print(f"⚠️  No opportunities found for {pipeline_name}")
    
    if not all_opportunities:
        print("\n⚠️  No opportunities found in any pipeline")
        return
    
    print(f"\n{'='*80}")
    print(f"📊 Total opportunities fetched from GHL: {len(all_opportunities)}")
    print(f"{'='*80}\n")
    
    # Step 2: Update Firebase with complete UTM data
    update_stats = update_firebase_utm_data(all_opportunities, dry_run=dry_run)
    
    # Final summary
    print("\n" + "=" * 100)
    print("🎉 UTM REFRESH COMPLETE")
    print("=" * 100)
    print()
    
    if dry_run:
        print("This was a DRY RUN. To apply changes, run:")
        print("  python3 refresh_utm_from_ghl.py --execute")
        print()
        print("After running with --execute, you should also run:")
        print("  python3 update_opportunity_values.py --execute")
        print("  to re-aggregate the data into adPerformance collection")
    else:
        print("✅ UTM attribution has been refreshed from GHL!")
        print()
        print("IMPORTANT: Now run the re-aggregation script:")
        print("  python3 update_opportunity_values.py --execute")
        print()
        print("This will update the adPerformance collection with the correct monetary values")
        print("matched to the proper campaigns using the refreshed UTM data.")
    
    print()


if __name__ == "__main__":
    main()

