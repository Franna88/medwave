#!/usr/bin/env python3
"""
Compare Summary Data
====================
This script compares summary collection data before and after rebuild
to identify differences in metrics.

Usage:
  python3 compare_summary_data.py [campaign_id]
  
  If campaign_id provided, shows detailed comparison for that campaign.
  Otherwise, shows summary comparison for all campaigns.
"""

import firebase_admin
from firebase_admin import credentials, firestore
import sys
from collections import defaultdict

FIREBASE_CRED_PATH = '/Users/mac/dev/medwave/medx-ai-firebase-adminsdk-fbsvc-a86e7bd050.json'

def get_campaign_totals(campaign_data):
    """Calculate total metrics across all weeks for a campaign"""
    totals = {
        'spend': 0,
        'impressions': 0,
        'clicks': 0,
        'reach': 0,
        'leads': 0,
        'bookedAppointments': 0,
        'deposits': 0,
        'cashCollected': 0,
        'cashAmount': 0,
        'weeks': 0,
        'ads': set(),
        'adSets': set()
    }
    
    weeks = campaign_data.get('weeks', {})
    totals['weeks'] = len(weeks)
    
    for week_id, week_data in weeks.items():
        # Campaign level data
        campaign_week = week_data.get('campaign', {})
        fb = campaign_week.get('facebookInsights', {})
        ghl = campaign_week.get('ghlData', {})
        
        totals['spend'] += fb.get('spend', 0)
        totals['impressions'] += fb.get('impressions', 0)
        totals['clicks'] += fb.get('clicks', 0)
        totals['reach'] += fb.get('reach', 0)
        
        totals['leads'] += ghl.get('leads', 0)
        totals['bookedAppointments'] += ghl.get('bookedAppointments', 0)
        totals['deposits'] += ghl.get('deposits', 0)
        totals['cashCollected'] += ghl.get('cashCollected', 0)
        totals['cashAmount'] += ghl.get('cashAmount', 0)
        
        # Count unique ads and ad sets
        totals['ads'].update(week_data.get('ads', {}).keys())
        totals['adSets'].update(week_data.get('adSets', {}).keys())
    
    totals['ads'] = len(totals['ads'])
    totals['adSets'] = len(totals['adSets'])
    
    return totals

def compare_campaigns(campaign_id, old_data, new_data):
    """Compare old and new data for a campaign"""
    old_totals = get_campaign_totals(old_data) if old_data else None
    new_totals = get_campaign_totals(new_data) if new_data else None
    
    if not old_totals and not new_totals:
        return None
    
    if not old_totals:
        return {
            'status': 'NEW',
            'new': new_totals
        }
    
    if not new_totals:
        return {
            'status': 'REMOVED',
            'old': old_totals
        }
    
    # Calculate differences
    diff = {}
    metrics = ['spend', 'impressions', 'clicks', 'reach', 'leads', 
               'bookedAppointments', 'deposits', 'cashCollected', 'cashAmount',
               'weeks', 'ads', 'adSets']
    
    has_changes = False
    for metric in metrics:
        old_val = old_totals.get(metric, 0)
        new_val = new_totals.get(metric, 0)
        
        if old_val != new_val:
            has_changes = True
            diff[metric] = {
                'old': old_val,
                'new': new_val,
                'change': new_val - old_val,
                'percent': ((new_val - old_val) / old_val * 100) if old_val > 0 else 0
            }
    
    return {
        'status': 'CHANGED' if has_changes else 'UNCHANGED',
        'old': old_totals,
        'new': new_totals,
        'diff': diff
    }

