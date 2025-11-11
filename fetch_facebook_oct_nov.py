#!/usr/bin/env python3
"""
Fetch ads from Facebook API for October & November 2025 with weekly insights
"""

import requests
import firebase_admin
from firebase_admin import credentials, firestore
from datetime import datetime, timedelta
import time

# Initialize Firebase
try:
    cred = credentials.Certificate('medx-ai-firebase-adminsdk-fbsvc-a86e7bd050.json')
    firebase_admin.initialize_app(cred)
except:
    pass

db = firestore.client()

# Facebook API Configuration
FB_ACCESS_TOKEN = "EAAc9pw8rgA0BP0S8U9s2cLzSJbCYmJZBKZCTFUNDD2zVXVqkC45q1BIQaPdZAmtXKbZBk6wjprLclIUUafHJ4icQZAXuuePybTL38pNQIcjQQZCbRGGhAtLcLVSGeJP59nMdpt8KNEoMQtvDfZBwBgpLNhQboPpaaeU8fW2rCEEhZA9pRN4RjZAAnwnLqEDaP8Fueo0cZD"
FB_AD_ACCOUNT_ID = "act_220298027464902"  # Correct ad account
FB_API_VERSION = "v24.0"  # Match the version used in existing code

def get_fb_token():
    """Get Facebook token"""
    return FB_ACCESS_TOKEN

def calculate_week_id(date_str):
    """Calculate week ID from date string"""
    date = datetime.strptime(date_str, '%Y-%m-%d')
    days_since_monday = date.weekday()
    monday = date - timedelta(days=days_since_monday)
    sunday = monday + timedelta(days=6)
    
    monday_str = monday.strftime('%Y-%m-%d')
    sunday_str = sunday.strftime('%Y-%m-%d')
    
    return f"{monday_str}_{sunday_str}"

