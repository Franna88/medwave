#!/usr/bin/env python3
"""
Verify deposits and cash collected by ad campaign
Compares GHL API data with Firebase to ensure 100% accuracy
"""

import os
import requests
import firebase_admin
from firebase_admin import credentials, firestore
from collections import defaultdict
import json
from datetime import datetime

# Configuration
GHL_API_KEY = os.environ.get('GHL_API_KEY')
GHL_BASE_URL = 'https://services.leadconnectorhq.com'
LOCATION_ID = 'QdLXaFEqrdF0JbVbpKLw'
FIREBASE_CRED_PATH = 'medx-ai-firebase-adminsdk-fbsvc-a86e7bd050.json'

# Pipeline IDs
ANDRIES_PIPELINE_ID = 'XeAGJWRnUGJ5tuhXam2g'  # Andries Pipeline - DDM
DAVIDE_PIPELINE_ID = 'AUduOJBB2lxlsEaNmlJz'   # Davide's Pipeline - DDM

def get_headers():
    """Get GHL API headers"""
    return {
        'Authorization': f'Bearer {GHL_API_KEY}',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Version': '2021-07-28'
    }

def fetch_opportunities_with_pagination(pipeline_id, pipeline_name):
    """Fetch all opportunities for a pipeline"""
    print(f"\n🔍 Fetching opportunities from GHL: {pipeline_name}...")
    
    url = f"{GHL_BASE_URL}/opportunities/search"
    all_opportunities = []
    seen_ids = set()
    page = 1
    last_cursor = None
    
    params = {
        'location_id': LOCATION_ID,
        'pipeline_id': pipeline_id,
        'limit': 100
    }
    
    while True:
        response = requests.get(url, headers=get_headers(), params=params)
        response.raise_for_status()
        
        data = response.json()
        opportunities = data.get('opportunities', [])
        
        # Filter duplicates
        new_opportunities = []
        for opp in opportunities:
            opp_id = opp.get('id')
            if opp_id and opp_id not in seen_ids:
                seen_ids.add(opp_id)
                new_opportunities.append(opp)
        
        all_opportunities.extend(new_opportunities)
        
        print(f"  📦 Page {page}: {len(new_opportunities)} new (total: {len(all_opportunities)})")
        
        if len(new_opportunities) == 0:
            break
        
        meta = data.get('meta', {})
        next_page = meta.get('nextPage')
        
        if not next_page:
            break
        
        start_after_id = meta.get('startAfterId')
        start_after = meta.get('startAfter')
        
        if not start_after_id or (last_cursor and start_after_id == last_cursor):
            break
        
        last_cursor = start_after_id
        params['startAfterId'] = start_after_id
        params['startAfter'] = start_after
        page += 1
        
        if page > 15:
            print(f"  ⚠️  Safety limit reached")
            break
    
    print(f"✅ Fetched {len(all_opportunities)} total opportunities")
    return all_opportunities

def extract_campaign_info(opp):
    """Extract campaign attribution from opportunity"""
    # Check custom fields for UTM parameters
    custom_fields = opp.get('customFields', [])
    
    campaign_name = None
    campaign_source = None
    campaign_medium = None
    
    for field in custom_fields:
        field_key = field.get('key', '').lower()
        field_value = field.get('value', '')
        
        if 'campaign' in field_key and not 'source' in field_key and not 'medium' in field_key:
            campaign_name = field_value
        elif 'source' in field_key or field_key == 'utm_source':
            campaign_source = field_value
        elif 'medium' in field_key or field_key == 'utm_medium':
            campaign_medium = field_value
    
    # Fallback to contact source if no custom fields
    if not campaign_source:
        campaign_source = opp.get('source', '')
    
    return campaign_name, campaign_source, campaign_medium

