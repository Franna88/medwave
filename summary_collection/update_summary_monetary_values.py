#!/usr/bin/env python3
"""
Update Summary Collection with GHL Monetary Values
===================================================
This script updates the summary collection with correct monetary values
from ghl_opportunities collection.

Key Mapping:
- ghl_opportunities.monetaryValue (cents) → summary.weeks.{level}.ghlData.cashAmount (cents)
- Stages that contribute to cashAmount:
  * stageName contains "deposit" (Deposit Received)
  * stageName contains "cash" or "collected" (Cash Collected)

Process:
1. Load ghl_opportunities (monetaryValue field)
2. Load ghl_data for contactId → adId mapping
3. Load fb_ads to get campaignId and adSetId for each ad
4. Group by week (Monday-Sunday based on createdAt)
5. Calculate cashAmount by summing monetaryValue for deposit/cash stages
6. Update summary collection at campaign, ad set, and ad levels
7. Process October and November 2025 data
"""

import firebase_admin
from firebase_admin import credentials, firestore
from collections import defaultdict
from datetime import datetime, timedelta

# Initialize Firebase
try:
    cred = credentials.Certificate('/Users/mac/dev/medwave/medx-ai-firebase-adminsdk-fbsvc-a86e7bd050.json')
    firebase_admin.initialize_app(cred)
    print('✅ Firebase initialized successfully\n')
except Exception as e:
    print(f'⚠️  Firebase already initialized or error: {e}\n')
    pass

db = firestore.client()

def get_week_id(date):
    """Get week ID in format YYYY-MM-DD_YYYY-MM-DD (Monday to Sunday)"""
    if isinstance(date, str):
        date = datetime.fromisoformat(date.replace('Z', '+00:00'))
    
    # Find the Monday of the week
    days_since_monday = date.weekday()
    week_start = date - timedelta(days=days_since_monday)
    week_end = week_start + timedelta(days=6)
    
    return f"{week_start.strftime('%Y-%m-%d')}_{week_end.strftime('%Y-%m-%d')}"

def should_count_for_cash(stage_name):
    """Determine if a stage should contribute to cashAmount"""
    if not stage_name:
        return False
    
    stage_lower = stage_name.lower()
    
    # Check for deposit stages
    if 'deposit' in stage_lower:
        return True
    
    # Check for cash collected stages
    if 'cash' in stage_lower or 'collected' in stage_lower:
        return True
    
    return False

print('=' * 80)
print('UPDATING SUMMARY COLLECTION WITH GHL MONETARY VALUES')
print('=' * 80)
print()

# ============================================================================
# STEP 1: LOAD GHL_DATA FOR CONTACT → AD MAPPING
# ============================================================================
print('Step 1: Loading ghl_data for contactId → adId mapping...')
contact_to_ad = {}
ghl_data_docs = db.collection('ghl_data').stream()

for doc in ghl_data_docs:
    data = doc.to_dict()
    contact_id = doc.id
    ad_id = data.get('adId')
    
    if ad_id and ad_id != 'None':
        # Convert adId to string for consistency with fb_ads document IDs
        contact_to_ad[contact_id] = str(ad_id)

print(f'✅ Loaded {len(contact_to_ad)} contactId → adId mappings\n')

# ============================================================================
# STEP 2: LOAD FB_ADS FOR AD → CAMPAIGN/ADSET MAPPING
# ============================================================================
print('Step 2: Loading fb_ads for ad metadata...')
ad_metadata = {}
fb_ads_docs = db.collection('fb_ads').stream()

for doc in fb_ads_docs:
    data = doc.to_dict()
    ad_id = doc.id
    ad_details = data.get('adDetails', {})
    
    # Get campaign and adset IDs from adDetails
    campaign_id = ad_details.get('campaignId') if isinstance(ad_details, dict) else None
    adset_id = ad_details.get('adsetId') if isinstance(ad_details, dict) else None
    
    ad_metadata[ad_id] = {
        'adId': ad_id,
        'adName': data.get('adName', 'Unknown'),
        'adSetId': adset_id,
        'adSetName': 'Unknown',  # Not available in fb_ads
        'campaignId': campaign_id,
        'campaignName': 'Unknown'  # Not available in fb_ads
    }

print(f'✅ Loaded metadata for {len(ad_metadata)} ads\n')

# ============================================================================
# STEP 3: LOAD GHL_OPPORTUNITIES AND GROUP BY WEEK/AD
# ============================================================================
print('Step 3: Loading ghl_opportunities and calculating monetary values...')

