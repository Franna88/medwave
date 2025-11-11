#!/usr/bin/env python3
"""
Check AdvertData collection for October 2025 to find GHL deposits and monetary values.
Focuses on Andries and Davide pipelines.
"""

import firebase_admin
from firebase_admin import credentials, firestore
import json
from datetime import datetime

# Initialize Firebase
cred = credentials.Certificate('medx-ai-firebase-adminsdk-fbsvc-a86e7bd050.json')
try:
    firebase_admin.get_app()
except ValueError:
    firebase_admin.initialize_app(cred)

db = firestore.client()

# Pipeline IDs from documentation
ANDRIES_PIPELINE = "XeAGJWRnUGJ5tuhXam2g"
DAVIDE_PIPELINE = "pTbNvnrXqJc9u1oxir3q"

def check_october_ghl_values():
    """Check October 2025 ads for GHL deposits and monetary values."""
    
    print("=" * 80)
    print("CHECKING OCTOBER 2025 ADS FOR GHL DEPOSITS & MONETARY VALUES")
    print("=" * 80)
    print()
    
    # Target October 2025 (new month-first structure)
    month_key = "2025-10"
    
    # Check if month document exists
    month_ref = db.collection('advertData').document(month_key)
    month_doc = month_ref.get()
    
    if not month_doc.exists:
        print(f"❌ No October 2025 data found in advertData/{month_key}")
        return
    
    month_data = month_doc.to_dict()
    print(f"📊 October 2025 Summary:")
    print(f"   Total Ads: {month_data.get('totalAds', 0)}")
    print(f"   Ads with Insights: {month_data.get('adsWithInsights', 0)}")
    print(f"   Ads with GHL Data: {month_data.get('adsWithGHLData', 0)}")
    print()
    
    # Get all ads in October 2025
    ads_ref = month_ref.collection('ads')
    ads = ads_ref.stream()
    
    total_ads_checked = 0
    total_deposits = 0
    total_cash_collected = 0
    total_deposit_amount = 0.0
    total_cash_amount = 0.0
    ads_with_deposits = []
    
    print("🔍 Checking ads for GHL deposit data...")
    print()
    
    for ad_doc in ads:
        total_ads_checked += 1
        ad_id = ad_doc.id
        ad_data = ad_doc.to_dict()
        
        # Check if ad has GHL data
        if not ad_data.get('hasGHLData', False):
            continue
        
        # Get GHL weekly data
        ghl_weeks_ref = ad_doc.reference.collection('ghlWeekly')
        ghl_weeks = ghl_weeks_ref.stream()
        
        ad_deposits = 0
        ad_cash_collected = 0
        ad_deposit_amount = 0.0
        ad_cash_amount = 0.0
        weeks_with_data = []
        
        for week_doc in ghl_weeks:
            week_data = week_doc.to_dict()
            week_id = week_doc.id
            
            deposits = week_data.get('deposits', 0)
            cash_collected = week_data.get('cashCollected', 0)
            cash_amount = week_data.get('cashAmount', 0.0)
            leads = week_data.get('leads', 0)
            booked = week_data.get('bookedAppointments', 0)
            
            if deposits > 0 or cash_collected > 0 or cash_amount > 0:
                ad_deposits += deposits
                ad_cash_collected += cash_collected
                ad_deposit_amount += cash_amount if deposits > 0 else 0
                ad_cash_amount += cash_amount if cash_collected > 0 else 0
                
                weeks_with_data.append({
                    'week_id': week_id,
                    'leads': leads,
                    'booked': booked,
                    'deposits': deposits,
                    'cash_collected': cash_collected,
                    'cash_amount': cash_amount
                })
        
        if ad_deposits > 0 or ad_cash_collected > 0:
            total_deposits += ad_deposits
            total_cash_collected += ad_cash_collected
            total_deposit_amount += ad_deposit_amount
            total_cash_amount += ad_cash_amount
            
            ad_info = {
                'ad_id': ad_id,
                'ad_name': ad_data.get('adName', 'Unknown'),
                'campaign_name': ad_data.get('campaignName', 'Unknown'),
                'deposits': ad_deposits,
                'cash_collected': ad_cash_collected,
                'deposit_amount': ad_deposit_amount,
                'cash_amount': ad_cash_amount,
                'weeks': weeks_with_data
            }
            ads_with_deposits.append(ad_info)
            
            print(f"💰 Ad: {ad_info['ad_name'][:50]}")
            print(f"   Campaign: {ad_info['campaign_name'][:60]}")
            print(f"   Deposits: {ad_deposits} (R{ad_deposit_amount:.2f})")
            print(f"   Cash Collected: {ad_cash_collected} (R{ad_cash_amount:.2f})")
            print(f"   Weeks with data: {len(weeks_with_data)}")
            for week in weeks_with_data:
                print(f"      {week['week_id']}: {week['leads']} leads, {week['booked']} booked, "
                      f"{week['deposits']} deposits, {week['cash_collected']} cash (R{week['cash_amount']:.2f})")
            print()
    
    # Summary
    print("\n" + "=" * 80)
    print("OCTOBER 2025 - GHL DEPOSITS & CASH SUMMARY")
    print("=" * 80)
    print(f"Total ads checked: {total_ads_checked}")
    print(f"Ads with deposits/cash: {len(ads_with_deposits)}")
    print()
    print(f"📊 TOTALS:")
    print(f"   Total Deposits: {total_deposits}")
    print(f"   Total Deposit Amount: R{total_deposit_amount:,.2f}")
    print(f"   Total Cash Collected: {total_cash_collected}")
    print(f"   Total Cash Amount: R{total_cash_amount:,.2f}")
    print(f"   Combined Total: R{(total_deposit_amount + total_cash_amount):,.2f}")
    print()
    
    if ads_with_deposits:
        print("✅ FOUND ADS WITH DEPOSITS/CASH:")
        print()
        
        # Sort by total monetary value
        ads_with_deposits.sort(key=lambda x: x['deposit_amount'] + x['cash_amount'], reverse=True)
        
        print("Top 10 ads by monetary value:")
        for i, ad in enumerate(ads_with_deposits[:10], 1):
            total_value = ad['deposit_amount'] + ad['cash_amount']
            print(f"{i}. {ad['ad_name'][:40]}")
            print(f"   Deposits: {ad['deposits']} (R{ad['deposit_amount']:,.2f})")
            print(f"   Cash: {ad['cash_collected']} (R{ad['cash_amount']:,.2f})")
            print(f"   Total: R{total_value:,.2f}")
            print()
        
        # Save to JSON file
        output_file = f"october_ghl_deposits_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
        with open(output_file, 'w') as f:
            json.dump({
                'summary': {
                    'total_ads_checked': total_ads_checked,
                    'ads_with_deposits': len(ads_with_deposits),
                    'total_deposits': total_deposits,
                    'total_deposit_amount': total_deposit_amount,
                    'total_cash_collected': total_cash_collected,
                    'total_cash_amount': total_cash_amount,
                    'combined_total': total_deposit_amount + total_cash_amount
                },
                'ads': ads_with_deposits
            }, f, indent=2, default=str)
        print(f"📄 Detailed results saved to: {output_file}")
    else:
        print("❌ NO ADS FOUND WITH DEPOSITS OR CASH")
    
    print()

if __name__ == "__main__":
    check_october_ghl_values()

