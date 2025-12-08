#!/usr/bin/env python3
"""
Rebuild Summary Collection from Firebase Data
==============================================
This script rebuilds the summary collection using ONLY Firebase data (no API calls).

Data Sources:
- fb_ads collection: Facebook ad performance data
- ghl_data collection: GHL contact and ad_id mappings
- ghl_opportunities collection: Opportunity data with contact IDs

Process:
1. Load all fb_ads data and group by week
2. Create campaign and ad set hierarchies with weekly totals
3. Load ghl_data to get adId and contactId mappings
4. Match ghl_opportunities using contactId and adId
5. Add GHL data per adId per week
6. Aggregate totals to ad set and campaign levels

Output:
- Writes to summary collection with same structure as existing
- Processes December 2025 data
"""

import firebase_admin
from firebase_admin import credentials, firestore
from datetime import datetime, timedelta
from collections import defaultdict
import sys
import os

# ============================================================================
# CONFIGURATION
# ============================================================================

# Date range for December 2025
DECEMBER_START = datetime(2025, 12, 1)
DECEMBER_END = datetime(2025, 12, 31, 23, 59, 59)

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

def get_week_boundaries(date):
    """Get Monday and Sunday for the week containing the given date"""
    if isinstance(date, str):
        date = datetime.fromisoformat(date.replace('Z', '+00:00'))
    
    # Get the Monday of the week
    monday = date - timedelta(days=date.weekday())
    # Get the Sunday of the week
    sunday = monday + timedelta(days=6)
    return monday.date(), sunday.date()

def get_week_id(date):
    """Generate week ID in format YYYY-MM-DD_YYYY-MM-DD"""
    if isinstance(date, str):
        date = datetime.fromisoformat(date.replace('Z', '+00:00'))
    
    monday, sunday = get_week_boundaries(date)
    return f"{monday}_{sunday}"

def get_month_name(date):
    """Get month name and year (e.g., 'November 2025')"""
    if isinstance(date, str):
        date = datetime.fromisoformat(date.replace('Z', '+00:00'))
    return date.strftime('%B %Y')

def get_week_of_month(date):
    """Get week number within the month (1-5)"""
    if isinstance(date, str):
        date = datetime.fromisoformat(date.replace('Z', '+00:00'))
    
    first_day = date.replace(day=1)
    dom = date.day
    adjusted_dom = dom + first_day.weekday()
    return int((adjusted_dom - 1) / 7) + 1

def parse_date(date_value):
    """Parse various date formats to datetime object"""
    if date_value is None:
        return None
    
    if isinstance(date_value, datetime):
        return date_value
    
    if isinstance(date_value, str):
        # Try ISO format
        try:
            return datetime.fromisoformat(date_value.replace('Z', '+00:00'))
        except:
            pass
        
        # Try other formats
        for fmt in ['%Y-%m-%d', '%Y-%m-%dT%H:%M:%S', '%Y-%m-%d %H:%M:%S']:
            try:
                return datetime.strptime(date_value, fmt)
            except:
                continue
    
    # If it has a timestamp method (Firestore timestamp)
    if hasattr(date_value, 'timestamp'):
        return datetime.fromtimestamp(date_value.timestamp())
    
    return None

def is_date_in_range(date, start_date, end_date):
    """Check if date falls within the given range"""
    date = parse_date(date)
    if date is None:
        return False
    
    # Remove timezone info for comparison
    if date.tzinfo:
        date = date.replace(tzinfo=None)
    
    return start_date <= date <= end_date

def is_week_in_date_range(week_id, start_date, end_date):
    """Check if a week (week_id format: YYYY-MM-DD_YYYY-MM-DD) falls within date range"""
    try:
        monday_str, sunday_str = week_id.split('_')
        monday = datetime.strptime(monday_str, '%Y-%m-%d')
        sunday = datetime.strptime(sunday_str, '%Y-%m-%d')
        
        # Week is in range if any part of it overlaps with the date range
        # Check if week's Monday or Sunday falls within range, or if week completely contains the range
        week_start = monday.date()
        week_end = sunday.date()
        range_start = start_date.date() if isinstance(start_date, datetime) else start_date
        range_end = end_date.date() if isinstance(end_date, datetime) else end_date
        
        # Week overlaps if: week_start <= range_end AND week_end >= range_start
        return week_start <= range_end and week_end >= range_start
    except:
        return False