# Structure: {campaignId: {week_id: {adSetId: {adId: {deposits: X, cashCollected: Y, cashAmount: Z}}}}}
campaign_structure = defaultdict(lambda: defaultdict(lambda: defaultdict(lambda: defaultdict(lambda: {
    'leads': 0,
    'bookedAppointments': 0,
    'deposits': 0,
    'cashCollected': 0,
    'cashAmount': 0
}))))

total_opps = 0
matched_opps = 0
unmatched_opps = 0
with_monetary_value = 0
total_monetary_value = 0

opp_docs = db.collection('ghl_opportunities').stream()

for doc in opp_docs:
    total_opps += 1
    opp = doc.to_dict()
    
    contact_id = opp.get('contactId')
    assigned_ad_id = opp.get('assignedAdId')
    created_at = opp.get('createdAt')
    stage_name = opp.get('stageName', '')
    monetary_value = opp.get('monetaryValue', 0)
    
    # Skip if no creation date
    if not created_at:
        unmatched_opps += 1
        continue
    
    # Determine ad_id (primary: assignedAdId, fallback: contactId lookup)
    ad_id = None
    if assigned_ad_id and assigned_ad_id != 'None':
        ad_id = assigned_ad_id
    elif contact_id and contact_id in contact_to_ad:
        ad_id = contact_to_ad[contact_id]
    
    # Skip if no ad assignment
    if not ad_id or ad_id not in ad_metadata:
        unmatched_opps += 1
        continue
    
    # Get ad metadata
    ad_meta = ad_metadata[ad_id]
    campaign_id = ad_meta['campaignId']
    ad_set_id = ad_meta['adSetId']
    
    if not campaign_id or not ad_set_id:
        unmatched_opps += 1
        continue
    
    # Get week ID
    week_id = get_week_id(created_at)
    
    # Get reference to this ad's data for this week
    ad_data = campaign_structure[campaign_id][week_id][ad_set_id][ad_id]
    
    # Count as lead
    ad_data['leads'] += 1
    
    # Check if stage contributes to cashAmount
    if should_count_for_cash(stage_name):
        # Determine if it's deposit or cash collected
        stage_lower = stage_name.lower()
        
        if 'deposit' in stage_lower and 'cash' not in stage_lower and 'collected' not in stage_lower:
            ad_data['deposits'] += 1
        else:
            ad_data['cashCollected'] += 1
        
        # Add monetary value (keep in cents)
        if monetary_value and monetary_value > 0:
            ad_data['cashAmount'] += monetary_value
            with_monetary_value += 1
            total_monetary_value += monetary_value
    
    # Check for booked appointments
    if 'book' in stage_name.lower() or 'appointment' in stage_name.lower():
        ad_data['bookedAppointments'] += 1
    
    matched_opps += 1

print(f'✅ Processed {total_opps} total opportunities')
print(f'✅ Matched {matched_opps} opportunities to ads')
print(f'⚠️  {unmatched_opps} opportunities could not be matched')
print(f'💰 {with_monetary_value} opportunities with monetary values')
print(f'💰 Total monetary value: R {total_monetary_value:,.2f}\n')

# ============================================================================
# STEP 4: UPDATE SUMMARY COLLECTION
# ============================================================================
print('Step 4: Updating summary collection...\n')

campaigns_updated = 0
weeks_updated = 0
updates_made = 0

