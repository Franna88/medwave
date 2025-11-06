#!/usr/bin/env python3
"""
Reconcile GHL to Facebook using existing Firebase data
This analyzes what's already in Firebase and reports on deposit/cash accuracy
"""

import firebase_admin
from firebase_admin import credentials, firestore
from collections import defaultdict
import sys

# Initialize Firebase
try:
    cred = credentials.Certificate('../medx-ai-firebase-adminsdk-fbsvc-a86e7bd050.json')
    firebase_admin.initialize_app(cred)
except ValueError:
    pass

db = firestore.client()

# Pipeline IDs (from Firebase)
ANDRIES_PIPELINE_ID = 'XeAGJWRnUGJ5tuhXam2g'  # Andries Pipeline - DDM
DAVIDE_PIPELINE_ID = 'AUduOJBB2lxlsEaNmlJz'  # Davide's Pipeline - DDM

def normalize_name(name):
    if not name:
        return ''
    return ''.join(c.lower() for c in name if c.isalnum() or c.isspace()).strip()

print("=" * 80)
print("🔍 FIREBASE DATA RECONCILIATION")
print("=" * 80)
print()

# Step 1: Analyze opportunityStageHistory
print("📋 Loading opportunities from Firebase...")
opps_ref = db.collection('opportunityStageHistory')
all_opps = list(opps_ref.stream())
print(f"   ✓ Loaded {len(all_opps)} opportunity records")
print()

# Group by pipeline and ad
andries_by_ad = defaultdict(lambda: {
    'ad_id': '',
    'ad_name': '',
    'adset_name': '',
    'campaign_name': '',
    'leads': 0,
    'bookings': 0,
    'deposits': 0,
    'cash_collected': 0,
    'total_cash': 0.0,
    'opportunities': []
})

davide_by_ad = defaultdict(lambda: {
    'ad_id': '',
    'ad_name': '',
    'adset_name': '',
    'campaign_name': '',
    'leads': 0,
    'bookings': 0,
    'deposits': 0,
    'cash_collected': 0,
    'total_cash': 0.0,
    'opportunities': []
})

print("📊 Analyzing opportunities by pipeline...")
for opp_doc in all_opps:
    data = opp_doc.to_dict()
    
    pipeline_id = data.get('pipelineId', '')
    ad_id = data.get('adId', '')
    ad_name = data.get('adName', '')
    adset_name = data.get('adSetName', '')
    campaign_name = data.get('campaignName', '')
    stage_category = data.get('stageCategory', '')
    stage_name = data.get('stageName', '')
    monetary_value = data.get('monetaryValue', 0) or 0
    
    if not ad_id:
        continue
    
    # Determine which pipeline
    if pipeline_id == ANDRIES_PIPELINE_ID:
        by_ad = andries_by_ad
    elif pipeline_id == DAVIDE_PIPELINE_ID:
        by_ad = davide_by_ad
    else:
        continue
    
    # Update ad stats
    ad_stats = by_ad[ad_id]
    ad_stats['ad_id'] = ad_id
    ad_stats['ad_name'] = ad_name
    ad_stats['adset_name'] = adset_name
    ad_stats['campaign_name'] = campaign_name
    ad_stats['leads'] += 1
    
    if stage_category == 'bookedAppointments':
        ad_stats['bookings'] += 1
    
    # Count deposits and cash based on stage name and category
    if stage_name == 'Deposit Received' or stage_category == 'deposits':
        ad_stats['deposits'] += 1
    elif stage_name == 'Cash Collected' or stage_category == 'cashCollected':
        ad_stats['cash_collected'] += 1
        ad_stats['total_cash'] += monetary_value
    elif stage_category == 'callCompleted' and stage_name == 'Call Completed':
        ad_stats['deposits'] += 1
    
    ad_stats['opportunities'].append({
        'id': data.get('opportunityId', ''),
        'stage': stage_name,
        'category': stage_category,
        'value': monetary_value
    })

print(f"   ✓ Andries: {len(andries_by_ad)} unique ads")
print(f"   ✓ Davide: {len(davide_by_ad)} unique ads")
print()

# Calculate totals
andries_total_deposits = sum(ad['deposits'] for ad in andries_by_ad.values())
andries_total_cash = sum(ad['cash_collected'] for ad in andries_by_ad.values())
davide_total_deposits = sum(ad['deposits'] for ad in davide_by_ad.values())
davide_total_cash = sum(ad['cash_collected'] for ad in davide_by_ad.values())

print("=" * 80)
print("📊 PIPELINE SUMMARY")
print("=" * 80)
print()
print(f"ANDRIES PIPELINE:")
print(f"  Unique Ads: {len(andries_by_ad)}")
print(f"  Total Deposits: {andries_total_deposits}")
print(f"  Total Cash Collected: {andries_total_cash}")
print()
print(f"DAVIDE PIPELINE:")
print(f"  Unique Ads: {len(davide_by_ad)}")
print(f"  Total Deposits: {davide_total_deposits}")
print(f"  Total Cash Collected: {davide_total_cash}")
print()

# Step 2: Compare with Facebook ad data
print("=" * 80)
print("📋 COMPARING WITH FACEBOOK AD DATA")
print("=" * 80)
print()

print("📋 Loading Facebook ads from Firebase...")
ads_ref = db.collection('adPerformance')
all_ads = list(ads_ref.stream())
print(f"   ✓ Loaded {len(all_ads)} Facebook ads")
print()