# ============================================================================
# STEP 1: LOAD FB_ADS DATA AND GROUP BY WEEK
# ============================================================================

def load_fb_ads_by_week(db, start_date, end_date):
    """
    Load fb_ads data and group by week
    Returns: {week_id: {ad_id: {ad_data, fb_metrics}}}
    """
    print(f"\n{'='*80}")
    print(f"STEP 1: LOADING FB_ADS DATA")
    print(f"{'='*80}")
    print(f"Date range: {start_date.date()} to {end_date.date()}")
    
    # Structure: {week_id: {ad_id: ad_data}}
    weekly_fb_data = defaultdict(lambda: defaultdict(dict))
    
    # Also track ad metadata
    ad_metadata = {}
    
    print("\nFetching fb_ads collection...")
    fb_ads = db.collection('fb_ads').stream()
    
    total_ads = 0
    ads_in_range = 0
    
    for ad_doc in fb_ads:
        total_ads += 1
        ad_data = ad_doc.to_dict()
        ad_id = ad_doc.id
        
        # Get the insights array (stored as insightsDaily in fb_ads collection)
        insights = ad_data.get('insightsDaily', [])
        
        if not insights:
            continue
        
        # Extract ad details from first insight or adDetails field
        first_insight = insights[0] if insights else {}
        ad_details = ad_data.get('adDetails', {}) or {}
        
        # Extract adSetId with fallback logic (matching backfill_summary_adsetid.py)
        adset_id = ad_details.get('adSetId') or ad_details.get('adsetId')
        if not adset_id and first_insight:
            adset_id = (
                first_insight.get('adset_id')
                or first_insight.get('adSetId')
                or first_insight.get('adsetId')
            )
        adset_id = str(adset_id) if adset_id else ''
        
        # Store ad metadata
        ad_metadata[ad_id] = {
            'adId': ad_id,
            'adName': ad_data.get('adName', first_insight.get('ad_name', 'Unknown')),
            'adSetId': adset_id,
            'adSetName': first_insight.get('adset_name', ad_details.get('adSetName', '')),
            'campaignId': first_insight.get('campaign_id', ad_details.get('campaignId', '')),
            'campaignName': first_insight.get('campaign_name', ad_details.get('campaignName', ''))
        }
        
        # Process each insight (daily data)
        for insight in insights:
            date_start = insight.get('date_start')
            if not date_start:
                continue
            
            insight_date = parse_date(date_start)
            if not insight_date:
                continue
            
            # Check if in range
            if not is_date_in_range(insight_date, start_date, end_date):
                continue
            
            ads_in_range += 1
            
            # Get week ID
            week_id = get_week_id(insight_date)
            
            # Initialize ad data for this week if not exists
            if ad_id not in weekly_fb_data[week_id]:
                weekly_fb_data[week_id][ad_id] = {
                    'spend': 0,
                    'impressions': 0,
                    'reach': 0,
                    'clicks': 0,
                    'days_count': 0
                }
            
            # Aggregate metrics
            weekly_fb_data[week_id][ad_id]['spend'] += float(insight.get('spend', 0))
            weekly_fb_data[week_id][ad_id]['impressions'] += int(insight.get('impressions', 0))
            weekly_fb_data[week_id][ad_id]['reach'] += int(insight.get('reach', 0))
            weekly_fb_data[week_id][ad_id]['clicks'] += int(insight.get('clicks', 0))
            weekly_fb_data[week_id][ad_id]['days_count'] += 1
    
    # Calculate averages for CPM, CPC, CTR
    for week_id, ads in weekly_fb_data.items():
        for ad_id, metrics in ads.items():
            if metrics['impressions'] > 0:
                metrics['cpm'] = (metrics['spend'] / metrics['impressions']) * 1000
                metrics['ctr'] = (metrics['clicks'] / metrics['impressions']) * 100
            else:
                metrics['cpm'] = 0
                metrics['ctr'] = 0
            
            if metrics['clicks'] > 0:
                metrics['cpc'] = metrics['spend'] / metrics['clicks']
            else:
                metrics['cpc'] = 0
            
            # Remove days_count
            del metrics['days_count']
    
    print(f"\n✅ Loaded {total_ads} total ads")
    print(f"✅ Found {ads_in_range} ad insights in date range")
    print(f"✅ Grouped into {len(weekly_fb_data)} weeks")
    print(f"✅ Tracked {len(ad_metadata)} unique ads")
    
    return dict(weekly_fb_data), ad_metadata