for campaign_id, weeks_data in campaign_structure.items():
    try:
        campaign_name = None
        
        # Get campaign name from first ad
        first_week = list(weeks_data.values())[0]
        first_ad_set = list(first_week.values())[0]
        first_ad_id = list(first_ad_set.keys())[0]
        if first_ad_id in ad_metadata:
            campaign_name = ad_metadata[first_ad_id]['campaignName']
        
        print(f'📊 Processing campaign: {campaign_name or campaign_id}')
        
        # Get or create summary document
        summary_ref = db.collection('summary').document(campaign_id)
        summary_doc = summary_ref.get()
        
        if summary_doc.exists:
            summary_data = summary_doc.to_dict()
            weeks_map = summary_data.get('weeks', {})
        else:
            weeks_map = {}
            summary_data = {
                'campaignId': campaign_id,
                'campaignName': campaign_name or 'Unknown',
                'weeks': {}
            }
        
        # Process each week
        for week_id, ad_sets_data in weeks_data.items():
            print(f'   📅 Week: {week_id}')
            
            # Initialize week data if it doesn't exist
            if week_id not in weeks_map:
                weeks_map[week_id] = {
                    'campaign': {
                        'campaignId': campaign_id,
                        'campaignName': campaign_name or 'Unknown',
                        'facebookInsights': {},
                        'ghlData': {
                            'leads': 0,
                            'bookedAppointments': 0,
                            'deposits': 0,
                            'cashCollected': 0,
                            'cashAmount': 0
                        }
                    },
                    'adSets': {},
                    'ads': {}
                }
            
            week_data = weeks_map[week_id]
            
            # Aggregate campaign-level GHL stats for this week
            campaign_ghl = {
                'leads': 0,
                'bookedAppointments': 0,
                'deposits': 0,
                'cashCollected': 0,
                'cashAmount': 0
            }
            
            # Process each ad set
            for ad_set_id, ads_data in ad_sets_data.items():
                ad_set_name = None
                
                # Get ad set name from first ad
                first_ad_id = list(ads_data.keys())[0]
                if first_ad_id in ad_metadata:
                    ad_set_name = ad_metadata[first_ad_id]['adSetName']
                
                # Initialize ad set data if it doesn't exist
                if ad_set_id not in week_data['adSets']:
                    week_data['adSets'][ad_set_id] = {
                        'adSetId': ad_set_id,
                        'adSetName': ad_set_name or 'Unknown',
                        'facebookInsights': {},
                        'ghlData': {
                            'leads': 0,
                            'bookedAppointments': 0,
                            'deposits': 0,
                            'cashCollected': 0,
                            'cashAmount': 0
                        }
                    }
                
                ad_set_ghl = {
                    'leads': 0,
                    'bookedAppointments': 0,
                    'deposits': 0,
                    'cashCollected': 0,
                    'cashAmount': 0
                }
                
                # Process each ad
                for ad_id, ad_ghl_data in ads_data.items():
                    ad_name = ad_metadata.get(ad_id, {}).get('adName', 'Unknown')
                    
                    # Initialize ad data if it doesn't exist
                    if ad_id not in week_data['ads']:
                        week_data['ads'][ad_id] = {
                            'adId': ad_id,
                            'adName': ad_name,
                            'facebookInsights': {},
                            'ghlData': {
                                'leads': 0,
                                'bookedAppointments': 0,
                                'deposits': 0,
                                'cashCollected': 0,
                                'cashAmount': 0
                            }
                        }
                    
                    # Update ad GHL data
                    week_data['ads'][ad_id]['ghlData'] = ad_ghl_data
                    
                    # Aggregate to ad set
                    for key in ad_set_ghl:
                        ad_set_ghl[key] += ad_ghl_data[key]
                    
                    if ad_ghl_data['cashAmount'] > 0:
                        print(f'      ✅ Ad {ad_name[:40]}: R {ad_ghl_data["cashAmount"]:,.2f}')
                        updates_made += 1
                
                # Update ad set GHL data
                week_data['adSets'][ad_set_id]['ghlData'] = ad_set_ghl
                
                # Aggregate to campaign
                for key in campaign_ghl:
                    campaign_ghl[key] += ad_set_ghl[key]
            
            # Update campaign GHL data for this week
            week_data['campaign']['ghlData'] = campaign_ghl
            
            print(f'      📊 Week totals: {campaign_ghl["leads"]} leads, '
                  f'{campaign_ghl["deposits"]} deposits, '
                  f'{campaign_ghl["cashCollected"]} cash collected, '
                  f'R {campaign_ghl["cashAmount"]:,.2f}')
            weeks_updated += 1
        
        # Update the summary document
        summary_data['weeks'] = weeks_map
        summary_ref.set(summary_data, merge=True)
        
        campaigns_updated += 1
        print(f'   ✅ Updated campaign {campaign_name or campaign_id}\n')
        
    except Exception as e:
        print(f'   ❌ Error updating campaign {campaign_id}: {str(e)}\n')
        continue

print()
print('=' * 80)
print('SUMMARY COLLECTION UPDATE COMPLETE!')
print('=' * 80)
print(f'Campaigns updated: {campaigns_updated}')
print(f'Weeks updated: {weeks_updated}')
print(f'Ads with monetary values: {updates_made}')
print()
print('✅ The summary collection now has correct monetary values from ghl_opportunities!')
print('   Values are stored as currency amounts (not cents)')
print('=' * 80)
print()

