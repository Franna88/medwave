#!/usr/bin/env python3
"""
Sync GHL Opportunities to AdvertData Collection (Python Version)

⚠️ CRITICAL: Fetches data ONLY from GHL API (NOT from Firebase collections)
Extracts ALL 5 UTM parameters: h_ad_id, utm_source, utm_medium, utm_campaign, fbc_id

Usage: python3 functions/syncGHLToAdvertData.py [--dry-run]
"""

import os
import sys
import requests
import firebase_admin
from firebase_admin import credentials, firestore
from datetime import datetime, timedelta
from typing import Dict, List, Optional
import time
from collections import defaultdict

# Initialize Firebase Admin SDK
try:
    cred = credentials.Certificate('medx-ai-firebase-adminsdk-fbsvc-a86e7bd050.json')
    firebase_admin.initialize_app(cred)
except ValueError:
    # Already initialized
    pass

db = firestore.client()

# GHL API Configuration
GHL_BASE_URL = 'https://services.leadconnectorhq.com'
GHL_API_KEY = os.getenv('GHL_API_KEY', 'pit-22f8af95-3244-41e7-9a52-22c87b166f5a')
GHL_LOCATION_ID = 'QdLXaFEqrdF0JbVbpKLw'

# Check for dry-run flag
DRY_RUN = '--dry-run' in sys.argv


def get_ghl_headers():
    """Get GHL API headers"""
    return {
        'Authorization': f'Bearer {GHL_API_KEY}',
        'Version': '2021-07-28',
        'Content-Type': 'application/json',
        'Accept': 'application/json'
    }


def calculate_week_id(timestamp):
    """
    Calculate week ID from timestamp
    Returns format: "2025-11-04_2025-11-10" (Monday-Sunday)
    """
    date = timestamp if isinstance(timestamp, datetime) else datetime.fromisoformat(str(timestamp).replace('Z', '+00:00'))
    
    # Get start of week (Monday)
    days_to_monday = (date.weekday()) % 7  # Monday = 0
    start_of_week = date - timedelta(days=days_to_monday)
    start_of_week = start_of_week.replace(hour=0, minute=0, second=0, microsecond=0)
    
    # Get end of week (Sunday)
    end_of_week = start_of_week + timedelta(days=6)
    end_of_week = end_of_week.replace(hour=23, minute=59, second=59, microsecond=999999)
    
    return f"{start_of_week.strftime('%Y-%m-%d')}_{end_of_week.strftime('%Y-%m-%d')}"


