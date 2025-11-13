#!/usr/bin/env python3
"""
Verify Weekly Summary Collection
Checks the summary collection for data integrity and completeness
"""

import firebase_admin
from firebase_admin import credentials, firestore
from collections import defaultdict

# ============================================================================
# CONFIGURATION
# ============================================================================

FIREBASE_CRED_PATH = 'medx-ai-firebase-adminsdk-fbsvc-a86e7bd050.json'

# ============================================================================
# VERIFICATION FUNCTIONS
# ============================================================================

def verify_summary_collection(db):
    """Verify the summary collection structure and data"""
    print("="*80)
    print("WEEKLY SUMMARY COLLECTION VERIFICATION")
    print("="*80)
    
    # Get all summary documents
    summaries = list(db.collection('summary').stream())
    
    if not summaries:
        print("❌ No summary documents found!")
        return
    
    print(f"\n✅ Found {len(summaries)} campaign summaries\n")
    
    total_weeks = 0
    total_ads = 0
    total_ad_sets = 0
    campaigns_with_data = 0
    
    fb_spend_total = 0
    ghl_leads_total = 0
    ghl_bookings_total = 0
    ghl_deposits_total = 0
    ghl_cash_total = 0
    ghl_cash_amount_total = 0
    
    # Verify each campaign
    for summary_doc in summaries:
        campaign_data = summary_doc.to_dict()
        campaign_id = summary_doc.id
        campaign_name = campaign_data.get('campaignName', 'Unknown')
        weeks = campaign_data.get('weeks', {})
        
        if not weeks:
            print(f"⚠️  Campaign {campaign_id} ({campaign_name}) has no weeks")
            continue
        
        campaigns_with_data += 1
        total_weeks += len(weeks)
        
        print(f"\n📊 Campaign: {campaign_name}")
        print(f"   ID: {campaign_id}")
        print(f"   Weeks: {len(weeks)}")
        
        # Analyze weeks
        for week_id, week_data in weeks.items():
            ads = week_data.get('ads', {})
            ad_sets = week_data.get('adSets', {})
            campaign_metrics = week_data.get('campaign', {})
            
            total_ads += len(ads)
            total_ad_sets += len(ad_sets)
            
            # Get campaign totals for this week
            fb_insights = campaign_metrics.get('facebookInsights', {})
            ghl_data = campaign_metrics.get('ghlData', {})
            
            fb_spend_total += fb_insights.get('spend', 0)
            ghl_leads_total += ghl_data.get('leads', 0)
            ghl_bookings_total += ghl_data.get('bookedAppointments', 0)
            ghl_deposits_total += ghl_data.get('deposits', 0)
            ghl_cash_total += ghl_data.get('cashCollected', 0)
            ghl_cash_amount_total += ghl_data.get('cashAmount', 0)
            
            print(f"   Week {week_id}:")
            print(f"      Ads: {len(ads)}, Ad Sets: {len(ad_sets)}")
            print(f"      FB Spend: R {fb_insights.get('spend', 0):.2f}")
            print(f"      GHL: {ghl_data.get('leads', 0)} leads, {ghl_data.get('bookedAppointments', 0)} bookings, "
                  f"{ghl_data.get('deposits', 0)} deposits, {ghl_data.get('cashCollected', 0)} cash")
    
    # Overall summary
    print(f"\n{'='*80}")
    print("OVERALL SUMMARY")
    print(f"{'='*80}")
    print(f"✅ Total campaigns: {len(summaries)}")
    print(f"✅ Campaigns with data: {campaigns_with_data}")
    print(f"✅ Total weeks: {total_weeks}")
    print(f"✅ Total ads (across all weeks): {total_ads}")
    print(f"✅ Total ad sets (across all weeks): {total_ad_sets}")
    print(f"\n📊 FACEBOOK TOTALS:")
    print(f"   Total Spend: R {fb_spend_total:,.2f}")
    print(f"\n📊 GHL TOTALS:")
    print(f"   Leads: {ghl_leads_total}")
    print(f"   Booked Appointments: {ghl_bookings_total}")
    print(f"   Deposits: {ghl_deposits_total}")
    print(f"   Cash Collected: {ghl_cash_total}")
    print(f"   Cash Amount: R {ghl_cash_amount_total:,.2f}")
    print(f"{'='*80}")

