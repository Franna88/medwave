#!/usr/bin/env python3
"""
Check Facebook ads to see what UTM parameters are configured
"""

import requests
import os
import json
from urllib.parse import urlparse, parse_qs

# Facebook API Configuration (from facebookAdsSync.js)
FB_ACCESS_TOKEN = os.environ.get('FB_ACCESS_TOKEN', 'EAAc9pw8rgA0BP0S8U9s2cLzSJbCYmJZBKZCTFUNDD2zVXVqkC45q1BIQaPdZAmtXKbZBk6wjprLclIUUafHJ4icQZAXuuePybTL38pNQIcjQQZCbRGGhAtLcLVSGeJP59nMdpt8KNEoMQtvDfZBwBgpLNhQboPpaaeU8fW2rCEEhZA9pRN4RjZAAnwnLqEDaP8Fueo0cZD')
FB_AD_ACCOUNT_ID = 'act_220298027464902'

def get_ad_details(ad_id):
    """Fetch ad details from Facebook API including creative"""
    
    if not FB_ACCESS_TOKEN:
        print("❌ FB_ACCESS_TOKEN environment variable not set!")
        return None
    
    # Remove 'act_' prefix if present
    ad_account = FB_AD_ACCOUNT_ID.replace('act_', '')
    
    url = f'https://graph.facebook.com/v18.0/{ad_id}'
    
    params = {
        'access_token': FB_ACCESS_TOKEN,
        'fields': 'id,name,status,creative{id,name,object_story_spec,url_tags,link_url,call_to_action},effective_status,campaign{id,name},adset{id,name}'
    }
    
    try:
        response = requests.get(url, params=params, timeout=30)
        
        if response.status_code == 200:
            return response.json()
        else:
            print(f"❌ Error fetching ad {ad_id}: {response.status_code}")
            print(f"   Response: {response.text}")
            return None
            
    except Exception as e:
        print(f"❌ Exception fetching ad {ad_id}: {e}")
        return None

def extract_utm_from_url(url):
    """Extract UTM parameters from a URL"""
    if not url:
        return {}
    
    try:
        parsed = urlparse(url)
        params = parse_qs(parsed.query)
        
        utm_params = {}
        for key, value in params.items():
            if key.startswith('utm_') or key in ['h_ad_id', 'fbc_id']:
                utm_params[key] = value[0] if value else None
        
        return utm_params
    except Exception as e:
        print(f"Error parsing URL: {e}")
        return {}

