#!/usr/bin/env python3
"""
Preview what the reset will do - show current vs. what will be calculated
"""

import firebase_admin
from firebase_admin import credentials, firestore
from collections import defaultdict

# Initialize Firebase
cred = credentials.Certificate('/Users/mac/dev/medwave/medx-ai-firebase-adminsdk-fbsvc-a86e7bd050.json')
try:
    firebase_admin.get_app()
except ValueError:
    firebase_admin.initialize_app(cred)

db = firestore.client()

print("=" * 80)
print("PREVIEW: RESET IMPACT ON ADS GHL STATS")
print("=" * 80)
print()

# STEP 1: Calculate what GHL stats SHOULD be from ghlOpportunities
print("📊 STEP 1: Calculating correct GHL stats from ghlOpportunities...")
print()

ghl_opps_ref = db.collection('ghlOpportunities').stream()
correct_ad_stats = defaultdict(lambda: {'leads': 0, 'bookings': 0, 'deposits': 0, 'cash': 0})

total_opps = 0
assigned_opps = 0

for opp_doc in ghl_opps_ref:
    opp_data = opp_doc.to_dict()
    total_opps += 1
    
    assigned_ad_id = opp_data.get('assignedAdId')
    
    if not assigned_ad_id:
        continue
    
    assigned_opps += 1
    stage_category = opp_data.get('stageCategory', 'lead')
    
    # Count as lead
    correct_ad_stats[assigned_ad_id]['leads'] += 1
    
    # Count as booking if reached booking stage or beyond
    if stage_category in ['booking', 'deposit', 'cash_collected']:
        correct_ad_stats[assigned_ad_id]['bookings'] += 1
    
    # Count as deposit if reached deposit stage or beyond
    if stage_category in ['deposit', 'cash_collected']:
        correct_ad_stats[assigned_ad_id]['deposits'] += 1
    
    # Count as cash collected if reached final stage
    if stage_category == 'cash_collected':
        correct_ad_stats[assigned_ad_id]['cash'] += 1

print(f"✅ Processed {total_opps} opportunities")
print(f"✅ {assigned_opps} assigned to ads")
print(f"✅ {len(correct_ad_stats)} unique ads should have GHL stats")
print()

# STEP 2: Compare with current ads collection (sample first 200)
print("📊 STEP 2: Comparing with current ads collection (first 200 ads)...")
print()

ads_ref = db.collection('ads').limit(200).stream()

matches = 0
mismatches = 0
will_be_zeroed = 0
sample_mismatches = []

for ad_doc in ads_ref:
    ad_id = ad_doc.id
    ad_data = ad_doc.to_dict()
    
    current_ghl = ad_data.get('ghlStats', {})
    current_leads = current_ghl.get('leads', 0)
    current_bookings = current_ghl.get('bookings', 0)
    current_deposits = current_ghl.get('deposits', 0)
    current_cash = current_ghl.get('cashCollected', 0)
    
    correct_stats = correct_ad_stats.get(ad_id, {'leads': 0, 'bookings': 0, 'deposits': 0, 'cash': 0})
    correct_leads = correct_stats['leads']
    correct_bookings = correct_stats['bookings']
    correct_deposits = correct_stats['deposits']
    correct_cash = correct_stats['cash']
    
    if (current_leads == correct_leads and 
        current_bookings == correct_bookings and 
        current_deposits == correct_deposits and 
        current_cash == correct_cash):
        matches += 1
    else:
        mismatches += 1
        
        if len(sample_mismatches) < 20:
            sample_mismatches.append({
                'ad_id': ad_id,
                'ad_name': ad_data.get('adName', 'Unknown'),
                'current': {
                    'leads': current_leads,
                    'bookings': current_bookings,
                    'deposits': current_deposits,
                    'cash': current_cash
                },
                'correct': {
                    'leads': correct_leads,
                    'bookings': correct_bookings,
                    'deposits': correct_deposits,
                    'cash': correct_cash
                }
            })
        
        # Check if this ad will be zeroed out
        if correct_leads == 0 and current_leads > 0:
            will_be_zeroed += 1

print(f"✅ Checked 200 ads")
print(f"✅ {matches} ads already have CORRECT stats")
print(f"❌ {mismatches} ads have INCORRECT stats")
print(f"🔄 {will_be_zeroed} ads will be zeroed out (have stale data)")
print()

if sample_mismatches:
    print("=" * 80)
    print("📋 SAMPLE OF MISMATCHES (showing first 20):")
    print("=" * 80)
    print()
    
    for i, mismatch in enumerate(sample_mismatches, 1):
        print(f"{i}. Ad: {mismatch['ad_id']}")
        print(f"   Name: {mismatch['ad_name']}")
        print(f"   Current:  L:{mismatch['current']['leads']} B:{mismatch['current']['bookings']} D:{mismatch['current']['deposits']} C:{mismatch['current']['cash']}")
        print(f"   Correct:  L:{mismatch['correct']['leads']} B:{mismatch['correct']['bookings']} D:{mismatch['correct']['deposits']} C:{mismatch['correct']['cash']}")
        
        if mismatch['correct']['leads'] == 0:
            print(f"   ⚠️  Will be ZEROED OUT (no opportunities)")
        else:
            print(f"   🔄 Will be UPDATED")
        print()

print("=" * 80)
print("📊 SUMMARY")
print("=" * 80)
print()
print(f"Sample of 200 ads checked:")
print(f"  ✅ Already correct: {matches} ({matches/2:.0f}%)")
print(f"  ❌ Need fixing: {mismatches} ({mismatches/2:.0f}%)")
print(f"  🔄 Will be zeroed: {will_be_zeroed}")
print()
print("The reset script will:")
print("  1. Zero out ALL ads (clean slate)")
print("  2. Recalculate stats for ONLY the ads with exact Ad ID matches")
print("  3. Leave all other ads at zero")
print()
print("This ensures 100% accuracy with ONLY exact Ad ID matching!")
print()
print("=" * 80)