def verify_data_integrity(db):
    """Verify data integrity - check aggregations"""
    print(f"\n{'='*80}")
    print("DATA INTEGRITY CHECKS")
    print(f"{'='*80}")
    
    summaries = list(db.collection('summary').stream())
    
    issues_found = 0
    
    for summary_doc in summaries:
        campaign_data = summary_doc.to_dict()
        campaign_id = summary_doc.id
        weeks = campaign_data.get('weeks', {})
        
        for week_id, week_data in weeks.items():
            ads = week_data.get('ads', {})
            ad_sets = week_data.get('adSets', {})
            campaign_metrics = week_data.get('campaign', {})
            
            # Verify ad set aggregation
            for ad_set_id, ad_set_data in ad_sets.items():
                # Calculate expected totals from ads
                expected_fb = {'spend': 0, 'impressions': 0, 'reach': 0, 'clicks': 0}
                expected_ghl = {'leads': 0, 'bookedAppointments': 0, 'deposits': 0, 'cashCollected': 0, 'cashAmount': 0}
                
                for ad_id, ad_data in ads.items():
                    # Check if this ad belongs to this ad set
                    # (We don't have adSetId in ad data, so skip this check)
                    pass
                
                # Note: Can't verify ad set aggregation without ad-to-adset mapping in the data
            
            # Verify campaign aggregation
            expected_fb = {'spend': 0, 'impressions': 0, 'reach': 0, 'clicks': 0}
            expected_ghl = {'leads': 0, 'bookedAppointments': 0, 'deposits': 0, 'cashCollected': 0, 'cashAmount': 0}
            
            for ad_id, ad_data in ads.items():
                fb = ad_data.get('facebookInsights', {})
                ghl = ad_data.get('ghlData', {})
                
                for key in expected_fb:
                    expected_fb[key] += fb.get(key, 0)
                for key in expected_ghl:
                    expected_ghl[key] += ghl.get(key, 0)
            
            # Compare with actual campaign totals
            actual_fb = campaign_metrics.get('facebookInsights', {})
            actual_ghl = campaign_metrics.get('ghlData', {})
            
            # Check Facebook metrics
            for key in expected_fb:
                expected = expected_fb[key]
                actual = actual_fb.get(key, 0)
                
                # Allow small floating point differences
                if abs(expected - actual) > 0.01:
                    print(f"⚠️  Campaign {campaign_id}, Week {week_id}: FB {key} mismatch")
                    print(f"   Expected: {expected}, Actual: {actual}")
                    issues_found += 1
            
            # Check GHL metrics
            for key in expected_ghl:
                expected = expected_ghl[key]
                actual = actual_ghl.get(key, 0)
                
                # Allow small floating point differences for cashAmount
                tolerance = 0.01 if key == 'cashAmount' else 0
                if abs(expected - actual) > tolerance:
                    print(f"⚠️  Campaign {campaign_id}, Week {week_id}: GHL {key} mismatch")
                    print(f"   Expected: {expected}, Actual: {actual}")
                    issues_found += 1
    
    if issues_found == 0:
        print("✅ All aggregations are correct!")
    else:
        print(f"\n⚠️  Found {issues_found} aggregation issues")
    
    print(f"{'='*80}")

def sample_campaign_details(db):
    """Show detailed data for a sample campaign"""
    print(f"\n{'='*80}")
    print("SAMPLE CAMPAIGN DETAILS")
    print(f"{'='*80}")
    
    # Get first campaign with data
    summaries = list(db.collection('summary').limit(1).stream())
    
    if not summaries:
        print("❌ No campaigns found")
        return
    
    campaign_data = summaries[0].to_dict()
    campaign_id = summaries[0].id
    campaign_name = campaign_data.get('campaignName', 'Unknown')
    weeks = campaign_data.get('weeks', {})
    
    print(f"\n📊 Campaign: {campaign_name}")
    print(f"   ID: {campaign_id}")
    print(f"   Total Weeks: {len(weeks)}")
    
    # Show first week in detail
    if weeks:
        first_week_id = list(weeks.keys())[0]
        week_data = weeks[first_week_id]
        
        print(f"\n   Week: {first_week_id}")
        print(f"   Date Range: {week_data.get('dateRange', 'Unknown')}")
        print(f"   Month: {week_data.get('month', 'Unknown')}")
        print(f"   Week Number: {week_data.get('weekNumber', 'Unknown')}")
        
        ads = week_data.get('ads', {})
        print(f"\n   Ads in this week: {len(ads)}")
        
        # Show first ad
        if ads:
            first_ad_id = list(ads.keys())[0]
            ad_data = ads[first_ad_id]
            
            print(f"\n   Sample Ad:")
            print(f"      ID: {first_ad_id}")
            print(f"      Name: {ad_data.get('adName', 'Unknown')}")
            print(f"      Facebook Insights: {ad_data.get('facebookInsights', {})}")
            print(f"      GHL Data: {ad_data.get('ghlData', {})}")
        
        # Show campaign totals for this week
        campaign_metrics = week_data.get('campaign', {})
        print(f"\n   Campaign Totals (this week):")
        print(f"      Facebook: {campaign_metrics.get('facebookInsights', {})}")
        print(f"      GHL: {campaign_metrics.get('ghlData', {})}")
    
    print(f"{'='*80}")

# ============================================================================
# MAIN FUNCTION
# ============================================================================

def main():
    """Main verification function"""
    # Initialize Firebase
    if not firebase_admin._apps:
        cred = credentials.Certificate(FIREBASE_CRED_PATH)
        firebase_admin.initialize_app(cred)
    db = firestore.client()
    
    # Run verifications
    verify_summary_collection(db)
    verify_data_integrity(db)
    sample_campaign_details(db)
    
    print("\n✅ Verification complete!")

if __name__ == '__main__':
    main()