# Check each ad
print("🔍 Checking for discrepancies...")
print()

discrepancies = []

for ad_doc in all_ads:
    ad_data = ad_doc.to_dict()
    ad_id = ad_doc.id
    ad_name = ad_data.get('adName', '')
    ghl_stats = ad_data.get('ghlStats', {})
    
    fb_deposits = ghl_stats.get('deposits', 0)
    fb_cash = ghl_stats.get('cashCollected', 0)
    
    # Check if it's in Andries or Davide
    ghl_deposits = 0
    ghl_cash = 0
    
    if ad_id in andries_by_ad:
        ghl_deposits = andries_by_ad[ad_id]['deposits']
        ghl_cash = andries_by_ad[ad_id]['cash_collected']
    elif ad_id in davide_by_ad:
        ghl_deposits = davide_by_ad[ad_id]['deposits']
        ghl_cash = davide_by_ad[ad_id]['cash_collected']
    
    # Check for discrepancies
    if fb_deposits != ghl_deposits or fb_cash != ghl_cash:
        discrepancies.append({
            'ad_id': ad_id,
            'ad_name': ad_name,
            'fb_deposits': fb_deposits,
            'ghl_deposits': ghl_deposits,
            'fb_cash': fb_cash,
            'ghl_cash': ghl_cash
        })

print(f"Found {len(discrepancies)} discrepancies")
print()

if discrepancies:
    print("=" * 80)
    print("⚠️  DISCREPANCIES FOUND")
    print("=" * 80)
    print()
    
    for i, disc in enumerate(discrepancies[:20], 1):
        print(f"{i}. {disc['ad_name'][:50]}")
        print(f"   Ad ID: {disc['ad_id']}")
        print(f"   Firebase: {disc['fb_deposits']} deposits, {disc['fb_cash']} cash")
        print(f"   GHL Data: {disc['ghl_deposits']} deposits, {disc['ghl_cash']} cash")
        print()
    
    if len(discrepancies) > 20:
        print(f"   ... and {len(discrepancies) - 20} more")
        print()

# Step 3: Show top performing ads
print("=" * 80)
print("🏆 TOP 10 ADS - ANDRIES PIPELINE")
print("=" * 80)
print()

sorted_andries = sorted(
    andries_by_ad.items(),
    key=lambda x: x[1]['deposits'] + x[1]['cash_collected'],
    reverse=True
)[:10]

for i, (ad_id, stats) in enumerate(sorted_andries, 1):
    print(f"{i}. {stats['ad_name'][:50]}")
    print(f"   Ad ID: {ad_id}")
    print(f"   Ad Set: {stats['adset_name'][:50]}")
    print(f"   Leads: {stats['leads']}, Bookings: {stats['bookings']}")
    print(f"   Deposits: {stats['deposits']}, Cash: {stats['cash_collected']}")
    print()

print("=" * 80)
print("🏆 TOP 10 ADS - DAVIDE PIPELINE")
print("=" * 80)
print()

sorted_davide = sorted(
    davide_by_ad.items(),
    key=lambda x: x[1]['deposits'] + x[1]['cash_collected'],
    reverse=True
)[:10]

for i, (ad_id, stats) in enumerate(sorted_davide, 1):
    print(f"{i}. {stats['ad_name'][:50]}")
    print(f"   Ad ID: {ad_id}")
    print(f"   Ad Set: {stats['adset_name'][:50]}")
    print(f"   Leads: {stats['leads']}, Bookings: {stats['bookings']}")
    print(f"   Deposits: {stats['deposits']}, Cash: {stats['cash_collected']}")
    print()

# Step 4: Update Firebase if requested
if '--update' in sys.argv:
    print("=" * 80)
    print("💾 UPDATING FIREBASE")
    print("=" * 80)
    print()
    
    updated = 0
    
    # Update Andries ads
    for ad_id, stats in andries_by_ad.items():
        try:
            db.collection('adPerformance').document(ad_id).update({
                'ghlStats.leads': stats['leads'],
                'ghlStats.bookings': stats['bookings'],
                'ghlStats.deposits': stats['deposits'],
                'ghlStats.cashCollected': stats['cash_collected'],
                'lastSync': firestore.SERVER_TIMESTAMP
            })
            updated += 1
            if updated % 10 == 0:
                print(f"   Updated {updated} ads...")
        except Exception as e:
            print(f"   ⚠️  Error updating {ad_id}: {e}")
    
    # Update Davide ads
    for ad_id, stats in davide_by_ad.items():
        try:
            db.collection('adPerformance').document(ad_id).update({
                'ghlStats.leads': stats['leads'],
                'ghlStats.bookings': stats['bookings'],
                'ghlStats.deposits': stats['deposits'],
                'ghlStats.cashCollected': stats['cash_collected'],
                'lastSync': firestore.SERVER_TIMESTAMP
            })
            updated += 1
            if updated % 10 == 0:
                print(f"   Updated {updated} ads...")
        except Exception as e:
            print(f"   ⚠️  Error updating {ad_id}: {e}")
    
    print()
    print(f"✅ Updated {updated} ads in Firebase")
    print()
else:
    print("=" * 80)
    print("ℹ️  To update Firebase with correct data, run:")
    print("   python3 reconcileFromFirebase.py --update")
    print("=" * 80)
    print()

