#!/usr/bin/env python3
"""
Read and Display Monetary Values in Summary Collection
=======================================================
This script reads the summary collection and displays all monetary values
(cashAmount) at campaign, ad set, and ad levels.

Structure:
summary/{campaignId}/
  weeks: {
    "YYYY-MM-DD_YYYY-MM-DD": {
      campaign: { ghlData: { cashAmount: X } },
      adSets: { {adSetId}: { ghlData: { cashAmount: X } } },
      ads: { {adId}: { ghlData: { cashAmount: X } } }
    }
  }
"""

import firebase_admin
from firebase_admin import credentials, firestore
from collections import defaultdict

# Initialize Firebase
try:
    cred = credentials.Certificate('/Users/mac/dev/medwave/medx-ai-firebase-adminsdk-fbsvc-a86e7bd050.json')
    firebase_admin.initialize_app(cred)
    print('✅ Firebase initialized successfully\n')
except Exception as e:
    print(f'⚠️  Firebase already initialized or error: {e}\n')
    pass

db = firestore.client()

print('=' * 80)
print('READING MONETARY VALUES FROM SUMMARY COLLECTION')
print('=' * 80)
print()

# Load all summary documents
print('📄 Loading summary collection...')
summary_docs = list(db.collection('summary').stream())
print(f'✅ Loaded {len(summary_docs)} campaign summaries\n')

if not summary_docs:
    print('⚠️  No documents found in summary collection!')
    exit(0)

# Statistics
total_campaigns = len(summary_docs)
total_weeks = 0
campaigns_with_cash = 0
weeks_with_cash = 0
total_campaign_cash = 0
total_ad_set_cash = 0
total_ad_cash = 0

campaign_details = []

# Process each campaign
for campaign_doc in summary_docs:
    campaign_id = campaign_doc.id
    campaign_data = campaign_doc.to_dict()
    campaign_name = campaign_data.get('campaignName', 'Unknown')
    weeks = campaign_data.get('weeks', {})
    
    campaign_total_cash = 0
    campaign_weeks_with_cash = 0
    week_details = []
    
    for week_id, week_data in weeks.items():
        total_weeks += 1
        
        # Campaign level cash for this week
        campaign_week_data = week_data.get('campaign', {})
        campaign_ghl = campaign_week_data.get('ghlData', {})
        campaign_cash = campaign_ghl.get('cashAmount', 0)
        
        # Ad set level cash
        ad_sets = week_data.get('adSets', {})
        week_ad_set_cash = sum(
            ad_set.get('ghlData', {}).get('cashAmount', 0)
            for ad_set in ad_sets.values()
        )
        
        # Ad level cash
        ads = week_data.get('ads', {})
        week_ad_cash = sum(
            ad.get('ghlData', {}).get('cashAmount', 0)
            for ad in ads.values()
        )
        
        if campaign_cash > 0 or week_ad_set_cash > 0 or week_ad_cash > 0:
            weeks_with_cash += 1
            campaign_weeks_with_cash += 1
            
            week_details.append({
                'week_id': week_id,
                'campaign_cash': campaign_cash,
                'ad_set_cash': week_ad_set_cash,
                'ad_cash': week_ad_cash,
                'num_ad_sets': len(ad_sets),
                'num_ads': len(ads)
            })
        
        campaign_total_cash += campaign_cash
        total_campaign_cash += campaign_cash
        total_ad_set_cash += week_ad_set_cash
        total_ad_cash += week_ad_cash
    
    if campaign_total_cash > 0:
        campaigns_with_cash += 1
        campaign_details.append({
            'campaign_id': campaign_id,
            'campaign_name': campaign_name,
            'total_cash': campaign_total_cash,
            'weeks_with_cash': campaign_weeks_with_cash,
            'total_weeks': len(weeks),
            'week_details': week_details
        })

# Display summary statistics
print('=' * 80)
print('SUMMARY STATISTICS')
print('=' * 80)
print()
print(f'Total Campaigns: {total_campaigns}')
print(f'Campaigns with Cash: {campaigns_with_cash}')
print(f'Total Weeks: {total_weeks}')
print(f'Weeks with Cash: {weeks_with_cash}')
print()
print(f'💰 Total Campaign-Level Cash: R {total_campaign_cash:,.2f}')
print(f'💰 Total Ad Set-Level Cash: R {total_ad_set_cash:,.2f}')
print(f'💰 Total Ad-Level Cash: R {total_ad_cash:,.2f}')
print()

# Display detailed campaign information
if campaign_details:
    print('=' * 80)
    print('CAMPAIGNS WITH MONETARY VALUES')
    print('=' * 80)
    print()
    
    # Sort by total cash (descending)
    campaign_details.sort(key=lambda x: x['total_cash'], reverse=True)
    
    for i, campaign in enumerate(campaign_details, 1):
        print(f'{i}. Campaign: {campaign["campaign_name"][:50]}')
        print(f'   Campaign ID: {campaign["campaign_id"]}')
        print(f'   💰 Total Cash: R {campaign["total_cash"]:,.2f}')
        print(f'   📅 Weeks: {campaign["weeks_with_cash"]} with cash / {campaign["total_weeks"]} total')
        print()
        
        # Show week details
        for week in campaign['week_details']:
            print(f'      Week {week["week_id"]}:')
            print(f'         Campaign: R {week["campaign_cash"]:,.2f}')
            print(f'         Ad Sets ({week["num_ad_sets"]}): R {week["ad_set_cash"]:,.2f}')
            print(f'         Ads ({week["num_ads"]}): R {week["ad_cash"]:,.2f}')
        print()
else:
    print('=' * 80)
    print('⚠️  NO CAMPAIGNS WITH MONETARY VALUES FOUND')
    print('=' * 80)
    print()
    print('This means the summary collection has no cashAmount data in ghlData.')
    print('The update script will populate these values from ghl_opportunities.')
    print()

print('=' * 80)
print('READ COMPLETE')
print('=' * 80)
print()

