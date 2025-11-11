#!/usr/bin/env python3
"""
Migrate advertData collection to split collections schema

This script migrates data from the nested advertData/{month}/ads/{adId} structure
to separate collections: campaigns, adSets, ads, ghlOpportunities, ghlOpportunityMapping

Key Features:
- Extracts and aggregates campaign-level metrics
- Extracts and aggregates ad set-level metrics
- Creates individual ad documents with aggregated stats
- Creates opportunity mapping to prevent cross-campaign duplicates
- Migrates GHL opportunities using the mapping (ONE ad per opportunity)
- Creates time-series snapshots for comparisons
"""

import firebase_admin
from firebase_admin import credentials, firestore
from collections import defaultdict
from datetime import datetime, timedelta
import time
import json

# Initialize Firebase
if not firebase_admin._apps:
    cred = credentials.Certificate('medx-ai-firebase-adminsdk-fbsvc-a86e7bd050.json')
    firebase_admin.initialize_app(cred)

db = firestore.client()

# Statistics tracking
stats = {
    'campaigns_created': 0,
    'ad_sets_created': 0,
    'ads_created': 0,
    'opportunities_mapped': 0,
    'opportunities_migrated': 0,
    'errors': []
}

def calculate_week_id(timestamp):
    """Calculate week ID in Monday-Sunday format"""
    if isinstance(timestamp, str):
        dt = datetime.fromisoformat(timestamp.replace('Z', '+00:00'))
    else:
        dt = timestamp
    
    # Get Monday of the week
    monday = dt - timedelta(days=dt.weekday())
    sunday = monday + timedelta(days=6)
    
    return f"{monday.strftime('%Y-%m-%d')}_{sunday.strftime('%Y-%m-%d')}"

def get_stage_category(stage_name):
    """Map stage name to category"""
    if not stage_name:
        return 'other'
    
    stage_lower = stage_name.lower()
    
    if any(x in stage_lower for x in ['appointment', 'booked', 'scheduled']):
        return 'bookedAppointments'
    elif any(x in stage_lower for x in ['deposit', 'paid deposit']):
        return 'deposits'
    elif any(x in stage_lower for x in ['cash collected', 'paid', 'completed', 'payment received']):
        return 'cashCollected'
    else:
        return 'other'

def extract_ad_id_from_attribution(attr):
    """Extract Ad ID from attribution with multiple field name variations"""
    # Check direct fields
    ad_id = (
        attr.get('h_ad_id') or 
        attr.get('utmAdId') or 
        attr.get('utm_ad_id') or
        attr.get('adId') or 
        attr.get('ad_id') or
        attr.get('Ad Id')
    )
    
    # Check in customField array
    if not ad_id and 'customField' in attr:
        for field in attr.get('customField', []):
            field_name = field.get('name', '').lower()
            if field_name in ['ad_id', 'adid', 'utm_ad_id', 'utmadid', 'h_ad_id']:
                ad_id = field.get('value')
                if ad_id:
                    break
    
    # Check in pageDetails
    if not ad_id:
        page_details = attr.get('pageDetails') or attr.get('page_details') or {}
        ad_id = (
            page_details.get('adId') or 
            page_details.get('ad_id') or
            page_details.get('Ad Id')
        )
    
    return ad_id

print("=" * 100)
print("SPLIT COLLECTIONS MIGRATION")
print("=" * 100)
print()

# ============================================================================
# PHASE 1: Extract all ads from advertData and build lookup maps
# ============================================================================

print("📊 PHASE 1: Extracting ads from advertData collection...")
print()

all_ads = []
campaign_map = {}  # campaignId -> campaign data
ad_set_map = {}    # adSetId -> ad set data
ad_map = {}        # adId -> ad data

# Lookup maps for opportunity assignment
campaign_to_ads = defaultdict(list)      # campaignId -> [adIds]
ad_name_to_ads = defaultdict(list)       # (campaignId, adName) -> [adIds]
adset_name_to_ads = defaultdict(list)    # (campaignId, adSetName) -> [adIds]

# Query all month documents
month_docs = list(db.collection('advertData').stream())

