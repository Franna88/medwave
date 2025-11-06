#!/usr/bin/env python3
"""
Match Davide's Pipeline Opportunities to Facebook Ads
This script fetches opportunities from Davide's Pipeline and matches them to Facebook ads
using the same logic as the automated sync system.
"""

import requests
import json
from datetime import datetime
from typing import Dict, List, Optional
from collections import defaultdict
import os
import firebase_admin
from firebase_admin import credentials, firestore
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

# Initialize Firebase
try:
    cred = credentials.Certificate('medx-ai-firebase-adminsdk-fbsvc-a86e7bd050.json')
    firebase_admin.initialize_app(cred)
except ValueError:
    # Already initialized
    pass

db = firestore.client()

# GHL API Configuration
GHL_API_BASE_URL = "https://services.leadconnectorhq.com"
GHL_API_VERSION = "2021-07-28"
GHL_ACCESS_TOKEN = os.getenv('GHL_API_KEY', 'pit-e305020a-9a42-4290-a052-daf828c3978e')
GHL_LOCATION_ID = "QdLXaFEqrdF0JbVbpKLw"
DAVIDE_PIPELINE_ID = "AUduOJBB2lxlsEaNmlJz"

def normalize_ad_name(name: str) -> str:
    """Normalize ad name for matching (same logic as opportunityHistoryService.js)"""
    if not name:
        return ''
    import re
    # Remove special characters, normalize whitespace, convert to lowercase
    normalized = re.sub(r'[^\w\s]', '', name.lower())
    normalized = re.sub(r'\s+', ' ', normalized).strip()
    return normalized

def get_ghl_headers():
    return {
        "Authorization": f"Bearer {GHL_ACCESS_TOKEN}",
        "Version": GHL_API_VERSION,
        "Content-Type": "application/json"
    }

def fetch_opportunities_from_ghl(pipeline_id: str) -> List[Dict]:
    """Fetch all opportunities from Davide's pipeline"""
    url = f"{GHL_API_BASE_URL}/opportunities/search"
    
    all_opportunities = []
    next_cursor = None
    
    print(f"📊 Fetching opportunities from GHL API...")
    
    while True:
        params = {
            "location_id": GHL_LOCATION_ID,
            "pipeline_id": pipeline_id,
            "limit": 100
        }
        
        if next_cursor:
            params['startAfterId'] = next_cursor
            params['startAfter'] = next_cursor
        
        try:
            response = requests.get(url, headers=get_ghl_headers(), params=params, timeout=30)
            response.raise_for_status()
            
            data = response.json()
            opportunities = data.get('opportunities', [])
            
            if not opportunities:
                break
            
            all_opportunities.extend(opportunities)
            print(f"   Fetched {len(opportunities)} opportunities (total: {len(all_opportunities)})")
            
            # Check for next cursor
            meta = data.get('meta', {})
            next_cursor = meta.get('nextStartAfterId') or meta.get('nextStartAfter')
            
            if not next_cursor or len(opportunities) < 100:
                break
                
        except Exception as e:
            print(f"❌ Error fetching opportunities: {e}")
            break
    
    print(f"✅ Fetched {len(all_opportunities)} total opportunities\n")
    return all_opportunities

def extract_attribution_data(opportunity: Dict) -> Dict:
    """Extract campaign and ad info from opportunity attributions"""
    # Get last attribution
    attributions = opportunity.get('attributions', [])
    last_attr = None
    
    for attr in attributions:
        if attr.get('isLast'):
            last_attr = attr
            break
    
    if not last_attr and attributions:
        last_attr = attributions[-1]
    
    if not last_attr:
        return {
            'campaignName': '',
            'campaignSource': '',
            'campaignMedium': '',
            'adId': '',
            'adName': '',
            'adSetName': ''
        }
    
    return {
        'campaignName': last_attr.get('utmCampaign', ''),
        'campaignSource': last_attr.get('utmSource', ''),
        'campaignMedium': last_attr.get('utmMedium', ''),
        'adId': last_attr.get('utmAdId') or last_attr.get('utmContent', ''),
        'adName': last_attr.get('utmContent') or last_attr.get('utmAdId', ''),
        'adSetName': last_attr.get('utmAdset') or last_attr.get('adset', '')
    }