def extract_utm_params(opportunity, show_progress=False):
    """
    Extract UTM parameters from opportunity attributions array
    
    Based on previous successful implementation:
    - Each opportunity has an "attributions" array from GHL API
    - Checks fields in reverse order (last attribution first):
      * attr.get('h_ad_id') - Facebook Ad ID
      * attr.get('utmAdId')
      * attr.get('adId')
      * attr.get('utmSource') - Campaign name
      * attr.get('utmMedium') - Ad Set name
      * attr.get('utmCampaign') - Ad name
      * attr.get('fbc_id') or attr.get('fbcId') - Ad Set ID
    """
    attributions = opportunity.get('attributions', [])
    
    if show_progress:
        print(f'      🔍 Checking attributions array...')
        print(f'         Found {len(attributions)} attributions')
    
    if not attributions:
        if show_progress:
            print(f'      ⚠️  No attributions found in opportunity')
        return None
    
    # Get last attribution (most recent)
    last_attribution = None
    for attr in attributions:
        if attr.get('isLast'):
            last_attribution = attr
            break
    
    if not last_attribution and attributions:
        last_attribution = attributions[-1]
    
    if not last_attribution:
        if show_progress:
            print(f'      ⚠️  Could not find last attribution')
        return None
    
    if show_progress:
        print(f'      📋 ALL FIELDS IN LAST ATTRIBUTION:')
        for key in sorted(last_attribution.keys()):
            value = last_attribution.get(key)
            value_str = str(value)[:100] if value else 'None'
            print(f'         - {key}: {value_str}')
        print()
    
    # Extract Facebook Ad data from attribution
    # Try multiple field name variations
    facebook_ad_id = (
        last_attribution.get('h_ad_id') or 
        last_attribution.get('hAdId') or 
        last_attribution.get('utmAdId') or 
        last_attribution.get('adId') or 
        ''
    )
    
    utm_data = {
        'facebookAdId': facebook_ad_id,
        'campaignName': last_attribution.get('utmSource') or last_attribution.get('utm_source') or '',
        'adSetName': last_attribution.get('utmMedium') or last_attribution.get('utm_medium') or '',
        'adName': last_attribution.get('utmCampaign') or last_attribution.get('utm_campaign') or '',
        'adSetId': last_attribution.get('fbc_id') or last_attribution.get('fbcId') or last_attribution.get('adsetId') or '',
        'campaignId': last_attribution.get('campaignId') or last_attribution.get('campaign_id') or '',
        'fbclid': last_attribution.get('fbclid') or '',
        'gclid': last_attribution.get('gclid') or ''
    }
    
    if show_progress:
        print(f'      🔍 EXTRACTED UTM DATA:')
        print(f'         - facebookAdId (h_ad_id): {utm_data["facebookAdId"] or "❌ MISSING"}')
        print(f'         - campaignName (utm_source): {utm_data["campaignName"] or "❌ MISSING"}')
        print(f'         - adSetName (utm_medium): {utm_data["adSetName"] or "❌ MISSING"}')
        print(f'         - adName (utm_campaign): {utm_data["adName"] or "❌ MISSING"}')
        print(f'         - adSetId (fbc_id): {utm_data["adSetId"] or "❌ MISSING"}')
    
    return utm_data


def get_stage_category(stage_name):
    """Get stage category from stage name"""
    if not stage_name:
        return 'other'
    
    stage = stage_name.lower()
    
    if 'appointment' in stage or 'booked' in stage:
        return 'bookedAppointments'
    if 'deposit' in stage:
        return 'deposits'
    if 'cash' in stage and 'collected' in stage:
        return 'cashCollected'
    
    return 'other'


def fetch_all_opportunities_from_ghl():
    """
    Fetch ALL opportunities from GHL API with pagination
    Returns opportunities from last 2 months (October and November)
    """
    print('📋 Fetching ALL opportunities from GHL API...')
    print('   ⚠️  Data source: GHL API ONLY (not Firebase)')
    print('   📅 Date range: Last 2 months (October & November 2025)')
    print()
    
    all_opportunities = []
    page = 1
    limit = 100
    
    # Calculate 2 months ago
    two_months_ago = datetime.now() - timedelta(days=60)
    
    while True:
        try:
            print(f'   Fetching page {page}...')
            
            response = requests.get(
                f'{GHL_BASE_URL}/opportunities/search',
                headers=get_ghl_headers(),
                params={
                    'location_id': GHL_LOCATION_ID,
                    'limit': limit,
                    'page': page
                },
                timeout=30
            )
            
            response.raise_for_status()
            data = response.json()
            opportunities = data.get('opportunities', [])
            
            if not opportunities:
                break
            
            # Filter to last 2 months
            recent_opportunities = []
            for opp in opportunities:
                created_at_str = opp.get('createdAt') or opp.get('dateAdded') or ''
                if created_at_str:
                    try:
                        created_at = datetime.fromisoformat(created_at_str.replace('Z', '+00:00'))
                        # Make two_months_ago timezone-aware to match
                        if created_at.tzinfo is not None and two_months_ago.tzinfo is None:
                            from datetime import timezone
                            two_months_ago_aware = two_months_ago.replace(tzinfo=timezone.utc)
                            if created_at >= two_months_ago_aware:
                                recent_opportunities.append(opp)
                        else:
                            if created_at >= two_months_ago:
                                recent_opportunities.append(opp)
                    except:
                        # If date parsing fails, skip this opportunity
                        pass
            
            all_opportunities.extend(recent_opportunities)
            
            print(f'   ✓ Page {page}: {len(opportunities)} opportunities ({len(recent_opportunities)} in last 2 months)')
            
            # Check if we got fewer results than limit (last page)
            if len(opportunities) < limit:
                break
            
            page += 1
            
            # Rate limiting: 500ms delay between requests
            time.sleep(0.5)
            
        except Exception as e:
            print(f'   ❌ Error fetching page {page}: {e}')
            break
    
    print()
    print(f'✅ Total opportunities fetched: {len(all_opportunities)}')
    print()
    
    return all_opportunities


