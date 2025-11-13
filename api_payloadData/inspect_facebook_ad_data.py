#!/usr/bin/env python3
"""
Facebook Ad Data Inspector
Connects to Facebook Marketing API and displays all available data for a running ad
"""

import requests
import json
from datetime import datetime, timedelta

# Facebook API Configuration (from facebookAdsSync.js)
FACEBOOK_API_VERSION = 'v24.0'
FACEBOOK_BASE_URL = f'https://graph.facebook.com/{FACEBOOK_API_VERSION}'
FACEBOOK_AD_ACCOUNT_ID = 'act_220298027464902'
FACEBOOK_ACCESS_TOKEN = 'EAAc9pw8rgA0BP0S8U9s2cLzSJbCYmJZBKZCTFUNDD2zVXVqkC45q1BIQaPdZAmtXKbZBk6wjprLclIUUafHJ4icQZAXuuePybTL38pNQIcjQQZCbRGGhAtLcLVSGeJP59nMdpt8KNEoMQtvDfZBwBgpLNhQboPpaaeU8fW2rCEEhZA9pRN4RjZAAnwnLqEDaP8Fueo0cZD'

def print_section(title):
    """Print a formatted section header"""
    print("\n" + "="*80)
    print(f"  {title}")
    print("="*80)

def print_json(data, indent=2):
    """Pretty print JSON data"""
    print(json.dumps(data, indent=indent, default=str))

def fetch_active_ads():
    """Fetch a list of active ads from the ad account"""
    print_section("FETCHING ACTIVE ADS")
    
    url = f"{FACEBOOK_BASE_URL}/{FACEBOOK_AD_ACCOUNT_ID}/ads"
    
    params = {
        'access_token': FACEBOOK_ACCESS_TOKEN,
        'fields': 'id,name,status,effective_status,created_time,updated_time',
        'filtering': json.dumps([
            {'field': 'effective_status', 'operator': 'IN', 'value': ['ACTIVE', 'PAUSED']}
        ]),
        'limit': 10
    }
    
    try:
        response = requests.get(url, params=params)
        response.raise_for_status()
        data = response.json()
        
        ads = data.get('data', [])
        print(f"\n✅ Found {len(ads)} active/paused ads\n")
        
        for i, ad in enumerate(ads, 1):
            print(f"{i}. {ad['name']}")
            print(f"   ID: {ad['id']}")
            print(f"   Status: {ad.get('effective_status', 'N/A')}")
            print(f"   Created: {ad.get('created_time', 'N/A')}")
            print()
        
        return ads
    
    except requests.exceptions.RequestException as e:
        print(f"❌ Error fetching ads: {e}")
        if hasattr(e, 'response') and e.response is not None:
            print(f"Response: {e.response.text}")
        return []