def fetch_facebook_ads_from_firebase() -> List[Dict]:
    """Fetch all Facebook ads from adPerformance collection"""
    print(f"📊 Fetching Facebook ads from Firebase...")
    
    ads_ref = db.collection('adPerformance')
    ads_docs = ads_ref.stream()
    
    facebook_ads = []
    for doc in ads_docs:
        ad_data = doc.to_dict()
        ad_data['id'] = doc.id
        facebook_ads.append(ad_data)
    
    print(f"✅ Fetched {len(facebook_ads)} Facebook ads from Firebase\n")
    return facebook_ads

def normalize_name(name: str) -> str:
    """Normalize name for matching"""
    if not name:
        return ''
    # Remove special characters, normalize whitespace, convert to lowercase
    import re
    normalized = re.sub(r'[^\w\s]', '', name.lower())
    normalized = re.sub(r'\s+', ' ', normalized).strip()
    return normalized

def match_opportunity_to_ad(opp_attr: Dict, facebook_ads: List[Dict]) -> Optional[Dict]:
    """
    Match an opportunity to a Facebook ad using the matching logic from opportunityHistoryService.js
    
    Matching Priority:
    1. Match by Facebook Ad ID if available (most accurate)
    2. Match by Campaign + Ad Set + Ad Name (composite matching)
    3. Match by Campaign + Ad Name only (fallback)
    """
    
    campaign_name = opp_attr['campaignName']
    ad_name = opp_attr['adName']
    ad_set_name = opp_attr['adSetName']
    ad_id = opp_attr['adId']
    
    if not campaign_name:
        return None
    
    # Normalize for matching
    normalized_opp_ad_name = normalize_name(ad_name)
    normalized_opp_ad_set = normalize_name(ad_set_name)
    normalized_campaign = normalize_name(campaign_name)
    
    # Try to find matching Facebook ad
    for fb_ad in facebook_ads:
        fb_ad_id = fb_ad.get('id', '')
        fb_ad_name = fb_ad.get('adName', '')
        fb_campaign_name = fb_ad.get('campaignName', '')
        fb_ad_set_name = fb_ad.get('adSetName', '')
        
        # Normalize Facebook ad info
        normalized_fb_ad_name = normalize_name(fb_ad_name)
        normalized_fb_campaign = normalize_name(fb_campaign_name)
        normalized_fb_ad_set = normalize_name(fb_ad_set_name)
        
        # Priority 1: Match by Facebook Ad ID if available
        if ad_id and ad_id == fb_ad_id:
            return fb_ad
        
        # Priority 2: Match by Campaign Name first
        if normalized_campaign != normalized_fb_campaign:
            continue
        
        # Then match ad name
        if normalized_opp_ad_name == normalized_fb_ad_name:
            # If we have ad set info from both sides, require it to match
            if normalized_opp_ad_set and normalized_fb_ad_set:
                if normalized_opp_ad_set == normalized_fb_ad_set:
                    return fb_ad
            else:
                # Fallback: match by ad name only (backward compatibility)
                return fb_ad
    
    return None

