#!/usr/bin/env python3
"""
Check why ads are getting _placeh as month
"""

import firebase_admin
from firebase_admin import credentials, firestore

# Initialize Firebase
if not firebase_admin._apps:
    cred = credentials.Certificate('medx-ai-firebase-adminsdk-fbsvc-a86e7bd050.json')
    firebase_admin.initialize_app(cred)

db = firestore.client()

print('\n' + '='*80)
print('CHECKING PLACEHOLDER MONTH ISSUE')
print('='*80)

# Check the _placeh month
placeh_ref = db.collection('advertData').document('_placeh')
placeh_doc = placeh_ref.get()

if placeh_doc.exists:
    print('\n❌ Found _placeh month document!')
    print(f'   Data: {placeh_doc.to_dict()}')
    
    # Get sample ads
    ads = list(placeh_ref.collection('ads').limit(3).stream())
    print(f'\n   Sample ads in _placeh: {len(ads)}')
    
    for ad in ads:
        ad_data = ad.to_dict()
        print(f'\n   📱 Ad: {ad.id}')
        print(f'      Campaign: {ad_data.get("campaignName", "N/A")}')
        print(f'      Ad Name: {ad_data.get("adName", "N/A")}')
        print(f'      Created Month: {ad_data.get("createdMonth", "N/A")}')
        print(f'      Has Insights: {ad_data.get("hasInsights", False)}')
        print(f'      Has GHL: {ad_data.get("hasGHLData", False)}')
        
        # Check insights
        insights = list(ad.reference.collection('insights').limit(1).stream())
        if insights:
            insight_data = insights[0].to_dict()
            print(f'      First insight ID: {insights[0].id}')
            print(f'      First insight dateStart: {insight_data.get("dateStart", "MISSING")}')
        else:
            print(f'      No insights found')
        
        # Check ghlWeekly
        ghl = list(ad.reference.collection('ghlWeekly').limit(1).stream())
        if ghl:
            print(f'      First GHL week ID: {ghl[0].id}')
        else:
            print(f'      No GHL data found')

# Check old structure for comparison
print('\n\n' + '='*80)
print('CHECKING OLD STRUCTURE (first 3 ads)')
print('='*80)

old_ads = list(db.collection('advertData').where('adId', '!=', '').limit(3).stream())

for ad in old_ads:
    ad_data = ad.to_dict()
    print(f'\n📱 Old structure ad: {ad.id}')
    print(f'   Campaign: {ad_data.get("campaignName", "N/A")}')
    
    # Check insights
    insights = list(ad.reference.collection('insights').limit(1).stream())
    if insights:
        insight_data = insights[0].to_dict()
        print(f'   First insight ID: {insights[0].id}')
        print(f'   First insight dateStart: {insight_data.get("dateStart", "MISSING")}')
        print(f'   Expected month: {insight_data.get("dateStart", "")[:7] if insight_data.get("dateStart") else "N/A"}')
    else:
        print(f'   No insights')
    
    # Check ghlWeekly
    ghl = list(ad.reference.collection('ghlWeekly').limit(1).stream())
    if ghl:
        print(f'   First GHL week ID: {ghl[0].id}')
        print(f'   Expected month from GHL: {ghl[0].id[:7] if len(ghl[0].id) >= 7 else "N/A"}')
    else:
        print(f'   No GHL data')

print('\n' + '='*80)

