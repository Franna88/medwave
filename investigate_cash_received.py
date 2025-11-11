#!/usr/bin/env python3
"""
Investigation Script: Cash Received Opportunities in Davide's Pipeline
This script checks GHL API for opportunities with cash received and traces
why they might not be appearing in the Overview dashboard.
"""

import requests
import json
from datetime import datetime
from typing import Dict, List, Optional
from collections import defaultdict

# GHL API Configuration
GHL_API_BASE_URL = "https://services.leadconnectorhq.com"
GHL_API_VERSION = "2021-07-28"

# GHL API Configuration (from codebase)
GHL_ACCESS_TOKEN = "pit-22f8af95-3244-41e7-9a52-22c87b166f5a"  # Updated API token
GHL_LOCATION_ID = "QdLXaFEqrdF0JbVbpKLw"  # Correct location ID from functions/fullGHLSync.py
DAVIDE_PIPELINE_ID = "AUduOJBB2lxlsEaNmlJz"  # Davide's pipeline ID

class GHLInvestigator:
    def __init__(self, access_token: str, location_id: str):
        self.access_token = access_token
        self.location_id = location_id
        self.headers = {
            "Authorization": f"Bearer {access_token}",
            "Version": GHL_API_VERSION,
            "Content-Type": "application/json"
        }
        
    def get_pipelines(self) -> List[Dict]:
        """Get all pipelines for the location"""
        url = f"{GHL_API_BASE_URL}/opportunities/pipelines"
        params = {"locationId": self.location_id}
        
        try:
            response = requests.get(url, headers=self.headers, params=params)
            response.raise_for_status()
            data = response.json()
            return data.get('pipelines', [])
        except Exception as e:
            print(f"❌ Error fetching pipelines: {e}")
            return []
    
    def find_davide_pipeline(self, pipelines: List[Dict]) -> Optional[Dict]:
        """Find Davide's Pipeline - DDM"""
        for pipeline in pipelines:
            if 'DDM' in pipeline.get('name', '') or 'Davide' in pipeline.get('name', ''):
                return pipeline
        return None
    
    def get_opportunities(self, pipeline_id: str, limit: int = 100) -> List[Dict]:
        """Get all opportunities and filter by pipeline"""
        url = f"{GHL_API_BASE_URL}/opportunities/search"
        
        all_opportunities = []
        page = 1
        
        while True:
            params = {
                "location_id": self.location_id,
                "limit": limit,
                "page": page  # Use page instead of offset
            }
            
            try:
                response = requests.get(url, headers=self.headers, params=params, timeout=30)
                response.raise_for_status()
                data = response.json()
                
                opportunities = data.get('opportunities', [])
                if not opportunities:
                    break
                    
                all_opportunities.extend(opportunities)
                
                print(f"   Fetched page {page}: {len(opportunities)} opportunities (total so far: {len(all_opportunities)})")
                
                page += 1
                
                # Break if we got fewer results than the limit
                if len(opportunities) < limit:
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
        
        # Filter by pipeline ID
        pipeline_opps = [opp for opp in all_opportunities if opp.get('pipelineId') == pipeline_id]
        print(f"   Filtered to {len(pipeline_opps)} opportunities in pipeline {pipeline_id}")
        
        return pipeline_opps
    
    def analyze_cash_received_opportunities(self, opportunities: List[Dict]) -> Dict:
        """Analyze opportunities that have cash received"""
        cash_received_opps = []
        
        for opp in opportunities:
            # Check if opportunity has monetary value
            monetary_value = opp.get('monetaryValue', 0)
            status = opp.get('status', '')
            stage_name = opp.get('pipelineStageId', '')
            
            # Look for cash-related stages
            if monetary_value > 0:
                opp_data = {
                    'id': opp.get('id'),
                    'name': opp.get('name', 'Unnamed'),
                    'contact_name': opp.get('contact', {}).get('name', 'Unknown'),
                    'monetary_value': monetary_value,
                    'status': status,
                    'stage_id': stage_name,
                    'created_at': opp.get('createdAt'),
                    'updated_at': opp.get('updatedAt'),
                    'source': opp.get('source', 'Unknown'),
                    'custom_fields': opp.get('customFields', []),
                    'tags': opp.get('tags', []),
                }
                
                # Try to find campaign/ad information
                opp_data['campaign_info'] = self.extract_campaign_info(opp)
                
                cash_received_opps.append(opp_data)
        
        return {
            'total_opportunities': len(opportunities),
            'cash_received_count': len(cash_received_opps),
            'cash_received_opps': cash_received_opps,
            'total_cash_value': sum(o['monetary_value'] for o in cash_received_opps)
        }
    
    def extract_campaign_info(self, opp: Dict) -> Dict:
        """Extract campaign/ad information from opportunity"""
        campaign_info = {
            'source': opp.get('source', 'Unknown'),
            'found_campaign': None,
            'found_ad': None,
            'custom_field_campaign': None,
        }
        
        # Check tags for campaign/ad info
        tags = opp.get('tags', [])
        for tag in tags:
            tag_lower = tag.lower()
            if 'campaign' in tag_lower or 'ad' in tag_lower:
                campaign_info['found_campaign'] = tag
        
        # Check custom fields
        custom_fields = opp.get('customFields', [])
        for field in custom_fields:
            field_name = field.get('name', '').lower()
            field_value = field.get('value', '')
            
            if 'campaign' in field_name or 'ad' in field_name:
                campaign_info['custom_field_campaign'] = {
                    'field': field.get('name'),
                    'value': field_value
                }
        
        # Check source information
        source = opp.get('source', '')
        if source:
            campaign_info['source_details'] = source
            
        return campaign_info
    
    def check_firebase_matching(self, opportunities: List[Dict]) -> Dict:
        """
        Check potential issues with Firebase matching
        This analyzes why opportunities might not be showing in the dashboard
        """
        issues = {
            'missing_source': [],
            'missing_monetary_value': [],
            'no_campaign_identifier': [],
            'inactive_status': [],
        }
        
        for opp in opportunities:
            opp_id = opp.get('id')
            opp_name = opp.get('name', 'Unnamed')
            
            # Check for missing source
            if not opp.get('source'):
                issues['missing_source'].append({
                    'id': opp_id,
                    'name': opp_name
                })
            
            # Check for missing monetary value
            if opp.get('monetaryValue', 0) <= 0:
                issues['missing_monetary_value'].append({
                    'id': opp_id,
                    'name': opp_name
                })
            
            # Check if there's any campaign/ad identifier
            campaign_info = self.extract_campaign_info(opp)
            if not any([
                campaign_info.get('found_campaign'),
                campaign_info.get('custom_field_campaign'),
            ]):
                issues['no_campaign_identifier'].append({
                    'id': opp_id,
                    'name': opp_name,
                    'source': opp.get('source')
                })
            
            # Check status
            status = opp.get('status', '')
            if status not in ['open', 'won']:
                issues['inactive_status'].append({
                    'id': opp_id,
                    'name': opp_name,
                    'status': status
                })
        
        return issues


