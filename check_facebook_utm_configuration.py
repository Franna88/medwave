#!/usr/bin/env python3
"""
Check Facebook Ads UTM Configuration
=====================================

This script checks what UTM parameters are configured in Facebook ads
and compares them with what GHL is receiving from opportunities.

Purpose: Identify why 487 opportunities have missing UTM data

Author: MedWave Development Team
Date: November 11, 2025
"""

import os
import json
import requests
from datetime import datetime
from collections import defaultdict
import firebase_admin
from firebase_admin import credentials, firestore

# Initialize Firebase
if not firebase_admin._apps:
    cred = credentials.Certificate('medx-ai-firebase-adminsdk-fbsvc-a86e7bd050.json')
    firebase_admin.initialize_app(cred)

db = firestore.client()

# Facebook API Configuration
FB_ACCESS_TOKEN = os.environ.get('FB_ACCESS_TOKEN', 'EAAc9pw8rgA0BP0S8U9s2cLzSJbCYmJZBKZCTFUNDD2zVXVqkC45q1BIQaPdZAmtXKbZBk6wjprLclIUUafHJ4icQZAXuuePybTL38pNQIcjQQZCbRGGhAtLcLVSGeJP59nMdpt8KNEoMQtvDfZBwBgpLNhQboPpaaeU8fW2rCEEhZA9pRN4RjZAAnwnLqEDaP8Fueo0cZD')
FB_AD_ACCOUNT_ID = 'act_220298027464902'

# GHL API Configuration
GHL_API_KEY = os.environ.get('GHL_API_KEY', 'pit-22f8af95-3244-41e7-9a52-22c87b166f5a')
GHL_LOCATION_ID = os.environ.get('GHL_LOCATION_ID', 'QdLXaFEqrdF0JbVbpKLw')

# Pipeline IDs
ANDRIES_PIPELINE_ID = 'XeAGJWRnUGJ5tuhXam2g'
DAVIDE_PIPELINE_ID = 'AUduOJBB2lxlsEaNmlJz'


def get_facebook_ad_utm(ad_id):
    """Fetch UTM configuration from Facebook API"""
    url = f'https://graph.facebook.com/v18.0/{ad_id}'
    
    params = {
        'access_token': FB_ACCESS_TOKEN,
        'fields': 'id,name,status,creative{id,name,url_tags},effective_status,campaign{id,name},adset{id,name}'
    }
    
    try:
        response = requests.get(url, params=params, timeout=30)
        
        if response.status_code == 200:
            data = response.json()
            
            # Extract UTM configuration
            creative = data.get('creative', {})
            url_tags = creative.get('url_tags', '')
            
            return {
                'ad_id': ad_id,
                'ad_name': data.get('name', ''),
                'campaign_id': data.get('campaign', {}).get('id', ''),
                'campaign_name': data.get('campaign', {}).get('name', ''),
                'adset_id': data.get('adset', {}).get('id', ''),
                'adset_name': data.get('adset', {}).get('name', ''),
                'url_tags': url_tags,
                'has_utm_config': bool(url_tags),
                'has_h_ad_id': 'h_ad_id' in url_tags if url_tags else False
            }
        else:
            return None
            
    except Exception as e:
        print(f"❌ Error fetching ad {ad_id}: {e}", flush=True)
        return None


def get_recent_october_november_ads():
    """Get all ads from October and November 2025"""
    print("📊 Fetching October & November 2025 ads from Firebase...", flush=True)
    
    ads = []
    
    # Check both months
    for month in ['2025-10', '2025-11']:
        month_ref = db.collection('advertData').document(month)
        month_doc = month_ref.get()
        
        if month_doc.exists:
            ads_ref = month_ref.collection('ads')
            for ad_doc in ads_ref.stream():
                ad_data = ad_doc.to_dict()
                ads.append({
                    'ad_id': ad_doc.id,
                    'ad_name': ad_data.get('adName', ''),
                    'campaign_id': ad_data.get('campaignId', ''),
                    'campaign_name': ad_data.get('campaignName', ''),
                    'month': month
                })
    
    print(f"✅ Found {len(ads)} ads from Oct/Nov 2025", flush=True)
    return ads


