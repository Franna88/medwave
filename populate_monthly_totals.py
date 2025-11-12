#!/usr/bin/env python3
"""
Populate Monthly Totals for Campaigns and Ad Sets
Runs the monthly aggregation for all existing campaigns and ad sets
"""

import firebase_admin
from firebase_admin import credentials, firestore
from datetime import datetime

# Initialize Firebase
if not firebase_admin._apps:
    cred = credentials.Certificate('medx-ai-firebase-adminsdk-fbsvc-a86e7bd050.json')
    firebase_admin.initialize_app(cred)

db = firestore.client()

def populate_campaign_monthly_totals():
    """Populate monthlyTotals for all campaigns"""
    print('=' * 80)
    print('POPULATING MONTHLY TOTALS FOR CAMPAIGNS')
    print('=' * 80)
    print()
    
    campaigns = list(db.collection('campaigns').stream())
    print(f'Found {len(campaigns)} campaigns')
    print()
    
    for i, campaign_doc in enumerate(campaigns, 1):
        campaign_id = campaign_doc.id
        campaign = campaign_doc.to_dict()
        campaign_name = campaign.get('campaignName', 'Unknown')
        
        print(f'{i}/{len(campaigns)}: {campaign_name} ({campaign_id})')
        
        # Get all ads for this campaign
        ads = list(db.collection('ads').where('campaignId', '==', campaign_id).stream())
        
        if not ads:
            print(f'   ⚠️  No ads found')
            continue
        
        # Group ads by month
        monthly_data = {}
        
        for ad_doc in ads:
            ad = ad_doc.to_dict()
            
            # Get month from firstInsightDate
            first_insight = ad.get('firstInsightDate', '')
            if not first_insight:
                continue
            
            month = first_insight[:7]  # "2025-11"
            
            if month not in monthly_data:
                monthly_data[month] = {
                    'spend': 0,
                    'impressions': 0,
                    'clicks': 0,
                    'reach': 0,
                    'leads': 0,
                    'bookings': 0,
                    'deposits': 0,
                    'cashCollected': 0,
                    'cashAmount': 0,
                    'adCount': 0
                }
            
            # Aggregate Facebook stats
            fb_stats = ad.get('facebookStats', {})
            monthly_data[month]['spend'] += fb_stats.get('spend', 0)
            monthly_data[month]['impressions'] += fb_stats.get('impressions', 0)
            monthly_data[month]['clicks'] += fb_stats.get('clicks', 0)
            monthly_data[month]['reach'] += fb_stats.get('reach', 0)
            
            # Aggregate GHL stats
            ghl_stats = ad.get('ghlStats', {})
            monthly_data[month]['leads'] += ghl_stats.get('leads', 0)
            monthly_data[month]['bookings'] += ghl_stats.get('bookings', 0)
            monthly_data[month]['deposits'] += ghl_stats.get('deposits', 0)
            monthly_data[month]['cashCollected'] += ghl_stats.get('cashCollected', 0)
            monthly_data[month]['cashAmount'] += ghl_stats.get('cashAmount', 0)
            monthly_data[month]['adCount'] += 1
        
        # Calculate computed metrics for each month
        monthly_totals = {}
        
        for month, data in monthly_data.items():
            profit = data['cashAmount'] - data['spend']
            cpl = data['spend'] / data['leads'] if data['leads'] > 0 else 0
            cpb = data['spend'] / data['bookings'] if data['bookings'] > 0 else 0
            cpa = data['spend'] / data['deposits'] if data['deposits'] > 0 else 0
            roi = ((data['cashAmount'] - data['spend']) / data['spend']) * 100 if data['spend'] > 0 else 0
            cpm = (data['spend'] / data['impressions']) * 1000 if data['impressions'] > 0 else 0
            cpc = data['spend'] / data['clicks'] if data['clicks'] > 0 else 0
            ctr = (data['clicks'] / data['impressions']) * 100 if data['impressions'] > 0 else 0
            
            monthly_totals[month] = {
                'spend': data['spend'],
                'impressions': data['impressions'],
                'clicks': data['clicks'],
                'reach': data['reach'],
                'leads': data['leads'],
                'bookings': data['bookings'],
                'deposits': data['deposits'],
                'cashCollected': data['cashCollected'],
                'cashAmount': data['cashAmount'],
                'profit': profit,
                'cpl': cpl,
                'cpb': cpb,
                'cpa': cpa,
                'roi': roi,
                'cpm': cpm,
                'cpc': cpc,
                'ctr': ctr,
                'adCount': data['adCount']
            }
        
        # Update campaign document
        db.collection('campaigns').document(campaign_id).update({
            'monthlyTotals': monthly_totals,
            'lastMonthlyAggregation': firestore.SERVER_TIMESTAMP
        })
        
        print(f'   ✅ Added {len(monthly_totals)} months: {", ".join(sorted(monthly_totals.keys()))}')
    
    print()
    print('✅ Campaign monthly totals populated!')