def analyze_opportunities_with_facebook_ads(opportunities: List[Dict], facebook_ads: List[Dict]):
    """Analyze opportunities and match them to Facebook ads"""
    
    results = {
        'total_opportunities': len(opportunities),
        'with_attribution': 0,
        'with_facebook_match': 0,
        'without_facebook_match': 0,
        'matched_opportunities': [],
        'unmatched_opportunities': [],
        'no_attribution': []
    }
    
    # Group Facebook ads by campaign for easier lookup
    fb_ads_by_campaign = defaultdict(list)
    for ad in facebook_ads:
        campaign_name = normalize_name(ad.get('campaignName', ''))
        if campaign_name:
            fb_ads_by_campaign[campaign_name].append(ad)
    
    print(f"🔍 Matching opportunities to Facebook ads...\n")
    
    for opp in opportunities:
        opp_id = opp.get('id')
        opp_name = opp.get('name', 'Unnamed')
        monetary_value = float(opp.get('monetaryValue', 0))
        stage_name = opp.get('pipelineStageName', 'Unknown')
        
        # Extract attribution data
        attr = extract_attribution_data(opp)
        
        if not attr['campaignName']:
            results['no_attribution'].append({
                'id': opp_id,
                'name': opp_name,
                'value': monetary_value,
                'stage': stage_name,
                'source': opp.get('source', 'Unknown')
            })
            continue
        
        results['with_attribution'] += 1
        
        # Try to match to Facebook ad
        matched_ad = match_opportunity_to_ad(attr, facebook_ads)
        
        opp_data = {
            'id': opp_id,
            'name': opp_name,
            'value': monetary_value,
            'stage': stage_name,
            'contact': opp.get('contact', {}).get('name', 'Unknown'),
            'email': opp.get('contact', {}).get('email', 'N/A'),
            'phone': opp.get('contact', {}).get('phone', 'N/A'),
            'created': opp.get('createdAt', 'Unknown'),
            'attribution': attr
        }
        
        if matched_ad:
            results['with_facebook_match'] += 1
            opp_data['matched_facebook_ad'] = {
                'ad_id': matched_ad.get('id'),
                'ad_name': matched_ad.get('adName', ''),
                'campaign_name': matched_ad.get('campaignName', ''),
                'ad_set_name': matched_ad.get('adSetName', ''),
                'spend': matched_ad.get('facebookStats', {}).get('spend', 0),
                'impressions': matched_ad.get('facebookStats', {}).get('impressions', 0),
                'clicks': matched_ad.get('facebookStats', {}).get('clicks', 0)
            }
            results['matched_opportunities'].append(opp_data)
        else:
            results['without_facebook_match'] += 1
            opp_data['match_failure_reason'] = 'No Facebook ad found matching campaign and ad name'
            results['unmatched_opportunities'].append(opp_data)
    
    return results

