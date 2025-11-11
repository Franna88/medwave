#!/usr/bin/env python3
import firebase_admin
from firebase_admin import credentials, firestore

# Initialize Firebase
if not firebase_admin._apps:
    cred = credentials.Certificate('medx-ai-firebase-adminsdk-fbsvc-a86e7bd050.json')
    firebase_admin.initialize_app(cred)

db = firestore.client()

# Check one ad that has GHL leads but no cash
# From the logs: "COLIN LAGRANGE (DDM) (120234319081200335)" has 2 leads but $0 cash
ad_id = '120234319081200335'
month = '2025-10'

print(f'\n🔍 Checking GHL data for ad {ad_id} in month {month}')
print('='*80)

# Get the ad document
ad_ref = db.collection('advertData').document(month).collection('ads').document(ad_id)
ad_doc = ad_ref.get()

if ad_doc.exists:
    print(f'\n📄 Ad Document Data:')
    ad_data = ad_doc.to_dict()
    print(f'   Ad Name: {ad_data.get("adName")}')
    print(f'   Has GHL Data: {ad_data.get("hasGHLData")}')
    print(f'   Last GHL Sync: {ad_data.get("lastGHLSync")}')
    
    # Get all ghlWeekly documents
    ghl_weeks = ad_ref.collection('ghlWeekly').stream()
    
    print(f'\n📊 GHL Weekly Data:')
    total_cash = 0
    total_leads = 0
    
    for week_doc in ghl_weeks:
        week_data = week_doc.to_dict()
        print(f'\n   Week: {week_doc.id}')
        print(f'      Leads: {week_data.get("leads", 0)}')
        print(f'      Booked: {week_data.get("bookedAppointments", 0)}')
        print(f'      Deposits: {week_data.get("deposits", 0)}')
        print(f'      Cash Collected: {week_data.get("cashCollected", 0)}')
        print(f'      Cash Amount: ${week_data.get("cashAmount", 0)}')
        
        total_cash += week_data.get("cashAmount", 0)
        total_leads += week_data.get("leads", 0)
    
    print(f'\n   TOTALS:')
    print(f'      Total Leads: {total_leads}')
    print(f'      Total Cash: ${total_cash}')
else:
    print(f'❌ Ad document not found!')

print('\n' + '='*80)