def populate_adset_monthly_totals():
    """Populate monthlyTotals for all ad sets"""
    print()
    print('=' * 80)
    print('POPULATING MONTHLY TOTALS FOR AD SETS')
    print('=' * 80)
    print()
    
    ad_sets = list(db.collection('adSets').stream())
    print(f'Found {len(ad_sets)} ad sets')
    print()
    
    for i, adset_doc in enumerate(ad_sets, 1):
        adset_id = adset_doc.id
        adset = adset_doc.to_dict()
        adset_name = adset.get('adSetName', 'Unknown')
        
        print(f'{i}/{len(ad_sets)}: {adset_name} ({adset_id})')
        
        # Get all ads for this ad set
        ads = list(db.collection('ads').where('adSetId', '==', adset_id).stream())
        
        if not ads:
            print(f'   ⚠️  No ads found')
            continue
        
        # Group ads by month
        monthly_data = {}
        
        for ad_doc in ads:
            ad = ad_doc.to_dict()
            
            # Get month from firstInsightDate
            first_insight = ad.get('firstInsightDate', '')
            if not first_insight:
                continue
            
            month = first_insight[:7]  # "2025-11"
            
            if month not in monthly_data:
                monthly_data[month] = {
                    'spend': 0,
                    'impressions': 0,
                    'clicks': 0,
                    'reach': 0,
                    'leads': 0,
                    'bookings': 0,
                    'deposits': 0,
                    'cashCollected': 0,
                    'cashAmount': 0,
                    'adCount': 0
                }
            
            # Aggregate Facebook stats
            fb_stats = ad.get('facebookStats', {})
            monthly_data[month]['spend'] += fb_stats.get('spend', 0)
            monthly_data[month]['impressions'] += fb_stats.get('impressions', 0)
            monthly_data[month]['clicks'] += fb_stats.get('clicks', 0)
            monthly_data[month]['reach'] += fb_stats.get('reach', 0)
            
            # Aggregate GHL stats
            ghl_stats = ad.get('ghlStats', {})
            monthly_data[month]['leads'] += ghl_stats.get('leads', 0)
            monthly_data[month]['bookings'] += ghl_stats.get('bookings', 0)
            monthly_data[month]['deposits'] += ghl_stats.get('deposits', 0)
            monthly_data[month]['cashCollected'] += ghl_stats.get('cashCollected', 0)
            monthly_data[month]['cashAmount'] += ghl_stats.get('cashAmount', 0)
            monthly_data[month]['adCount'] += 1
        
        # Calculate computed metrics for each month
        monthly_totals = {}
        
        for month, data in monthly_data.items():
            profit = data['cashAmount'] - data['spend']
            cpl = data['spend'] / data['leads'] if data['leads'] > 0 else 0
            cpb = data['spend'] / data['bookings'] if data['bookings'] > 0 else 0
            cpa = data['spend'] / data['deposits'] if data['deposits'] > 0 else 0
            cpm = (data['spend'] / data['impressions']) * 1000 if data['impressions'] > 0 else 0
            cpc = data['spend'] / data['clicks'] if data['clicks'] > 0 else 0
            ctr = (data['clicks'] / data['impressions']) * 100 if data['impressions'] > 0 else 0
            
            monthly_totals[month] = {
                'spend': data['spend'],
                'impressions': data['impressions'],
                'clicks': data['clicks'],
                'reach': data['reach'],
                'leads': data['leads'],
                'bookings': data['bookings'],
                'deposits': data['deposits'],
                'cashCollected': data['cashCollected'],
                'cashAmount': data['cashAmount'],
                'profit': profit,
                'cpl': cpl,
                'cpb': cpb,
                'cpa': cpa,
                'cpm': cpm,
                'cpc': cpc,
                'ctr': ctr,
                'adCount': data['adCount']
            }
        
        # Update ad set document
        db.collection('adSets').document(adset_id).update({
            'monthlyTotals': monthly_totals,
            'lastMonthlyAggregation': firestore.SERVER_TIMESTAMP
        })
        
        print(f'   ✅ Added {len(monthly_totals)} months: {", ".join(sorted(monthly_totals.keys()))}')
    
    print()
    print('✅ Ad set monthly totals populated!')

if __name__ == '__main__':
    print()
    print('🚀 POPULATING MONTHLY TOTALS')
    print('This will add monthlyTotals to all campaigns and ad sets')
    print()
    
    populate_campaign_monthly_totals()
    populate_adset_monthly_totals()
    
    print()
    print('=' * 80)
    print('✅ COMPLETE! Monthly totals populated for all campaigns and ad sets')
    print('=' * 80)