for month_doc in month_docs:
    month_data = month_doc.to_dict()
    
    # Skip if not a month document
    if 'totalAds' not in month_data:
        continue
    
    month_id = month_doc.id
    print(f"   Processing month: {month_id}")
    
    # Get all ads in this month
    ads_ref = month_doc.reference.collection('ads')
    ads = list(ads_ref.stream())
    
    for ad_doc in ads:
        ad_data = ad_doc.to_dict()
        ad_id = ad_doc.id
        
        # Extract ad info
        campaign_id = ad_data.get('campaignId', '')
        campaign_name = ad_data.get('campaignName', '')
        ad_set_id = ad_data.get('adSetId', '')
        ad_set_name = ad_data.get('adSetName', '')
        ad_name = ad_data.get('adName', '')
        
        # Aggregate Facebook stats from insights subcollection
        fb_stats = {
            'spend': 0,
            'impressions': 0,
            'clicks': 0,
            'reach': 0,
            'dateStart': '',
            'dateStop': ''
        }
        
        insights = list(ad_doc.reference.collection('insights').stream())
        for insight in insights:
            insight_data = insight.to_dict()
            fb_stats['spend'] += insight_data.get('spend', 0)
            fb_stats['impressions'] += insight_data.get('impressions', 0)
            fb_stats['clicks'] += insight_data.get('clicks', 0)
            fb_stats['reach'] += insight_data.get('reach', 0)
            
            # Track date range
            if not fb_stats['dateStart'] or insight_data.get('dateStart', '') < fb_stats['dateStart']:
                fb_stats['dateStart'] = insight_data.get('dateStart', '')
            if not fb_stats['dateStop'] or insight_data.get('dateStop', '') > fb_stats['dateStop']:
                fb_stats['dateStop'] = insight_data.get('dateStop', '')
        
        # Calculate averages
        if fb_stats['impressions'] > 0:
            fb_stats['cpm'] = (fb_stats['spend'] / fb_stats['impressions']) * 1000
            fb_stats['ctr'] = (fb_stats['clicks'] / fb_stats['impressions']) * 100
        else:
            fb_stats['cpm'] = 0
            fb_stats['ctr'] = 0
        
        if fb_stats['clicks'] > 0:
            fb_stats['cpc'] = fb_stats['spend'] / fb_stats['clicks']
        else:
            fb_stats['cpc'] = 0
        
        # Aggregate GHL stats from ghlWeekly subcollection
        ghl_stats = {
            'leads': 0,
            'bookings': 0,
            'deposits': 0,
            'cashCollected': 0,
            'cashAmount': 0
        }
        
        ghl_weeks = list(ad_doc.reference.collection('ghlWeekly').stream())
        for week in ghl_weeks:
            week_data = week.to_dict()
            ghl_stats['leads'] += week_data.get('leads', 0)
            ghl_stats['bookings'] += week_data.get('bookedAppointments', 0)
            ghl_stats['deposits'] += week_data.get('deposits', 0)
            ghl_stats['cashCollected'] += week_data.get('cashCollected', 0)
            ghl_stats['cashAmount'] += week_data.get('cashAmount', 0)
        
        # Calculate profit and metrics
        profit = ghl_stats['cashAmount'] - fb_stats['spend']
        cpl = fb_stats['spend'] / ghl_stats['leads'] if ghl_stats['leads'] > 0 else 0
        cpb = fb_stats['spend'] / ghl_stats['bookings'] if ghl_stats['bookings'] > 0 else 0
        cpa = fb_stats['spend'] / ghl_stats['deposits'] if ghl_stats['deposits'] > 0 else 0
        
        # Store ad data
        ad_info = {
            'adId': ad_id,
            'adName': ad_name,
            'adSetId': ad_set_id,
            'adSetName': ad_set_name,
            'campaignId': campaign_id,
            'campaignName': campaign_name,
            'facebookStats': fb_stats,
            'ghlStats': ghl_stats,
            'profit': profit,
            'cpl': cpl,
            'cpb': cpb,
            'cpa': cpa,
            'lastUpdated': ad_data.get('lastUpdated'),
            'lastFacebookSync': ad_data.get('lastFacebookSync'),
            'lastGHLSync': ad_data.get('lastGHLSync'),
            'createdAt': ad_data.get('createdAt'),
            'month': month_id
        }
        
        all_ads.append(ad_info)
        ad_map[ad_id] = ad_info
        
        # Build lookup maps for opportunity assignment
        if campaign_id:
            campaign_to_ads[campaign_id].append(ad_id)
            if ad_name:
                ad_name_to_ads[(campaign_id, ad_name.lower().strip())].append(ad_id)
            if ad_set_name:
                adset_name_to_ads[(campaign_id, ad_set_name.lower().strip())].append(ad_id)

print(f"✅ Extracted {len(all_ads)} ads from advertData")
print(f"   Found {len(set(ad['campaignId'] for ad in all_ads if ad['campaignId']))} unique campaigns")
print(f"   Found {len(set(ad['adSetId'] for ad in all_ads if ad['adSetId']))} unique ad sets")
print()

# ============================================================================
# PHASE 2: Aggregate campaigns
# ============================================================================

print("📊 PHASE 2: Aggregating campaign data...")
print()

campaigns_data = defaultdict(lambda: {
    'totalSpend': 0,
    'totalImpressions': 0,
    'totalClicks': 0,
    'totalReach': 0,
    'totalLeads': 0,
    'totalBookings': 0,
    'totalDeposits': 0,
    'totalCashCollected': 0,
    'totalCashAmount': 0,
    'adSetIds': set(),
    'adIds': set(),
    'firstAdDate': None,
    'lastAdDate': None
})

