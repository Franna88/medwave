#!/usr/bin/env python3
"""
Facebook Ad Data Inspector - Find ad with actual performance data
"""

import requests
import json
from datetime import datetime, timedelta

# Facebook API Configuration
FACEBOOK_API_VERSION = 'v24.0'
FACEBOOK_BASE_URL = f'https://graph.facebook.com/{FACEBOOK_API_VERSION}'
FACEBOOK_AD_ACCOUNT_ID = 'act_220298027464902'
FACEBOOK_ACCESS_TOKEN = 'EAAc9pw8rgA0BP0S8U9s2cLzSJbCYmJZBKZCTFUNDD2zVXVqkC45q1BIQaPdZAmtXKbZBk6wjprLclIUUafHJ4icQZAXuuePybTL38pNQIcjQQZCbRGGhAtLcLVSGeJP59nMdpt8KNEoMQtvDfZBwBgpLNhQboPpaaeU8fW2rCEEhZA9pRN4RjZAAnwnLqEDaP8Fueo0cZD'

def print_section(title):
    """Print a formatted section header"""
    print("\n" + "="*100)
    print(f"  {title}")
    print("="*100)

def print_json(data, indent=2):
    """Pretty print JSON data"""
    print(json.dumps(data, indent=indent, default=str))

def fetch_ads_with_insights():
    """Fetch ads that have actual performance data"""
    print_section("FETCHING ADS WITH PERFORMANCE DATA (LAST 7 DAYS)")
    
    url = f"{FACEBOOK_BASE_URL}/{FACEBOOK_AD_ACCOUNT_ID}/insights"
    
    params = {
        'access_token': FACEBOOK_ACCESS_TOKEN,
        'fields': 'ad_id,ad_name,campaign_id,campaign_name,adset_id,adset_name,impressions,reach,spend,clicks,ctr,cpm,cpc,actions',
        'level': 'ad',
        'date_preset': 'last_7d',
        'filtering': json.dumps([
            {'field': 'impressions', 'operator': 'GREATER_THAN', 'value': 0}
        ]),
        'limit': 20,
        'sort': 'spend_descending'
    }
    
    try:
        response = requests.get(url, params=params)
        response.raise_for_status()
        data = response.json()
        
        ads = data.get('data', [])
        print(f"\n✅ Found {len(ads)} ads with performance data\n")
        
        for i, ad in enumerate(ads, 1):
            impressions = int(ad.get('impressions', 0))
            spend = float(ad.get('spend', 0))
            clicks = int(ad.get('clicks', 0))
            
            print(f"{i}. {ad.get('ad_name', 'N/A')}")
            print(f"   Ad ID: {ad.get('ad_id', 'N/A')}")
            print(f"   Campaign: {ad.get('campaign_name', 'N/A')}")
            print(f"   Impressions: {impressions:,}")
            print(f"   Spend: R {spend:,.2f}")
            print(f"   Clicks: {clicks}")
            print()
        
        return ads
    
    except requests.exceptions.RequestException as e:
        print(f"❌ Error fetching ads: {e}")
        if hasattr(e, 'response') and e.response is not None:
            print(f"Response: {e.response.text}")
        return []

def fetch_complete_ad_insights(ad_id):
    """Fetch complete insights for a specific ad"""
    print_section(f"COMPLETE INSIGHTS PAYLOAD FOR AD: {ad_id}")
    
    url = f"{FACEBOOK_BASE_URL}/{ad_id}/insights"
    
    # Request ALL available insight fields
    fields = [
        # Basic identifiers
        'account_id', 'account_name', 'ad_id', 'ad_name',
        'adset_id', 'adset_name', 'campaign_id', 'campaign_name',
        
        # Campaign info
        'objective', 'buying_type', 'optimization_goal',
        
        # Delivery metrics
        'impressions', 'reach', 'frequency',
        
        # Engagement
        'clicks', 'unique_clicks', 'ctr', 'unique_ctr',
        'inline_link_clicks', 'inline_link_click_ctr', 'unique_inline_link_clicks',
        
        # Cost metrics
        'spend', 'cpm', 'cpc', 'cpp', 'cost_per_inline_link_click',
        'cost_per_unique_click', 'cost_per_unique_inline_link_click',
        
        # Conversions & Actions
        'actions', 'action_values', 'conversions', 'conversion_values',
        'cost_per_action_type', 'cost_per_conversion',
        
        # Video metrics
        'video_play_actions', 'video_avg_time_watched_actions',
        'video_p25_watched_actions', 'video_p50_watched_actions',
        'video_p75_watched_actions', 'video_p100_watched_actions',
        'video_p95_watched_actions', 'video_continuous_2_sec_watched_actions',
        'video_30_sec_watched_actions',
        
        # Outbound
        'outbound_clicks', 'outbound_clicks_ctr', 'cost_per_outbound_click',
        'unique_outbound_clicks', 'unique_outbound_clicks_ctr',
        
        # Social
        'social_spend',
        
        # Attribution
        'attribution_setting',
        
        # Date range
        'date_start', 'date_stop'
    ]
    
    params = {
        'access_token': FACEBOOK_ACCESS_TOKEN,
        'fields': ','.join(fields),
        'date_preset': 'last_7d'
    }
    
    try:
        response = requests.get(url, params=params)
        response.raise_for_status()
        insights_data = response.json()
        
        print("\n📊 COMPLETE INSIGHTS DATA:")
        print_json(insights_data)
        
        return insights_data
    
    except requests.exceptions.RequestException as e:
        print(f"❌ Error fetching insights: {e}")
        if hasattr(e, 'response') and e.response is not None:
            print(f"Response: {e.response.text}")
        return None

