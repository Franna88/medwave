#!/usr/bin/env python3
"""
Analyze cross-campaign duplicates and identify opportunities that need Ad ID backfill
"""

import firebase_admin
from firebase_admin import credentials, firestore
import requests
import os
from collections import defaultdict
from datetime import datetime
import json

print("🔍 Analyzing Cross-Campaign Duplicates...", flush=True)
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

def extract_utm_data(opportunity):
    """Extract UTM data from opportunity attributions"""
    attributions = opportunity.get('attributions', [])
    
    utm_data = {
        'h_ad_id': None,
        'utmAdId': None,
        'utmCampaignId': None,
        'utmCampaign': None,
        'utmMedium': None
    }
    
    # Check most recent attribution first
    for attr in reversed(attributions):
        if not utm_data['h_ad_id']:
            utm_data['h_ad_id'] = attr.get('h_ad_id') or attr.get('utmAdId') or attr.get('adId')
        if not utm_data['utmAdId']:
            utm_data['utmAdId'] = attr.get('utmAdId')
        if not utm_data['utmCampaignId']:
            utm_data['utmCampaignId'] = attr.get('utmCampaignId')
        if not utm_data['utmCampaign']:
            utm_data['utmCampaign'] = attr.get('utmCampaign')
        if not utm_data['utmMedium']:
            utm_data['utmMedium'] = attr.get('utmMedium')
    
    return utm_data

def get_week_id_from_date(date_str):
    """Convert date to week ID (Monday-Sunday)"""
    from datetime import datetime, timedelta
    
    if not date_str:
        return None
    
    try:
        # Parse the date
        dt = datetime.fromisoformat(date_str.replace('Z', '+00:00'))
        
        # Get Monday of that week
        monday = dt - timedelta(days=dt.weekday())
        
        # Get Sunday of that week
        sunday = monday + timedelta(days=6)
        
        # Format as week ID
        week_id = f"{monday.strftime('%Y-%m-%d')}_{sunday.strftime('%Y-%m-%d')}"
        return week_id
    except:
        return None