for ad in all_ads:
    campaign_id = ad['campaignId']
    if not campaign_id:
        continue
    
    campaign = campaigns_data[campaign_id]
    campaign['campaignName'] = ad['campaignName']
    
    # Aggregate Facebook stats
    campaign['totalSpend'] += ad['facebookStats']['spend']
    campaign['totalImpressions'] += ad['facebookStats']['impressions']
    campaign['totalClicks'] += ad['facebookStats']['clicks']
    campaign['totalReach'] += ad['facebookStats']['reach']
    
    # Aggregate GHL stats
    campaign['totalLeads'] += ad['ghlStats']['leads']
    campaign['totalBookings'] += ad['ghlStats']['bookings']
    campaign['totalDeposits'] += ad['ghlStats']['deposits']
    campaign['totalCashCollected'] += ad['ghlStats']['cashCollected']
    campaign['totalCashAmount'] += ad['ghlStats']['cashAmount']
    
    # Track ad sets and ads
    if ad['adSetId']:
        campaign['adSetIds'].add(ad['adSetId'])
    campaign['adIds'].add(ad['adId'])
    
    # Track date range
    if ad['createdAt']:
        if not campaign['firstAdDate'] or ad['createdAt'] < campaign['firstAdDate']:
            campaign['firstAdDate'] = ad['createdAt']
        if not campaign['lastAdDate'] or ad['createdAt'] > campaign['lastAdDate']:
            campaign['lastAdDate'] = ad['createdAt']

# Calculate computed metrics for campaigns
for campaign_id, campaign in campaigns_data.items():
    campaign['totalProfit'] = campaign['totalCashAmount'] - campaign['totalSpend']
    campaign['cpl'] = campaign['totalSpend'] / campaign['totalLeads'] if campaign['totalLeads'] > 0 else 0
    campaign['cpb'] = campaign['totalSpend'] / campaign['totalBookings'] if campaign['totalBookings'] > 0 else 0
    campaign['cpa'] = campaign['totalSpend'] / campaign['totalDeposits'] if campaign['totalDeposits'] > 0 else 0
    campaign['roi'] = ((campaign['totalCashAmount'] - campaign['totalSpend']) / campaign['totalSpend']) * 100 if campaign['totalSpend'] > 0 else 0
    
    # Conversion rates
    campaign['leadToBookingRate'] = (campaign['totalBookings'] / campaign['totalLeads']) * 100 if campaign['totalLeads'] > 0 else 0
    campaign['bookingToDepositRate'] = (campaign['totalDeposits'] / campaign['totalBookings']) * 100 if campaign['totalBookings'] > 0 else 0
    campaign['depositToCashRate'] = (campaign['totalCashCollected'] / campaign['totalDeposits']) * 100 if campaign['totalDeposits'] > 0 else 0
    
    # Averages
    if campaign['totalImpressions'] > 0:
        campaign['avgCPM'] = (campaign['totalSpend'] / campaign['totalImpressions']) * 1000
        campaign['avgCTR'] = (campaign['totalClicks'] / campaign['totalImpressions']) * 100
    else:
        campaign['avgCPM'] = 0
        campaign['avgCTR'] = 0
    
    if campaign['totalClicks'] > 0:
        campaign['avgCPC'] = campaign['totalSpend'] / campaign['totalClicks']
    else:
        campaign['avgCPC'] = 0
    
    # Counts
    campaign['adSetCount'] = len(campaign['adSetIds'])
    campaign['adCount'] = len(campaign['adIds'])
    
    # Status (based on last ad date)
    if campaign['lastAdDate']:
        days_since = (datetime.now() - campaign['lastAdDate'].replace(tzinfo=None)).days
        if days_since <= 1:
            campaign['status'] = 'ACTIVE'
        elif days_since <= 7:
            campaign['status'] = 'RECENT'
        else:
            campaign['status'] = 'PAUSED'
    else:
        campaign['status'] = 'UNKNOWN'

print(f"✅ Aggregated {len(campaigns_data)} campaigns")
print()

# ============================================================================
# PHASE 3: Aggregate ad sets
# ============================================================================

print("📊 PHASE 3: Aggregating ad set data...")
print()

ad_sets_data = defaultdict(lambda: {
    'totalSpend': 0,
    'totalImpressions': 0,
    'totalClicks': 0,
    'totalReach': 0,
    'totalLeads': 0,
    'totalBookings': 0,
    'totalDeposits': 0,
    'totalCashCollected': 0,
    'totalCashAmount': 0,
    'adIds': set(),
    'firstAdDate': None,
    'lastAdDate': None
})

for ad in all_ads:
    ad_set_id = ad['adSetId']
    if not ad_set_id:
        continue
    
    ad_set = ad_sets_data[ad_set_id]
    ad_set['adSetName'] = ad['adSetName']
    ad_set['campaignId'] = ad['campaignId']
    ad_set['campaignName'] = ad['campaignName']
    
    # Aggregate Facebook stats
    ad_set['totalSpend'] += ad['facebookStats']['spend']
    ad_set['totalImpressions'] += ad['facebookStats']['impressions']
    ad_set['totalClicks'] += ad['facebookStats']['clicks']
    ad_set['totalReach'] += ad['facebookStats']['reach']
    
    # Aggregate GHL stats
    ad_set['totalLeads'] += ad['ghlStats']['leads']
    ad_set['totalBookings'] += ad['ghlStats']['bookings']
    ad_set['totalDeposits'] += ad['ghlStats']['deposits']
    ad_set['totalCashCollected'] += ad['ghlStats']['cashCollected']
    ad_set['totalCashAmount'] += ad['ghlStats']['cashAmount']
    
    # Track ads
    ad_set['adIds'].add(ad['adId'])
    
    # Track date range
    if ad['createdAt']:
        if not ad_set['firstAdDate'] or ad['createdAt'] < ad_set['firstAdDate']:
            ad_set['firstAdDate'] = ad['createdAt']
        if not ad_set['lastAdDate'] or ad['createdAt'] > ad_set['lastAdDate']:
            ad_set['lastAdDate'] = ad['createdAt']

