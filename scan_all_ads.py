#!/usr/bin/env python3
"""
Count ads with GHL data
"""

import firebase_admin
from firebase_admin import credentials, firestore

# Initialize Firebase
try:
    cred = credentials.Certificate('medx-ai-firebase-adminsdk-fbsvc-a86e7bd050.json')
    firebase_admin.initialize_app(cred)
except:
    pass

db = firestore.client()

print('\n' + '='*80)
print('SCANNING ALL ADS FOR GHL DATA')
print('='*80 + '\n')

# Get all ads
adverts_ref = db.collection('advertData')
all_ads = list(adverts_ref.stream())

print(f'Total ads in collection: {len(all_ads)}\n')
print('Scanning...\n')

ads_with_data = []
total_weeks = 0
total_leads = 0

for i, ad in enumerate(all_ads, 1):
    ghl_ref = db.collection('advertData').document(ad.id).collection('ghlData').document('weekly').collection('weekly')
    ghl_docs = list(ghl_ref.stream())
    
    if ghl_docs:
        ad_data = ad.to_dict()
        week_count = len(ghl_docs)
        leads = sum(doc.to_dict().get('leads', 0) for doc in ghl_docs)
        cash = sum(doc.to_dict().get('cashAmount', 0) for doc in ghl_docs)
        
        ads_with_data.append({
            'id': ad.id,
            'name': ad_data.get('adName', 'N/A'),
            'campaign': ad_data.get('campaignName', 'N/A'),
            'weeks': week_count,
            'leads': leads,
            'cash': cash
        })
        
        total_weeks += week_count
        total_leads += leads
        
        print(f'✅ {ad_data.get("adName", ad.id)[:50]}')
        print(f'   Weeks: {week_count}, Leads: {leads}, Cash: R{cash:.2f}')
    
    if i % 100 == 0:
        print(f'\n   Progress: {i}/{len(all_ads)} ads scanned...\n')

print('\n' + '='*80)
print('RESULTS')
print('='*80 + '\n')

print(f'Total ads: {len(all_ads)}')
print(f'Ads with GHL data: {len(ads_with_data)}')
print(f'Total weekly documents: {total_weeks}')
print(f'Total leads: {total_leads}')
print(f'Total cash: R{sum(ad["cash"] for ad in ads_with_data):.2f}')

if ads_with_data:
    print('\n' + '='*80)
    print('TOP 10 ADS BY LEADS')
    print('='*80 + '\n')
    
    ads_with_data.sort(key=lambda x: x['leads'], reverse=True)
    
    for i, ad in enumerate(ads_with_data[:10], 1):
        print(f'{i}. {ad["name"]}')
        print(f'   Campaign: {ad["campaign"]}')
        print(f'   Leads: {ad["leads"]}, Cash: R{ad["cash"]:.2f}, Weeks: {ad["weeks"]}')
        print()

print('='*80)