def print_report(results: Dict):
    """Print comprehensive report"""
    
    print("\n" + "=" * 100)
    print("📊 DAVIDE'S PIPELINE - FACEBOOK AD MATCHING REPORT")
    print("=" * 100)
    
    # Summary
    print(f"\n📈 SUMMARY")
    print(f"{'─' * 100}")
    print(f"Total Opportunities: {results['total_opportunities']}")
    print(f"Opportunities with Attribution Data: {results['with_attribution']} ({results['with_attribution']/results['total_opportunities']*100:.1f}%)")
    print(f"Matched to Facebook Ads: {results['with_facebook_match']} ({results['with_facebook_match']/results['total_opportunities']*100:.1f}%)")
    print(f"With Attribution but No Facebook Match: {results['without_facebook_match']}")
    print(f"No Attribution Data: {len(results['no_attribution'])}")
    
    # Matched opportunities
    if results['matched_opportunities']:
        print(f"\n\n{'═' * 100}")
        print(f"✅ OPPORTUNITIES MATCHED TO FACEBOOK ADS ({len(results['matched_opportunities'])})")
        print(f"{'═' * 100}\n")
        
        # Sort by value
        matched = sorted(results['matched_opportunities'], key=lambda x: x['value'], reverse=True)
        
        for i, opp in enumerate(matched, 1):
            fb_ad = opp['matched_facebook_ad']
            print(f"\n{'─' * 100}")
            print(f"#{i} | {opp['name']}")
            print(f"{'─' * 100}")
            print(f"  💵 Value: R {opp['value']:,.2f}")
            print(f"  📊 Stage: {opp['stage']}")
            print(f"  👤 Contact: {opp['contact']} | {opp['email']}")
            print(f"  📅 Created: {opp['created']}")
            print(f"\n  📢 FACEBOOK AD MATCH:")
            print(f"     Ad Name: {fb_ad['ad_name']}")
            print(f"     Ad ID: {fb_ad['ad_id']}")
            print(f"     Campaign: {fb_ad['campaign_name']}")
            print(f"     Ad Set: {fb_ad['ad_set_name']}")
            print(f"     Spend: ${fb_ad['spend']:.2f}")
            print(f"     Impressions: {fb_ad['impressions']:,}")
            print(f"     Clicks: {fb_ad['clicks']:,}")
            print(f"\n  🎯 GHL ATTRIBUTION:")
            print(f"     Campaign: {opp['attribution']['campaignName']}")
            print(f"     Ad Name: {opp['attribution']['adName']}")
            print(f"     Ad Set: {opp['attribution']['adSetName']}")
    
    # Unmatched with attribution
    if results['unmatched_opportunities']:
        print(f"\n\n{'═' * 100}")
        print(f"⚠️  OPPORTUNITIES WITH ATTRIBUTION BUT NO FACEBOOK MATCH ({len(results['unmatched_opportunities'])})")
        print(f"{'═' * 100}\n")
        
        unmatched = sorted(results['unmatched_opportunities'], key=lambda x: x['value'], reverse=True)
        
        for i, opp in enumerate(unmatched[:10], 1):  # Show first 10
            print(f"\n{'─' * 100}")
            print(f"#{i} | {opp['name']}")
            print(f"{'─' * 100}")
            print(f"  💵 Value: R {opp['value']:,.2f}")
            print(f"  📊 Stage: {opp['stage']}")
            print(f"  👤 Contact: {opp['contact']}")
            print(f"\n  🎯 GHL ATTRIBUTION:")
            print(f"     Campaign: {opp['attribution']['campaignName']}")
            print(f"     Ad Name: {opp['attribution']['adName']}")
            print(f"     Ad Set: {opp['attribution']['adSetName']}")
            print(f"     Source: {opp['attribution']['campaignSource']}")
            print(f"\n  ❌ Reason: {opp['match_failure_reason']}")
        
        if len(unmatched) > 10:
            print(f"\n... and {len(unmatched) - 10} more")
    
    # No attribution
    if results['no_attribution']:
        print(f"\n\n{'═' * 100}")
        print(f"❌ OPPORTUNITIES WITH NO ATTRIBUTION DATA ({len(results['no_attribution'])})")
        print(f"{'═' * 100}\n")
        print("These opportunities cannot be matched to Facebook ads because they don't have campaign tracking.")
        print("Common sources: Calendly, test forms, manual entry, or other pipelines.")
        
        no_attr = sorted(results['no_attribution'], key=lambda x: x['value'], reverse=True)
        
        for i, opp in enumerate(no_attr[:10], 1):
            print(f"\n  #{i} | {opp['name']} | R {opp['value']:,.2f} | Stage: {opp['stage']} | Source: {opp['source']}")
        
        if len(no_attr) > 10:
            print(f"\n  ... and {len(no_attr) - 10} more")


def main():
    print("\n" + "=" * 100)
    print("🚀 DAVIDE'S PIPELINE - FACEBOOK AD MATCHING ANALYSIS")
    print("=" * 100)
    print(f"\nPipeline ID: {DAVIDE_PIPELINE_ID}")
    print(f"Analysis Time: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
    
    # Fetch opportunities from GHL
    opportunities = fetch_opportunities_from_ghl(DAVIDE_PIPELINE_ID)
    
    if not opportunities:
        print("\n⚠️  No opportunities found")
        return
    
    # Fetch Facebook ads from Firebase
    facebook_ads = fetch_facebook_ads_from_firebase()
    
    if not facebook_ads:
        print("\n⚠️  No Facebook ads found in Firebase. Run Facebook sync first.")
        return
    
    # Match and analyze
    results = analyze_opportunities_with_facebook_ads(opportunities, facebook_ads)
    
    # Print report
    print_report(results)
    
    # Save detailed JSON report
    report_file = f"davide_facebook_matching_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
    with open(report_file, 'w') as f:
        json.dump(results, f, indent=2, default=str)
    
    print(f"\n\n{'═' * 100}")
    print(f"💾 Detailed JSON report saved to: {report_file}")
    print(f"{'═' * 100}\n")


if __name__ == "__main__":
    main()