# Calculate computed metrics for ad sets
for ad_set_id, ad_set in ad_sets_data.items():
    ad_set['totalProfit'] = ad_set['totalCashAmount'] - ad_set['totalSpend']
    ad_set['cpl'] = ad_set['totalSpend'] / ad_set['totalLeads'] if ad_set['totalLeads'] > 0 else 0
    ad_set['cpb'] = ad_set['totalSpend'] / ad_set['totalBookings'] if ad_set['totalBookings'] > 0 else 0
    ad_set['cpa'] = ad_set['totalSpend'] / ad_set['totalDeposits'] if ad_set['totalDeposits'] > 0 else 0
    
    # Averages
    if ad_set['totalImpressions'] > 0:
        ad_set['avgCPM'] = (ad_set['totalSpend'] / ad_set['totalImpressions']) * 1000
        ad_set['avgCTR'] = (ad_set['totalClicks'] / ad_set['totalImpressions']) * 100
    else:
        ad_set['avgCPM'] = 0
        ad_set['avgCTR'] = 0
    
    if ad_set['totalClicks'] > 0:
        ad_set['avgCPC'] = ad_set['totalSpend'] / ad_set['totalClicks']
    else:
        ad_set['avgCPC'] = 0
    
    # Count
    ad_set['adCount'] = len(ad_set['adIds'])

print(f"✅ Aggregated {len(ad_sets_data)} ad sets")
print()

# ============================================================================
# PHASE 4: Write campaigns to Firebase
# ============================================================================

print("📊 PHASE 4: Writing campaigns to Firebase...")
print()

batch = db.batch()
batch_count = 0

for campaign_id, campaign in campaigns_data.items():
    campaign_ref = db.collection('campaigns').document(campaign_id)
    
    # Convert sets to counts
    campaign_doc = {
        'campaignId': campaign_id,
        'campaignName': campaign.get('campaignName', ''),
        'status': campaign['status'],
        'totalSpend': campaign['totalSpend'],
        'totalImpressions': campaign['totalImpressions'],
        'totalClicks': campaign['totalClicks'],
        'totalReach': campaign['totalReach'],
        'avgCPM': campaign['avgCPM'],
        'avgCPC': campaign['avgCPC'],
        'avgCTR': campaign['avgCTR'],
        'totalLeads': campaign['totalLeads'],
        'totalBookings': campaign['totalBookings'],
        'totalDeposits': campaign['totalDeposits'],
        'totalCashCollected': campaign['totalCashCollected'],
        'totalCashAmount': campaign['totalCashAmount'],
        'totalProfit': campaign['totalProfit'],
        'cpl': campaign['cpl'],
        'cpb': campaign['cpb'],
        'cpa': campaign['cpa'],
        'roi': campaign['roi'],
        'leadToBookingRate': campaign['leadToBookingRate'],
        'bookingToDepositRate': campaign['bookingToDepositRate'],
        'depositToCashRate': campaign['depositToCashRate'],
        'adSetCount': campaign['adSetCount'],
        'adCount': campaign['adCount'],
        'lastUpdated': firestore.SERVER_TIMESTAMP,
        'createdAt': campaign.get('firstAdDate') or firestore.SERVER_TIMESTAMP,
        'firstAdDate': campaign.get('firstAdDate'),
        'lastAdDate': campaign.get('lastAdDate')
    }
    
    batch.set(campaign_ref, campaign_doc, merge=True)
    batch_count += 1
    stats['campaigns_created'] += 1
    
    # Commit batch every 500 operations
    if batch_count >= 500:
        batch.commit()
        batch = db.batch()
        batch_count = 0

# Commit remaining
if batch_count > 0:
    batch.commit()

print(f"✅ Created {stats['campaigns_created']} campaign documents")
print()

# ============================================================================
# PHASE 5: Write ad sets to Firebase
# ============================================================================

print("📊 PHASE 5: Writing ad sets to Firebase...")
print()

batch = db.batch()
batch_count = 0

for ad_set_id, ad_set in ad_sets_data.items():
    ad_set_ref = db.collection('adSets').document(ad_set_id)
    
    ad_set_doc = {
        'adSetId': ad_set_id,
        'adSetName': ad_set.get('adSetName', ''),
        'campaignId': ad_set.get('campaignId', ''),
        'campaignName': ad_set.get('campaignName', ''),
        'totalSpend': ad_set['totalSpend'],
        'totalImpressions': ad_set['totalImpressions'],
        'totalClicks': ad_set['totalClicks'],
        'totalReach': ad_set['totalReach'],
        'avgCPM': ad_set['avgCPM'],
        'avgCPC': ad_set['avgCPC'],
        'avgCTR': ad_set['avgCTR'],
        'totalLeads': ad_set['totalLeads'],
        'totalBookings': ad_set['totalBookings'],
        'totalDeposits': ad_set['totalDeposits'],
        'totalCashCollected': ad_set['totalCashCollected'],
        'totalCashAmount': ad_set['totalCashAmount'],
        'totalProfit': ad_set['totalProfit'],
        'cpl': ad_set['cpl'],
        'cpb': ad_set['cpb'],
        'cpa': ad_set['cpa'],
        'adCount': ad_set['adCount'],
        'lastUpdated': firestore.SERVER_TIMESTAMP,
        'createdAt': ad_set.get('firstAdDate') or firestore.SERVER_TIMESTAMP,
        'firstAdDate': ad_set.get('firstAdDate'),
        'lastAdDate': ad_set.get('lastAdDate')
    }
    
    batch.set(ad_set_ref, ad_set_doc, merge=True)
    batch_count += 1
    stats['ad_sets_created'] += 1
    
    # Commit batch every 500 operations
    if batch_count >= 500:
        batch.commit()
        batch = db.batch()
        batch_count = 0

