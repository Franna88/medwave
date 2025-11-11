#!/usr/bin/env python3
"""
Find ads with GHL data for manual verification
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
print('ADS WITH GHL DATA - FOR MANUAL VERIFICATION IN FIREBASE CONSOLE')
print('='*80 + '\n')

# Get all ads
adverts_ref = db.collection('advertData')
all_ads = list(adverts_ref.stream())

ads_with_data = []

for ad in all_ads:
    ghl_ref = db.collection('advertData').document(ad.id).collection('ghlData').document('weekly').collection('weekly')
    ghl_docs = list(ghl_ref.stream())
    
    if ghl_docs:
        ad_data = ad.to_dict()
        leads = sum(doc.to_dict().get('leads', 0) for doc in ghl_docs)
        cash = sum(doc.to_dict().get('cashAmount', 0) for doc in ghl_docs)
        
        ads_with_data.append({
            'id': ad.id,
            'name': ad_data.get('adName', 'N/A'),
            'campaign': ad_data.get('campaignName', 'N/A'),
            'weeks': len(ghl_docs),
            'leads': leads,
            'cash': cash,
            'weekIds': [doc.id for doc in ghl_docs]
        })

# Sort by leads
ads_with_data.sort(key=lambda x: x['leads'], reverse=True)

print(f'Found {len(ads_with_data)} ads with GHL data\n')
print('='*80)
print('TOP 10 ADS TO CHECK IN FIREBASE CONSOLE')
print('='*80 + '\n')

for i, ad in enumerate(ads_with_data[:10], 1):
    print(f'{i}. AD ID: {ad["id"]}')
    print(f'   Ad Name: {ad["name"]}')
    print(f'   Campaign: {ad["campaign"]}')
    print(f'   Leads: {ad["leads"]}, Cash: R{ad["cash"]:.2f}, Weeks: {ad["weeks"]}')
    print(f'   Week IDs: {", ".join(ad["weekIds"])}')
    print(f'\n   📍 Firebase Path:')
    print(f'   advertData/{ad["id"]}/ghlData/weekly/weekly/')
    print(f'\n   🔗 Direct Link:')
    print(f'   https://console.firebase.google.com/project/medx-ai/firestore/databases/-default-/data/~2FadvertData~2F{ad["id"]}~2FghlData~2Fweekly~2Fweekly')
    print('\n' + '-'*80 + '\n')

print('='*80)
print('HOW TO VERIFY IN FIREBASE CONSOLE:')
print('='*80)
print('\n1. Go to: https://console.firebase.google.com/project/medx-ai/firestore')
print('2. Navigate to: advertData collection')
print('3. Find one of the Ad IDs listed above')
print('4. Expand: ghlData > weekly > weekly')
print('5. You should see week documents (e.g., 2025-10-20_2025-10-26)')
print('6. Each week document contains: leads, bookedAppointments, deposits, cashCollected, cashAmount')
print('\n' + '='*80 + '\n')

