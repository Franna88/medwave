#!/usr/bin/env python3
"""
Pre-aggregate ad data at the month level to speed up UI loading
Creates a summary document for each month with all ads and their totals
"""

import firebase_admin
from firebase_admin import credentials, firestore
from collections import defaultdict
from datetime import datetime

# Initialize Firebase
if not firebase_admin._apps:
    cred = credentials.Certificate('medx-ai-firebase-adminsdk-fbsvc-a86e7bd050.json')
    firebase_admin.initialize_app(cred)

db = firestore.client()

def aggregate_month_data(month_id):
    """
    Aggregate all ad data for a specific month into a summary document
    Structure: advertData/{month}/summary/aggregated
    """
    print(f'\n📊 Aggregating data for month: {month_id}')
    print('='*80)
    
    month_ref = db.collection('advertData').document(month_id)
    ads_ref = month_ref.collection('ads')
    
    # Get all ads for this month
    ads = list(ads_ref.stream())
    print(f'   Found {len(ads)} ads in {month_id}')
    
    aggregated_ads = []
    
    for ad_doc in ads:
        ad_data = ad_doc.to_dict()
        ad_id = ad_doc.id
        
        print(f'   Processing: {ad_data.get("adName", "Unknown")} ({ad_id})')
        
        # Get all Facebook insights for this ad
        fb_insights = list(ad_doc.reference.collection('insights').stream())
        fb_totals = {
            'spend': 0.0,
            'impressions': 0,
            'clicks': 0,
            'reach': 0,
            'weeks': len(fb_insights)
        }
        
        for insight_doc in fb_insights:
            insight = insight_doc.to_dict()
            fb_totals['spend'] += float(insight.get('spend', 0))
            fb_totals['impressions'] += int(insight.get('impressions', 0))
            fb_totals['clicks'] += int(insight.get('clicks', 0))
            fb_totals['reach'] += int(insight.get('reach', 0))
        
        # Calculate averages for CPM, CPC, CTR
        if fb_totals['impressions'] > 0:
            fb_totals['avgCPM'] = (fb_totals['spend'] / fb_totals['impressions']) * 1000
        else:
            fb_totals['avgCPM'] = 0.0
            
        if fb_totals['clicks'] > 0:
            fb_totals['avgCPC'] = fb_totals['spend'] / fb_totals['clicks']
            fb_totals['avgCTR'] = (fb_totals['clicks'] / fb_totals['impressions']) * 100 if fb_totals['impressions'] > 0 else 0.0
        else:
            fb_totals['avgCPC'] = 0.0
            fb_totals['avgCTR'] = 0.0
        
        # Get all GHL weekly data for this ad
        ghl_weeks = list(ad_doc.reference.collection('ghlWeekly').stream())
        ghl_totals = {
            'leads': 0,
            'bookedAppointments': 0,
            'deposits': 0,
            'cashCollected': 0,
            'cashAmount': 0.0,
            'weeks': len(ghl_weeks)
        }
        
        for ghl_doc in ghl_weeks:
            ghl = ghl_doc.to_dict()
            ghl_totals['leads'] += int(ghl.get('leads', 0))
            ghl_totals['bookedAppointments'] += int(ghl.get('bookedAppointments', 0))
            ghl_totals['deposits'] += int(ghl.get('deposits', 0))
            ghl_totals['cashCollected'] += int(ghl.get('cashCollected', 0))
            ghl_totals['cashAmount'] += float(ghl.get('cashAmount', 0))
        
        # Calculate profit
        profit = ghl_totals['cashAmount'] - fb_totals['spend']
        
        # Build aggregated ad object
        aggregated_ad = {
            'adId': ad_id,
            'adName': ad_data.get('adName', 'Unknown'),
            'campaignId': ad_data.get('campaignId', ''),
            'campaignName': ad_data.get('campaignName', ''),
            'adSetId': ad_data.get('adSetId', ''),
            'adSetName': ad_data.get('adSetName', ''),
            'status': ad_data.get('status', 'UNKNOWN'),
            'facebookTotals': fb_totals,
            'ghlTotals': ghl_totals,
            'profit': profit,
            'hasGHLData': ghl_totals['leads'] > 0
        }
        
        aggregated_ads.append(aggregated_ad)
    
    # Write aggregated data to summary document
    summary_ref = month_ref.collection('summary').document('aggregated')
    
    summary_data = {
        'month': month_id,
        'totalAds': len(aggregated_ads),
        'adsWithGHLData': sum(1 for ad in aggregated_ads if ad['hasGHLData']),
        'ads': aggregated_ads,
        'lastAggregated': firestore.SERVER_TIMESTAMP
    }
    
    summary_ref.set(summary_data)
    
    print(f'\n   ✅ Aggregated {len(aggregated_ads)} ads')
    print(f'   ✅ Ads with GHL data: {summary_data["adsWithGHLData"]}')
    print(f'   ✅ Written to: advertData/{month_id}/summary/aggregated')
    print('='*80)
    
    return summary_data

def aggregate_all_months():
    """Aggregate data for all available months"""
    print('\n🚀 AGGREGATING ALL MONTHS')
    print('='*80)
    
    # Get all month documents
    months_snapshot = db.collection('advertData').get()
    
    valid_months = []
    for doc in months_snapshot.docs:
        data = doc.data()
        month_id = doc.id
        # Filter valid months (have totalAds field and match YYYY-MM format)
        if data.get('totalAds') and '-' in month_id and not month_id.startswith('_'):
            valid_months.append(month_id)
    
    valid_months.sort(reverse=True)  # Newest first
    
    print(f'\nFound {len(valid_months)} valid months: {valid_months}')
    
    for month in valid_months:
        try:
            aggregate_month_data(month)
        except Exception as e:
            print(f'❌ Error aggregating {month}: {e}')
            continue
    
    print(f'\n✅ AGGREGATION COMPLETE!')
    print(f'   Processed {len(valid_months)} months')
    print('='*80)

if __name__ == '__main__':
    aggregate_all_months()








