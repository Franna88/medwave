#!/usr/bin/env python3
"""
Update Summary Collection with GHL Data
========================================
This script updates the 'summary' collection with correct GHL data from ghlOpportunities.

The summary collection structure:
summary/{campaignId}/
  weeks: {
    "2025-11-03_2025-11-09": {
      campaign: {
        facebookInsights: {...},
        ghlData: {leads, bookedAppointments, deposits, cashCollected, cashAmount}
      },
      adSets: {
        {adSetId}: {
          facebookInsights: {...},
          ghlData: {...}
        }
      },
      ads: {
        {adId}: {
          facebookInsights: {...},
          ghlData: {...}
        }
      }
    }
  }

This script:
1. Reads all opportunities from ghlOpportunities
2. Groups by ad ID and week (based on createdAt date)
3. Aggregates GHL stats per ad per week
4. Updates the summary collection with correct GHL data
"""

import firebase_admin
from firebase_admin import credentials, firestore
from collections import defaultdict
from datetime import datetime, timedelta

# Initialize Firebase
if not firebase_admin._apps:
    cred = credentials.Certificate('/Users/mac/dev/medwave/medx-ai-firebase-adminsdk-fbsvc-a86e7bd050.json')
    firebase_admin.initialize_app(cred)

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

print("=" * 80)
print("UPDATING SUMMARY COLLECTION WITH GHL DATA")
print("=" * 80)
print()

# Step 1: Load all opportunities
print("Step 1: Loading all opportunities from ghlOpportunities...")
opportunities = list(db.collection('ghlOpportunities').stream())
print(f"Loaded {len(opportunities)} opportunities")
print()

# Step 2: Group opportunities by campaign, ad set, ad, and week
print("Step 2: Grouping opportunities by campaign/ad/week...")

# Structure: {campaignId: {weekId: {adSetId: {adId: [opportunities]}}}}
campaign_weeks = defaultdict(lambda: defaultdict(lambda: defaultdict(lambda: defaultdict(list))))

assigned_count = 0
unassigned_count = 0

for opp_doc in opportunities:
    opp = opp_doc.to_dict()
    opp['id'] = opp_doc.id
    
    assigned_ad_id = opp.get('assignedAdId')
    campaign_id = opp.get('campaignId')
    created_at = opp.get('createdAt')
    
    # Skip if no ad assignment or no date
    if not assigned_ad_id or assigned_ad_id == 'None' or not created_at:
        unassigned_count += 1
        continue
    
    # Get week ID from creation date
    week_id = get_week_id(created_at)
    
    # Get ad details to find ad set
    ad_doc = db.collection('ads').document(assigned_ad_id).get()
    if not ad_doc.exists:
        unassigned_count += 1
        continue
    
    ad_data = ad_doc.to_dict()
    ad_set_id = ad_data.get('adSetId')
    campaign_id = ad_data.get('campaignId')
    
    if not campaign_id or not ad_set_id:
        unassigned_count += 1
        continue
    
    # Add to structure
    campaign_weeks[campaign_id][week_id][ad_set_id][assigned_ad_id].append(opp)
    assigned_count += 1

print(f"Opportunities assigned to campaigns: {assigned_count}")
print(f"Unassigned opportunities: {unassigned_count}")
print(f"Unique campaigns: {len(campaign_weeks)}")
print()

# Step 3: Calculate GHL stats and update summary collection
print("Step 3: Updating summary collection...")
print()

campaigns_updated = 0
weeks_updated = 0