def fetch_ghl_opportunities():
    """Fetch recent opportunities from GHL API"""
    print("\n📊 Fetching recent opportunities from GHL API...", flush=True)
    
    url = 'https://services.leadconnectorhq.com/opportunities/search'
    headers = {
        'Authorization': f'Bearer {GHL_API_KEY}',
        'Version': '2021-07-28',
        'Content-Type': 'application/json',
        'Accept': 'application/json'
    }
    
    opportunities = []
    page = 1
    
    while True:
        params = {
            'location_id': GHL_LOCATION_ID,
            'page': page,
            'limit': 100
        }
        
        try:
            response = requests.get(url, headers=headers, params=params, timeout=30)
            
            if response.status_code == 200:
                data = response.json()
                opps = data.get('opportunities', [])
                
                if not opps:
                    break
                
                # Filter for Andries and Davide pipelines
                for opp in opps:
                    pipeline_id = opp.get('pipelineId', '')
                    if pipeline_id in [ANDRIES_PIPELINE_ID, DAVIDE_PIPELINE_ID]:
                        opportunities.append(opp)
                
                print(f"   Page {page}: {len(opps)} opportunities (Total Andries/Davide: {len(opportunities)})", flush=True)
                
                page += 1
                
                # Safety limit
                if page > 100:
                    break
            else:
                print(f"   ❌ Error: {response.status_code}", flush=True)
                break
                
        except Exception as e:
            print(f"   ❌ Exception: {e}", flush=True)
            break
    
    print(f"✅ Total Andries & Davide opportunities: {len(opportunities)}", flush=True)
    return opportunities