# Commit remaining
if batch_count > 0:
    batch.commit()

print(f"✅ Created {stats['ad_sets_created']} ad set documents")
print()

# ============================================================================
# PHASE 6: Write ads to Firebase
# ============================================================================

print("📊 PHASE 6: Writing ads to Firebase...")
print()

batch = db.batch()
batch_count = 0

for ad in all_ads:
    ad_ref = db.collection('ads').document(ad['adId'])
    
    ad_doc = {
        'adId': ad['adId'],
        'adName': ad['adName'],
        'adSetId': ad['adSetId'],
        'adSetName': ad['adSetName'],
        'campaignId': ad['campaignId'],
        'campaignName': ad['campaignName'],
        'facebookStats': ad['facebookStats'],
        'ghlStats': ad['ghlStats'],
        'profit': ad['profit'],
        'cpl': ad['cpl'],
        'cpb': ad['cpb'],
        'cpa': ad['cpa'],
        'status': 'ACTIVE',
        'lastUpdated': ad.get('lastUpdated') or firestore.SERVER_TIMESTAMP,
        'lastFacebookSync': ad.get('lastFacebookSync'),
        'lastGHLSync': ad.get('lastGHLSync'),
        'createdAt': ad.get('createdAt') or firestore.SERVER_TIMESTAMP,
        'firstInsightDate': ad['facebookStats'].get('dateStart'),
        'lastInsightDate': ad['facebookStats'].get('dateStop')
    }
    
    batch.set(ad_ref, ad_doc, merge=True)
    batch_count += 1
    stats['ads_created'] += 1
    
    # Commit batch every 500 operations
    if batch_count >= 500:
        batch.commit()
        batch = db.batch()
        batch_count = 0

# Commit remaining
if batch_count > 0:
    batch.commit()

print(f"✅ Created {stats['ads_created']} ad documents")
print()

# ============================================================================
# PHASE 7: Fetch GHL opportunities and create mapping
# ============================================================================

print("📊 PHASE 7: Fetching GHL opportunities and creating mapping...")
print()

import requests

GHL_API_KEY = 'pit-22f8af95-3244-41e7-9a52-22c87b166f5a'
GHL_LOCATION_ID = 'QdLXaFEqrdF0JbVbpKLw'
ANDRIES_PIPELINE_ID = 'XeAGJWRnUGJ5tuhXam2g'
DAVIDE_PIPELINE_ID = 'pTbNvnrXqJc9u1oxir3q'

headers = {
    'Authorization': f'Bearer {GHL_API_KEY}',
    'Version': '2021-07-28'
}

# Fetch all opportunities
all_opportunities = []
page = 1

while True:
    print(f"   Fetching page {page}...")
    
    params = {
        'location_id': GHL_LOCATION_ID,
        'limit': 100,
        'page': page
    }
    
    response = requests.get(
        'https://services.leadconnectorhq.com/opportunities/search',
        headers=headers,
        params=params
    )
    
    if response.status_code != 200:
        print(f"   ⚠️  Error fetching opportunities: {response.status_code}")
        break
    
    data = response.json()
    opportunities = data.get('opportunities', [])
    
    if not opportunities:
        print(f"   ✅ Reached end of data")
        break
    
    all_opportunities.extend(opportunities)
    page += 1
    
    # Rate limiting
    time.sleep(0.2)

print(f"✅ Fetched {len(all_opportunities)} total opportunities")

# Filter to Andries and Davide pipelines
filtered_opportunities = [
    opp for opp in all_opportunities
    if opp.get('pipelineId') in [ANDRIES_PIPELINE_ID, DAVIDE_PIPELINE_ID]
]

print(f"✅ Filtered to {len(filtered_opportunities)} opportunities (Andries & Davide)")
print()

# ============================================================================
# PHASE 7.5: Fetch Form Submissions to get accurate Ad IDs
# ============================================================================

print("📊 PHASE 7.5: Fetching form submissions to extract Ad IDs...")
print()

# Create a mapping of contactId -> adId from form submissions
contact_to_ad_from_forms = {}

# Fetch form submissions from the last 120 days (adjust as needed)
from datetime import datetime, timedelta

end_date = datetime.now()
start_date = end_date - timedelta(days=120)

print(f"   Fetching submissions from {start_date.strftime('%Y-%m-%d')} to {end_date.strftime('%Y-%m-%d')}...")