# ============================================================================
# STEP 2: LOAD GHL_DATA FOR CONTACT-TO-AD MAPPING
# ============================================================================

def load_ghl_contact_mappings(db):
    """
    Load ghl_data to get contactId -> adId mappings
    Returns: {contact_id: ad_id}
    """
    print(f"\n{'='*80}")
    print(f"STEP 2: LOADING GHL_DATA FOR CONTACT MAPPINGS")
    print(f"{'='*80}")
    
    contact_to_ad = {}
    
    print("\nFetching ghl_data collection...")
    ghl_data = db.collection('ghl_data').stream()
    
    total_records = 0
    with_ad_id = 0
    
    for ghl_doc in ghl_data:
        total_records += 1
        ghl_record = ghl_doc.to_dict()
        
        contact_id = ghl_record.get('contactId') or ghl_doc.id
        ad_id = ghl_record.get('adId')
        
        if ad_id and ad_id != 'None':
            contact_to_ad[contact_id] = ad_id
            with_ad_id += 1
    
    print(f"\n✅ Loaded {total_records} ghl_data records")
    print(f"✅ Found {with_ad_id} contacts with adId mappings")
    
    return contact_to_ad

# ============================================================================
# STEP 3: LOAD GHL_OPPORTUNITIES AND MAP TO ADS
# ============================================================================

def load_ghl_opportunities_by_week(db, contact_to_ad, start_date, end_date):
    """
    Load ghl_opportunities and map to ads by week
    Returns: {week_id: {ad_id: {leads, bookings, deposits, cashCollected, cashAmount}}}
    """
    print(f"\n{'='*80}")
    print(f"STEP 3: LOADING GHL_OPPORTUNITIES")
    print(f"{'='*80}")
    
    # Structure: {week_id: {ad_id: ghl_metrics}}
    weekly_ghl_data = defaultdict(lambda: defaultdict(lambda: {
        'leads': 0,
        'bookedAppointments': 0,
        'deposits': 0,
        'cashCollected': 0,
        'cashAmount': 0
    }))
    
    print("\nFetching ghl_opportunities collection...")
    opportunities = db.collection('ghl_opportunities').stream()
    
    total_opps = 0
    matched_opps = 0
    unmatched_opps = 0
    out_of_range = 0
    
    for opp_doc in opportunities:
        total_opps += 1
        opp = opp_doc.to_dict()
        
        # Get dates
        created_at = opp.get('createdAt')
        if not created_at:
            continue
        
        created_date = parse_date(created_at)
        if not created_date:
            continue
        
        # Check if in range
        if not is_date_in_range(created_date, start_date, end_date):
            out_of_range += 1
            continue
        
        # Get ad ID - try multiple sources
        ad_id = opp.get('assignedAdId')
        
        # If no assigned ad, try contact mapping
        if not ad_id or ad_id == 'None':
            contact_id = opp.get('contactId')
            if contact_id:
                ad_id = contact_to_ad.get(contact_id)
        
        if not ad_id or ad_id == 'None':
            unmatched_opps += 1
            continue
        
        matched_opps += 1
        
        # Get week ID from creation date
        week_id = get_week_id(created_date)
        
        # Count as lead
        weekly_ghl_data[week_id][ad_id]['leads'] += 1
        
        # Get stage information
        stage_category = opp.get('stageCategory', '').lower()
        current_stage = opp.get('currentStage', '').lower()
        monetary_value = opp.get('monetaryValue', 0)
        
        # Determine stage for counting
        # Check both stageCategory and currentStage for flexibility
        is_booking = False
        is_deposit = False
        is_cash = False
        
        if 'book' in stage_category or 'appointment' in stage_category:
            is_booking = True
        elif 'book' in current_stage or 'appointment' in current_stage:
            is_booking = True
        
        if 'deposit' in stage_category:
            is_deposit = True
        elif 'deposit' in current_stage:
            is_deposit = True
        
        if 'cash' in stage_category or 'collected' in stage_category:
            is_cash = True
        elif 'cash' in current_stage or 'collected' in current_stage:
            is_cash = True
        
        # Count by stage
        if is_booking:
            weekly_ghl_data[week_id][ad_id]['bookedAppointments'] += 1
        
        if is_deposit:
            weekly_ghl_data[week_id][ad_id]['deposits'] += 1
            if monetary_value and monetary_value > 0:
                weekly_ghl_data[week_id][ad_id]['cashAmount'] += monetary_value
        
        if is_cash:
            weekly_ghl_data[week_id][ad_id]['cashCollected'] += 1
            if monetary_value and monetary_value > 0:
                weekly_ghl_data[week_id][ad_id]['cashAmount'] += monetary_value
    
    print(f"\n✅ Loaded {total_opps} total opportunities")
    print(f"✅ Matched {matched_opps} opportunities to ads")
    print(f"⚠️  {unmatched_opps} opportunities could not be matched")
    print(f"⚠️  {out_of_range} opportunities outside date range")
    print(f"✅ Grouped into {len(weekly_ghl_data)} weeks")
    
    return dict(weekly_ghl_data)

