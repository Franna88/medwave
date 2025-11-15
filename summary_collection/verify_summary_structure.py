#!/usr/bin/env python3
"""
Verify Summary Structure
=========================
This script compares the structure of documents in the summary collection
to ensure they match the expected format.

Usage:
  python3 verify_summary_structure.py [campaign_id]
  
  If campaign_id is provided, shows detailed structure for that campaign.
  Otherwise, shows summary statistics for all campaigns.
"""

import firebase_admin
from firebase_admin import credentials, firestore
import sys
import json

FIREBASE_CRED_PATH = '/Users/mac/dev/medwave/medx-ai-firebase-adminsdk-fbsvc-a86e7bd050.json'

def verify_campaign_structure(campaign_id, campaign_data):
    """Verify a single campaign document structure"""
    issues = []
    
    # Check top-level fields
    required_fields = ['campaignId', 'campaignName', 'weeks']
    for field in required_fields:
        if field not in campaign_data:
            issues.append(f"Missing required field: {field}")
    
    # Check weeks structure
    weeks = campaign_data.get('weeks', {})
    if not isinstance(weeks, dict):
        issues.append(f"'weeks' should be a dict, got {type(weeks)}")
        return issues
    
    for week_id, week_data in weeks.items():
        # Verify week ID format
        if '_' not in week_id:
            issues.append(f"Invalid week ID format: {week_id}")
        
        # Check week fields
        week_required = ['month', 'dateRange', 'weekNumber', 'campaign', 'adSets', 'ads']
        for field in week_required:
            if field not in week_data:
                issues.append(f"Week {week_id} missing field: {field}")
        
        # Check campaign data in week
        if 'campaign' in week_data:
            campaign_week = week_data['campaign']
            campaign_required = ['campaignId', 'campaignName', 'facebookInsights', 'ghlData']
            for field in campaign_required:
                if field not in campaign_week:
                    issues.append(f"Week {week_id} campaign missing field: {field}")
            
            # Check facebookInsights
            if 'facebookInsights' in campaign_week:
                fb = campaign_week['facebookInsights']
                fb_required = ['spend', 'impressions', 'reach', 'clicks', 'cpm', 'cpc', 'ctr']
                for field in fb_required:
                    if field not in fb:
                        issues.append(f"Week {week_id} campaign facebookInsights missing: {field}")
            
            # Check ghlData
            if 'ghlData' in campaign_week:
                ghl = campaign_week['ghlData']
                ghl_required = ['leads', 'bookedAppointments', 'deposits', 'cashCollected', 'cashAmount']
                for field in ghl_required:
                    if field not in ghl:
                        issues.append(f"Week {week_id} campaign ghlData missing: {field}")
    
    return issues

def main():
    """Main execution"""
    print("="*80)
    print("SUMMARY COLLECTION STRUCTURE VERIFICATION")
    print("="*80)
    
    # Initialize Firebase
    if not firebase_admin._apps:
        cred = credentials.Certificate(FIREBASE_CRED_PATH)
        firebase_admin.initialize_app(cred)
    db = firestore.client()
    
    # Check if specific campaign ID provided
    if len(sys.argv) > 1:
        campaign_id = sys.argv[1]
        print(f"\nVerifying campaign: {campaign_id}")
        
        doc = db.collection('summary').document(campaign_id).get()
        if not doc.exists:
            print(f"❌ Campaign {campaign_id} not found in summary collection")
            return
        
        campaign_data = doc.to_dict()
        issues = verify_campaign_structure(campaign_id, campaign_data)
        
        if issues:
            print(f"\n❌ Found {len(issues)} issues:")
            for issue in issues:
                print(f"  - {issue}")
        else:
            print(f"\n✅ Campaign structure is valid")
        
        # Show detailed structure
        print(f"\nCampaign: {campaign_data.get('campaignName')}")
        print(f"Weeks: {len(campaign_data.get('weeks', {}))}")
        
        weeks = campaign_data.get('weeks', {})
        for week_id in sorted(weeks.keys()):
            week_data = weeks[week_id]
            campaign_week = week_data.get('campaign', {})
            fb = campaign_week.get('facebookInsights', {})
            ghl = campaign_week.get('ghlData', {})
            
            print(f"\n  Week: {week_id}")
            print(f"    Month: {week_data.get('month')}")
            print(f"    Date Range: {week_data.get('dateRange')}")
            print(f"    Ads: {len(week_data.get('ads', {}))}")
            print(f"    Ad Sets: {len(week_data.get('adSets', {}))}")
            print(f"    FB Spend: R {fb.get('spend', 0):,.2f}")
            print(f"    GHL Leads: {ghl.get('leads', 0)}")
            print(f"    GHL Cash: R {ghl.get('cashAmount', 0):,.2f}")
    
    else:
        # Verify all campaigns
        print("\nVerifying all campaigns in summary collection...")
        
        campaigns = db.collection('summary').stream()
        
        total_campaigns = 0
        campaigns_with_issues = 0
        total_issues = 0
        total_weeks = 0
        total_ads = 0
        
        campaigns_list = []
        
        for campaign_doc in campaigns:
            total_campaigns += 1
            campaign_id = campaign_doc.id
            campaign_data = campaign_doc.to_dict()
            
            issues = verify_campaign_structure(campaign_id, campaign_data)
            
            weeks = campaign_data.get('weeks', {})
            total_weeks += len(weeks)
            
            # Count ads
            for week_data in weeks.values():
                total_ads += len(week_data.get('ads', {}))
            
            if issues:
                campaigns_with_issues += 1
                total_issues += len(issues)
                campaigns_list.append({
                    'id': campaign_id,
                    'name': campaign_data.get('campaignName', 'Unknown'),
                    'issues': len(issues),
                    'weeks': len(weeks)
                })
            else:
                campaigns_list.append({
                    'id': campaign_id,
                    'name': campaign_data.get('campaignName', 'Unknown'),
                    'issues': 0,
                    'weeks': len(weeks)
                })
        
        print(f"\n{'='*80}")
        print("VERIFICATION SUMMARY")
        print(f"{'='*80}")
        print(f"Total campaigns: {total_campaigns}")
        print(f"Total weeks: {total_weeks}")
        print(f"Total ads: {total_ads}")
        print(f"Campaigns with issues: {campaigns_with_issues}")
        print(f"Total issues found: {total_issues}")
        
        if campaigns_with_issues > 0:
            print(f"\n❌ Campaigns with issues:")
            for campaign in campaigns_list:
                if campaign['issues'] > 0:
                    print(f"  - {campaign['name'][:60]} ({campaign['issues']} issues, {campaign['weeks']} weeks)")
        else:
            print(f"\n✅ All campaigns have valid structure!")
        
        # Show top campaigns by weeks
        print(f"\nTop 10 campaigns by week count:")
        campaigns_list.sort(key=lambda x: x['weeks'], reverse=True)
        for i, campaign in enumerate(campaigns_list[:10], 1):
            status = "✅" if campaign['issues'] == 0 else "❌"
            print(f"  {i}. {status} {campaign['name'][:60]} ({campaign['weeks']} weeks)")
    
    print(f"\n{'='*80}")

if __name__ == '__main__':
    main()