page = 1
total_submissions = 0
submissions_with_ad_id = 0

while True:
    print(f"   Fetching form submissions page {page}...")
    
    params = {
        'locationId': GHL_LOCATION_ID,
        'startAt': start_date.strftime('%Y-%m-%dT00:00:00.000Z'),
        'endAt': end_date.strftime('%Y-%m-%dT23:59:59.999Z'),
        'limit': 100,
        'page': page
    }
    
    response = requests.get(
        'https://services.leadconnectorhq.com/forms/submissions',
        headers=headers,
        params=params
    )
    
    if response.status_code != 200:
        print(f"   ⚠️  Error fetching form submissions: {response.status_code}")
        break
    
    data = response.json()
    submissions = data.get('submissions', [])
    
    if not submissions:
        print(f"   ✅ Reached end of form submissions")
        break
    
    total_submissions += len(submissions)
    
    # Extract Ad IDs from submissions
    for submission in submissions:
        contact_id = submission.get('contactId')
        if not contact_id:
            continue
        
        others = submission.get('others', {})
        
        # Try to get Ad ID from lastAttributionSource
        last_attr = others.get('lastAttributionSource', {})
        ad_id = last_attr.get('adId')
        
        # If not found, try eventData.url_params
        if not ad_id:
            event_data = others.get('eventData', {})
            url_params = event_data.get('url_params', {})
            ad_id = url_params.get('ad_id')
        
        # Store the mapping if we found an Ad ID
        if ad_id and str(ad_id) in ad_map:
            contact_to_ad_from_forms[contact_id] = str(ad_id)
            submissions_with_ad_id += 1
    
    # Check if there are more pages
    total = data.get('total', 0)
    if page * 100 >= total:
        break
    
    page += 1
    
    # Rate limiting
    time.sleep(0.2)

print(f"✅ Processed {total_submissions} form submissions")
print(f"✅ Found {submissions_with_ad_id} submissions with valid Ad IDs")
print(f"✅ Created contact-to-ad mapping for {len(contact_to_ad_from_forms)} contacts")
print()

# ============================================================================
# PHASE 8: Assign Ad IDs to opportunities (prevent duplicates)
# ============================================================================

print("📊 PHASE 8: Assigning Ad IDs to opportunities...")
print()

batch = db.batch()
batch_count = 0

assignment_stats = {
    'form_submission_ad_id': 0,
    'contact_ad_id': 0,
    'contact_adset_id': 0,
    'h_ad_id': 0,
    'campaign_id_and_ad_name': 0,
    'campaign_id': 0,
    'unassigned': 0
}

total_opps = len(filtered_opportunities)
processed_count = 0

