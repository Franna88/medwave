#!/usr/bin/env python3
"""
Assign Ad IDs to GHL opportunities that don't have h_ad_id

Strategy:
1. Find opportunities WITHOUT h_ad_id
2. Match by Campaign ID + Ad Name to find ONE specific ad
3. Store the "assigned Ad ID" in Firebase (ghlOpportunityMapping)
4. This creates a 1:1 mapping (opportunity -> single ad)
"""

import firebase_admin
from firebase_admin import credentials, firestore
import requests
import os
from collections import defaultdict
from datetime import datetime
import json

print("🔧 Assigning Ad IDs to Opportunities...", flush=True)
print("📦 Initializing Firebase...", flush=True)

# Initialize Firebase
if not firebase_admin._apps:
    cred = credentials.Certificate('medx-ai-firebase-adminsdk-fbsvc-a86e7bd050.json')
    firebase_admin.initialize_app(cred)

db = firestore.client()
print("✅ Firebase initialized", flush=True)

# GHL Configuration
GHL_API_KEY = os.environ.get('GHL_API_KEY', 'pit-22f8af95-3244-41e7-9a52-22c87b166f5a')
GHL_LOCATION_ID = 'QdLXaFEqrdF0JbVbpKLw'
ANDRIES_PIPELINE_ID = 'XeAGJWRnUGJ5tuhXam2g'
DAVIDE_PIPELINE_ID = 'AUduOJBB2lxlsEaNmlJz'

def fetch_opportunities_from_ghl():
    """Fetch all opportunities from GHL API"""
    print("\n📊 Fetching opportunities from GHL API...")
    
    url = 'https://services.leadconnectorhq.com/opportunities/search'
    headers = {
        'Authorization': f'Bearer {GHL_API_KEY}',
        'Version': '2021-07-28'
    }
    
    all_opportunities = []
    page = 1
    
    while True:
        params = {
            'location_id': GHL_LOCATION_ID,
            'limit': 100,
            'page': page
        }
        
        try:
            response = requests.get(url, headers=headers, params=params)
            response.raise_for_status()
            data = response.json()
            
            opportunities = data.get('opportunities', [])
            if not opportunities:
                break
            
            all_opportunities.extend(opportunities)
            print(f"   Page {page}: {len(opportunities)} opportunities (Total: {len(all_opportunities)})", flush=True)
            
            if len(opportunities) < 100:
                break
            
            page += 1
            
        except Exception as e:
            print(f"   ⚠️  Error fetching page {page}: {e}")
            break
    
    # Filter to Andries & Davide pipelines
    filtered = [
        opp for opp in all_opportunities 
        if opp.get('pipelineId') in [ANDRIES_PIPELINE_ID, DAVIDE_PIPELINE_ID]
    ]
    
    print(f"   ✅ Total opportunities: {len(all_opportunities)}")
    print(f"   ✅ Andries & Davide: {len(filtered)}")
    
    return filtered

def load_ads_from_firebase():
    """Load all ads from Firebase and build lookup by campaign + ad name"""
    print("\n📊 Loading ads from Firebase...")
    
    ad_map = {}  # ad_id -> ad_data
    campaign_and_name_to_ad = {}  # (campaign_id, ad_name_lower) -> ad_id
    campaign_to_ads = defaultdict(list)  # campaign_id -> [ad_ids]
    
    months = list(db.collection('advertData').stream())
    
    for month_doc in months:
        month_id = month_doc.id
        month_data = month_doc.to_dict()
        
        # Skip old structure documents
        if 'adId' in month_data:
            continue
        
        # Get all ads in this month
        ads = list(month_doc.reference.collection('ads').stream())
        for ad in ads:
            ad_data = ad.to_dict()
            ad_id = ad.id
            campaign_id = ad_data.get('campaignId', '')
            ad_name = ad_data.get('adName', '').strip()
            
            ad_map[ad_id] = {
                'month': month_id,
                'ref': ad.reference,
                'campaign_id': campaign_id,
                'campaign_name': ad_data.get('campaignName', ''),
                'ad_name': ad_name,
                'adset_name': ad_data.get('adSetName', '')
            }
            
            # Build lookup by (campaign_id, ad_name)
            # This gives us ONE specific ad per campaign+name combination
            if campaign_id and ad_name:
                key = (campaign_id, ad_name.lower())
                # If multiple ads have same campaign+name, take the first one
                # (This handles duplicates within same campaign)
                if key not in campaign_and_name_to_ad:
                    campaign_and_name_to_ad[key] = ad_id
            
            if campaign_id:
                campaign_to_ads[campaign_id].append(ad_id)
    
    print(f'   ✅ Found {len(ad_map)} ads')
    print(f'   ✅ Found {len(campaign_and_name_to_ad)} unique (campaign + ad name) combinations')
    print(f'   ✅ Found {len(campaign_to_ads)} unique campaigns')
    
    return ad_map, campaign_and_name_to_ad, campaign_to_ads