def check_ad_utm(ad_id, contact_name):
    """Check UTM parameters for a specific ad"""
    
    print("=" * 80)
    print(f"CHECKING AD: {ad_id}")
    print(f"Contact: {contact_name}")
    print("=" * 80)
    
    ad_data = get_ad_details(ad_id)
    
    if not ad_data:
        print("❌ Could not fetch ad data")
        return
    
    print(f"\n✅ Ad Name: {ad_data.get('name', 'Unknown')}")
    print(f"   Status: {ad_data.get('status', 'Unknown')}")
    print(f"   Effective Status: {ad_data.get('effective_status', 'Unknown')}")
    
    # Campaign info
    campaign = ad_data.get('campaign', {})
    print(f"\n📊 Campaign:")
    print(f"   ID: {campaign.get('id', 'Unknown')}")
    print(f"   Name: {campaign.get('name', 'Unknown')}")
    
    # Adset info
    adset = ad_data.get('adset', {})
    print(f"\n🎯 Ad Set:")
    print(f"   ID: {adset.get('id', 'Unknown')}")
    print(f"   Name: {adset.get('name', 'Unknown')}")
    
    # Creative info
    creative = ad_data.get('creative', {})
    if creative:
        print(f"\n🎨 Creative:")
        print(f"   ID: {creative.get('id', 'Unknown')}")
        print(f"   Name: {creative.get('name', 'Unknown')}")
        
        # Check url_tags (UTM parameters configured in ad)
        url_tags = creative.get('url_tags')
        if url_tags:
            print(f"\n✅ URL Tags (UTM Parameters):")
            print(f"   {url_tags}")
            
            # Parse the URL tags
            utm_params = {}
            for param in url_tags.split('&'):
                if '=' in param:
                    key, value = param.split('=', 1)
                    utm_params[key] = value
            
            print(f"\n   Parsed UTM Parameters:")
            for key, value in utm_params.items():
                if key == 'h_ad_id':
                    print(f"      ✅ {key}: {value} ← AD ID PARAMETER!")
                else:
                    print(f"      {key}: {value}")
        else:
            print(f"\n❌ NO URL Tags configured!")
        
        # Check link_url
        link_url = creative.get('link_url')
        if link_url:
            print(f"\n🔗 Link URL:")
            print(f"   {link_url}")
            
            # Extract UTM from URL
            url_utms = extract_utm_from_url(link_url)
            if url_utms:
                print(f"\n   UTM Parameters in URL:")
                for key, value in url_utms.items():
                    print(f"      {key}: {value}")
        
        # Check call_to_action
        cta = creative.get('call_to_action', {})
        if cta:
            print(f"\n📞 Call to Action:")
            print(f"   Type: {cta.get('type', 'Unknown')}")
            if 'value' in cta and 'link' in cta['value']:
                cta_link = cta['value']['link']
                print(f"   Link: {cta_link}")
                
                # Extract UTM from CTA link
                cta_utms = extract_utm_from_url(cta_link)
                if cta_utms:
                    print(f"\n   UTM Parameters in CTA Link:")
                    for key, value in cta_utms.items():
                        if key == 'h_ad_id':
                            print(f"      ✅ {key}: {value} ← AD ID PARAMETER!")
                        else:
                            print(f"      {key}: {value}")
    
    # Save full response
    output_file = f"facebook_ad_{ad_id}.json"
    with open(output_file, 'w') as f:
        json.dump(ad_data, f, indent=2)
    print(f"\n📄 Full ad data saved to: {output_file}")
    print()

def main():
    """Check both ads"""
    
    print("\n" + "=" * 80)
    print("CHECKING FACEBOOK ADS FOR UTM PARAMETERS")
    print("=" * 80)
    print()
    
    if not FB_ACCESS_TOKEN:
        print("❌ ERROR: FB_ACCESS_TOKEN environment variable not set!")
        print()
        print("Please set it with:")
        print("export FB_ACCESS_TOKEN='your_facebook_access_token'")
        print()
        return
    
    # Ad 1: Has utmAdId (WORKING)
    ad_with_utm = "120235559827960335"
    check_ad_utm(ad_with_utm, "Marilette Bes Bester")
    
    # Ad 2: We need to find the ad ID for Yolandi
    # Since we don't have it, let's check the campaign and see all ads
    print("\n" + "=" * 80)
    print("NOTE: For Yolandi Nel, we don't have the ad ID")
    print("Campaign ID: 120235556205010335")
    print("We would need to fetch all ads in this campaign to find which one she came from")
    print("=" * 80)
    print()
    
    # Let's also try to fetch the campaign to see all its ads
    campaign_id = "120235556205010335"
    print(f"Fetching all ads in campaign {campaign_id}...")
    
    url = f'https://graph.facebook.com/v18.0/{campaign_id}/ads'
    params = {
        'access_token': FB_ACCESS_TOKEN,
        'fields': 'id,name,status,effective_status',
        'limit': 100
    }
    
    try:
        response = requests.get(url, params=params, timeout=30)
        
        if response.status_code == 200:
            data = response.json()
            ads = data.get('data', [])
            
            print(f"\n✅ Found {len(ads)} ads in campaign:")
            for ad in ads:
                print(f"   - {ad.get('id')}: {ad.get('name')} (Status: {ad.get('effective_status')})")
            
            # Check each ad for UTM parameters
            print("\n" + "=" * 80)
            print("CHECKING ALL ADS IN CAMPAIGN FOR UTM PARAMETERS")
            print("=" * 80)
            
            for ad in ads:
                check_ad_utm(ad.get('id'), f"Ad in campaign {campaign_id}")
        else:
            print(f"❌ Error fetching campaign ads: {response.status_code}")
            print(f"   Response: {response.text}")
    except Exception as e:
        print(f"❌ Exception: {e}")

if __name__ == "__main__":
    main()