for opp in filtered_opportunities:
    opp_id = opp.get('id')
    contact_id = opp.get('contactId') or opp.get('contact', {}).get('id')
    
    if not opp_id:
        continue
    
    # Try to extract h_ad_id from attributions
    assigned_ad_id = None
    assignment_method = None
    confidence = 0
    
    attributions = opp.get('attributions', [])
    
    # PRIORITY 1: Ad ID from Form Submissions API (MOST ACCURATE!)
    if contact_id and contact_id in contact_to_ad_from_forms:
        assigned_ad_id = contact_to_ad_from_forms[contact_id]
        assignment_method = 'form_submission_ad_id'
        confidence = 100
        assignment_stats['form_submission_ad_id'] += 1
    
    # PRIORITY 2: Fetch Contact object to get attributionSource (only if not found in forms)
    contact_ad_id = None
    contact_adset_id = None
    contact_campaign_id = None
    
    if not assigned_ad_id and contact_id:
        try:
            contact_response = requests.get(
                f'https://services.leadconnectorhq.com/contacts/{contact_id}',
                headers=headers,
                timeout=10
            )
            
            if contact_response.status_code == 200:
                contact_data = contact_response.json().get('contact', {})
                
                # Try lastAttributionSource first (most recent)
                last_attr_source = contact_data.get('lastAttributionSource', {})
                contact_ad_id = last_attr_source.get('adId')
                contact_adset_id = last_attr_source.get('adSetId')
                contact_campaign_id = last_attr_source.get('campaignId')
                
                # Fallback to attributionSource if not found
                if not contact_ad_id:
                    attr_source = contact_data.get('attributionSource', {})
                    contact_ad_id = attr_source.get('adId')
                    contact_adset_id = contact_adset_id or attr_source.get('adSetId')
                    contact_campaign_id = contact_campaign_id or attr_source.get('campaignId')
        except Exception as e:
            print(f"   ⚠️  Error fetching contact {contact_id}: {e}")
    
    # Priority 3: Direct Ad ID from Contact object
    if not assigned_ad_id and contact_ad_id and str(contact_ad_id) in ad_map:
        assigned_ad_id = str(contact_ad_id)
        assignment_method = 'contact_ad_id'
        confidence = 100
        assignment_stats['contact_ad_id'] += 1
    
    # Priority 4: Ad Set ID from Contact object (for older Lead Forms without form submission data)
    if not assigned_ad_id and contact_adset_id:
        # Find ads in this ad set
        matching_ads = [ad for ad in all_ads if ad.get('adSetId') == str(contact_adset_id)]
        
        if matching_ads:
            # If only one ad in the ad set, assign it
            if len(matching_ads) == 1:
                assigned_ad_id = matching_ads[0]['adId']
                assignment_method = 'contact_adset_id_single'
                confidence = 95
                assignment_stats['contact_adset_id'] += 1
            else:
                # Multiple ads in ad set - try to match by utmMedium (interest targeting)
                for attr in reversed(attributions):
                    utm_medium = attr.get('utmMedium', '').lower().strip()
                    if utm_medium:
                        # Find ad with matching ad set name (which often contains the interest)
                        for ad in matching_ads:
                            ad_set_name = ad.get('adSetName', '').lower()
                            if utm_medium in ad_set_name or ad_set_name in utm_medium:
                                assigned_ad_id = ad['adId']
                                assignment_method = 'contact_adset_id_medium'
                                confidence = 90
                                assignment_stats['contact_adset_id'] += 1
                                break
                        if assigned_ad_id:
                            break
                
                # If still not found, take the first ad in the ad set
                if not assigned_ad_id:
                    assigned_ad_id = matching_ads[0]['adId']
                    assignment_method = 'contact_adset_id_first'
                    confidence = 85
                    assignment_stats['contact_adset_id'] += 1
    
    # Priority 3: Campaign ID + Ad Name
    if not assigned_ad_id:
        for attr in reversed(attributions):
            # Check multiple campaign ID variations
            campaign_id = (
                attr.get('utmCampaignId') or
                attr.get('utm_campaign_id') or
                attr.get('campaignId') or
                attr.get('campaign_id') or
                attr.get('Campaign Id')
            )
            
            # Check in pageDetails if not found
            if not campaign_id:
                page_details = attr.get('pageDetails') or attr.get('page_details') or {}
                campaign_id = (
                    page_details.get('campaignId') or
                    page_details.get('campaign_id') or
                    page_details.get('Campaign Id')
                )
            
            ad_name = attr.get('utmCampaign', '').lower().strip()
            
            if campaign_id and ad_name:
                key = (campaign_id, ad_name)
                if key in ad_name_to_ads and ad_name_to_ads[key]:
                    assigned_ad_id = ad_name_to_ads[key][0]  # Take first match
                    assignment_method = 'campaign_id_and_ad_name'
                    confidence = 80
                    assignment_stats['campaign_id_and_ad_name'] += 1
                    break
    
    # Priority 3: Campaign ID only
    if not assigned_ad_id:
        for attr in reversed(attributions):
            # Check multiple campaign ID variations
            campaign_id = (
                attr.get('utmCampaignId') or
                attr.get('utm_campaign_id') or
                attr.get('campaignId') or
                attr.get('campaign_id') or
                attr.get('Campaign Id')
            )
            
            # Check in pageDetails if not found
            if not campaign_id:
                page_details = attr.get('pageDetails') or attr.get('page_details') or {}
                campaign_id = (
                    page_details.get('campaignId') or
                    page_details.get('campaign_id') or
                    page_details.get('Campaign Id')
                )
            
            if campaign_id and str(campaign_id) in campaign_to_ads and campaign_to_ads[str(campaign_id)]:
                assigned_ad_id = campaign_to_ads[str(campaign_id)][0]  # Take first ad in campaign
                assignment_method = 'campaign_id'
                confidence = 60
                assignment_stats['campaign_id'] += 1
                break
    
    if not assigned_ad_id:
        assignment_stats['unassigned'] += 1
        continue
    
    # Create mapping document
    mapping_ref = db.collection('ghlOpportunityMapping').document(opp_id)
    
    # Get campaign info from assigned ad
    assigned_ad = ad_map.get(assigned_ad_id, {})
    
    mapping_doc = {
        'opportunityId': opp_id,
        'assignedAdId': assigned_ad_id,
        'assignmentMethod': assignment_method,
        'assignmentConfidence': confidence,
        'campaignId': assigned_ad.get('campaignId', ''),
        'campaignName': assigned_ad.get('campaignName', ''),
        'adName': assigned_ad.get('adName', ''),
        'stage': opp.get('status', ''),
        'stageCategory': get_stage_category(opp.get('status', '')),
        'monetaryValue': opp.get('monetaryValue', 0),
        'opportunityCreatedAt': opp.get('createdAt') or opp.get('dateAdded'),
        'assignedAt': firestore.SERVER_TIMESTAMP
    }
    
    batch.set(mapping_ref, mapping_doc, merge=True)
    batch_count += 1
    stats['opportunities_mapped'] += 1
    processed_count += 1
    
    # Show progress every 100 opportunities
    if processed_count % 100 == 0:
        print(f"   Progress: {processed_count}/{total_opps} opportunities processed ({(processed_count/total_opps*100):.1f}%)")
    
    # Commit batch every 500 operations
    if batch_count >= 500:
        batch.commit()
        batch = db.batch()
        batch_count = 0

# Commit remaining
if batch_count > 0:
    batch.commit()

