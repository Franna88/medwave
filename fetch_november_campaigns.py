#!/usr/bin/env python3
"""
Fetch November 2025 Campaign Data from Facebook API
Retrieves campaigns running in November 2025 and calculates total ad spend
"""

import requests
import json
from datetime import datetime

# Facebook API Configuration (from ADVERTDATA_IMPLEMENTATION_SESSION_SUMMARY.md)
FACEBOOK_API_VERSION = 'v24.0'
FACEBOOK_BASE_URL = f'https://graph.facebook.com/{FACEBOOK_API_VERSION}'
FACEBOOK_AD_ACCOUNT_ID = 'act_220298027464902'
FACEBOOK_ACCESS_TOKEN = 'EAAc9pw8rgA0BP0S8U9s2cLzSJbCYmJZBKZCTFUNDD2zVXVqkC45q1BIQaPdZAmtXKbZBk6wjprLclIUUafHJ4icQZAXuuePybTL38pNQIcjQQZCbRGGhAtLcLVSGeJP59nMdpt8KNEoMQtvDfZBwBgpLNhQboPpaaeU8fW2rCEEhZA9pRN4RjZAAnwnLqEDaP8Fueo0cZD'

# November 2025 date range
NOVEMBER_START = '2025-11-01'
NOVEMBER_END = '2025-11-30'

def fetch_campaigns_with_insights():
    """
    Fetch all campaigns with insights for November 2025
    Returns list of campaigns with their spend data
    """
    print('🚀 Fetching Facebook campaigns for November 2025...')
    print(f'   Date Range: {NOVEMBER_START} to {NOVEMBER_END}')
    print()
    
    url = f'{FACEBOOK_BASE_URL}/{FACEBOOK_AD_ACCOUNT_ID}/campaigns'
    
    all_campaigns = []
    params = {
        'fields': 'id,name,status,insights{spend,impressions,clicks,reach,date_start,date_stop}',
        'time_range': json.dumps({
            'since': NOVEMBER_START,
            'until': NOVEMBER_END
        }),
        'access_token': FACEBOOK_ACCESS_TOKEN,
        'limit': 100
    }
    
    try:
        while True:
            response = requests.get(url, params=params)
            response.raise_for_status()
            
            data = response.json()
            campaigns = data.get('data', [])
            all_campaigns.extend(campaigns)
            
            # Check for pagination
            paging = data.get('paging', {})
            next_url = paging.get('next')
            
            if not next_url:
                break
                
            # Update URL for next page (params already included in next URL)
            url = next_url
            params = {}  # Clear params as they're in the next URL
            
        print(f'✅ Successfully fetched {len(all_campaigns)} campaigns')
        return all_campaigns
        
    except requests.exceptions.RequestException as e:
        print(f'❌ Error fetching campaigns: {e}')
        if hasattr(e, 'response') and e.response is not None:
            print(f'   Response: {e.response.text}')
        return []

def analyze_campaigns(campaigns):
    """
    Analyze campaign data and calculate totals
    """
    print()
    print('=' * 80)
    print('NOVEMBER 2025 CAMPAIGN ANALYSIS')
    print('=' * 80)
    print()
    
    total_spend = 0.0
    campaigns_with_spend = []
    campaigns_no_insights = []
    
    for campaign in campaigns:
        campaign_id = campaign.get('id')
        campaign_name = campaign.get('name')
        status = campaign.get('status', 'UNKNOWN')
        insights = campaign.get('insights', {})
        
        # Extract spend from insights
        insights_data = insights.get('data', [])
        if insights_data:
            # Sum up spend from all insight periods
            campaign_spend = sum(float(insight.get('spend', 0)) for insight in insights_data)
            
            if campaign_spend > 0:
                campaigns_with_spend.append({
                    'id': campaign_id,
                    'name': campaign_name,
                    'status': status,
                    'spend': campaign_spend,
                    'insights': insights_data[0] if insights_data else {}
                })
                total_spend += campaign_spend
        else:
            campaigns_no_insights.append({
                'id': campaign_id,
                'name': campaign_name,
                'status': status
            })
    
    # Sort campaigns by spend (highest first)
    campaigns_with_spend.sort(key=lambda x: x['spend'], reverse=True)
    
    # Print summary
    print(f'📊 SUMMARY:')
    print(f'   Total Campaigns Found: {len(campaigns)}')
    print(f'   Campaigns with Spend: {len(campaigns_with_spend)}')
    print(f'   Campaigns without Insights: {len(campaigns_no_insights)}')
    print()
    print(f'💰 TOTAL AD SPEND (November 2025): R {total_spend:,.2f}')
    print()
    
    # Print top campaigns
    if campaigns_with_spend:
        print('=' * 80)
        print('TOP CAMPAIGNS BY SPEND:')
        print('=' * 80)
        print()
        
        for i, campaign in enumerate(campaigns_with_spend[:10], 1):
            insights = campaign.get('insights', {})
            impressions = int(insights.get('impressions', 0)) if insights.get('impressions') else 0
            clicks = int(insights.get('clicks', 0)) if insights.get('clicks') else 0
            reach = int(insights.get('reach', 0)) if insights.get('reach') else 0
            
            print(f'{i}. {campaign["name"]}')
            print(f'   Campaign ID: {campaign["id"]}')
            print(f'   Status: {campaign["status"]}')
            print(f'   Spend: R {campaign["spend"]:,.2f}')
            if impressions:
                print(f'   Impressions: {impressions:,}')
            if clicks:
                print(f'   Clicks: {clicks:,}')
            if reach:
                print(f'   Reach: {reach:,}')
            print()
    
    # Print campaigns without insights
    if campaigns_no_insights:
        print('=' * 80)
        print(f'CAMPAIGNS WITHOUT INSIGHTS ({len(campaigns_no_insights)}):')
        print('=' * 80)
        print()
        
        for campaign in campaigns_no_insights[:5]:
            print(f'- {campaign["name"]} ({campaign["id"]}) - Status: {campaign["status"]}')
        
        if len(campaigns_no_insights) > 5:
            print(f'  ... and {len(campaigns_no_insights) - 5} more')
        print()
    
    # Save detailed report
    report = {
        'date_generated': datetime.now().isoformat(),
        'date_range': {
            'start': NOVEMBER_START,
            'end': NOVEMBER_END
        },
        'summary': {
            'total_campaigns': len(campaigns),
            'campaigns_with_spend': len(campaigns_with_spend),
            'campaigns_without_insights': len(campaigns_no_insights),
            'total_spend': total_spend
        },
        'campaigns_with_spend': campaigns_with_spend,
        'campaigns_no_insights': campaigns_no_insights
    }
    
    report_filename = f'november_2025_campaign_report_{datetime.now().strftime("%Y%m%d_%H%M%S")}.json'
    with open(report_filename, 'w') as f:
        json.dump(report, f, indent=2)
    
    print('=' * 80)
    print(f'📄 Detailed report saved to: {report_filename}')
    print('=' * 80)
    
    return report

def main():
    """Main execution function"""
    print()
    print('=' * 80)
    print('FACEBOOK CAMPAIGNS - NOVEMBER 2025 REPORT')
    print('=' * 80)
    print()
    
    # Fetch campaigns
    campaigns = fetch_campaigns_with_insights()
    
    if not campaigns:
        print('❌ No campaigns found or error occurred')
        return
    
    # Analyze and display results
    analyze_campaigns(campaigns)

if __name__ == '__main__':
    main()