def fetch_complete_ad_data(ad_id):
    """Fetch ALL available data for a specific ad"""
    print_section(f"FETCHING COMPLETE DATA FOR AD: {ad_id}")
    
    # Define all possible fields we want to retrieve
    fields = [
        # Basic Info
        'id', 'name', 'status', 'effective_status', 'configured_status',
        'created_time', 'updated_time',
        
        # Relationships
        'account_id', 'campaign_id', 'campaign{id,name,status,objective}',
        'adset_id', 'adset{id,name,status,targeting,optimization_goal,billing_event}',
        
        # Creative
        'creative{id,name,title,body,image_url,video_id,thumbnail_url,object_story_spec,link_url,call_to_action_type}',
        
        # Tracking
        'tracking_specs', 'conversion_specs',
        
        # Recommendations
        'recommendations',
        
        # Issues
        'issues_info',
        
        # Preview
        'preview_shareable_link',
        
        # Bid & Budget (at ad level if available)
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
        
        print("\n📦 COMPLETE AD DATA PAYLOAD:")
        print_json(ad_data)
        
        return ad_data
    
    except requests.exceptions.RequestException as e:
        print(f"❌ Error fetching ad data: {e}")
        if hasattr(e, 'response') and e.response is not None:
            print(f"Response: {e.response.text}")
        return None

def fetch_ad_insights(ad_id, date_preset='last_30d'):
    """Fetch insights (performance metrics) for an ad"""
    print_section(f"FETCHING INSIGHTS FOR AD: {ad_id}")
    
    # All available insight fields (removed invalid fields)
    fields = [
        # Delivery
        'impressions', 'reach', 'frequency',
        
        # Engagement
        'clicks', 'unique_clicks', 'ctr', 'unique_ctr',
        'inline_link_clicks', 'inline_link_click_ctr',
        
        # Cost
        'spend', 'cpm', 'cpc', 'cpp', 'cost_per_inline_link_click',
        
        # Conversions
        'actions', 'action_values', 'conversions', 'conversion_values',
        'cost_per_action_type', 'cost_per_conversion',
        
        # Video (if applicable)
        'video_play_actions', 'video_avg_time_watched_actions',
        'video_p25_watched_actions', 'video_p50_watched_actions',
        'video_p75_watched_actions', 'video_p100_watched_actions',
        
        # Outbound
        'outbound_clicks', 'outbound_clicks_ctr', 'cost_per_outbound_click',
        
        # Attribution
        'attribution_setting',
        
        # Date range
        'date_start', 'date_stop',
        
        # Additional useful fields
        'account_id', 'account_name', 'ad_id', 'ad_name',
        'adset_id', 'adset_name', 'campaign_id', 'campaign_name',
        'objective', 'buying_type', 'optimization_goal'
    ]
    
    url = f"{FACEBOOK_BASE_URL}/{ad_id}/insights"
    
    params = {
        'access_token': FACEBOOK_ACCESS_TOKEN,
        'fields': ','.join(fields),
        'date_preset': date_preset,
        'level': 'ad'
    }
    
    try:
        response = requests.get(url, params=params)
        response.raise_for_status()
        insights_data = response.json()
        
        print("\n📊 AD INSIGHTS PAYLOAD:")
        print_json(insights_data)
        
        return insights_data
    
    except requests.exceptions.RequestException as e:
        print(f"❌ Error fetching insights: {e}")
        if hasattr(e, 'response') and e.response is not None:
            print(f"Response: {e.response.text}")
        return None

def fetch_ad_leads(ad_id):
    """Fetch leads generated by this ad (if it's a lead form ad)"""
    print_section(f"FETCHING LEADS FOR AD: {ad_id}")
    
    url = f"{FACEBOOK_BASE_URL}/{ad_id}/leads"
    
    params = {
        'access_token': FACEBOOK_ACCESS_TOKEN,
        'fields': 'id,created_time,field_data,ad_id,ad_name,form_id',
        'limit': 10
    }
    
    try:
        response = requests.get(url, params=params)
        response.raise_for_status()
        leads_data = response.json()
        
        leads = leads_data.get('data', [])
        
        if leads:
            print(f"\n📝 FOUND {len(leads)} LEADS:")
            print_json(leads_data)
        else:
            print("\n📝 No leads found (this may not be a lead form ad)")
        
        return leads_data
    
    except requests.exceptions.RequestException as e:
        print(f"❌ Error fetching leads: {e}")
        if hasattr(e, 'response') and e.response is not None:
            print(f"Response: {e.response.text}")
        return None

def fetch_ad_creatives(ad_id):
    """Fetch creative details for the ad"""
    print_section(f"FETCHING CREATIVES FOR AD: {ad_id}")
    
    url = f"{FACEBOOK_BASE_URL}/{ad_id}/adcreatives"
    
    params = {
        'access_token': FACEBOOK_ACCESS_TOKEN,
        'fields': 'id,name,title,body,image_url,video_id,thumbnail_url,object_story_spec,link_url,call_to_action_type,effective_object_story_id'
    }
    
    try:
        response = requests.get(url, params=params)
        response.raise_for_status()
        creatives_data = response.json()
        
        print("\n🎨 AD CREATIVES PAYLOAD:")
        print_json(creatives_data)
        
        return creatives_data
    
    except requests.exceptions.RequestException as e:
        print(f"❌ Error fetching creatives: {e}")
        if hasattr(e, 'response') and e.response is not None:
            print(f"Response: {e.response.text}")
        return None

def fetch_daily_breakdown(ad_id, days_back=30):
    """Fetch daily breakdown of insights"""
    print_section(f"FETCHING DAILY BREAKDOWN FOR AD: {ad_id}")
    
    end_date = datetime.now()
    start_date = end_date - timedelta(days=days_back)
    
    url = f"{FACEBOOK_BASE_URL}/{ad_id}/insights"
    
    params = {
        'access_token': FACEBOOK_ACCESS_TOKEN,
        'fields': 'impressions,reach,spend,clicks,ctr,cpm,cpc,actions,conversions',
        'time_range': json.dumps({
            'since': start_date.strftime('%Y-%m-%d'),
            'until': end_date.strftime('%Y-%m-%d')
        }),
        'time_increment': 1,  # Daily breakdown
        'level': 'ad',
        'limit': days_back
    }
    
    try:
        response = requests.get(url, params=params)
        response.raise_for_status()
        daily_data = response.json()
        
        print(f"\n📅 DAILY BREAKDOWN (Last {days_back} days):")
        print_json(daily_data)
        
        return daily_data
    
    except requests.exceptions.RequestException as e:
        print(f"❌ Error fetching daily breakdown: {e}")
        if hasattr(e, 'response') and e.response is not None:
            print(f"Response: {e.response.text}")
        return None

def main():
    """Main execution"""
    print_section("FACEBOOK AD DATA INSPECTOR")
    print(f"API Version: {FACEBOOK_API_VERSION}")
    print(f"Ad Account: {FACEBOOK_AD_ACCOUNT_ID}")
    print(f"Timestamp: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    
    # Step 1: Fetch active ads
    ads = fetch_active_ads()
    
    if not ads:
        print("\n❌ No active ads found or error occurred")
        return
    
    # Step 2: Select the first active ad for detailed inspection
    selected_ad = ads[0]
    ad_id = selected_ad['id']
    
    print_section(f"INSPECTING AD: {selected_ad['name']}")
    print(f"Ad ID: {ad_id}")
    
    # Step 3: Fetch all available data
    print("\n🔍 Fetching complete ad data...")
    ad_data = fetch_complete_ad_data(ad_id)
    
    print("\n🔍 Fetching insights...")
    insights = fetch_ad_insights(ad_id)
    
    print("\n🔍 Fetching leads...")
    leads = fetch_ad_leads(ad_id)
    
    print("\n🔍 Fetching creatives...")
    creatives = fetch_ad_creatives(ad_id)
    
    print("\n🔍 Fetching daily breakdown...")
    daily = fetch_daily_breakdown(ad_id, days_back=7)
    
    # Step 4: Summary
    print_section("SUMMARY OF AVAILABLE DATA")
    print("\n✅ Data Retrieved:")
    print(f"   - Ad Basic Info: {'✓' if ad_data else '✗'}")
    print(f"   - Insights (Performance): {'✓' if insights else '✗'}")
    print(f"   - Leads: {'✓' if leads and leads.get('data') else '✗'}")
    print(f"   - Creatives: {'✓' if creatives else '✗'}")
    print(f"   - Daily Breakdown: {'✓' if daily else '✗'}")
    
    print("\n📋 Available Fields in Ad Data:")
    if ad_data:
        for key in sorted(ad_data.keys()):
            print(f"   - {key}")
    
    print("\n📋 Available Fields in Insights:")
    if insights and insights.get('data') and len(insights['data']) > 0:
        for key in sorted(insights['data'][0].keys()):
            print(f"   - {key}")
    
    print_section("INSPECTION COMPLETE")
    print(f"\n✅ All data has been retrieved and displayed above")
    print(f"📝 Review the payloads to see what data is available from Facebook API")

if __name__ == '__main__':
    main()