def analyze_utm_configuration():
    """Main analysis function"""
    
    print("\n" + "=" * 80)
    print("FACEBOOK UTM CONFIGURATION ANALYSIS")
    print("=" * 80)
    print()
    
    # Get Facebook ads
    fb_ads = get_recent_october_november_ads()
    
    # Sample 20 ads to check their UTM configuration
    sample_size = min(20, len(fb_ads))
    sample_ads = fb_ads[:sample_size]
    
    print(f"\n🔍 Checking UTM configuration for {sample_size} sample ads...", flush=True)
    print()
    
    utm_configs = []
    ads_with_utm = 0
    ads_with_h_ad_id = 0
    ads_without_utm = 0
    
    for i, ad in enumerate(sample_ads, 1):
        print(f"   Checking ad {i}/{sample_size}: {ad['ad_id']}", flush=True)
        
        config = get_facebook_ad_utm(ad['ad_id'])
        
        if config:
            utm_configs.append(config)
            
            if config['has_utm_config']:
                ads_with_utm += 1
                if config['has_h_ad_id']:
                    ads_with_h_ad_id += 1
            else:
                ads_without_utm += 1
    
    print()
    print("=" * 80)
    print("FACEBOOK UTM CONFIGURATION RESULTS")
    print("=" * 80)
    print()
    print(f"📊 Sample Size: {len(utm_configs)} ads")
    print(f"   ✅ Ads WITH UTM config: {ads_with_utm} ({ads_with_utm/len(utm_configs)*100:.1f}%)")
    print(f"   ✅ Ads WITH h_ad_id parameter: {ads_with_h_ad_id} ({ads_with_h_ad_id/len(utm_configs)*100:.1f}%)")
    print(f"   ❌ Ads WITHOUT UTM config: {ads_without_utm} ({ads_without_utm/len(utm_configs)*100:.1f}%)")
    print()
    
    # Show example configurations
    print("=" * 80)
    print("EXAMPLE UTM CONFIGURATIONS")
    print("=" * 80)
    print()
    
    # Show ads WITH UTM
    with_utm = [c for c in utm_configs if c['has_utm_config']]
    if with_utm:
        print("✅ ADS WITH UTM CONFIGURATION:")
        print()
        for i, config in enumerate(with_utm[:3], 1):
            print(f"{i}. Ad: {config['ad_name'][:50]}")
            print(f"   ID: {config['ad_id']}")
            print(f"   Campaign: {config['campaign_name'][:60]}")
            print(f"   URL Tags: {config['url_tags']}")
            print()
    
    # Show ads WITHOUT UTM
    without_utm = [c for c in utm_configs if not c['has_utm_config']]
    if without_utm:
        print("❌ ADS WITHOUT UTM CONFIGURATION:")
        print()
        for i, config in enumerate(without_utm[:3], 1):
            print(f"{i}. Ad: {config['ad_name'][:50]}")
            print(f"   ID: {config['ad_id']}")
            print(f"   Campaign: {config['campaign_name'][:60]}")
            print(f"   ⚠️ NO URL TAGS CONFIGURED!")
            print()
    
    # Now fetch GHL opportunities and check what they're receiving
    print("=" * 80)
    print("GHL OPPORTUNITY UTM DATA ANALYSIS")
    print("=" * 80)
    print()
    
    opportunities = fetch_ghl_opportunities()
    
    # Analyze UTM data in opportunities
    opps_with_h_ad_id = 0
    opps_with_campaign_id = 0
    opps_with_ad_name = 0
    opps_with_no_utm = 0
    
    for opp in opportunities:
        attributions = opp.get('attributions', [])
        
        if not attributions:
            opps_with_no_utm += 1
            continue
        
        # Check last attribution
        last_attr = None
        for attr in attributions:
            if attr.get('isLast'):
                last_attr = attr
                break
        
        if not last_attr and attributions:
            last_attr = attributions[-1]
        
        if not last_attr:
            opps_with_no_utm += 1
            continue
        
        # Check what UTM data exists
        has_h_ad_id = bool(last_attr.get('h_ad_id') or last_attr.get('utmAdId'))
        has_campaign_id = bool(last_attr.get('utmCampaignId'))
        has_ad_name = bool(last_attr.get('utmCampaign'))
        
        if has_h_ad_id:
            opps_with_h_ad_id += 1
        elif has_campaign_id:
            opps_with_campaign_id += 1
        elif has_ad_name:
            opps_with_ad_name += 1
        else:
            opps_with_no_utm += 1
    
    print(f"📊 GHL Opportunities Analysis:")
    print(f"   Total: {len(opportunities)}")
    print(f"   ✅ WITH h_ad_id: {opps_with_h_ad_id} ({opps_with_h_ad_id/len(opportunities)*100:.1f}%)")
    print(f"   ⚠️  WITH Campaign ID (no Ad ID): {opps_with_campaign_id} ({opps_with_campaign_id/len(opportunities)*100:.1f}%)")
    print(f"   ⚠️  WITH Ad Name only: {opps_with_ad_name} ({opps_with_ad_name/len(opportunities)*100:.1f}%)")
    print(f"   ❌ NO UTM data: {opps_with_no_utm} ({opps_with_no_utm/len(opportunities)*100:.1f}%)")
    print()
    
    # Final analysis
    print("=" * 80)
    print("ROOT CAUSE ANALYSIS")
    print("=" * 80)
    print()
    
    print("🔍 KEY FINDINGS:")
    print()
    
    if ads_with_h_ad_id == len(utm_configs):
        print("✅ ALL sampled Facebook ads have h_ad_id parameter configured!")
        print("   → Facebook ads are set up correctly")
        print()
        print("❌ BUT GHL is not receiving h_ad_id for all opportunities")
        print("   → Problem is likely:")
        print("      1. Facebook Lead Forms not passing UTM parameters")
        print("      2. GHL not capturing custom parameters from forms")
        print("      3. Integration between Facebook Forms → GHL broken")
    else:
        print(f"⚠️  Only {ads_with_h_ad_id}/{len(utm_configs)} sampled ads have h_ad_id configured")
        print("   → Some Facebook ads are missing UTM configuration")
        print("   → Need to update Facebook ad settings")
    
    print()
    print("🎯 RECOMMENDATIONS:")
    print()
    print("1. Check Facebook Lead Form configuration")
    print("   - Verify that custom parameters are being passed")
    print("   - Check that h_ad_id={{ad.id}} is in the form URL")
    print()
    print("2. Check GHL Integration")
    print("   - Verify GHL is capturing custom parameters from Facebook")
    print("   - Check webhook/integration settings")
    print()
    print("3. Test with a new lead")
    print("   - Submit a test form from a Facebook ad")
    print("   - Check if h_ad_id appears in GHL opportunity")
    print()
    
    # Save detailed report
    output_file = f"facebook_utm_analysis_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
    with open(output_file, 'w') as f:
        json.dump({
            'facebook_ads': {
                'total_sampled': len(utm_configs),
                'with_utm': ads_with_utm,
                'with_h_ad_id': ads_with_h_ad_id,
                'without_utm': ads_without_utm,
                'sample_configs': utm_configs
            },
            'ghl_opportunities': {
                'total': len(opportunities),
                'with_h_ad_id': opps_with_h_ad_id,
                'with_campaign_id': opps_with_campaign_id,
                'with_ad_name': opps_with_ad_name,
                'with_no_utm': opps_with_no_utm
            }
        }, f, indent=2, default=str)
    
    print(f"📄 Detailed report saved to: {output_file}")
    print()


if __name__ == "__main__":
    analyze_utm_configuration()