def fetch_facebook_ads_with_insights():
    """Fetch ads from Facebook for Oct-Nov 2025"""
    
    print('\n' + '='*80)
    print('FETCH FACEBOOK ADS - OCTOBER & NOVEMBER 2025 (BATCH 4)')
    print('='*80 + '\n')
    
    # Date range - OCTOBER & NOVEMBER 2025 (continue fetching more)
    start_date = '2025-10-01'
    end_date = '2025-11-30'
    
    print(f'📅 Date range: {start_date} to {end_date}\n')
    
    # Get access token
    token = get_fb_token()
    
    headers = {
        'Authorization': f'Bearer {token}'
    }
    
    # Step 1: Get all campaigns
    print('📊 Step 1: Fetching campaigns...\n')
    
    campaigns_url = f'https://graph.facebook.com/{FB_API_VERSION}/{FB_AD_ACCOUNT_ID}/campaigns'
    campaigns_params = {
        'fields': 'id,name,status',
        'limit': 100
        # No filtering - let the insights date range filter the data
    }
    
    try:
        response = requests.get(campaigns_url, headers=headers, params=campaigns_params)
        response.raise_for_status()
        campaigns = response.json().get('data', [])
        print(f'✅ Found {len(campaigns)} campaigns\n')
    except Exception as e:
        print(f'❌ Error fetching campaigns: {e}')
        return
    
    # Step 2: For each campaign, get ads with insights
    all_ads = []
    
    for campaign in campaigns[35:50]:  # Process campaigns 35-50 (batch 4)
        campaign_id = campaign['id']
        campaign_name = campaign['name']
        
        print(f'📱 Processing campaign: {campaign_name}')
        
        # Get ads for this campaign
        ads_url = f'https://graph.facebook.com/{FB_API_VERSION}/{campaign_id}/ads'
        ads_params = {
            'fields': 'id,name,adset_id,adset{name},campaign_id',
            'limit': 50
        }
        
        try:
            response = requests.get(ads_url, headers=headers, params=ads_params)
            response.raise_for_status()
            ads = response.json().get('data', [])
            
            print(f'   Found {len(ads)} ads')
            
            # For each ad, get weekly insights
            for ad in ads:
                ad_id = ad['id']
                ad_name = ad.get('name', '')
                adset = ad.get('adset', {})
                
                # Get weekly insights
                insights_url = f'https://graph.facebook.com/{FB_API_VERSION}/{ad_id}/insights'
                insights_params = {
                    'time_range': f'{{"since":"{start_date}","until":"{end_date}"}}',
                    'time_increment': 7,  # Weekly
                    'fields': 'spend,impressions,reach,clicks,cpm,cpc,ctr,date_start,date_stop',
                    'limit': 100
                }
                
                try:
                    response = requests.get(insights_url, headers=headers, params=insights_params)
                    response.raise_for_status()
                    insights = response.json().get('data', [])
                    
                    if insights:
                        all_ads.append({
                            'adId': ad_id,
                            'adName': ad_name,
                            'adSetId': adset.get('id', ''),
                            'adSetName': adset.get('name', ''),
                            'campaignId': campaign_id,
                            'campaignName': campaign_name,
                            'insights': insights
                        })
                        print(f'      ✅ {ad_name[:40]} - {len(insights)} weeks')
                    
                    time.sleep(0.5)  # Rate limiting
                    
                except Exception as e:
                    print(f'      ⚠️  Error getting insights for {ad_name}: {e}')
                    continue
            
            time.sleep(1)  # Rate limiting between campaigns
            
        except Exception as e:
            print(f'   ❌ Error getting ads: {e}')
            continue
        
        print()
    
    print(f'\n✅ Total ads with insights: {len(all_ads)}\n')
    
    # Step 3: Write to Firebase
    print('📝 Step 3: Writing to Firebase...\n')
    
    for ad in all_ads:
        ad_id = ad['adId']
        
        # Create main ad document
        ad_ref = db.collection('advertData').document(ad_id)
        ad_ref.set({
            'campaignId': ad['campaignId'],
            'campaignName': ad['campaignName'],
            'adSetId': ad['adSetId'],
            'adSetName': ad['adSetName'],
            'adId': ad_id,
            'adName': ad['adName'],
            'lastUpdated': firestore.SERVER_TIMESTAMP,
            'lastFacebookSync': firestore.SERVER_TIMESTAMP,
            'createdAt': firestore.SERVER_TIMESTAMP
        })
        
        # Write insights to subcollection
        for insight in ad['insights']:
            week_id = calculate_week_id(insight['date_start'])
            
            insight_ref = ad_ref.collection('insights').document(week_id)
            insight_ref.set({
                'dateStart': insight['date_start'],
                'dateStop': insight['date_stop'],
                'spend': float(insight.get('spend', 0)),
                'impressions': int(insight.get('impressions', 0)),
                'reach': int(insight.get('reach', 0)),
                'clicks': int(insight.get('clicks', 0)),
                'cpm': float(insight.get('cpm', 0)),
                'cpc': float(insight.get('cpc', 0)),
                'ctr': float(insight.get('ctr', 0)),
                'fetchedAt': firestore.SERVER_TIMESTAMP
            })
        
        # Create empty ghlWeekly placeholder
        ad_ref.collection('ghlWeekly').document('_placeholder').set({
            'note': 'GHL data will be populated from API',
            'createdAt': firestore.SERVER_TIMESTAMP
        })
        
        print(f'✅ {ad["adName"][:50]} - {len(ad["insights"])} weeks')
    
    print('\n' + '='*80)
    print('FACEBOOK DATA POPULATED!')
    print('='*80 + '\n')
    
    print(f'📊 Summary:')
    print(f'   Ads created: {len(all_ads)}')
    print(f'   Date range: {start_date} to {end_date}')
    print(f'   Structure: advertData/{{adId}}/insights/{{weekId}}')
    print('\n' + '='*80 + '\n')

if __name__ == '__main__':
    fetch_facebook_ads_with_insights()

