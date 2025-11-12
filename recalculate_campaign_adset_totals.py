#!/usr/bin/env python3
"""
Recalculate Campaign and Ad Set Totals
Aggregates data from ads collection based on their date ranges
"""

import firebase_admin
from firebase_admin import credentials, firestore
from datetime import datetime

# Initialize Firebase
if not firebase_admin._apps:
    cred = credentials.Certificate('medx-ai-firebase-adminsdk-fbsvc-a86e7bd050.json')
    firebase_admin.initialize_app(cred)

db = firestore.client()

def recalculate_campaign_totals(campaign_id, campaign_name):
    """Recalculate totals for a campaign from its ad sets"""
    print(f'\n📊 Processing: {campaign_name}')
    print(f'   Campaign ID: {campaign_id}')
    
    # Get all ad sets for this campaign
    adsets_ref = db.collection('adSets').where('campaignId', '==', campaign_id).stream()
    
    # Initialize totals
    total_spend = 0
    total_impressions = 0
    total_clicks = 0
    total_reach = 0
    total_leads = 0
    total_bookings = 0
    total_deposits = 0
    total_cash_collected = 0
    total_cash_amount = 0
    
    first_ad_date = None
    last_ad_date = None
    adset_count = 0
    total_ad_count = 0
    
    for adset_doc in adsets_ref:
        adset_data = adset_doc.to_dict()
        adset_count += 1
        
        # Track date range from ad sets
        adset_first_date = adset_data.get('firstAdDate')
        adset_last_date = adset_data.get('lastAdDate')
        
        if adset_first_date:
            if not first_ad_date or adset_first_date < first_ad_date:
                first_ad_date = adset_first_date
        
        if adset_last_date:
            if not last_ad_date or adset_last_date > last_ad_date:
                last_ad_date = adset_last_date
        
        # Aggregate from ad set totals
        total_spend += adset_data.get('totalSpend', 0)
        total_impressions += adset_data.get('totalImpressions', 0)
        total_clicks += adset_data.get('totalClicks', 0)
        total_reach += adset_data.get('totalReach', 0)
        total_leads += adset_data.get('totalLeads', 0)
        total_bookings += adset_data.get('totalBookings', 0)
        total_deposits += adset_data.get('totalDeposits', 0)
        total_cash_collected += adset_data.get('totalCashCollected', 0)
        total_cash_amount += adset_data.get('totalCashAmount', 0)
        total_ad_count += adset_data.get('adCount', 0)
    
    # Calculate derived metrics
    total_profit = total_cash_amount - total_spend
    cpl = total_spend / total_leads if total_leads > 0 else 0
    cpb = total_spend / total_bookings if total_bookings > 0 else 0
    cpa = total_spend / total_deposits if total_deposits > 0 else 0
    roi = (total_profit / total_spend * 100) if total_spend > 0 else 0
    cpm = (total_spend / total_impressions * 1000) if total_impressions > 0 else 0
    cpc = total_spend / total_clicks if total_clicks > 0 else 0
    ctr = (total_clicks / total_impressions * 100) if total_impressions > 0 else 0
    
    # Update campaign document
    update_data = {
        'totalSpend': total_spend,
        'totalImpressions': total_impressions,
        'totalClicks': total_clicks,
        'totalReach': total_reach,
        'totalLeads': total_leads,
        'totalBookings': total_bookings,
        'totalDeposits': total_deposits,
        'totalCashCollected': total_cash_collected,
        'totalCashAmount': total_cash_amount,
        'totalProfit': total_profit,
        'cpl': cpl,
        'cpb': cpb,
        'cpa': cpa,
        'roi': roi,
        'cpm': cpm,
        'cpc': cpc,
        'ctr': ctr,
        'adSetCount': adset_count,
        'adCount': total_ad_count,
        'firstAdDate': first_ad_date,
        'lastAdDate': last_ad_date,
        'lastUpdated': firestore.SERVER_TIMESTAMP
    }
    
    db.collection('campaigns').document(campaign_id).update(update_data)
    
    print(f'   ✅ Updated campaign')
    print(f'      Ad Sets: {adset_count}')
    print(f'      Total Ads: {total_ad_count}')
    print(f'      Date Range: {first_ad_date} to {last_ad_date}')
    print(f'      Spend: R {total_spend:,.2f}')
    print(f'      Leads: {total_leads}')
    print(f'      Bookings: {total_bookings}')
    print(f'      Deposits: {total_deposits}')
    print(f'      Cash: R {total_cash_amount:,.2f}')
    print(f'      Profit: R {total_profit:,.2f}')