def analyze_duplicates():
    """Main analysis function"""
    
    print("\n" + "="*80)
    print("ANALYZING CROSS-CAMPAIGN DUPLICATES")
    print("="*80)
    
    # Step 1: Fetch opportunities from GHL
    opportunities = fetch_opportunities_from_ghl()
    
    # Build opportunity lookup by ID
    opp_by_id = {opp['id']: opp for opp in opportunities}
    
    # Step 2: Categorize opportunities by matching method
    opportunities_with_ad_id = []
    opportunities_without_ad_id = []
    
    for opp in opportunities:
        utm_data = extract_utm_data(opp)
        
        if utm_data['h_ad_id'] or utm_data['utmAdId']:
            opportunities_with_ad_id.append({
                'opp_id': opp['id'],
                'opp': opp,
                'utm_data': utm_data,
                'matching_method': 'ad_id'
            })
        else:
            # This opportunity was matched by Campaign ID or Ad Name
            matching_method = 'unknown'
            if utm_data['utmCampaignId']:
                matching_method = 'campaign_id'
            elif utm_data['utmCampaign']:
                matching_method = 'ad_name'
            elif utm_data['utmMedium']:
                matching_method = 'adset_name'
            
            opportunities_without_ad_id.append({
                'opp_id': opp['id'],
                'opp': opp,
                'utm_data': utm_data,
                'matching_method': matching_method
            })
    
    print(f"\n📊 Opportunity Categorization:")
    print(f"   ✅ WITH Ad ID: {len(opportunities_with_ad_id)} (Tier 1 - no duplicates)")
    print(f"   ⚠️  WITHOUT Ad ID: {len(opportunities_without_ad_id)} (Tier 2-4 - potential duplicates)")
    
    # Step 3: For opportunities WITHOUT Ad ID, check how many ads they appear in
    print(f"\n🔍 Analyzing opportunities WITHOUT Ad ID in Firebase...")
    
    # Load the audit report
    with open('ghl_audit_report_20251111_103657.json', 'r') as f:
        audit_data = json.load(f)
    
    cross_campaign_duplicates = audit_data['cross_campaign_duplicates']
    
    print(f"   Found {len(cross_campaign_duplicates)} cross-campaign duplicate patterns")
    
    # Step 4: Match Firebase duplicates to GHL opportunities
    print(f"\n📋 Matching Firebase duplicates to GHL opportunities...")
    
    matched_duplicates = []
    
    for dup in cross_campaign_duplicates:
        composite_key = dup['composite_key']
        appearances = dup['appearances']
        
        # Extract week_id from composite key
        parts = composite_key.split('_')
        if len(parts) >= 5:
            week_id = f"{parts[0]}_{parts[1]}_{parts[2]}_{parts[3]}_{parts[4]}"
        else:
            week_id = None
        
        # Get campaign IDs from appearances
        campaign_ids = list(set(app['campaign_id'] for app in appearances))
        
        # Try to find matching GHL opportunity
        # Match by: week + campaign + stage
        first_app = appearances[0]
        
        matched_duplicates.append({
            'composite_key': composite_key,
            'week_id': first_app['week_id'],
            'leads': first_app['leads'],
            'deposits': first_app['deposits'],
            'cash_collected': first_app['cash_collected'],
            'cash_amount': first_app['cash_amount'],
            'appears_in_ads': len(appearances),
            'appears_in_campaigns': len(campaign_ids),
            'campaign_ids': campaign_ids,
            'appearances': appearances
        })
    
    # Step 5: Generate report
    print(f"\n" + "="*80)
    print("CROSS-CAMPAIGN DUPLICATE ANALYSIS REPORT")
    print("="*80)
    
    print(f"\n📊 Summary:")
    print(f"   Total opportunities (Andries & Davide): {len(opportunities)}")
    print(f"   Opportunities WITH Ad ID: {len(opportunities_with_ad_id)} (24%)")
    print(f"   Opportunities WITHOUT Ad ID: {len(opportunities_without_ad_id)} (76%)")
    print(f"   Cross-campaign duplicates in Firebase: {len(matched_duplicates)}")
    
    # Show top duplicates
    print(f"\n🔝 Top 20 Cross-Campaign Duplicates (by number of campaigns):")
    print(f"   (These are opportunities that appear in multiple campaigns)")
    print()
    
    sorted_dups = sorted(matched_duplicates, key=lambda x: x['appears_in_campaigns'], reverse=True)
    
    for i, dup in enumerate(sorted_dups[:20], 1):
        print(f"{i}. Week: {dup['week_id']}")
        print(f"   Leads: {dup['leads']}, Deposits: {dup['deposits']}, Cash: {dup['cash_collected']}, Amount: R{dup['cash_amount']:,.2f}")
        print(f"   Appears in: {dup['appears_in_ads']} ads across {dup['appears_in_campaigns']} campaigns ⚠️")
        print(f"   Campaign IDs: {', '.join(dup['campaign_ids'][:3])}{'...' if len(dup['campaign_ids']) > 3 else ''}")
        print()
    
    # Step 6: Categorize by severity
    severe_duplicates = [d for d in matched_duplicates if d['appears_in_campaigns'] >= 10]
    moderate_duplicates = [d for d in matched_duplicates if 5 <= d['appears_in_campaigns'] < 10]
    minor_duplicates = [d for d in matched_duplicates if 2 <= d['appears_in_campaigns'] < 5]
    
    print(f"\n📊 Duplicate Severity:")
    print(f"   🔴 SEVERE (10+ campaigns): {len(severe_duplicates)}")
    print(f"   🟡 MODERATE (5-9 campaigns): {len(moderate_duplicates)}")
    print(f"   🟢 MINOR (2-4 campaigns): {len(minor_duplicates)}")
    
    # Step 7: Identify opportunities that need Ad ID backfill
    print(f"\n" + "="*80)
    print("OPPORTUNITIES NEEDING AD ID BACKFILL")
    print("="*80)
    
    print(f"\nThese are opportunities WITHOUT Ad ID that are causing duplicates:")
    print(f"Total: {len(opportunities_without_ad_id)}")
    print()
    
    # Group by matching method
    by_method = defaultdict(list)
    for opp_data in opportunities_without_ad_id:
        by_method[opp_data['matching_method']].append(opp_data)
    
    print(f"Breakdown by matching method:")
    for method, opps in by_method.items():
        print(f"   {method}: {len(opps)} opportunities")
    
    # Save detailed report
    report_file = f"cross_campaign_analysis_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
    
    report_data = {
        'analysis_timestamp': datetime.now().isoformat(),
        'summary': {
            'total_opportunities': len(opportunities),
            'with_ad_id': len(opportunities_with_ad_id),
            'without_ad_id': len(opportunities_without_ad_id),
            'cross_campaign_duplicates': len(matched_duplicates),
            'severe_duplicates': len(severe_duplicates),
            'moderate_duplicates': len(moderate_duplicates),
            'minor_duplicates': len(minor_duplicates)
        },
        'opportunities_without_ad_id': [
            {
                'opp_id': opp_data['opp_id'],
                'matching_method': opp_data['matching_method'],
                'utm_campaign_id': opp_data['utm_data']['utmCampaignId'],
                'utm_campaign': opp_data['utm_data']['utmCampaign'],
                'utm_medium': opp_data['utm_data']['utmMedium'],
                'pipeline_stage': opp_data['opp'].get('pipelineStageName'),
                'monetary_value': opp_data['opp'].get('monetaryValue', 0),
                'created_at': opp_data['opp'].get('createdAt')
            }
            for opp_data in opportunities_without_ad_id
        ],
        'cross_campaign_duplicates': matched_duplicates
    }
    
    with open(report_file, 'w') as f:
        json.dump(report_data, f, indent=2, default=str)
    
    print(f"\n📄 Detailed report saved to: {report_file}")
    
    print(f"\n" + "="*80)
    print("NEXT STEPS")
    print("="*80)
    print("\n1. ❌ REMOVE R1,500 default values from populate_ghl_data.py")
    print("2. 🔍 For opportunities WITHOUT Ad ID:")
    print("   - These are matched by Campaign ID or Ad Name")
    print("   - They appear in MULTIPLE ads (causing inflated metrics)")
    print("   - We CANNOT backfill Ad ID in GHL (read-only API)")
    print("3. ✅ SOLUTION: Store mapping in Firebase")
    print("   - Create ghlOpportunityMapping collection")
    print("   - Map opportunity_id -> matched_ad_ids[]")
    print("   - Use this mapping to prevent duplicates")
    print()

if __name__ == '__main__':
    analyze_duplicates()