def analyze_ghl_data():
    """Analyze GHL data grouped by ad campaign"""
    print("=" * 80)
    print("GHL API ANALYSIS - DEPOSITS & CASH BY AD CAMPAIGN")
    print("=" * 80)
    
    # Fetch data from both pipelines
    andries_opps = fetch_opportunities_with_pagination(ANDRIES_PIPELINE_ID, "Andries Pipeline")
    davide_opps = fetch_opportunities_with_pagination(DAVIDE_PIPELINE_ID, "Davide Pipeline")
    
    # Group by campaign
    campaigns = defaultdict(lambda: {
        'deposits': [],
        'cash': [],
        'pipeline': None
    })
    
    # Process Andries
    for opp in andries_opps:
        stage_name = opp.get('pipelineStage', {}).get('name', '').lower()
        
        if 'deposit received' in stage_name or stage_name == 'deposit received':
            campaign_name, campaign_source, campaign_medium = extract_campaign_info(opp)
            
            if campaign_name:
                key = f"{campaign_name}|{campaign_source}|{campaign_medium}"
                campaigns[key]['deposits'].append({
                    'id': opp.get('id'),
                    'name': opp.get('name'),
                    'contact': opp.get('contact', {}).get('name', 'Unknown'),
                    'stage': opp.get('pipelineStage', {}).get('name'),
                    'value': opp.get('monetaryValue', 0)
                })
                campaigns[key]['pipeline'] = 'Andries'
        
        elif 'cash collected' in stage_name or stage_name == 'cash collected':
            campaign_name, campaign_source, campaign_medium = extract_campaign_info(opp)
            
            if campaign_name:
                key = f"{campaign_name}|{campaign_source}|{campaign_medium}"
                campaigns[key]['cash'].append({
                    'id': opp.get('id'),
                    'name': opp.get('name'),
                    'contact': opp.get('contact', {}).get('name', 'Unknown'),
                    'stage': opp.get('pipelineStage', {}).get('name'),
                    'value': opp.get('monetaryValue', 0)
                })
                campaigns[key]['pipeline'] = 'Andries'
    
    # Process Davide
    for opp in davide_opps:
        stage_name = opp.get('pipelineStage', {}).get('name', '').lower()
        
        if 'deposit received' in stage_name or stage_name == 'deposit received':
            campaign_name, campaign_source, campaign_medium = extract_campaign_info(opp)
            
            if campaign_name:
                key = f"{campaign_name}|{campaign_source}|{campaign_medium}"
                campaigns[key]['deposits'].append({
                    'id': opp.get('id'),
                    'name': opp.get('name'),
                    'contact': opp.get('contact', {}).get('name', 'Unknown'),
                    'stage': opp.get('pipelineStage', {}).get('name'),
                    'value': opp.get('monetaryValue', 0)
                })
                campaigns[key]['pipeline'] = 'Davide'
        
        elif 'cash collected' in stage_name or stage_name == 'cash collected':
            campaign_name, campaign_source, campaign_medium = extract_campaign_info(opp)
            
            if campaign_name:
                key = f"{campaign_name}|{campaign_source}|{campaign_medium}"
                campaigns[key]['cash'].append({
                    'id': opp.get('id'),
                    'name': opp.get('name'),
                    'contact': opp.get('contact', {}).get('name', 'Unknown'),
                    'stage': opp.get('pipelineStage', {}).get('name'),
                    'value': opp.get('monetaryValue', 0)
                })
                campaigns[key]['pipeline'] = 'Davide'
    
    return campaigns

def analyze_firebase_data():
    """Analyze Firebase data grouped by ad campaign"""
    print("\n" + "=" * 80)
    print("FIREBASE ANALYSIS - DEPOSITS & CASH BY AD CAMPAIGN")
    print("=" * 80)
    
    # Initialize Firebase
    if not firebase_admin._apps:
        cred = credentials.Certificate(FIREBASE_CRED_PATH)
        firebase_admin.initialize_app(cred)
    
    db = firestore.client()
    
    campaigns = defaultdict(lambda: {
        'deposits': set(),
        'cash': set(),
        'pipeline': None
    })
    
    # Query opportunityStageHistory
    print("\n🔍 Querying opportunityStageHistory...")
    docs = db.collection('opportunityStageHistory').stream()
    
    for doc in docs:
        data = doc.to_dict()
        stage_cat = data.get('stageCategory')
        campaign_name = data.get('campaignName')
        pipeline_name = data.get('pipelineName', '').lower()
        
        if not campaign_name:
            continue
        
        campaign_source = data.get('campaignSource', '')
        campaign_medium = data.get('campaignMedium', '')
        opp_id = data.get('opportunityId')
        
        key = f"{campaign_name}|{campaign_source}|{campaign_medium}"
        
        if 'andries' in pipeline_name:
            campaigns[key]['pipeline'] = 'Andries'
        elif 'davide' in pipeline_name:
            campaigns[key]['pipeline'] = 'Davide'
        
        if stage_cat == 'deposits':
            campaigns[key]['deposits'].add(opp_id)
        elif stage_cat == 'cashCollected':
            campaigns[key]['cash'].add(opp_id)
    
    print(f"✅ Found {len(campaigns)} campaigns in Firebase")
    return campaigns