def recalculate_adset_totals(adset_id, adset_name, campaign_name):
    """Recalculate totals for an ad set from its ads"""
    print(f'\n   📂 Processing Ad Set: {adset_name}')
    print(f'      Ad Set ID: {adset_id}')
    
    # Get all ads for this ad set
    ads_ref = db.collection('ads').where('adSetId', '==', adset_id).stream()
    
    # Initialize totals
    total_spend = 0
    total_impressions = 0
    total_clicks = 0
    total_reach = 0
    total_leads = 0
    total_bookings = 0
    total_deposits = 0
    total_cash_collected = 0
    total_cash_amount = 0
    
    first_ad_date = None
    last_ad_date = None
    ad_count = 0
    
    for ad_doc in ads_ref:
        ad_data = ad_doc.to_dict()
        ad_count += 1
        
        # Track date range
        first_insight_date = ad_data.get('firstInsightDate')
        last_insight_date = ad_data.get('lastInsightDate')
        
        if first_insight_date:
            if not first_ad_date or first_insight_date < first_ad_date:
                first_ad_date = first_insight_date
        
        if last_insight_date:
            if not last_ad_date or last_insight_date > last_ad_date:
                last_ad_date = last_insight_date
        
        # Aggregate Facebook stats
        fb_stats = ad_data.get('facebookStats', {})
        total_spend += fb_stats.get('spend', 0)
        total_impressions += fb_stats.get('impressions', 0)
        total_clicks += fb_stats.get('clicks', 0)
        total_reach += fb_stats.get('reach', 0)
        
        # Aggregate GHL stats
        ghl_stats = ad_data.get('ghlStats', {})
        total_leads += ghl_stats.get('leads', 0)
        total_bookings += ghl_stats.get('bookings', 0)
        total_deposits += ghl_stats.get('deposits', 0)
        total_cash_collected += ghl_stats.get('cashCollected', 0)
        total_cash_amount += ghl_stats.get('cashAmount', 0)
    
    # Calculate derived metrics
    total_profit = total_cash_amount - total_spend
    cpl = total_spend / total_leads if total_leads > 0 else 0
    cpb = total_spend / total_bookings if total_bookings > 0 else 0
    cpa = total_spend / total_deposits if total_deposits > 0 else 0
    cpm = (total_spend / total_impressions * 1000) if total_impressions > 0 else 0
    cpc = total_spend / total_clicks if total_clicks > 0 else 0
    ctr = (total_clicks / total_impressions * 100) if total_impressions > 0 else 0
    
    # Update ad set document
    update_data = {
        'totalSpend': total_spend,
        'totalImpressions': total_impressions,
        'totalClicks': total_clicks,
        'totalReach': total_reach,
        'totalLeads': total_leads,
        'totalBookings': total_bookings,
        'totalDeposits': total_deposits,
        'totalCashCollected': total_cash_collected,
        'totalCashAmount': total_cash_amount,
        'totalProfit': total_profit,
        'cpl': cpl,
        'cpb': cpb,
        'cpa': cpa,
        'cpm': cpm,
        'cpc': cpc,
        'ctr': ctr,
        'adCount': ad_count,
        'firstAdDate': first_ad_date,
        'lastAdDate': last_ad_date,
        'lastUpdated': firestore.SERVER_TIMESTAMP
    }
    
    db.collection('adSets').document(adset_id).update(update_data)
    
    print(f'      ✅ Updated ad set')
    print(f'         Ads: {ad_count}')
    print(f'         Date Range: {first_ad_date} to {last_ad_date}')
    print(f'         Spend: R {total_spend:,.2f}')
    print(f'         Leads: {total_leads}')
    print(f'         Cash: R {total_cash_amount:,.2f}')

def main():
    print('=' * 80)
    print('RECALCULATING CAMPAIGN AND AD SET TOTALS')
    print('=' * 80)
    print()
    print('STEP 1: Recalculating Ad Sets (from ads)')
    print('STEP 2: Recalculating Campaigns (from ad sets)')
    print()
    
    campaign_count = 0
    adset_count = 0
    error_count = 0
    
    # Process campaigns in batches with pagination
    batch_size = 50
    last_doc = None
    
    while True:
        try:
            # Get campaigns in batches
            if last_doc:
                campaigns_query = db.collection('campaigns').order_by('__name__').start_after(last_doc).limit(batch_size)
            else:
                campaigns_query = db.collection('campaigns').order_by('__name__').limit(batch_size)
            
            campaigns_docs = list(campaigns_query.stream())
            
            if not campaigns_docs:
                break  # No more campaigns to process
            
            print(f'\n📦 Processing batch of {len(campaigns_docs)} campaigns...')
            
            for campaign_doc in campaigns_docs:
                try:
                    campaign_data = campaign_doc.to_dict()
                    campaign_id = campaign_doc.id
                    campaign_name = campaign_data.get('campaignName', 'Unknown')
                    
                    campaign_count += 1
                    
                    print(f'\n📊 Processing Campaign: {campaign_name}')
                    
                    # STEP 1: Recalculate all ad sets first (from ads)
                    adsets_ref = db.collection('adSets').where('campaignId', '==', campaign_id).stream()
                    
                    for adset_doc in adsets_ref:
                        try:
                            adset_data = adset_doc.to_dict()
                            adset_id = adset_doc.id
                            adset_name = adset_data.get('adSetName', 'Unknown')
                            
                            adset_count += 1
                            
                            # Recalculate ad set totals from ads
                            recalculate_adset_totals(adset_id, adset_name, campaign_name)
                        except Exception as e:
                            print(f'      ❌ Error processing ad set {adset_id}: {str(e)}')
                            error_count += 1
                    
                    # STEP 2: Recalculate campaign totals from ad sets
                    recalculate_campaign_totals(campaign_id, campaign_name)
                    
                except Exception as e:
                    print(f'   ❌ Error processing campaign {campaign_id}: {str(e)}')
                    error_count += 1
            
            # Update last_doc for pagination
            last_doc = campaigns_docs[-1]
            
            print(f'\n✅ Batch complete. Progress: {campaign_count} campaigns, {adset_count} ad sets')
            
        except Exception as e:
            print(f'\n❌ Batch error: {str(e)}')
            print(f'Resuming from campaign count: {campaign_count}')
            error_count += 1
            # Continue with next batch
            if last_doc:
                continue
            else:
                break
    
    print()
    print('=' * 80)
    print('✅ RECALCULATION COMPLETE!')
    print('=' * 80)
    print(f'   Campaigns updated: {campaign_count}')
    print(f'   Ad Sets updated: {adset_count}')
    print(f'   Errors encountered: {error_count}')
    print()

if __name__ == '__main__':
    main()

