#!/usr/bin/env python3
"""
Verify Campaign Totals - Are they timeframe-based or lifetime-based?
Checks if campaign/adSet totals match the sum of their ads within date ranges
"""

import firebase_admin
from firebase_admin import credentials, firestore
from datetime import datetime

# Initialize Firebase
if not firebase_admin._apps:
    cred = credentials.Certificate('medx-ai-firebase-adminsdk-fbsvc-a86e7bd050.json')
    firebase_admin.initialize_app(cred)

db = firestore.client()

def verify_campaign(campaign_id):
    """Verify if a campaign's totals match its ads within its date range"""
    
    print('=' * 80)
    print(f'VERIFYING CAMPAIGN: {campaign_id}')
    print('=' * 80)
    print()
    
    # Get campaign document
    campaign_doc = db.collection('campaigns').document(campaign_id).get()
    if not campaign_doc.exists:
        print(f'❌ Campaign {campaign_id} not found!')
        return
    
    campaign = campaign_doc.to_dict()
    
    print('📋 CAMPAIGN DATA:')
    print(f'   Name: {campaign.get("campaignName", "Unknown")}')
    print(f'   First Ad Date: {campaign.get("firstAdDate")}')
    print(f'   Last Ad Date: {campaign.get("lastAdDate")}')
    print(f'   Total Spend (stored): ${campaign.get("totalSpend", 0):,.2f}')
    print(f'   Total Leads (stored): {campaign.get("totalLeads", 0)}')
    print(f'   Total Profit (stored): ${campaign.get("totalProfit", 0):,.2f}')
    print()
    
    # Get all ads for this campaign
    ads = list(db.collection('ads').where('campaignId', '==', campaign_id).stream())
    
    print(f'📊 FOUND {len(ads)} ADS:')
    print()
    
    # Calculate totals from ads
    calculated_spend = 0
    calculated_leads = 0
    calculated_cash = 0
    
    campaign_first_date = campaign.get('firstAdDate')
    campaign_last_date = campaign.get('lastAdDate')
    
    # Convert to string if Timestamp
    if hasattr(campaign_first_date, 'strftime'):
        campaign_first_date = campaign_first_date.strftime('%Y-%m-%d')
    if hasattr(campaign_last_date, 'strftime'):
        campaign_last_date = campaign_last_date.strftime('%Y-%m-%d')
    
    ads_within_range = 0
    ads_outside_range = 0
    
    for i, ad_doc in enumerate(ads, 1):
        ad = ad_doc.to_dict()
        ad_id = ad_doc.id
        ad_name = ad.get('adName', 'Unknown')
        
        first_insight = ad.get('firstInsightDate', '')
        last_insight = ad.get('lastInsightDate', '')
        
        fb_stats = ad.get('facebookStats', {})
        ghl_stats = ad.get('ghlStats', {})
        
        ad_spend = fb_stats.get('spend', 0)
        ad_leads = ghl_stats.get('leads', 0)
        ad_cash = ghl_stats.get('cashAmount', 0)
        
        # Check if ad is within campaign date range
        within_range = True
        if campaign_first_date and campaign_last_date:
            if first_insight and last_insight:
                if first_insight < campaign_first_date or last_insight > campaign_last_date:
                    within_range = False
        
        if within_range:
            ads_within_range += 1
            calculated_spend += ad_spend
            calculated_leads += ad_leads
            calculated_cash += ad_cash
        else:
            ads_outside_range += 1
        
        # Print first 5 ads as examples
        if i <= 5:
            print(f'{i}. {ad_name[:50]}')
            print(f'   Ad ID: {ad_id}')
            print(f'   Date Range: {first_insight} to {last_insight}')
            print(f'   Spend: ${ad_spend:,.2f}')
            print(f'   Leads: {ad_leads}')
            print(f'   Cash: ${ad_cash:,.2f}')
            if not within_range:
                print(f'   ⚠️  OUTSIDE campaign date range!')
            print()
    
    if len(ads) > 5:
        print(f'   ... and {len(ads) - 5} more ads')
        print()
    
    print('=' * 80)
    print('VERIFICATION RESULTS:')
    print('=' * 80)
    print()
    
    print(f'Ads within campaign date range: {ads_within_range}')
    print(f'Ads outside campaign date range: {ads_outside_range}')
    print()
    
    calculated_profit = calculated_cash - calculated_spend
    
    print('CALCULATED FROM ADS (within date range):')
    print(f'   Total Spend: ${calculated_spend:,.2f}')
    print(f'   Total Leads: {calculated_leads}')
    print(f'   Total Cash: ${calculated_cash:,.2f}')
    print(f'   Total Profit: ${calculated_profit:,.2f}')
    print()
    
    print('STORED IN CAMPAIGN:')
    print(f'   Total Spend: ${campaign.get("totalSpend", 0):,.2f}')
    print(f'   Total Leads: {campaign.get("totalLeads", 0)}')
    print(f'   Total Profit: ${campaign.get("totalProfit", 0):,.2f}')
    print()
    
    # Compare
    spend_diff = abs(campaign.get("totalSpend", 0) - calculated_spend)
    leads_diff = abs(campaign.get("totalLeads", 0) - calculated_leads)
    
    print('COMPARISON:')
    if spend_diff < 0.01 and leads_diff == 0:
        print('   ✅ MATCH! Campaign totals = Sum of ads within date range')
        print('   → Totals are TIMEFRAME-BASED ✅')
    else:
        print(f'   ❌ MISMATCH!')
        print(f'   → Spend difference: ${spend_diff:,.2f}')
        print(f'   → Leads difference: {leads_diff}')
        if ads_outside_range > 0:
            print(f'   → {ads_outside_range} ads are OUTSIDE the campaign date range')
            print('   → Totals might be LIFETIME-BASED ❌')
        else:
            print('   → All ads are within range, but totals still don\'t match')
            print('   → Possible aggregation issue')
    
    print()
    
    # Check ad sets
    print('=' * 80)
    print('CHECKING AD SETS:')
    print('=' * 80)
    print()
    
    ad_sets = list(db.collection('adSets').where('campaignId', '==', campaign_id).stream())
    
    print(f'Found {len(ad_sets)} ad sets')
    print()
    
    for adset_doc in ad_sets[:3]:  # Check first 3 ad sets
        adset = adset_doc.to_dict()
        adset_id = adset_doc.id
        
        print(f'Ad Set: {adset.get("adSetName", "Unknown")}')
        print(f'   Stored Spend: ${adset.get("totalSpend", 0):,.2f}')
        print(f'   Stored Leads: {adset.get("totalLeads", 0)}')
        print(f'   Date Range: {adset.get("firstAdDate")} to {adset.get("lastAdDate")}')
        
        # Calculate from ads
        adset_ads = list(db.collection('ads').where('adSetId', '==', adset_id).stream())
        adset_calc_spend = sum(ad.to_dict().get('facebookStats', {}).get('spend', 0) for ad in adset_ads)
        adset_calc_leads = sum(ad.to_dict().get('ghlStats', {}).get('leads', 0) for ad in adset_ads)
        
        print(f'   Calculated Spend: ${adset_calc_spend:,.2f}')
        print(f'   Calculated Leads: {adset_calc_leads}')
        
        if abs(adset.get("totalSpend", 0) - adset_calc_spend) < 0.01:
            print(f'   ✅ Match!')
        else:
            print(f'   ❌ Mismatch: ${abs(adset.get("totalSpend", 0) - adset_calc_spend):,.2f}')
        print()