def process_opportunities(opportunities):
    """Process opportunities and extract UTM data"""
    print('🔍 Processing opportunities and extracting UTM parameters...')
    print()
    
    stats = {
        'total': len(opportunities),
        'withHAdId': 0,
        'withAllUTMParams': 0,
        'withoutHAdId': 0,
        'utmQuality': {
            'hasHAdId': 0,
            'hasCampaignName': 0,
            'hasAdSetName': 0,
            'hasAdName': 0,
            'hasAdSetId': 0
        }
    }
    
    processed_data = []
    sample_utm_data = []
    processed_count = 0
    
    print('📋 Showing detailed progress for first 5 opportunities...')
    print()
    
    for opp in opportunities:
        processed_count += 1
        
        # Show detailed progress for first 5 opportunities
        show_progress = processed_count <= 5
        
        if show_progress:
            print(f'   🔍 Processing opportunity {processed_count}/{len(opportunities)}:')
            print(f'      ID: {opp.get("id", "N/A")}')
            print(f'      Contact ID: {opp.get("contactId", "N/A")}')
            print(f'      Name: {opp.get("name", "N/A")}')
        
        # Progress update every 100 opportunities (after first 5)
        if processed_count > 5 and processed_count % 100 == 0:
            print(f'   Processing: {processed_count}/{len(opportunities)} opportunities...')
        
        utm_data = extract_utm_params(opp, show_progress=show_progress)
        
        if show_progress:
            if utm_data and utm_data.get('facebookAdId'):
                print(f'      ✅ Found Facebook Ad ID: {utm_data["facebookAdId"]}')
            else:
                print(f'      ⚠️  No Facebook Ad ID found')
            print()
        
        if not utm_data:
            stats['withoutHAdId'] += 1
            continue
        
        # Track UTM quality
        if utm_data['facebookAdId']:
            stats['utmQuality']['hasHAdId'] += 1
        if utm_data['campaignName']:
            stats['utmQuality']['hasCampaignName'] += 1
        if utm_data['adSetName']:
            stats['utmQuality']['hasAdSetName'] += 1
        if utm_data['adName']:
            stats['utmQuality']['hasAdName'] += 1
        if utm_data['adSetId']:
            stats['utmQuality']['hasAdSetId'] += 1
        
        # Only process opportunities with h_ad_id
        if not utm_data['facebookAdId']:
            stats['withoutHAdId'] += 1
            continue
        
        stats['withHAdId'] += 1
        
        # Check if all 5 UTM params are present
        if (utm_data['facebookAdId'] and utm_data['campaignName'] and 
            utm_data['adSetName'] and utm_data['adName'] and utm_data['adSetId']):
            stats['withAllUTMParams'] += 1
        
        # Get stage category
        stage_category = get_stage_category(opp.get('pipelineStageName') or opp.get('status'))
        
        # Get monetary value
        monetary_value = 0
        
        # First: Check standard opportunity monetaryValue field
        if opp.get('monetaryValue') and opp['monetaryValue'] > 0:
            monetary_value = float(opp['monetaryValue'])
        
        # Second: Check custom fields if monetaryValue not set
        if monetary_value == 0:
            custom_fields = opp.get('customFields', [])
            for field in custom_fields:
                field_key = (field.get('key') or field.get('id') or '').lower()
                field_value = float(field.get('value', 0) or 0)
                
                if 'contract' in field_key or 'value' in field_key:
                    monetary_value = field_value
                    break
                if 'cash' in field_key and 'collected' in field_key:
                    monetary_value = field_value
                    break
        
        # Third: Default to R1500 for deposits/cash stages if still no value
        if monetary_value == 0 and stage_category in ['deposits', 'cashCollected']:
            monetary_value = 1500
        
        # Get timestamp
        timestamp = datetime.fromisoformat(
            (opp.get('createdAt') or opp.get('dateAdded') or datetime.now().isoformat()).replace('Z', '+00:00')
        )
        
        processed_data.append({
            'opportunityId': opp['id'],
            'opportunityName': opp.get('name', 'Unnamed'),
            'facebookAdId': utm_data['facebookAdId'],
            'campaignName': utm_data['campaignName'],
            'adSetName': utm_data['adSetName'],
            'adName': utm_data['adName'],
            'adSetId': utm_data['adSetId'],
            'stageCategory': stage_category,
            'stageName': opp.get('pipelineStageName') or opp.get('status') or '',
            'monetaryValue': monetary_value,
            'timestamp': timestamp
        })
        
        # Collect sample UTM data (first 5)
        if len(sample_utm_data) < 5:
            sample_utm_data.append({
                'opportunityName': opp.get('name'),
                'h_ad_id': utm_data['facebookAdId'],
                'utm_source': utm_data['campaignName'],
                'utm_medium': utm_data['adSetName'],
                'utm_campaign': utm_data['adName'],
                'fbc_id': utm_data['adSetId']
            })
    
    # Print statistics
    print('📊 UTM Extraction Statistics:')
    print(f"   Total opportunities: {stats['total']}")
    print(f"   With h_ad_id: {stats['withHAdId']} ({stats['withHAdId']/stats['total']*100:.1f}%)")
    print(f"   With ALL 5 UTM params: {stats['withAllUTMParams']} ({stats['withAllUTMParams']/stats['total']*100:.1f}%)")
    print(f"   Without h_ad_id (skipped): {stats['withoutHAdId']} ({stats['withoutHAdId']/stats['total']*100:.1f}%)")
    print()
    print('📊 UTM Parameter Completeness:')
    print(f"   h_ad_id: {stats['utmQuality']['hasHAdId']} ({stats['utmQuality']['hasHAdId']/stats['total']*100:.1f}%)")
    print(f"   utm_source (campaign): {stats['utmQuality']['hasCampaignName']} ({stats['utmQuality']['hasCampaignName']/stats['total']*100:.1f}%)")
    print(f"   utm_medium (ad set): {stats['utmQuality']['hasAdSetName']} ({stats['utmQuality']['hasAdSetName']/stats['total']*100:.1f}%)")
    print(f"   utm_campaign (ad): {stats['utmQuality']['hasAdName']} ({stats['utmQuality']['hasAdName']/stats['total']*100:.1f}%)")
    print(f"   fbc_id (ad set ID): {stats['utmQuality']['hasAdSetId']} ({stats['utmQuality']['hasAdSetId']/stats['total']*100:.1f}%)")
    print()
    
    # Show sample UTM data
    if sample_utm_data:
        print('📋 Sample UTM Data (first 5 opportunities):')
        for idx, sample in enumerate(sample_utm_data, 1):
            print(f'   {idx}. {sample["opportunityName"]}')
            print(f'      h_ad_id: {sample["h_ad_id"]}')
            print(f'      utm_source: {sample["utm_source"]}')
            print(f'      utm_medium: {sample["utm_medium"]}')
            print(f'      utm_campaign: {sample["utm_campaign"]}')
            print(f'      fbc_id: {sample["fbc_id"]}')
            print()
    
    return processed_data, stats


