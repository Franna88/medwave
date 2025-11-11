#!/usr/bin/env python3
"""
Check Firebase advertData for deposits and cash collected values.
"""

import firebase_admin
from firebase_admin import credentials, firestore
from collections import defaultdict

# Initialize Firebase
if not firebase_admin._apps:
    cred = credentials.Certificate('medx-ai-firebase-adminsdk-fbsvc-a86e7bd050.json')
    firebase_admin.initialize_app(cred)

db = firestore.client()

def check_all_months():
    """Check all months for deposits and cash"""
    
    print("=" * 80)
    print("CHECKING ALL MONTHS FOR DEPOSITS & CASH")
    print("=" * 80)
    print()
    
    # Get all month documents
    months_ref = db.collection('advertData')
    months = months_ref.stream()
    
    all_months_data = []
    
    for month_doc in months:
        month_id = month_doc.id
        month_data = month_doc.to_dict()
        
        # Skip if this is old structure (has adId field)
        if 'adId' in month_data:
            continue
        
        print(f"📅 Checking month: {month_id}")
        
        # Get all ads in this month
        ads_ref = month_doc.reference.collection('ads')
        ads = ads_ref.stream()
        
        month_total_deposits = 0
        month_total_cash = 0
        month_deposit_amount = 0.0
        month_cash_amount = 0.0
        ads_with_deposits = 0
        
        for ad_doc in ads:
            ad_data = ad_doc.to_dict()
            
            # Check if ad has GHL data
            if not ad_data.get('hasGHLData', False):
                continue
            
            # Get GHL weekly data
            ghl_weeks_ref = ad_doc.reference.collection('ghlWeekly')
            ghl_weeks = list(ghl_weeks_ref.stream())
            
            ad_has_deposits = False
            
            for week_doc in ghl_weeks:
                week_data = week_doc.to_dict()
                
                deposits = week_data.get('deposits', 0)
                cash_collected = week_data.get('cashCollected', 0)
                cash_amount = week_data.get('cashAmount', 0.0)
                
                if deposits > 0 or cash_collected > 0:
                    ad_has_deposits = True
                    month_total_deposits += deposits
                    month_total_cash += cash_collected
                    
                    # Cash amount is used for both deposits and cash collected
                    if deposits > 0:
                        month_deposit_amount += cash_amount
                    if cash_collected > 0:
                        month_cash_amount += cash_amount
            
            if ad_has_deposits:
                ads_with_deposits += 1
        
        if ads_with_deposits > 0:
            print(f"   ✅ Found {ads_with_deposits} ads with deposits/cash")
            print(f"      Deposits: {month_total_deposits} (R{month_deposit_amount:,.2f})")
            print(f"      Cash: {month_total_cash} (R{month_cash_amount:,.2f})")
        else:
            print(f"   ❌ No deposits/cash found")
        
        print()
        
        all_months_data.append({
            'month': month_id,
            'ads_with_deposits': ads_with_deposits,
            'total_deposits': month_total_deposits,
            'total_cash': month_total_cash,
            'deposit_amount': month_deposit_amount,
            'cash_amount': month_cash_amount
        })
    
    # Summary
    print("=" * 80)
    print("OVERALL SUMMARY")
    print("=" * 80)
    print()
    
    total_ads_with_deposits = sum(m['ads_with_deposits'] for m in all_months_data)
    total_deposits = sum(m['total_deposits'] for m in all_months_data)
    total_cash = sum(m['total_cash'] for m in all_months_data)
    total_deposit_amount = sum(m['deposit_amount'] for m in all_months_data)
    total_cash_amount = sum(m['cash_amount'] for m in all_months_data)
    
    print(f"📊 Total ads with deposits/cash: {total_ads_with_deposits}")
    print(f"📊 Total deposits: {total_deposits} (R{total_deposit_amount:,.2f})")
    print(f"📊 Total cash collected: {total_cash} (R{total_cash_amount:,.2f})")
    print(f"📊 Combined total: R{(total_deposit_amount + total_cash_amount):,.2f})")
    print()
    
    if total_deposits == 0 and total_cash == 0:
        print("⚠️  WARNING: NO DEPOSITS OR CASH FOUND IN ANY MONTH!")
        print()
        print("This could mean:")
        print("1. The GHL opportunities don't have 'Deposit Received' or 'Cash Collected' stages")
        print("2. The stage name matching in populate_ghl_data.py is incorrect")
        print("3. The monetaryValue field is not set in GHL opportunities")
        print()
        print("Check the stage names in GHL API:")
        print("   - Andries: 'Deposit Received', 'Cash Collected'")
        print("   - Davide: 'Deposit Received', 'Cash Collected'")
    else:
        print("✅ SUCCESS: Found deposits and cash in Firebase!")
        print()
        print("Monthly breakdown:")
        for m in sorted(all_months_data, key=lambda x: x['month'], reverse=True):
            if m['ads_with_deposits'] > 0:
                print(f"   {m['month']}: {m['ads_with_deposits']} ads, "
                      f"{m['total_deposits']} deposits (R{m['deposit_amount']:,.2f}), "
                      f"{m['total_cash']} cash (R{m['cash_amount']:,.2f})")
    
    print()

if __name__ == "__main__":
    check_all_months()