def main():
    print("=" * 80)
    print("🔍 INVESTIGATING CASH RECEIVED OPPORTUNITIES IN DAVIDE'S PIPELINE")
    print("=" * 80)
    print()
    
    # Check if token is set
    if not GHL_ACCESS_TOKEN:
        print("⚠️  WARNING: GHL_ACCESS_TOKEN not set!")
        print()
        print("To run this script, you need to:")
        print("1. Get your GHL access token from Firebase Admin SDK or GHL OAuth")
        print("2. Set it in this script or as an environment variable")
        print()
        print("For now, I'll show you what the script would do:")
        print()
        print("SCRIPT WORKFLOW:")
        print("-" * 80)
        print("1. Connect to GHL API")
        print("2. Fetch Davide's Pipeline (DDM)")
        print("3. Get all opportunities in the pipeline")
        print("4. Filter opportunities with cash received (monetary_value > 0)")
        print("5. For each cash opportunity:")
        print("   - Extract opportunity details")
        print("   - Look for campaign/ad identifiers in:")
        print("     * Tags")
        print("     * Custom fields")
        print("     * Source information")
        print("6. Analyze potential issues:")
        print("   - Missing source information")
        print("   - No campaign identifiers")
        print("   - Status issues")
        print("7. Generate report showing why cash isn't appearing in dashboard")
        print()
        print("COMMON REASONS FOR MISSING DATA:")
        print("-" * 80)
        print("❌ Opportunity source doesn't match any Facebook ad")
        print("❌ No campaign key/identifier in tags or custom fields")
        print("❌ Opportunity status is 'abandoned' or 'lost'")
        print("❌ Firebase sync hasn't run for these opportunities")
        print("❌ Campaign matching logic in PerformanceCostProvider doesn't find match")
        print()
        return
    
    # Initialize investigator
    investigator = GHLInvestigator(GHL_ACCESS_TOKEN, GHL_LOCATION_ID)
    
    # Step 1: Get pipelines
    print("📋 Step 1: Fetching pipelines...")
    pipelines = investigator.get_pipelines()
    print(f"   Found {len(pipelines)} pipelines")
    
    # Step 2: Find Davide's pipeline or use direct ID
    print()
    print("🔍 Step 2: Finding Davide's Pipeline...")
    davide_pipeline = investigator.find_davide_pipeline(pipelines)
    
    if not davide_pipeline:
        print("   ⚠️  Could not find by name, using direct Pipeline ID...")
        print(f"   Using Davide Pipeline ID: {DAVIDE_PIPELINE_ID}")
        davide_pipeline = {'id': DAVIDE_PIPELINE_ID, 'name': "Davide's Pipeline - DDM"}
    else:
        print(f"   ✅ Found: {davide_pipeline.get('name')}")
        print(f"   Pipeline ID: {davide_pipeline.get('id')}")
    
    # Step 3: Get opportunities
    print()
    print("📊 Step 3: Fetching opportunities...")
    opportunities = investigator.get_opportunities(davide_pipeline.get('id'))
    print(f"   Found {len(opportunities)} total opportunities")
    
    # Step 4: Analyze cash received opportunities
    print()
    print("💰 Step 4: Analyzing opportunities with cash received...")
    analysis = investigator.analyze_cash_received_opportunities(opportunities)
    
    print(f"   Total opportunities: {analysis['total_opportunities']}")
    print(f"   Opportunities with monetary value: {analysis['cash_received_count']}")
    print(f"   Total cash value: ${analysis['total_cash_value']:,.2f}")
    
    # Step 5: Show cash received opportunities
    print()
    print("=" * 80)
    print("💵 OPPORTUNITIES WITH CASH RECEIVED")
    print("=" * 80)
    
    for i, opp in enumerate(analysis['cash_received_opps'], 1):
        print()
        print(f"Opportunity #{i}")
        print(f"  ID: {opp['id']}")
        print(f"  Name: {opp['name']}")
        print(f"  Contact: {opp['contact_name']}")
        print(f"  Value: ${opp['monetary_value']:,.2f}")
        print(f"  Status: {opp['status']}")
        print(f"  Source: {opp['source']}")
        print(f"  Created: {opp['created_at']}")
        print()
        print(f"  Campaign Info:")
        camp_info = opp['campaign_info']
        print(f"    Source: {camp_info.get('source', 'None')}")
        print(f"    Found Campaign Tag: {camp_info.get('found_campaign', 'None')}")
        print(f"    Custom Field Campaign: {camp_info.get('custom_field_campaign', 'None')}")
        print()
        print(f"  Tags: {', '.join(opp['tags']) if opp['tags'] else 'None'}")
        print("-" * 80)
    
    # Step 6: Check for matching issues
    print()
    print("=" * 80)
    print("⚠️  POTENTIAL ISSUES (Why data might not appear in dashboard)")
    print("=" * 80)
    
    issues = investigator.check_firebase_matching(opportunities)
    
    print()
    print(f"🔴 Opportunities missing source: {len(issues['missing_source'])}")
    for item in issues['missing_source'][:5]:
        print(f"   - {item['name']} (ID: {item['id']})")
    
    print()
    print(f"🔴 Opportunities with no campaign identifier: {len(issues['no_campaign_identifier'])}")
    for item in issues['no_campaign_identifier'][:5]:
        print(f"   - {item['name']} (Source: {item['source']})")
    
    print()
    print(f"🔴 Opportunities with inactive status: {len(issues['inactive_status'])}")
    for item in issues['inactive_status'][:5]:
        print(f"   - {item['name']} (Status: {item['status']})")
    
    # Step 7: Recommendations
    print()
    print("=" * 80)
    print("💡 RECOMMENDATIONS")
    print("=" * 80)
    print()
    print("To fix the dashboard display issues:")
    print()
    print("1. Check Firebase collection 'ad_performance' to see if these opportunities exist")
    print("2. Verify the campaign matching logic in PerformanceCostProvider.mergeWithCumulativeData()")
    print("3. Ensure GHL sync is running and updating the 'ghlStats' field")
    print("4. Check if the campaign keys in Firebase match the ad source information")
    print("5. Review the GHL webhook/sync implementation in Cloud Functions")
    print()
    print("Next steps:")
    print("- Run: python inspect_firebase_data.py to check Firebase data")
    print("- Check Cloud Functions logs for any sync errors")
    print("- Verify the campaign key format matches between GHL and Facebook ads")
    print()
    
    # Save detailed report
    report_file = f"cash_received_investigation_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
    with open(report_file, 'w') as f:
        json.dump({
            'timestamp': datetime.now().isoformat(),
            'analysis': analysis,
            'issues': issues,
            'pipeline': {
                'id': davide_pipeline.get('id'),
                'name': davide_pipeline.get('name')
            }
        }, f, indent=2, default=str)
    
    print(f"📄 Detailed report saved to: {report_file}")
    print()


if __name__ == "__main__":
    main()