for campaign_id, weeks_data in campaign_weeks.items():
    try:
        print(f"📊 Processing campaign {campaign_id}...")
        
        # Get or create summary document
        summary_ref = db.collection('summary').document(campaign_id)
        summary_doc = summary_ref.get()
        
        if summary_doc.exists:
            summary_data = summary_doc.to_dict()
            weeks_map = summary_data.get('weeks', {})
        else:
            weeks_map = {}
            # Get campaign name from first ad
            first_week = list(weeks_data.values())[0]
            first_ad_set = list(first_week.values())[0]
            first_ad_id = list(first_ad_set.keys())[0]
            ad_doc = db.collection('ads').document(first_ad_id).get()
            campaign_name = ad_doc.to_dict().get('campaignName', 'Unknown') if ad_doc.exists else 'Unknown'
            
            summary_data = {
                'campaignId': campaign_id,
                'campaignName': campaign_name,
                'weeks': {}
            }
        
        # Process each week
        for week_id, ad_sets_data in weeks_data.items():
            print(f"  📅 Week: {week_id}")
            
            # Initialize week data if it doesn't exist
            if week_id not in weeks_map:
                weeks_map[week_id] = {
                    'campaign': {
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
                # Initialize ad set data if it doesn't exist
                if ad_set_id not in week_data['adSets']:
                    week_data['adSets'][ad_set_id] = {
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
                for ad_id, opps in ads_data.items():
                    # Calculate GHL stats for this ad
                    ad_ghl = {
                        'leads': 0,
                        'bookedAppointments': 0,
                        'deposits': 0,
                        'cashCollected': 0,
                        'cashAmount': 0
                    }
                    
                    for opp in opps:
                        stage_category = opp.get('stageCategory', '')
                        monetary_value = opp.get('monetaryValue', 0)
                        
                        # Count as lead
                        ad_ghl['leads'] += 1
                        
                        # Count by stage category
                        if stage_category == 'booking' or stage_category == 'bookedAppointments':
                            ad_ghl['bookedAppointments'] += 1
                        
                        if stage_category == 'deposit':
                            ad_ghl['deposits'] += 1
                            if monetary_value and monetary_value > 0:
                                ad_ghl['cashAmount'] += monetary_value
                        
                        if stage_category == 'cash_collected':
                            ad_ghl['cashCollected'] += 1
                            if monetary_value and monetary_value > 0:
                                ad_ghl['cashAmount'] += monetary_value
                    
                    # Initialize ad data if it doesn't exist
                    if ad_id not in week_data['ads']:
                        week_data['ads'][ad_id] = {
                            'facebookInsights': {},
                            'ghlData': {}
                        }
                    
                    # Update ad GHL data
                    week_data['ads'][ad_id]['ghlData'] = ad_ghl
                    
                    # Aggregate to ad set
                    for key in ad_set_ghl:
                        ad_set_ghl[key] += ad_ghl[key]
                    
                    if ad_ghl['leads'] > 0:
                        print(f"    ✅ Ad {ad_id[:20]}: {ad_ghl['leads']} leads, R {ad_ghl['cashAmount']:,.2f}")
                
                # Update ad set GHL data
                week_data['adSets'][ad_set_id]['ghlData'] = ad_set_ghl
                
                # Aggregate to campaign
                for key in campaign_ghl:
                    campaign_ghl[key] += ad_set_ghl[key]
            
            # Update campaign GHL data for this week
            week_data['campaign']['ghlData'] = campaign_ghl
            
            print(f"    📊 Week totals: {campaign_ghl['leads']} leads, R {campaign_ghl['cashAmount']:,.2f}")
            weeks_updated += 1
        
        # Update the summary document
        summary_data['weeks'] = weeks_map
        summary_ref.set(summary_data, merge=True)
        
        campaigns_updated += 1
        print(f"  ✅ Updated campaign {campaign_id}")
        print()
        
    except Exception as e:
        print(f"  ❌ Error updating campaign {campaign_id}: {str(e)}")
        continue

print()
print("=" * 80)
print("SUMMARY COLLECTION UPDATE COMPLETE!")
print("=" * 80)
print(f"Campaigns updated: {campaigns_updated}")
print(f"Weeks updated: {weeks_updated}")
print()
print("✅ The summary collection now has correct GHL data from ghlOpportunities!")
print("   Your Superadmin should now show accurate GHL metrics!")
print("=" * 80)