def extract_h_ad_id_from_attributions(opportunity):
    """Extract h_ad_id from opportunity attributions"""
    attributions = opportunity.get('attributions', [])
    
    for attr in reversed(attributions):
        ad_id = attr.get('h_ad_id') or attr.get('utmAdId') or attr.get('adId')
        if ad_id:
            return ad_id.strip()
    
    return None

def extract_utm_data(opportunity):
    """Extract all UTM data from opportunity"""
    attributions = opportunity.get('attributions', [])
    
    utm_data = {
        'h_ad_id': None,
        'utmCampaignId': None,
        'utmCampaign': None,
        'utmMedium': None
    }
    
    for attr in reversed(attributions):
        if not utm_data['h_ad_id']:
            utm_data['h_ad_id'] = attr.get('h_ad_id') or attr.get('utmAdId') or attr.get('adId')
        if not utm_data['utmCampaignId']:
            utm_data['utmCampaignId'] = attr.get('utmCampaignId', '').strip()
        if not utm_data['utmCampaign']:
            utm_data['utmCampaign'] = attr.get('utmCampaign', '').strip()
        if not utm_data['utmMedium']:
            utm_data['utmMedium'] = attr.get('utmMedium', '').strip()
    
    return utm_data

def assign_ad_ids():
    """Main function to assign Ad IDs to opportunities"""
    
    print("\n" + "="*80)
    print("ASSIGNING AD IDS TO OPPORTUNITIES")
    print("="*80)
    
    # Step 1: Load ads from Firebase
    ad_map, campaign_and_name_to_ad, campaign_to_ads = load_ads_from_firebase()
    
    # Step 2: Fetch opportunities from GHL
    opportunities = fetch_opportunities_from_ghl()
    
    # Step 3: Categorize and assign
    print("\n📊 Processing opportunities...")
    
    stats = {
        'already_has_ad_id': 0,
        'assigned_by_campaign_and_name': 0,
        'assigned_by_campaign_only': 0,
        'could_not_assign': 0
    }
    
    assignments = []
    unassigned = []
    
    for opp in opportunities:
        opp_id = opp['id']
        utm_data = extract_utm_data(opp)
        
        # Check if already has Ad ID
        if utm_data['h_ad_id']:
            stats['already_has_ad_id'] += 1
            assignments.append({
                'opportunity_id': opp_id,
                'assigned_ad_id': utm_data['h_ad_id'],
                'assignment_method': 'original_h_ad_id',
                'campaign_id': utm_data['utmCampaignId'],
                'ad_name': utm_data['utmCampaign'],
                'stage': opp.get('pipelineStageName'),
                'monetary_value': opp.get('monetaryValue', 0),
                'created_at': opp.get('createdAt'),
                'assigned_at': datetime.now().isoformat()
            })
            continue
        
        # Try to assign by Campaign ID + Ad Name (MOST SPECIFIC)
        if utm_data['utmCampaignId'] and utm_data['utmCampaign']:
            key = (utm_data['utmCampaignId'], utm_data['utmCampaign'].lower())
            
            if key in campaign_and_name_to_ad:
                assigned_ad_id = campaign_and_name_to_ad[key]
                stats['assigned_by_campaign_and_name'] += 1
                
                ad_info = ad_map[assigned_ad_id]
                
                assignments.append({
                    'opportunity_id': opp_id,
                    'assigned_ad_id': assigned_ad_id,
                    'assignment_method': 'campaign_id_and_ad_name',
                    'campaign_id': utm_data['utmCampaignId'],
                    'campaign_name': ad_info['campaign_name'],
                    'ad_name': utm_data['utmCampaign'],
                    'stage': opp.get('pipelineStageName'),
                    'monetary_value': opp.get('monetaryValue', 0),
                    'created_at': opp.get('createdAt'),
                    'assigned_at': datetime.now().isoformat()
                })
                continue
        
        # Try to assign by Campaign ID only (pick first ad in campaign)
        if utm_data['utmCampaignId'] and utm_data['utmCampaignId'] in campaign_to_ads:
            # Pick the first ad in this campaign
            assigned_ad_id = campaign_to_ads[utm_data['utmCampaignId']][0]
            stats['assigned_by_campaign_only'] += 1
            
            ad_info = ad_map[assigned_ad_id]
            
            assignments.append({
                'opportunity_id': opp_id,
                'assigned_ad_id': assigned_ad_id,
                'assignment_method': 'campaign_id_only',
                'campaign_id': utm_data['utmCampaignId'],
                'campaign_name': ad_info['campaign_name'],
                'ad_name': ad_info['ad_name'],
                'stage': opp.get('pipelineStageName'),
                'monetary_value': opp.get('monetaryValue', 0),
                'created_at': opp.get('createdAt'),
                'assigned_at': datetime.now().isoformat(),
                'note': 'Assigned to first ad in campaign (no ad name match)'
            })
            continue
        
        # Could not assign
        stats['could_not_assign'] += 1
        unassigned.append({
            'opportunity_id': opp_id,
            'utm_campaign_id': utm_data['utmCampaignId'],
            'utm_campaign': utm_data['utmCampaign'],
            'utm_medium': utm_data['utmMedium'],
            'stage': opp.get('pipelineStageName'),
            'monetary_value': opp.get('monetaryValue', 0),
            'created_at': opp.get('createdAt')
        })
    
    print(f"\n   ✅ Processed {len(opportunities)} opportunities")
    print(f"      - Already has Ad ID: {stats['already_has_ad_id']}")
    print(f"      - Assigned by Campaign + Name: {stats['assigned_by_campaign_and_name']}")
    print(f"      - Assigned by Campaign only: {stats['assigned_by_campaign_only']}")
    print(f"      - Could not assign: {stats['could_not_assign']}")
    
    # Step 4: Store assignments in Firebase
    print("\n📊 Storing assignments in Firebase...")
    
    mapping_ref = db.collection('ghlOpportunityMapping')
    
    batch = db.batch()
    batch_count = 0
    total_written = 0
    
    for assignment in assignments:
        doc_ref = mapping_ref.document(assignment['opportunity_id'])
        batch.set(doc_ref, assignment, merge=True)
        batch_count += 1
        
        if batch_count >= 500:
            batch.commit()
            total_written += batch_count
            print(f"   ✅ Written {total_written} assignments...", flush=True)
            batch = db.batch()
            batch_count = 0
    
    if batch_count > 0:
        batch.commit()
        total_written += batch_count
    
    print(f"   ✅ Total assignments written: {total_written}")
    
    # Step 5: Save reports
    print("\n📄 Saving reports...")
    
    # Save assignments report
    assignments_file = f"opportunity_assignments_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
    with open(assignments_file, 'w') as f:
        json.dump({
            'timestamp': datetime.now().isoformat(),
            'statistics': stats,
            'assignments': assignments
        }, f, indent=2, default=str)
    print(f"   ✅ Assignments saved to: {assignments_file}")
    
    # Save unassigned report
    if unassigned:
        unassigned_file = f"unassigned_opportunities_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
        with open(unassigned_file, 'w') as f:
            json.dump({
                'timestamp': datetime.now().isoformat(),
                'count': len(unassigned),
                'opportunities': unassigned
            }, f, indent=2, default=str)
        print(f"   ✅ Unassigned saved to: {unassigned_file}")
    
    # Step 6: Summary
    print("\n" + "="*80)
    print("ASSIGNMENT SUMMARY")
    print("="*80)
    
    print(f"\n📊 Total Opportunities: {len(opportunities)}")
    print(f"   ✅ Successfully Assigned: {len(assignments)} ({len(assignments)/len(opportunities)*100:.1f}%)")
    print(f"   ❌ Unassigned: {len(unassigned)} ({len(unassigned)/len(opportunities)*100:.1f}%)")
    
    print(f"\n📊 Assignment Methods:")
    print(f"   Original h_ad_id: {stats['already_has_ad_id']} ({stats['already_has_ad_id']/len(assignments)*100:.1f}%)")
    print(f"   Campaign + Name: {stats['assigned_by_campaign_and_name']} ({stats['assigned_by_campaign_and_name']/len(assignments)*100:.1f}%)")
    print(f"   Campaign only: {stats['assigned_by_campaign_only']} ({stats['assigned_by_campaign_only']/len(assignments)*100:.1f}%)")
    
    print(f"\n✅ Mapping stored in Firebase: ghlOpportunityMapping")
    print(f"   Each opportunity now has ONE assigned Ad ID")
    print(f"   No more cross-campaign duplicates!")
    print()

if __name__ == '__main__':
    assign_ad_ids()