# ============================================================================
# STEP 4: BUILD SUMMARY STRUCTURE
# ============================================================================

def build_summary_structure(weekly_fb_data, weekly_ghl_data, ad_metadata):
    """
    Build the summary collection structure
    Returns: {campaign_id: summary_data}
    """
    print(f"\n{'='*80}")
    print(f"STEP 4: BUILDING SUMMARY STRUCTURE")
    print(f"{'='*80}")
    
    # Structure: {campaign_id: {campaignId, campaignName, weeks: {...}}}
    summary_data = defaultdict(lambda: {
        'campaignId': '',
        'campaignName': '',
        'weeks': {}
    })
    
    # Get all unique weeks
    all_weeks = set(list(weekly_fb_data.keys()) + list(weekly_ghl_data.keys()))
    
    print(f"\nProcessing {len(all_weeks)} weeks...")
    
    for week_id in sorted(all_weeks):
        # Parse week dates
        monday_str, sunday_str = week_id.split('_')
        monday = datetime.strptime(monday_str, '%Y-%m-%d')
        sunday = datetime.strptime(sunday_str, '%Y-%m-%d')
        
        # Get ads for this week
        fb_ads_this_week = weekly_fb_data.get(week_id, {})
        ghl_ads_this_week = weekly_ghl_data.get(week_id, {})
        
        # Combine all ad IDs for this week
        all_ad_ids = set(list(fb_ads_this_week.keys()) + list(ghl_ads_this_week.keys()))
        
        print(f"\n  Week {week_id}: {len(all_ad_ids)} ads")
        
        for ad_id in all_ad_ids:
            # Get ad metadata
            if ad_id not in ad_metadata:
                print(f"    ⚠️  Ad {ad_id} not found in metadata, skipping...")
                continue
            
            ad_info = ad_metadata[ad_id]
            campaign_id = ad_info['campaignId']
            ad_set_id = ad_info['adSetId']
            
            if not campaign_id:
                continue
            
            # Initialize campaign if needed
            if not summary_data[campaign_id]['campaignId']:
                summary_data[campaign_id]['campaignId'] = campaign_id
                summary_data[campaign_id]['campaignName'] = ad_info['campaignName']
            
            # Initialize week structure if needed
            if week_id not in summary_data[campaign_id]['weeks']:
                summary_data[campaign_id]['weeks'][week_id] = {
                    'month': get_month_name(monday),
                    'dateRange': f"{monday.strftime('%d %b %Y')} - {sunday.strftime('%d %b %Y')}",
                    'weekNumber': get_week_of_month(monday),
                    'ads': {},
                    'adSets': {},
                    'campaign': {
                        'campaignId': campaign_id,
                        'campaignName': ad_info['campaignName'],
                        'facebookInsights': {
                            'spend': 0, 'impressions': 0, 'reach': 0, 'clicks': 0,
                            'cpm': 0, 'cpc': 0, 'ctr': 0
                        },
                        'ghlData': {
                            'leads': 0, 'bookedAppointments': 0, 'deposits': 0,
                            'cashCollected': 0, 'cashAmount': 0
                        }
                    }
                }
            
            week_data = summary_data[campaign_id]['weeks'][week_id]
            
            # Get FB and GHL data for this ad
            fb_metrics = fb_ads_this_week.get(ad_id, {
                'spend': 0, 'impressions': 0, 'reach': 0, 'clicks': 0,
                'cpm': 0, 'cpc': 0, 'ctr': 0
            })
            
            ghl_metrics = ghl_ads_this_week.get(ad_id, {
                'leads': 0, 'bookedAppointments': 0, 'deposits': 0,
                'cashCollected': 0, 'cashAmount': 0
            })
            
            # Add ad-level data (include adSetId for ad set-level queries)
            week_data['ads'][ad_id] = {
                'adId': ad_id,
                'adName': ad_info['adName'],
                'adSetId': ad_info['adSetId'],  # Include adSetId for accurate ad set-level queries
                'facebookInsights': fb_metrics.copy(),
                'ghlData': ghl_metrics.copy()
            }
            
            # Initialize ad set if needed
            if ad_set_id and ad_set_id not in week_data['adSets']:
                week_data['adSets'][ad_set_id] = {
                    'adSetId': ad_set_id,
                    'adSetName': ad_info['adSetName'],
                    'facebookInsights': {
                        'spend': 0, 'impressions': 0, 'reach': 0, 'clicks': 0,
                        'cpm': 0, 'cpc': 0, 'ctr': 0
                    },
                    'ghlData': {
                        'leads': 0, 'bookedAppointments': 0, 'deposits': 0,
                        'cashCollected': 0, 'cashAmount': 0
                    }
                }
            
            # Aggregate to ad set level
            if ad_set_id:
                ad_set_data = week_data['adSets'][ad_set_id]
                
                # Sum Facebook metrics
                for key in ['spend', 'impressions', 'reach', 'clicks']:
                    ad_set_data['facebookInsights'][key] += fb_metrics.get(key, 0)
                
                # Sum GHL metrics
                for key in ['leads', 'bookedAppointments', 'deposits', 'cashCollected', 'cashAmount']:
                    ad_set_data['ghlData'][key] += ghl_metrics.get(key, 0)
            
            # Aggregate to campaign level
            campaign_data = week_data['campaign']
            
            # Sum Facebook metrics
            for key in ['spend', 'impressions', 'reach', 'clicks']:
                campaign_data['facebookInsights'][key] += fb_metrics.get(key, 0)
            
            # Sum GHL metrics
            for key in ['leads', 'bookedAppointments', 'deposits', 'cashCollected', 'cashAmount']:
                campaign_data['ghlData'][key] += ghl_metrics.get(key, 0)
    
    # Calculate averages for CPM, CPC, CTR at ad set and campaign levels
    print("\nCalculating derived metrics...")
    for campaign_id, campaign_summary in summary_data.items():
        for week_id, week_data in campaign_summary['weeks'].items():
            # Ad set level
            for ad_set_id, ad_set_data in week_data['adSets'].items():
                fb = ad_set_data['facebookInsights']
                if fb['impressions'] > 0:
                    fb['cpm'] = (fb['spend'] / fb['impressions']) * 1000
                    fb['ctr'] = (fb['clicks'] / fb['impressions']) * 100
                else:
                    fb['cpm'] = 0
                    fb['ctr'] = 0
                
                if fb['clicks'] > 0:
                    fb['cpc'] = fb['spend'] / fb['clicks']
                else:
                    fb['cpc'] = 0
            
            # Campaign level
            fb = week_data['campaign']['facebookInsights']
            if fb['impressions'] > 0:
                fb['cpm'] = (fb['spend'] / fb['impressions']) * 1000
                fb['ctr'] = (fb['clicks'] / fb['impressions']) * 100
            else:
                fb['cpm'] = 0
                fb['ctr'] = 0
            
            if fb['clicks'] > 0:
                fb['cpc'] = fb['spend'] / fb['clicks']
            else:
                fb['cpc'] = 0
    
    print(f"\n✅ Built summary structure for {len(summary_data)} campaigns")
    
    return dict(summary_data)