def group_by_ad_and_week(processed_data):
    """Group opportunities by Facebook Ad ID and week"""
    print('📅 Grouping opportunities by ad and week...')
    print()
    
    # Map: adId -> weekId -> { opportunities, metrics }
    ad_week_map = defaultdict(lambda: defaultdict(lambda: {
        'opportunities': set(),
        'leads': 0,
        'bookedAppointments': 0,
        'deposits': 0,
        'cashCollected': 0,
        'cashAmount': 0
    }))
    
    for opp in processed_data:
        ad_id = opp['facebookAdId']
        week_id = calculate_week_id(opp['timestamp'])
        
        week_data = ad_week_map[ad_id][week_id]
        
        # Only count each opportunity once
        if opp['opportunityId'] not in week_data['opportunities']:
            week_data['opportunities'].add(opp['opportunityId'])
            week_data['leads'] += 1
            
            if opp['stageCategory'] == 'bookedAppointments':
                week_data['bookedAppointments'] += 1
            elif opp['stageCategory'] == 'deposits':
                week_data['deposits'] += 1
                week_data['cashAmount'] += opp['monetaryValue']
            elif opp['stageCategory'] == 'cashCollected':
                week_data['cashCollected'] += 1
                week_data['cashAmount'] += opp['monetaryValue']
    
    print(f'✅ Grouped data for {len(ad_week_map)} ads')
    
    # Calculate total weeks
    total_weeks = sum(len(weeks) for weeks in ad_week_map.values())
    print(f'✅ Total weeks to update: {total_weeks}')
    
    # Show sample
    print()
    print('📋 Sample of grouped data (first 3 ads):')
    for idx, (ad_id, weeks) in enumerate(list(ad_week_map.items())[:3], 1):
        print(f'   Ad {ad_id}: {len(weeks)} weeks')
    print()
    
    return ad_week_map