def main():
    print()
    print('=' * 80)
    print('CAMPAIGN TOTALS VERIFICATION')
    print('Testing if totals are timeframe-based or lifetime-based')
    print('=' * 80)
    print()
    
    # Get a sample campaign with recent activity (November 2025)
    print('Finding a campaign with November 2025 activity...')
    print()
    
    campaigns = db.collection('campaigns').limit(10).stream()
    
    sample_campaign_id = None
    for campaign_doc in campaigns:
        campaign = campaign_doc.to_dict()
        last_ad_date = campaign.get('lastAdDate')
        
        # Convert to string if needed
        if hasattr(last_ad_date, 'strftime'):
            last_ad_date = last_ad_date.strftime('%Y-%m-%d')
        
        # Find a campaign active in November 2025
        if last_ad_date and last_ad_date >= '2025-11-01':
            sample_campaign_id = campaign_doc.id
            print(f'✅ Found: {campaign.get("campaignName")} ({sample_campaign_id})')
            print(f'   Date Range: {campaign.get("firstAdDate")} to {last_ad_date}')
            print()
            break
    
    if not sample_campaign_id:
        print('❌ No suitable campaign found!')
        return
    
    # Verify this campaign
    verify_campaign(sample_campaign_id)
    
    print()
    print('=' * 80)
    print('CONCLUSION:')
    print('=' * 80)
    print()
    print('If totals MATCH → Campaign totals are TIMEFRAME-BASED ✅')
    print('   → No dynamic calculation needed!')
    print('   → Just filter campaigns by date range')
    print()
    print('If totals DON\'T MATCH → Campaign totals are LIFETIME-BASED ❌')
    print('   → Need dynamic calculation from ads')
    print('   → Current implementation is correct')
    print()

if __name__ == '__main__':
    main()