# ============================================================================
# STEP 5: WRITE TO FIREBASE
# ============================================================================

def write_summary_to_firebase(db, summary_data, start_date, end_date, dry_run=False):
    """
    Write summary data to Firebase summary collection with merge logic
    - Preserves existing weeks outside date range
    - Recalculates weeks within date range
    - Preserves campaign names
    """
    print(f"\n{'='*80}")
    print(f"STEP 5: WRITING TO FIREBASE")
    print(f"{'='*80}")
    print(f"Date range: {start_date.date()} to {end_date.date()}")
    
    if dry_run:
        print("\n⚠️  DRY RUN MODE - No data will be written")
    
    total_campaigns = len(summary_data)
    campaigns_created = 0
    campaigns_updated = 0
    total_weeks_preserved = 0
    total_weeks_recalculated = 0
    total_weeks_added = 0
    
    for campaign_id, campaign_summary in summary_data.items():
        try:
            campaign_name = campaign_summary['campaignName']
            new_weeks = campaign_summary['weeks']
            new_weeks_count = len(new_weeks)
            
            print(f"\n  Campaign: {campaign_name[:60]}")
            print(f"  ID: {campaign_id}")
            print(f"  New weeks in this run: {new_weeks_count}")
            
            # Calculate totals for display
            total_spend = 0
            total_leads = 0
            total_cash = 0
            
            for week_data in new_weeks.values():
                total_spend += week_data['campaign']['facebookInsights']['spend']
                total_leads += week_data['campaign']['ghlData']['leads']
                total_cash += week_data['campaign']['ghlData']['cashAmount']
            
            print(f"  Spend: R {total_spend:,.2f}")
            print(f"  Leads: {total_leads}")
            print(f"  Cash: R {total_cash:,.2f}")
            
            if not dry_run:
                doc_ref = db.collection('summary').document(campaign_id)
                existing_doc = doc_ref.get()
                
                if existing_doc.exists:
                    # Existing campaign - merge weeks
                    existing_data = existing_doc.to_dict()
                    existing_weeks = existing_data.get('weeks', {})
                    
                    # Preserve original campaign name
                    campaign_summary['campaignName'] = existing_data.get('campaignName', campaign_name)
                    
                    # Identify which weeks to preserve vs recalculate
                    weeks_to_preserve = {}
                    weeks_recalculated = 0
                    weeks_added = 0
                    
                    for week_id, week_data in existing_weeks.items():
                        if is_week_in_date_range(week_id, start_date, end_date):
                            # Week is in current run's date range - will be replaced
                            weeks_recalculated += 1
                        else:
                            # Week is outside date range - preserve it
                            weeks_to_preserve[week_id] = week_data
                            total_weeks_preserved += 1
                    
                    # Count new weeks (not in existing)
                    for week_id in new_weeks.keys():
                        if week_id not in existing_weeks:
                            weeks_added += 1
                            total_weeks_added += 1
                    
                    # Merge weeks: preserve old ones outside range, add/replace new ones
                    merged_weeks = {**weeks_to_preserve, **new_weeks}
                    campaign_summary['weeks'] = merged_weeks
                    
                    # Write merged data
                    doc_ref.set(campaign_summary)
                    campaigns_updated += 1
                    total_weeks_recalculated += weeks_recalculated
                    
                    print(f"  ✅ Updated in Firebase")
                    print(f"     - Weeks preserved: {len(weeks_to_preserve)}")
                    print(f"     - Weeks recalculated: {weeks_recalculated}")
                    print(f"     - Weeks added: {weeks_added}")
                    print(f"     - Total weeks: {len(merged_weeks)}")
                else:
                    # New campaign - create new document
                    doc_ref.set(campaign_summary)
                    campaigns_created += 1
                    total_weeks_added += new_weeks_count
                    print(f"  ✅ Created in Firebase")
                    print(f"     - Weeks added: {new_weeks_count}")
            else:
                # Dry run - check what would happen
                doc_ref = db.collection('summary').document(campaign_id)
                existing_doc = doc_ref.get()
                
                if existing_doc.exists:
                    existing_data = existing_doc.to_dict()
                    existing_weeks = existing_data.get('weeks', {})
                    weeks_to_preserve = {}
                    weeks_recalculated = 0
                    weeks_added = 0
                    
                    for week_id, week_data in existing_weeks.items():
                        if is_week_in_date_range(week_id, start_date, end_date):
                            weeks_recalculated += 1
                        else:
                            weeks_to_preserve[week_id] = week_data
                            total_weeks_preserved += 1
                    
                    for week_id in new_weeks.keys():
                        if week_id not in existing_weeks:
                            weeks_added += 1
                            total_weeks_added += 1
                    
                    campaigns_updated += 1
                    total_weeks_recalculated += weeks_recalculated
                    
                    print(f"  ✅ Would update in Firebase (dry run)")
                    print(f"     - Weeks preserved: {len(weeks_to_preserve)}")
                    print(f"     - Weeks recalculated: {weeks_recalculated}")
                    print(f"     - Weeks added: {weeks_added}")
                else:
                    campaigns_created += 1
                    total_weeks_added += new_weeks_count
                    print(f"  ✅ Would create in Firebase (dry run)")
                    print(f"     - Weeks added: {new_weeks_count}")
            
        except Exception as e:
            print(f"  ❌ Error writing campaign {campaign_id}: {e}")
            import traceback
            traceback.print_exc()
            continue
    
    print(f"\n{'='*80}")
    print(f"SUMMARY")
    print(f"{'='*80}")
    print(f"Total campaigns processed: {total_campaigns}")
    if not dry_run:
        print(f"  - Campaigns created: {campaigns_created}")
        print(f"  - Campaigns updated: {campaigns_updated}")
        print(f"  - Weeks preserved: {total_weeks_preserved}")
        print(f"  - Weeks recalculated: {total_weeks_recalculated}")
        print(f"  - Weeks added: {total_weeks_added}")
    else:
        print(f"  - Campaigns ready to create: {campaigns_created}")
        print(f"  - Campaigns ready to update: {campaigns_updated}")
    print(f"{'='*80}")

