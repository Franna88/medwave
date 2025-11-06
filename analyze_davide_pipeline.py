#!/usr/bin/env python3
"""
Analyze Davide's Pipeline Opportunities
This script fetches opportunities from Davide's Pipeline, shows their values,
and finds the related Facebook ads for each opportunity.
"""

import requests
import json
from datetime import datetime
from typing import Dict, List, Optional
from collections import defaultdict
import os
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

# GHL API Configuration
GHL_API_BASE_URL = "https://services.leadconnectorhq.com"
GHL_API_VERSION = "2021-07-28"
GHL_ACCESS_TOKEN = os.getenv('GHL_API_KEY', 'pit-e305020a-9a42-4290-a052-daf828c3978e')
GHL_LOCATION_ID = "QdLXaFEqrdF0JbVbpKLw"
DAVIDE_PIPELINE_ID = "AUduOJBB2lxlsEaNmlJz"  # Davide's Pipeline - DDM

class DavidePipelineAnalyzer:
    def __init__(self, access_token: str, location_id: str):
        self.access_token = access_token
        self.location_id = location_id
        self.headers = {
            "Authorization": f"Bearer {access_token}",
            "Version": GHL_API_VERSION,
            "Content-Type": "application/json"
        }
    
    def get_pipeline_stages(self, pipeline_id: str) -> Dict[str, str]:
        """Get pipeline stages to map stage IDs to names"""
        url = f"{GHL_API_BASE_URL}/opportunities/pipelines"
        params = {"locationId": self.location_id}
        
        try:
            response = requests.get(url, headers=self.headers, params=params)
            response.raise_for_status()
            data = response.json()
            
            pipelines = data.get('pipelines', [])
            for pipeline in pipelines:
                if pipeline.get('id') == pipeline_id:
                    stages = {}
                    for stage in pipeline.get('stages', []):
                        stages[stage['id']] = stage['name']
                    return stages
            
            return {}
        except Exception as e:
            print(f"❌ Error fetching pipeline stages: {e}")
            return {}
    
    def get_opportunities(self, pipeline_id: str, limit: int = 100) -> List[Dict]:
        """Get all opportunities from Davide's pipeline"""
        url = f"{GHL_API_BASE_URL}/opportunities/search"
        
        all_opportunities = []
        next_cursor = None
        
        while True:
            params = {
                "location_id": self.location_id,
                "pipeline_id": pipeline_id,
                "limit": limit
            }
            
            # Add cursor for pagination if available
            if next_cursor:
                params['startAfterId'] = next_cursor
                params['startAfter'] = next_cursor
            
            try:
                response = requests.get(url, headers=self.headers, params=params, timeout=30)
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
                
                # If no more pages, break
                if not next_cursor or len(opportunities) < limit:
                    break
                
                # Safety limit
                if len(all_opportunities) >= 1000:
                    print(f"   ⚠️  Reached safety limit of 1000 opportunities")
                    break
                    
            except Exception as e:
                print(f"❌ Error fetching opportunities: {e}")
                if hasattr(e, 'response') and e.response is not None:
                    print(f"   Response: {e.response.text}")
                break
        
        return all_opportunities
    
    def extract_ad_info(self, opp: Dict) -> Dict:
        """Extract ad information from opportunity's custom fields and source"""
        ad_info = {
            'campaign_name': None,
            'ad_name': None,
            'ad_id': None,
            'ad_set_name': None,
            'source': opp.get('source', 'Unknown'),
            'utm_params': {}
        }
        
        # Check custom fields for ad tracking data
        custom_fields = opp.get('customFields', [])
        for field in custom_fields:
            field_id = field.get('id', '')
            field_name = field.get('name', '').lower()
            field_value = field.get('value', '')
            
            # Look for known custom field IDs from the codebase
            if field_id == 'UJoVGQhVFXeIAoOkjAEK':  # h_campaign (Campaign Name)
                ad_info['campaign_name'] = field_value
            elif field_id == 'KApKi3F0Ymd0gH2e3GUl':  # h_ad_id (Facebook Ad ID)
                ad_info['ad_id'] = field_value
            elif field_id == 'XDlVWU6gXbRWO0Wz2uEf':  # h_ad_name (Ad Name)
                ad_info['ad_name'] = field_value
            elif field_id == 'R15xJ1BYD6VYhMt9fJfz':  # h_ad_set_name (Ad Set Name)
                ad_info['ad_set_name'] = field_value
            elif 'utm' in field_name or 'campaign' in field_name or 'ad' in field_name:
                ad_info['utm_params'][field_name] = field_value
        
        # Check contact custom fields if available
        contact = opp.get('contact', {})
        contact_custom_fields = contact.get('customFields', [])
        for field in contact_custom_fields:
            field_id = field.get('id', '')
            field_value = field.get('value', '')
            
            if field_id == 'UJoVGQhVFXeIAoOkjAEK' and not ad_info['campaign_name']:
                ad_info['campaign_name'] = field_value
            elif field_id == 'KApKi3F0Ymd0gH2e3GUl' and not ad_info['ad_id']:
                ad_info['ad_id'] = field_value
            elif field_id == 'XDlVWU6gXbRWO0Wz2uEf' and not ad_info['ad_name']:
                ad_info['ad_name'] = field_value
            elif field_id == 'R15xJ1BYD6VYhMt9fJfz' and not ad_info['ad_set_name']:
                ad_info['ad_set_name'] = field_value
        
        # Check tags for additional campaign info
        tags = opp.get('tags', [])
        for tag in tags:
            if 'campaign' in tag.lower() or 'ad' in tag.lower():
                if not ad_info['campaign_name']:
                    ad_info['campaign_name'] = tag
        
        return ad_info
    
    def analyze_opportunities(self, opportunities: List[Dict], stages: Dict[str, str]) -> List[Dict]:
        """Analyze opportunities and organize by value with ad info"""
        analyzed = []
        
        for opp in opportunities:
            opp_data = {
                'id': opp.get('id'),
                'name': opp.get('name', 'Unnamed'),
                'contact_name': opp.get('contact', {}).get('name', 'Unknown'),
                'contact_email': opp.get('contact', {}).get('email', 'N/A'),
                'contact_phone': opp.get('contact', {}).get('phone', 'N/A'),
                'monetary_value': float(opp.get('monetaryValue', 0)),
                'status': opp.get('status', 'unknown'),
                'stage_id': opp.get('pipelineStageId', ''),
                'stage_name': stages.get(opp.get('pipelineStageId', ''), 'Unknown Stage'),
                'created_at': opp.get('createdAt', 'Unknown'),
                'updated_at': opp.get('updatedAt', 'Unknown'),
                'ad_info': self.extract_ad_info(opp),
                'tags': opp.get('tags', [])
            }
            
            analyzed.append(opp_data)
        
        # Sort by monetary value (highest first)
        analyzed.sort(key=lambda x: x['monetary_value'], reverse=True)
        
        return analyzed
    
    def generate_report(self, opportunities: List[Dict]):
        """Generate a comprehensive report"""
        print("\n" + "=" * 100)
        print("📊 DAVIDE'S PIPELINE - OPPORTUNITIES ANALYSIS")
        print("=" * 100)
        
        # Summary statistics
        total_opps = len(opportunities)
        total_value = sum(opp['monetary_value'] for opp in opportunities)
        opps_with_value = [opp for opp in opportunities if opp['monetary_value'] > 0]
        opps_with_ads = [opp for opp in opportunities if opp['ad_info']['ad_name'] or opp['ad_info']['campaign_name']]
        
        print(f"\n📈 SUMMARY STATISTICS")
        print(f"{'─' * 100}")
        print(f"Total Opportunities: {total_opps}")
        print(f"Opportunities with Value: {len(opps_with_value)}")
        print(f"Total Pipeline Value: R {total_value:,.2f}")
        print(f"Opportunities with Ad Tracking: {len(opps_with_ads)} ({len(opps_with_ads)/total_opps*100:.1f}%)")
        print(f"Average Opportunity Value: R {total_value/total_opps if total_opps > 0 else 0:,.2f}")
        
        # Stage breakdown
        print(f"\n📊 BY STAGE")
        print(f"{'─' * 100}")
        stage_stats = defaultdict(lambda: {'count': 0, 'value': 0})
        for opp in opportunities:
            stage = opp['stage_name']
            stage_stats[stage]['count'] += 1
            stage_stats[stage]['value'] += opp['monetary_value']
        
        for stage, stats in sorted(stage_stats.items(), key=lambda x: x[1]['value'], reverse=True):
            print(f"{stage:40s} | Count: {stats['count']:3d} | Value: R {stats['value']:12,.2f}")
        
        # Ad source breakdown
        print(f"\n📢 BY AD CAMPAIGN")
        print(f"{'─' * 100}")
        campaign_stats = defaultdict(lambda: {'count': 0, 'value': 0, 'ads': set()})
        for opp in opportunities:
            campaign = opp['ad_info']['campaign_name'] or 'No Campaign Tracking'
            ad_name = opp['ad_info']['ad_name'] or 'Unknown Ad'
            campaign_stats[campaign]['count'] += 1
            campaign_stats[campaign]['value'] += opp['monetary_value']
            campaign_stats[campaign]['ads'].add(ad_name)
        
        for campaign, stats in sorted(campaign_stats.items(), key=lambda x: x[1]['value'], reverse=True):
            print(f"\n{campaign}")
            print(f"  Opportunities: {stats['count']}")
            print(f"  Total Value: R {stats['value']:,.2f}")
            print(f"  Unique Ads: {len(stats['ads'])}")
            if campaign != 'No Campaign Tracking':
                print(f"  Ads: {', '.join(sorted(stats['ads']))}")
        
        # Detailed opportunity list
        print(f"\n\n{'═' * 100}")
        print("💰 DETAILED OPPORTUNITIES LIST (Sorted by Value)")
        print(f"{'═' * 100}\n")
        
        for i, opp in enumerate(opportunities, 1):
            print(f"\n{'─' * 100}")
            print(f"#{i} | {opp['name']}")
            print(f"{'─' * 100}")
            print(f"  💵 Value: R {opp['monetary_value']:,.2f}")
            print(f"  📊 Stage: {opp['stage_name']}")
            print(f"  ✅ Status: {opp['status']}")
            print(f"  👤 Contact: {opp['contact_name']}")
            print(f"  📧 Email: {opp['contact_email']}")
            print(f"  📱 Phone: {opp['contact_phone']}")
            print(f"  📅 Created: {opp['created_at']}")
            print(f"  🔄 Updated: {opp['updated_at']}")
            
            ad_info = opp['ad_info']
            print(f"\n  📢 AD INFORMATION:")
            if ad_info['campaign_name']:
                print(f"     Campaign: {ad_info['campaign_name']}")
            if ad_info['ad_name']:
                print(f"     Ad Name: {ad_info['ad_name']}")
            if ad_info['ad_id']:
                print(f"     Ad ID: {ad_info['ad_id']}")
                print(f"     Ad URL: https://www.facebook.com/ads/library/?id={ad_info['ad_id']}")
            if ad_info['ad_set_name']:
                print(f"     Ad Set: {ad_info['ad_set_name']}")
            if not any([ad_info['campaign_name'], ad_info['ad_name'], ad_info['ad_id']]):
                print(f"     ⚠️  No ad tracking data found")
                print(f"     Source: {ad_info['source']}")
            
            if ad_info['utm_params']:
                print(f"     UTM Params: {ad_info['utm_params']}")
            
            if opp['tags']:
                print(f"\n  🏷️  Tags: {', '.join(opp['tags'])}")
            
            print()