def write_to_advert_data(ad_week_map):
    """Write weekly data to advertData collection"""
    print('💾 Writing data to advertData collection...')
    print()
    
    stats = {
        'adsProcessed': 0,
        'weeksWritten': 0,
        'errors': 0
    }
    
    batch = db.batch()
    batch_count = 0
    
    for ad_id, week_map in ad_week_map.items():
        try:
            stats['adsProcessed'] += 1
            
            # Progress update every 10 ads
            if stats['adsProcessed'] % 10 == 0:
                print(f"   📊 Progress: {stats['adsProcessed']}/{len(ad_week_map)} ads processed ({stats['weeksWritten']} weeks written)...")
            
            # Check if ad exists in advertData
            ad_ref = db.collection('advertData').document(ad_id)
            ad_doc = ad_ref.get()
            
            if not ad_doc.exists:
                if stats['adsProcessed'] <= 5:
                    print(f'   ⚠️  Ad {ad_id} not found in advertData collection (skipping)')
                continue
            
            # Write each week's data
            for week_id, week_data in week_map.items():
                weekly_ref = ad_ref.collection('ghlWeekly').document(week_id)
                
                weekly_data = {
                    'leads': week_data['leads'],
                    'bookedAppointments': week_data['bookedAppointments'],
                    'deposits': week_data['deposits'],
                    'cashCollected': week_data['cashCollected'],
                    'cashAmount': week_data['cashAmount'],
                    'lastUpdated': firestore.SERVER_TIMESTAMP
                }
                
                if DRY_RUN:
                    print(f'   [DRY RUN] Would write to advertData/{ad_id}/ghlWeekly/{week_id}: {weekly_data}')
                else:
                    batch.set(weekly_ref, weekly_data, merge=True)
                    batch_count += 1
                    stats['weeksWritten'] += 1
                    
                    # Commit batch every 500 writes
                    if batch_count >= 500:
                        batch.commit()
                        batch = db.batch()
                        batch_count = 0
            
            # Update lastGHLSync timestamp
            if not DRY_RUN:
                batch.update(ad_ref, {'lastGHLSync': firestore.SERVER_TIMESTAMP})
                batch_count += 1
                
                if batch_count >= 500:
                    batch.commit()
                    batch = db.batch()
                    batch_count = 0
        
        except Exception as e:
            print(f'   ❌ Error processing ad {ad_id}: {e}')
            stats['errors'] += 1
    
    # Commit remaining writes
    if batch_count > 0 and not DRY_RUN:
        batch.commit()
    
    print()
    print('=' * 60)
    print('✅ WRITE COMPLETED!')
    print('=' * 60)
    print(f"   📊 Ads processed: {stats['adsProcessed']}")
    print(f"   📅 Weeks written: {stats['weeksWritten']}")
    print(f"   ❌ Errors: {stats['errors']}")
    print('=' * 60)
    print()
    
    return stats