# ============================================================================
# MAIN FUNCTION
# ============================================================================

def main():
    """Main execution function"""
    print("="*80)
    print("REBUILD SUMMARY COLLECTION FROM FIREBASE DATA")
    print("="*80)
    print("Processing December 2025")
    print("="*80)
    
    # Check for dry run flag
    dry_run = '--dry-run' in sys.argv
    
    # Initialize Firebase
    if not firebase_admin._apps:
        # Get the directory where this script is located
        script_dir = os.path.dirname(os.path.abspath(__file__))
        
        # Try to find Firebase credentials file in common locations
        cred_paths = [
            os.path.join(script_dir, 'medx-ai-firebase-adminsdk-fbsvc-d88a6aa1a7.json'),
            os.path.join(script_dir, '..', 'ghl_opp_collection', 'medx-ai-firebase-adminsdk-fbsvc-d88a6aa1a7.json'),
            os.path.join(script_dir, '..', 'ghl_data_collection', 'medx-ai-firebase-adminsdk-fbsvc-d88a6aa1a7.json'),
            os.path.join(script_dir, '..', 'summary_collection', 'medx-ai-firebase-adminsdk-fbsvc-d88a6aa1a7.json'),
            os.path.join(script_dir, '..', 'medx-ai-firebase-adminsdk-fbsvc-a86e7bd050.json'),
            os.path.join(script_dir, '..', 'medx-ai-firebase-adminsdk-fbsvc-d88a6aa1a7.json')
        ]
        
        cred_path = None
        for path in cred_paths:
            if os.path.exists(path):
                cred_path = path
                break
        
        if not cred_path:
            raise FileNotFoundError(
                f"Firebase credentials file not found. Tried:\n" + 
                "\n".join(f"  - {p}" for p in cred_paths)
            )
        
        cred = credentials.Certificate(cred_path)
        firebase_admin.initialize_app(cred)
        print('✅ Firebase initialized successfully\n')
    db = firestore.client()
    
    # Process December 2025
    print(f"\n{'='*80}")
    print("PROCESSING DECEMBER 2025")
    print(f"{'='*80}")
    
    # Step 1: Load FB ads data
    weekly_fb_data_dec, ad_metadata_dec = load_fb_ads_by_week(db, DECEMBER_START, DECEMBER_END)
    
    # Step 2: Load GHL contact mappings
    contact_to_ad = load_ghl_contact_mappings(db)
    
    # Step 3: Load GHL opportunities
    weekly_ghl_data_dec = load_ghl_opportunities_by_week(db, contact_to_ad, DECEMBER_START, DECEMBER_END)
    
    # Step 4: Build summary structure
    summary_data_dec = build_summary_structure(weekly_fb_data_dec, weekly_ghl_data_dec, ad_metadata_dec)
    
    # Step 5: Write to Firebase
    write_summary_to_firebase(db, summary_data_dec, DECEMBER_START, DECEMBER_END, dry_run=dry_run)
    
    print(f"\n{'='*80}")
    print("COMPLETE!")
    print(f"{'='*80}")
    
    if dry_run:
        print("\n⚠️  This was a DRY RUN - no data was written to Firebase")
        print("Run without --dry-run flag to write data")

if __name__ == '__main__':
    main()