def fetch_ad_details(ad_id):
    """Fetch complete ad details"""
    print_section(f"COMPLETE AD DETAILS FOR: {ad_id}")
    
    fields = [
        'id', 'name', 'status', 'effective_status', 'configured_status',
        'created_time', 'updated_time',
        'account_id', 'campaign_id', 'campaign{id,name,status,objective}',
        'adset_id', 'adset{id,name,status,targeting,optimization_goal,billing_event,daily_budget,lifetime_budget}',
        'creative{id,name,title,body,image_url,video_id,thumbnail_url,object_story_spec,link_url,call_to_action_type}',
        'tracking_specs', 'conversion_specs',
        'bid_amount', 'bid_type'
    ]
    
    url = f"{FACEBOOK_BASE_URL}/{ad_id}"
    
    params = {
        'access_token': FACEBOOK_ACCESS_TOKEN,
        'fields': ','.join(fields)
    }
    
    try:
        response = requests.get(url, params=params)
        response.raise_for_status()
        ad_data = response.json()
        
        print("\n📦 COMPLETE AD DATA:")
        print_json(ad_data)
        
        return ad_data
    
    except requests.exceptions.RequestException as e:
        print(f"❌ Error fetching ad details: {e}")
        if hasattr(e, 'response') and e.response is not None:
            print(f"Response: {e.response.text}")
        return None

def fetch_daily_breakdown(ad_id):
    """Fetch daily breakdown"""
    print_section(f"DAILY BREAKDOWN FOR AD: {ad_id}")
    
    url = f"{FACEBOOK_BASE_URL}/{ad_id}/insights"
    
    params = {
        'access_token': FACEBOOK_ACCESS_TOKEN,
        'fields': 'date_start,date_stop,impressions,reach,spend,clicks,ctr,cpm,cpc,actions,conversions',
        'time_increment': 1,
        'date_preset': 'last_7d'
    }
    
    try:
        response = requests.get(url, params=params)
        response.raise_for_status()
        daily_data = response.json()
        
        print("\n📅 DAILY BREAKDOWN:")
        print_json(daily_data)
        
        return daily_data
    
    except requests.exceptions.RequestException as e:
        print(f"❌ Error fetching daily breakdown: {e}")
        if hasattr(e, 'response') and e.response is not None:
            print(f"Response: {e.response.text}")
        return None

def main():
    """Main execution"""
    print_section("FACEBOOK AD DATA INSPECTOR - FIND AD WITH PERFORMANCE DATA")
    print(f"API Version: {FACEBOOK_API_VERSION}")
    print(f"Ad Account: {FACEBOOK_AD_ACCOUNT_ID}")
    print(f"Timestamp: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    
    # Step 1: Find ads with actual performance data
    ads = fetch_ads_with_insights()
    
    if not ads:
        print("\n❌ No ads with performance data found")
        return
    
    # Step 2: Select the ad with most spend
    selected_ad = ads[0]
    ad_id = selected_ad['ad_id']
    
    print_section(f"INSPECTING AD: {selected_ad.get('ad_name', 'N/A')}")
    print(f"Ad ID: {ad_id}")
    
    spend = float(selected_ad.get('spend', 0))
    impressions = int(selected_ad.get('impressions', 0))
    
    print(f"Spend: R {spend:,.2f}")
    print(f"Impressions: {impressions:,}")
    
    # Step 3: Fetch complete data
    ad_details = fetch_ad_details(ad_id)
    insights = fetch_complete_ad_insights(ad_id)
    daily = fetch_daily_breakdown(ad_id)
    
    # Step 4: Summary
    print_section("DATA SUMMARY")
    
    if insights and insights.get('data') and len(insights['data']) > 0:
        insight = insights['data'][0]
        print("\n✅ AVAILABLE INSIGHT FIELDS:")
        for key in sorted(insight.keys()):
            value = insight[key]
            if isinstance(value, (list, dict)):
                print(f"   - {key}: {type(value).__name__} (see full payload above)")
            else:
                print(f"   - {key}: {value}")
    
    if ad_details:
        print("\n✅ AVAILABLE AD DETAIL FIELDS:")
        for key in sorted(ad_details.keys()):
            if key not in ['creative', 'campaign', 'adset', 'tracking_specs', 'conversion_specs']:
                print(f"   - {key}: {ad_details[key]}")
    
    print_section("INSPECTION COMPLETE")
    print("\n✅ All available data has been retrieved and displayed above")
    print("📝 Review the complete payloads to see what data Facebook API provides")
    print("\n💡 KEY FINDINGS:")
    print("   - Ad details include: status, targeting, creative, tracking specs")
    print("   - Insights include: impressions, reach, spend, clicks, conversions, actions")
    print("   - Daily breakdown shows day-by-day performance")
    print("   - Actions array contains all conversion events (leads, purchases, etc.)")

if __name__ == '__main__':
    main()

