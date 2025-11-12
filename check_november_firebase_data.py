#!/usr/bin/env python3
"""
Check November 2025 Campaign Data in Firebase Split Collections
Compare with Facebook API data
"""

import firebase_admin
from firebase_admin import credentials, firestore
from datetime import datetime
import json

# Initialize Firebase
if not firebase_admin._apps:
    cred = credentials.Certificate('medx-ai-firebase-adminsdk-fbsvc-a86e7bd050.json')
    firebase_admin.initialize_app(cred)

db = firestore.client()

def check_november_campaigns():
    """Check campaigns in Firebase for November 2025"""
    print('=' * 80)
    print('FIREBASE SPLIT COLLECTIONS - NOVEMBER 2025 CAMPAIGNS')
    print('=' * 80)
    print()
    
    # Query campaigns collection
    campaigns_ref = db.collection('campaigns')
    campaigns = list(campaigns_ref.stream())
    
    print(f'Total campaigns in Firebase: {len(campaigns)}')
    print()
    
    # Filter for November 2025
    november_campaigns = []
    
    for campaign_doc in campaigns:
        campaign = campaign_doc.to_dict()
        campaign_id = campaign_doc.id
        
        first_ad_date = campaign.get('firstAdDate', '')
        last_ad_date = campaign.get('lastAdDate', '')
        
        # Convert to string if it's a Timestamp
        if hasattr(first_ad_date, 'strftime'):
            first_ad_date = first_ad_date.strftime('%Y-%m-%d')
        if hasattr(last_ad_date, 'strftime'):
            last_ad_date = last_ad_date.strftime('%Y-%m-%d')
        
        # Check if campaign has activity in November 2025
        has_november_activity = False
        
        if first_ad_date and last_ad_date:
            # Check if date range overlaps with November 2025
            if (first_ad_date <= '2025-11-30' and last_ad_date >= '2025-11-01'):
                has_november_activity = True
        
        if has_november_activity:
            november_campaigns.append({
                'id': campaign_id,
                'name': campaign.get('campaignName', 'Unknown'),
                'totalSpend': campaign.get('totalSpend', 0),
                'totalLeads': campaign.get('totalLeads', 0),
                'firstAdDate': first_ad_date,
                'lastAdDate': last_ad_date,
                'status': campaign.get('status', 'UNKNOWN')
            })
    
    # Sort by spend
    november_campaigns.sort(key=lambda x: x['totalSpend'], reverse=True)
    
    print(f'Campaigns with November 2025 activity: {len(november_campaigns)}')
    print()
    
    # Calculate totals
    total_spend = sum(c['totalSpend'] for c in november_campaigns)
    total_leads = sum(c['totalLeads'] for c in november_campaigns)
    
    print(f'📊 FIREBASE TOTALS:')
    print(f'   Total Spend: ${total_spend:,.2f}')
    print(f'   Total Leads: {total_leads}')
    print()
    
    print('=' * 80)
    print('TOP 10 CAMPAIGNS BY SPEND (from Firebase):')
    print('=' * 80)
    print()
    
    for i, campaign in enumerate(november_campaigns[:10], 1):
        print(f'{i}. {campaign["name"]}')
        print(f'   Campaign ID: {campaign["id"]}')
        print(f'   Spend: ${campaign["totalSpend"]:,.2f}')
        print(f'   Leads: {campaign["totalLeads"]}')
        print(f'   Date Range: {campaign["firstAdDate"]} to {campaign["lastAdDate"]}')
        print(f'   Status: {campaign["status"]}')
        print()
    
    print('=' * 80)
    print('ISSUE ANALYSIS:')
    print('=' * 80)
    print()
    print(f'Facebook API reported: R 31,629.19 (17 campaigns with spend)')
    print(f'Firebase shows: ${total_spend:,.2f} ({len(november_campaigns)} campaigns)')
    print()
    
    if total_spend > 35000:
        print('⚠️  PROBLEM DETECTED:')
        print('   Firebase spend is MUCH HIGHER than Facebook API')
        print()
        print('   Possible causes:')
        print('   1. Date filtering issue - campaigns from other months included')
        print('   2. Cumulative data - spend from entire campaign lifetime, not just November')
        print('   3. Data not properly filtered by date range in Flutter app')
        print()
        print('   SOLUTION NEEDED:')
        print('   - Campaigns should only show spend for NOVEMBER 2025')
        print('   - Need to aggregate spend from ads collection filtered by November dates')
        print('   - Current totalSpend in campaigns collection is LIFETIME spend')
    
    # Check a specific campaign in detail
    print()
    print('=' * 80)
    print('DETAILED CHECK: Sample Campaign')
    print('=' * 80)
    print()
    
    if november_campaigns:
        sample_campaign = november_campaigns[0]
        campaign_id = sample_campaign['id']
        
        print(f'Campaign: {sample_campaign["name"]}')
        print(f'Campaign ID: {campaign_id}')
        print(f'Firebase totalSpend: ${sample_campaign["totalSpend"]:,.2f}')
        print()
        
        # Get ads for this campaign
        ads_ref = db.collection('ads').where('campaignId', '==', campaign_id)
        ads = list(ads_ref.stream())
        
        print(f'Total ads in campaign: {len(ads)}')
        print()
        
        # Calculate November-only spend
        november_spend = 0
        november_ads = 0
        
        for ad_doc in ads:
            ad = ad_doc.to_dict()
            first_insight = ad.get('firstInsightDate', '')
            last_insight = ad.get('lastInsightDate', '')
            ad_spend = ad.get('facebookStats', {}).get('spend', 0)
            
            # Convert to string if it's a Timestamp
            if hasattr(first_insight, 'strftime'):
                first_insight = first_insight.strftime('%Y-%m-%d')
            if hasattr(last_insight, 'strftime'):
                last_insight = last_insight.strftime('%Y-%m-%d')
            
            # Check if ad has November activity
            if first_insight and last_insight:
                if (first_insight <= '2025-11-30' and last_insight >= '2025-11-01'):
                    november_spend += ad_spend
                    november_ads += 1
        
        print(f'Ads with November activity: {november_ads}')
        print(f'November-only spend (from ads): ${november_spend:,.2f}')
        print()
        
        if november_spend < sample_campaign['totalSpend']:
            print('⚠️  CONFIRMED: Campaign totalSpend includes data from OTHER MONTHS')
            print(f'   Difference: ${sample_campaign["totalSpend"] - november_spend:,.2f}')
    
    # Save report
    report = {
        'date_generated': datetime.now().isoformat(),
        'firebase_campaigns': len(november_campaigns),
        'firebase_total_spend': total_spend,
        'facebook_api_spend': 31629.19,
        'discrepancy': total_spend - 31629.19,
        'campaigns': november_campaigns
    }
    
    with open('firebase_november_analysis.json', 'w') as f:
        json.dump(report, f, indent=2)
    
    print()
    print('=' * 80)
    print('📄 Report saved to: firebase_november_analysis.json')
    print('=' * 80)

if __name__ == '__main__':
    check_november_campaigns()