def main():
    print("\n" + "=" * 100)
    print("🚀 ANALYZING DAVIDE'S PIPELINE")
    print("=" * 100)
    print(f"\nPipeline ID: {DAVIDE_PIPELINE_ID}")
    print(f"Location ID: {GHL_LOCATION_ID}")
    print(f"Analysis Time: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    
    if not GHL_ACCESS_TOKEN:
        print("\n❌ ERROR: GHL_API_KEY not found!")
        print("Please set the GHL_API_KEY environment variable or add it to .env file")
        return
    
    # Initialize analyzer
    analyzer = DavidePipelineAnalyzer(GHL_ACCESS_TOKEN, GHL_LOCATION_ID)
    
    # Get pipeline stages
    print("\n📋 Fetching pipeline stages...")
    stages = analyzer.get_pipeline_stages(DAVIDE_PIPELINE_ID)
    if stages:
        print(f"   Found {len(stages)} stages:")
        for stage_id, stage_name in stages.items():
            print(f"      - {stage_name}")
    else:
        print("   ⚠️  Could not fetch stages")
    
    # Get opportunities
    print(f"\n📊 Fetching opportunities from Davide's Pipeline...")
    opportunities = analyzer.get_opportunities(DAVIDE_PIPELINE_ID)
    
    if not opportunities:
        print("\n⚠️  No opportunities found in Davide's Pipeline")
        return
    
    print(f"\n✅ Successfully fetched {len(opportunities)} opportunities")
    
    # Analyze opportunities
    print(f"\n🔍 Analyzing opportunities...")
    analyzed = analyzer.analyze_opportunities(opportunities, stages)
    
    # Generate report
    analyzer.generate_report(analyzed)
    
    # Save detailed JSON report
    report_file = f"davide_pipeline_analysis_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
    with open(report_file, 'w') as f:
        json.dump({
            'timestamp': datetime.now().isoformat(),
            'pipeline_id': DAVIDE_PIPELINE_ID,
            'pipeline_name': "Davide's Pipeline - DDM",
            'total_opportunities': len(analyzed),
            'total_value': sum(opp['monetary_value'] for opp in analyzed),
            'opportunities': analyzed
        }, f, indent=2, default=str)
    
    print(f"\n\n{'═' * 100}")
    print(f"💾 Detailed JSON report saved to: {report_file}")
    print(f"{'═' * 100}\n")


if __name__ == "__main__":
    main()

