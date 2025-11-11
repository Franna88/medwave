#!/usr/bin/env python3
"""
Audit GHL opportunities in Firebase to find duplicates and verify matching
"""

import firebase_admin
from firebase_admin import credentials, firestore
import requests
import os
from collections import defaultdict
from datetime import datetime

print("🔍 Starting GHL Opportunities Audit...", flush=True)
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

def fetch_all_opportunities_from_ghl():
    """Fetch all opportunities from GHL API for cross-reference"""
    print("\n📊 Fetching opportunities from GHL API for cross-reference...")
    
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
            print(f"   Fetched page {page}: {len(opportunities)} opportunities (Total: {len(all_opportunities)})", flush=True)
            
            if len(opportunities) < 100:
                break
            
            page += 1
            
        except Exception as e:
            print(f"   ⚠️  Error fetching page {page}: {e}")
            break
    
    print(f"   ✅ Total opportunities fetched: {len(all_opportunities)}")
    
    # Build lookup map
    opp_map = {}
    for opp in all_opportunities:
        opp_map[opp['id']] = opp
    
    return opp_map

def audit_firebase_ghl_data():
    """Audit all GHL data in Firebase"""
    
    print("\n" + "="*80)
    print("PHASE 1: SCANNING FIREBASE FOR GHL DATA")
    print("="*80)
    
    # Track statistics
    stats = {
        'total_ads_checked': 0,
        'ads_with_ghl_data': 0,
        'total_weeks': 0,
        'total_leads': 0,
        'total_deposits': 0,
        'total_cash_collected': 0,
        'weeks_with_1500_default': 0,
        'weeks_with_real_monetary_value': 0
    }
    
    # Track opportunity appearances
    opportunity_appearances = defaultdict(list)  # opp_id -> list of (ad_id, campaign_id, week_id, deposits, cash)
    
    # Get all months
    print("\n📅 Scanning all months in advertData...")
    months = list(db.collection('advertData').stream())
    
    for month_doc in months:
        month_id = month_doc.id
        month_data = month_doc.to_dict()
        
        # Skip invalid month documents
        if 'totalAds' not in month_data:
            continue
        
        print(f"\n📅 Month: {month_id}")
        
        # Get all ads in this month
        ads_ref = month_doc.reference.collection('ads')
        ads = list(ads_ref.stream())
        
        for ad_doc in ads:
            stats['total_ads_checked'] += 1
            ad_id = ad_doc.id
            ad_data = ad_doc.to_dict()
            
            # Check if ad has GHL data
            if not ad_data.get('hasGHLData', False):
                continue
            
            stats['ads_with_ghl_data'] += 1
            campaign_id = ad_data.get('campaignId', 'unknown')
            campaign_name = ad_data.get('campaignName', 'Unknown')
            ad_name = ad_data.get('adName', 'Unknown')
            
            # Get GHL weekly data
            ghl_weeks_ref = ad_doc.reference.collection('ghlWeekly')
            ghl_weeks = list(ghl_weeks_ref.stream())
            
            for week_doc in ghl_weeks:
                stats['total_weeks'] += 1
                week_id = week_doc.id
                week_data = week_doc.to_dict()
                
                leads = week_data.get('leads', 0)
                deposits = week_data.get('deposits', 0)
                cash_collected = week_data.get('cashCollected', 0)
                cash_amount = week_data.get('cashAmount', 0)
                
                stats['total_leads'] += leads
                stats['total_deposits'] += deposits
                stats['total_cash_collected'] += cash_collected
                
                # Check for R1,500 default values
                if cash_amount == 1500 and (deposits > 0 or cash_collected > 0):
                    stats['weeks_with_1500_default'] += 1
                elif cash_amount > 0:
                    stats['weeks_with_real_monetary_value'] += 1
                
                # Track this as an opportunity appearance
                # We don't have opportunity ID stored, so we'll use a composite key
                # based on week, leads, deposits, cash to identify potential duplicates
                composite_key = f"{week_id}_{leads}_{deposits}_{cash_collected}_{cash_amount}"
                
                opportunity_appearances[composite_key].append({
                    'ad_id': ad_id,
                    'ad_name': ad_name,
                    'campaign_id': campaign_id,
                    'campaign_name': campaign_name,
                    'month': month_id,
                    'week_id': week_id,
                    'leads': leads,
                    'deposits': deposits,
                    'cash_collected': cash_collected,
                    'cash_amount': cash_amount
                })
    
    print("\n" + "="*80)
    print("AUDIT RESULTS - FIREBASE SCAN")
    print("="*80)
    print(f"\n📊 Overall Statistics:")
    print(f"   Total ads checked: {stats['total_ads_checked']}")
    print(f"   Ads with GHL data: {stats['ads_with_ghl_data']}")
    print(f"   Total GHL weeks: {stats['total_weeks']}")
    print(f"   Total leads: {stats['total_leads']}")
    print(f"   Total deposits: {stats['total_deposits']}")
    print(f"   Total cash collected: {stats['total_cash_collected']}")
    
    print(f"\n💰 Monetary Value Analysis:")
    print(f"   Weeks with R1,500 default: {stats['weeks_with_1500_default']} ❌")
    print(f"   Weeks with real monetary value: {stats['weeks_with_real_monetary_value']} ✅")
    
    # Analyze potential duplicates
    print(f"\n🔍 Duplicate Analysis:")
    print(f"   Unique opportunity patterns: {len(opportunity_appearances)}")
    
    potential_duplicates = []
    cross_campaign_duplicates = []
    
    for composite_key, appearances in opportunity_appearances.items():
        if len(appearances) > 1:
            potential_duplicates.append((composite_key, appearances))
            
            # Check if appears in multiple campaigns
            campaigns = set(app['campaign_id'] for app in appearances)
            if len(campaigns) > 1:
                cross_campaign_duplicates.append((composite_key, appearances))
    
    print(f"   Potential duplicates (same data in multiple ads): {len(potential_duplicates)}")
    print(f"   Cross-campaign duplicates: {len(cross_campaign_duplicates)} ⚠️")
    
    # Show examples of cross-campaign duplicates
    if cross_campaign_duplicates:
        print(f"\n" + "="*80)
        print("CROSS-CAMPAIGN DUPLICATES DETECTED")
        print("="*80)
        print("\nShowing first 10 examples:\n")
        
        for i, (composite_key, appearances) in enumerate(cross_campaign_duplicates[:10], 1):
            first = appearances[0]
            print(f"{i}. Week: {first['week_id']}")
            print(f"   Leads: {first['leads']}, Deposits: {first['deposits']}, Cash: {first['cash_collected']}, Amount: R{first['cash_amount']:,.2f}")
            print(f"   Found in {len(appearances)} ads across {len(set(app['campaign_id'] for app in appearances))} campaigns:")
            
            for app in appearances:
                print(f"      - Ad: {app['ad_name'][:50]}")
                print(f"        Campaign: {app['campaign_name'][:60]}")
                print(f"        Campaign ID: {app['campaign_id']}")
                print(f"        Month: {app['month']}")
            print()
    
    # Save detailed report
    report_file = f"ghl_audit_report_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
    
    import json
    report_data = {
        'audit_timestamp': datetime.now().isoformat(),
        'statistics': stats,
        'potential_duplicates_count': len(potential_duplicates),
        'cross_campaign_duplicates_count': len(cross_campaign_duplicates),
        'cross_campaign_duplicates': [
            {
                'composite_key': key,
                'appearances': appearances
            }
            for key, appearances in cross_campaign_duplicates
        ]
    }
    
    with open(report_file, 'w') as f:
        json.dump(report_data, f, indent=2, default=str)
    
    print(f"\n📄 Detailed report saved to: {report_file}")
    
    return stats, cross_campaign_duplicates

if __name__ == '__main__':
    # Run the audit
    stats, duplicates = audit_firebase_ghl_data()
    
    print("\n" + "="*80)
    print("AUDIT COMPLETE")
    print("="*80)
    print("\n✅ Phase 1 discovery complete!")
    print(f"   Found {stats['weeks_with_1500_default']} weeks with R1,500 default values")
    print(f"   Found {len(duplicates)} cross-campaign duplicates")
    print("\nNext steps:")
    print("1. Review the detailed report file")
    print("2. Proceed with Phase 2: Fix monetary values and implement mapping")
    print()