def main():
    """Main execution"""
    print("="*80)
    print("SUMMARY DATA COMPARISON")
    print("="*80)
    print("\n⚠️  NOTE: This script is for BEFORE/AFTER comparison")
    print("   Run this BEFORE rebuilding to capture current state,")
    print("   then run again AFTER rebuilding to see differences.")
    print("="*80)
    
    # Initialize Firebase
    if not firebase_admin._apps:
        cred = credentials.Certificate(FIREBASE_CRED_PATH)
        firebase_admin.initialize_app(cred)
    db = firestore.client()
    
    # For now, just show current state
    # In a real before/after comparison, you'd save state to a file first
    
    if len(sys.argv) > 1:
        # Compare specific campaign
        campaign_id = sys.argv[1]
        print(f"\nShowing current state for campaign: {campaign_id}")
        
        doc = db.collection('summary').document(campaign_id).get()
        if not doc.exists:
            print(f"❌ Campaign {campaign_id} not found")
            return
        
        campaign_data = doc.to_dict()
        totals = get_campaign_totals(campaign_data)
        
        print(f"\nCampaign: {campaign_data.get('campaignName')}")
        print(f"Campaign ID: {campaign_id}")
        print(f"\nMetrics:")
        print(f"  Weeks: {totals['weeks']}")
        print(f"  Ad Sets: {totals['adSets']}")
        print(f"  Ads: {totals['ads']}")
        print(f"\nFacebook Metrics:")
        print(f"  Spend: R {totals['spend']:,.2f}")
        print(f"  Impressions: {totals['impressions']:,}")
        print(f"  Clicks: {totals['clicks']:,}")
        print(f"  Reach: {totals['reach']:,}")
        print(f"\nGHL Metrics:")
        print(f"  Leads: {totals['leads']}")
        print(f"  Booked Appointments: {totals['bookedAppointments']}")
        print(f"  Deposits: {totals['deposits']}")
        print(f"  Cash Collected: {totals['cashCollected']}")
        print(f"  Cash Amount: R {totals['cashAmount']:,.2f}")
        
        # Show week breakdown
        print(f"\nWeek Breakdown:")
        weeks = campaign_data.get('weeks', {})
        for week_id in sorted(weeks.keys()):
            week_data = weeks[week_id]
            campaign_week = week_data.get('campaign', {})
            fb = campaign_week.get('facebookInsights', {})
            ghl = campaign_week.get('ghlData', {})
            
            print(f"\n  {week_id} ({week_data.get('dateRange')})")
            print(f"    Ads: {len(week_data.get('ads', {}))}")
            print(f"    Spend: R {fb.get('spend', 0):,.2f}")
            print(f"    Leads: {ghl.get('leads', 0)}")
            print(f"    Cash: R {ghl.get('cashAmount', 0):,.2f}")
    
    else:
        # Show all campaigns summary
        print("\nLoading all campaigns from summary collection...")
        
        campaigns = db.collection('summary').stream()
        
        campaign_summaries = []
        
        for campaign_doc in campaigns:
            campaign_id = campaign_doc.id
            campaign_data = campaign_doc.to_dict()
            totals = get_campaign_totals(campaign_data)
            
            campaign_summaries.append({
                'id': campaign_id,
                'name': campaign_data.get('campaignName', 'Unknown'),
                'totals': totals
            })
        
        print(f"\n{'='*80}")
        print(f"CURRENT SUMMARY STATE")
        print(f"{'='*80}")
        print(f"Total campaigns: {len(campaign_summaries)}")
        
        # Calculate grand totals
        grand_totals = {
            'spend': 0,
            'leads': 0,
            'cashAmount': 0,
            'weeks': 0,
            'ads': 0
        }
        
        for campaign in campaign_summaries:
            totals = campaign['totals']
            grand_totals['spend'] += totals['spend']
            grand_totals['leads'] += totals['leads']
            grand_totals['cashAmount'] += totals['cashAmount']
            grand_totals['weeks'] += totals['weeks']
            grand_totals['ads'] += totals['ads']
        
        print(f"\nGrand Totals Across All Campaigns:")
        print(f"  Total Spend: R {grand_totals['spend']:,.2f}")
        print(f"  Total Leads: {grand_totals['leads']:,}")
        print(f"  Total Cash: R {grand_totals['cashAmount']:,.2f}")
        print(f"  Total Weeks: {grand_totals['weeks']}")
        print(f"  Total Ads: {grand_totals['ads']}")
        
        # Show top campaigns
        print(f"\nTop 10 Campaigns by Spend:")
        campaign_summaries.sort(key=lambda x: x['totals']['spend'], reverse=True)
        for i, campaign in enumerate(campaign_summaries[:10], 1):
            totals = campaign['totals']
            print(f"  {i}. {campaign['name'][:50]}")
            print(f"     Spend: R {totals['spend']:,.2f}, Leads: {totals['leads']}, Cash: R {totals['cashAmount']:,.2f}")
        
        print(f"\nTop 10 Campaigns by Leads:")
        campaign_summaries.sort(key=lambda x: x['totals']['leads'], reverse=True)
        for i, campaign in enumerate(campaign_summaries[:10], 1):
            totals = campaign['totals']
            print(f"  {i}. {campaign['name'][:50]}")
            print(f"     Leads: {totals['leads']}, Spend: R {totals['spend']:,.2f}, Cash: R {totals['cashAmount']:,.2f}")
        
        print(f"\nTop 10 Campaigns by Cash Amount:")
        campaign_summaries.sort(key=lambda x: x['totals']['cashAmount'], reverse=True)
        for i, campaign in enumerate(campaign_summaries[:10], 1):
            totals = campaign['totals']
            print(f"  {i}. {campaign['name'][:50]}")
            print(f"     Cash: R {totals['cashAmount']:,.2f}, Leads: {totals['leads']}, Spend: R {totals['spend']:,.2f}")
    
    print(f"\n{'='*80}")
    print("\n💡 TIP: To compare before/after:")
    print("   1. Run this script and save output: python3 compare_summary_data.py > before.txt")
    print("   2. Run rebuild script: python3 rebuild_summary_from_firebase.py")
    print("   3. Run this script again: python3 compare_summary_data.py > after.txt")
    print("   4. Compare files: diff before.txt after.txt")
    print("="*80)

if __name__ == '__main__':
    main()