print(f"✅ Created {stats['opportunities_mapped']} opportunity mappings")
print(f"   Assignment breakdown:")
print(f"   - Form Submission Ad ID (BEST!): {assignment_stats['form_submission_ad_id']} ({assignment_stats['form_submission_ad_id']/len(filtered_opportunities)*100:.1f}%)")
print(f"   - Contact Ad ID (direct): {assignment_stats['contact_ad_id']} ({assignment_stats['contact_ad_id']/len(filtered_opportunities)*100:.1f}%)")
print(f"   - Contact Ad Set ID (Lead Forms): {assignment_stats['contact_adset_id']} ({assignment_stats['contact_adset_id']/len(filtered_opportunities)*100:.1f}%)")
print(f"   - Opportunity h_ad_id: {assignment_stats['h_ad_id']} ({assignment_stats['h_ad_id']/len(filtered_opportunities)*100:.1f}%)")
print(f"   - Campaign ID + Ad Name: {assignment_stats['campaign_id_and_ad_name']} ({assignment_stats['campaign_id_and_ad_name']/len(filtered_opportunities)*100:.1f}%)")
print(f"   - Campaign ID only: {assignment_stats['campaign_id']} ({assignment_stats['campaign_id']/len(filtered_opportunities)*100:.1f}%)")
print(f"   - Unassigned: {assignment_stats['unassigned']} ({assignment_stats['unassigned']/len(filtered_opportunities)*100:.1f}%)")
print()
print(f"   🎉 NEW: Form Submissions API provides the most accurate Ad ID matching!")
print()

# ============================================================================
# PHASE 9: Create ghlOpportunities documents
# ============================================================================

print("📊 PHASE 9: Creating ghlOpportunities documents...")
print()

# Load all mappings
mappings = {}
mapping_docs = db.collection('ghlOpportunityMapping').stream()
for mapping_doc in mapping_docs:
    mapping_data = mapping_doc.to_dict()
    mappings[mapping_doc.id] = mapping_data

batch = db.batch()
batch_count = 0

for opp in filtered_opportunities:
    opp_id = opp.get('id')
    if not opp_id or opp_id not in mappings:
        continue
    
    mapping = mappings[opp_id]
    assigned_ad_id = mapping.get('assignedAdId') or mapping.get('assigned_ad_id')
    assigned_ad = ad_map.get(assigned_ad_id, {})
    
    # Extract attribution data
    attributions = opp.get('attributions', [])
    last_attr = attributions[-1] if attributions else {}
    
    opp_ref = db.collection('ghlOpportunities').document(opp_id)
    
    opp_doc = {
        'opportunityId': opp_id,
        'opportunityName': opp.get('name', ''),
        'contactId': opp.get('contact', {}).get('id', ''),
        'contactName': opp.get('contact', {}).get('name', ''),
        'adId': assigned_ad_id,
        'adName': assigned_ad.get('adName', ''),
        'adSetId': assigned_ad.get('adSetId', ''),
        'adSetName': assigned_ad.get('adSetName', ''),
        'campaignId': assigned_ad.get('campaignId', ''),
        'campaignName': assigned_ad.get('campaignName', ''),
        'currentStage': opp.get('status', ''),
        'stageCategory': get_stage_category(opp.get('status', '')),
        'pipelineId': opp.get('pipelineId', ''),
        'pipelineName': 'Andries Pipeline' if opp.get('pipelineId') == ANDRIES_PIPELINE_ID else 'Davide Pipeline',
        'monetaryValue': opp.get('monetaryValue', 0),
        'utmSource': last_attr.get('utmSource', ''),
        'utmMedium': last_attr.get('utmMedium', ''),
        'utmCampaign': last_attr.get('utmCampaign', ''),
        'h_ad_id': extract_ad_id_from_attribution(last_attr) or '',
        'createdAt': opp.get('createdAt') or opp.get('dateAdded'),
        'lastStageChange': opp.get('lastStatusChangeAt'),
        'lastUpdated': firestore.SERVER_TIMESTAMP
    }
    
    batch.set(opp_ref, opp_doc, merge=True)
    batch_count += 1
    stats['opportunities_migrated'] += 1
    
    # Commit batch every 500 operations
    if batch_count >= 500:
        batch.commit()
        batch = db.batch()
        batch_count = 0

# Commit remaining
if batch_count > 0:
    batch.commit()

print(f"✅ Created {stats['opportunities_migrated']} ghlOpportunities documents")
print()

# ============================================================================
# SUMMARY
# ============================================================================

print("=" * 100)
print("MIGRATION COMPLETE")
print("=" * 100)
print()
print(f"✅ Campaigns created: {stats['campaigns_created']}")
print(f"✅ Ad sets created: {stats['ad_sets_created']}")
print(f"✅ Ads created: {stats['ads_created']}")
print(f"✅ Opportunities mapped: {stats['opportunities_mapped']}")
print(f"✅ Opportunities migrated: {stats['opportunities_migrated']}")
print()

if stats['errors']:
    print(f"⚠️  Errors encountered: {len(stats['errors'])}")
    for error in stats['errors'][:10]:  # Show first 10 errors
        print(f"   - {error}")
    print()

print("=" * 100)
print("NEXT STEPS:")
print("1. Run verify_split_collections.py to verify the migration")
print("2. Check for cross-campaign duplicates")
print("3. Deploy Cloud Functions with dual-write enabled")
print("4. Update Flutter app to use new collections")
print("=" * 100)