def compare_data():
    """Compare GHL and Firebase data"""
    print("\n" + "=" * 80)
    print("COMPARISON REPORT")
    print("=" * 80)
    
    ghl_campaigns = analyze_ghl_data()
    fb_campaigns = analyze_firebase_data()
    
    # Find all unique campaign keys
    all_keys = set(ghl_campaigns.keys()) | set(fb_campaigns.keys())
    
    discrepancies = []
    perfect_matches = []
    
    for key in sorted(all_keys):
        campaign_name = key.split('|')[0]
        ghl_data = ghl_campaigns.get(key, {'deposits': [], 'cash': [], 'pipeline': None})
        fb_data = fb_campaigns.get(key, {'deposits': set(), 'cash': set(), 'pipeline': None})
        
        ghl_deposits = len(ghl_data['deposits'])
        ghl_cash = len(ghl_data['cash'])
        fb_deposits = len(fb_data['deposits'])
        fb_cash = len(fb_data['cash'])
        
        # Skip if no deposits or cash in either system
        if ghl_deposits == 0 and ghl_cash == 0 and fb_deposits == 0 and fb_cash == 0:
            continue
        
        pipeline = ghl_data['pipeline'] or fb_data['pipeline']
        
        match = (ghl_deposits == fb_deposits) and (ghl_cash == fb_cash)
        
        result = {
            'campaign': campaign_name,
            'pipeline': pipeline,
            'ghl_deposits': ghl_deposits,
            'fb_deposits': fb_deposits,
            'ghl_cash': ghl_cash,
            'fb_cash': fb_cash,
            'match': match,
            'ghl_deposit_opps': ghl_data['deposits'],
            'ghl_cash_opps': ghl_data['cash']
        }
        
        if match:
            perfect_matches.append(result)
        else:
            discrepancies.append(result)
    
    # Print perfect matches
    if perfect_matches:
        print(f"\n✅ PERFECT MATCHES ({len(perfect_matches)} campaigns):")
        print("-" * 80)
        for r in perfect_matches:
            print(f"\n📊 {r['campaign']} ({r['pipeline']} Pipeline)")
            print(f"   Deposits: {r['ghl_deposits']} (GHL) = {r['fb_deposits']} (Firebase) ✓")
            print(f"   Cash: {r['ghl_cash']} (GHL) = {r['fb_cash']} (Firebase) ✓")
    
    # Print discrepancies
    if discrepancies:
        print(f"\n\n⚠️  DISCREPANCIES FOUND ({len(discrepancies)} campaigns):")
        print("=" * 80)
        for r in discrepancies:
            print(f"\n📊 {r['campaign']} ({r['pipeline']} Pipeline)")
            
            if r['ghl_deposits'] != r['fb_deposits']:
                print(f"   ❌ DEPOSITS MISMATCH:")
                print(f"      GHL: {r['ghl_deposits']} | Firebase: {r['fb_deposits']}")
                print(f"      Difference: {r['ghl_deposits'] - r['fb_deposits']}")
                
                if r['ghl_deposit_opps']:
                    print(f"\n      GHL Deposit Opportunities:")
                    for opp in r['ghl_deposit_opps']:
                        print(f"        - {opp['contact']} (ID: {opp['id']}, Value: R{opp['value']})")
            
            if r['ghl_cash'] != r['fb_cash']:
                print(f"   ❌ CASH MISMATCH:")
                print(f"      GHL: {r['ghl_cash']} | Firebase: {r['fb_cash']}")
                print(f"      Difference: {r['ghl_cash'] - r['fb_cash']}")
                
                if r['ghl_cash_opps']:
                    print(f"\n      GHL Cash Opportunities:")
                    for opp in r['ghl_cash_opps']:
                        print(f"        - {opp['contact']} (ID: {opp['id']}, Value: R{opp['value']})")
    
    # Summary
    print("\n" + "=" * 80)
    print("SUMMARY")
    print("=" * 80)
    print(f"Total campaigns analyzed: {len(perfect_matches) + len(discrepancies)}")
    print(f"✅ Perfect matches: {len(perfect_matches)}")
    print(f"⚠️  Discrepancies: {len(discrepancies)}")
    
    # Calculate totals
    total_ghl_deposits = sum(r['ghl_deposits'] for r in perfect_matches + discrepancies)
    total_fb_deposits = sum(r['fb_deposits'] for r in perfect_matches + discrepancies)
    total_ghl_cash = sum(r['ghl_cash'] for r in perfect_matches + discrepancies)
    total_fb_cash = sum(r['fb_cash'] for r in perfect_matches + discrepancies)
    
    print(f"\nTOTAL DEPOSITS:")
    print(f"  GHL: {total_ghl_deposits}")
    print(f"  Firebase: {total_fb_deposits}")
    print(f"  Difference: {total_ghl_deposits - total_fb_deposits}")
    
    print(f"\nTOTAL CASH COLLECTED:")
    print(f"  GHL: {total_ghl_cash}")
    print(f"  Firebase: {total_fb_cash}")
    print(f"  Difference: {total_ghl_cash - total_fb_cash}")
    
    # Save detailed report
    report = {
        'timestamp': datetime.now().isoformat(),
        'summary': {
            'total_campaigns': len(perfect_matches) + len(discrepancies),
            'perfect_matches': len(perfect_matches),
            'discrepancies': len(discrepancies),
            'totals': {
                'ghl_deposits': total_ghl_deposits,
                'fb_deposits': total_fb_deposits,
                'ghl_cash': total_ghl_cash,
                'fb_cash': total_fb_cash
            }
        },
        'perfect_matches': perfect_matches,
        'discrepancies': discrepancies
    }
    
    filename = f"deposit_cash_verification_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
    with open(filename, 'w') as f:
        json.dump(report, f, indent=2, default=str)
    
    print(f"\n💾 Detailed report saved to: {filename}")

if __name__ == '__main__':
    if not GHL_API_KEY:
        print("❌ ERROR: GHL_API_KEY environment variable not set!")
        exit(1)
    
    try:
        compare_data()
    except Exception as e:
        print(f"\n❌ ERROR: {e}")
        import traceback
        traceback.print_exc()