def main():
    print()
    print('=' * 80)
    print('  GHL → ADVERTDATA SYNC (Python)')
    print('=' * 80)
    print()
    
    if DRY_RUN:
        print('⚠️  DRY RUN MODE - No data will be written')
        print()
    
    print('This script will:')
    print('1. Fetch ALL opportunities from GHL API (last 2 months - Oct & Nov 2025)')
    print('2. Extract ALL 5 UTM parameters (h_ad_id, utm_source, utm_medium, utm_campaign, fbc_id)')
    print('3. Group opportunities by Facebook Ad ID and week')
    print('4. Write weekly metrics to advertData collection')
    print()
    print('⚠️  Data source: GHL API ONLY (NOT Firebase collections)')
    print('📅 Date range: October 1, 2025 - November 9, 2025')
    print()
    
    try:
        # Step 1: Fetch opportunities from GHL API
        opportunities = fetch_all_opportunities_from_ghl()
        
        if not opportunities:
            print('⚠️  No opportunities found. Exiting.')
            sys.exit(0)
        
        # TEST MODE: Only process first 5 opportunities
        if '--test' in sys.argv:
            opportunities = opportunities[:5]
            print(f'🧪 TEST MODE - Limited to first {len(opportunities)} opportunities')
            print()
        
        # Step 2: Process and extract UTM data
        processed_data, extraction_stats = process_opportunities(opportunities)
        
        if not processed_data:
            print('⚠️  No opportunities with h_ad_id found. Exiting.')
            sys.exit(0)
        
        # Step 3: Group by ad and week
        ad_week_map = group_by_ad_and_week(processed_data)
        
        # Step 4: Write to advertData
        write_stats = write_to_advert_data(ad_week_map)
        
        # Final summary
        print()
        print('=' * 80)
        print('  SYNC COMPLETED SUCCESSFULLY!')
        print('=' * 80)
        print()
        print('📊 Final Summary:')
        print(f"   Total opportunities fetched: {len(opportunities)}")
        print(f"   Opportunities with h_ad_id: {extraction_stats['withHAdId']}")
        print(f"   Opportunities with all 5 UTM params: {extraction_stats['withAllUTMParams']}")
        print(f"   Ads updated: {write_stats['adsProcessed']}")
        print(f"   Weeks written: {write_stats['weeksWritten']}")
        print(f"   Errors: {write_stats['errors']}")
        print()
        print('Next Steps:')
        print('1. Verify data in Firebase Console')
        print('2. Check weekly breakdown for sample ads')
        print('3. Run verification script: python3 functions/verifyGHLAdvertDataSync.py')
        print()
        print('=' * 80)
        print()
        
        sys.exit(0)
        
    except Exception as error:
        print()
        print('=' * 80)
        print('❌ SYNC FAILED!')
        print('=' * 80)
        print()
        print(f'Error: {error}')
        print()
        import traceback
        traceback.print_exc()
        print()
        print('=' * 80)
        print()
        
        sys.exit(1)


if __name__ == '__main__':
    main()

