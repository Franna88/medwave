#!/usr/bin/env python3
"""
Verify the backfill results - check specific ads and overall statistics
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

def verify_backfill():
    """Verify the backfill results"""
    
    print('\n' + '='*80)
    print('VERIFY BACKFILL RESULTS')
    print('='*80 + '\n')
    
    # Check the specific ad mentioned by user
    specific_ad_id = '120235556204840335'
    
    print(f'🔍 Checking specific ad: {specific_ad_id}\n')
    
    ad_ref = db.collection('advertData').document(specific_ad_id)
    ad_doc = ad_ref.get()
    
    if ad_doc.exists:
        ad_data = ad_doc.to_dict()
        print(f'✅ Ad found: {ad_data.get("adName")}')
        print(f'   Campaign: {ad_data.get("campaignName")}')
        
        # Check insights
        insights_ref = ad_ref.collection('insights')
        insights = insights_ref.get()
        print(f'   Facebook insights: {len(insights)} weeks')
        
        if len(insights) > 0:
            print('\n   📊 Facebook Insights:')
            for insight_doc in insights:
                insight_data = insight_doc.to_dict()
                print(f'      Week {insight_doc.id}:')
                print(f'         Spend: R{insight_data.get("spend", 0):.2f}')
                print(f'         Impressions: {insight_data.get("impressions", 0):,}')
                print(f'         Clicks: {insight_data.get("clicks", 0)}')
        
        # Check GHL data
        ghl_ref = ad_ref.collection('ghlWeekly')
        ghl_docs = ghl_ref.get()
        print(f'\n   GHL weekly data: {len(ghl_docs)} weeks')
        
        if len(ghl_docs) > 0:
            print('\n   📈 GHL Data:')
            total_leads = 0
            total_booked = 0
            total_deposits = 0
            total_cash = 0
            
            for ghl_doc in ghl_docs:
                if ghl_doc.id == '_placeholder':
                    continue
                ghl_data = ghl_doc.to_dict()
                leads = ghl_data.get('leads', 0)
                booked = ghl_data.get('bookedAppointments', 0)
                deposits = ghl_data.get('deposits', 0)
                cash = ghl_data.get('cashAmount', 0)
                
                total_leads += leads
                total_booked += booked
                total_deposits += deposits
                total_cash += cash
                
                if leads > 0 or booked > 0 or deposits > 0:
                    print(f'      Week {ghl_doc.id}:')
                    print(f'         Leads: {leads}')
                    print(f'         Booked: {booked}')
                    print(f'         Deposits: {deposits}')
                    print(f'         Cash: R{cash:.2f}')
            
            print(f'\n   📊 GHL Totals:')
            print(f'      Total Leads: {total_leads}')
            print(f'      Total Booked: {total_booked}')
            print(f'      Total Deposits: {total_deposits}')
            print(f'      Total Cash: R{total_cash:.2f}')
    
    print('\n' + '='*80)
    print('OVERALL STATISTICS')
    print('='*80 + '\n')
    
    # Get all ads
    all_ads = db.collection('advertData').get()
    
    stats = {
        'total_ads': len(all_ads),
        'with_facebook': 0,
        'with_ghl': 0,
        'with_both': 0,
        'with_neither': 0
    }
    
    for ad_doc in all_ads:
        ad_id = ad_doc.id
        
        # Check Facebook insights
        insights = db.collection('advertData').document(ad_id).collection('insights').limit(1).get()
        has_facebook = len(insights) > 0
        
        # Check GHL data (excluding placeholder)
        ghl_docs = db.collection('advertData').document(ad_id).collection('ghlWeekly').get()
        has_ghl = any(doc.id != '_placeholder' for doc in ghl_docs)
        
        if has_facebook:
            stats['with_facebook'] += 1
        if has_ghl:
            stats['with_ghl'] += 1
        if has_facebook and has_ghl:
            stats['with_both'] += 1
        if not has_facebook and not has_ghl:
            stats['with_neither'] += 1
    
    print(f'📊 Total ads: {stats["total_ads"]}')
    print(f'✅ Ads with Facebook insights: {stats["with_facebook"]}')
    print(f'✅ Ads with GHL data: {stats["with_ghl"]}')
    print(f'🎯 Ads with BOTH Facebook + GHL: {stats["with_both"]}')
    print(f'⚠️  Ads with neither: {stats["with_neither"]}')
    
    print('\n' + '='*80 + '\n')
    
    # Show sample of ads with both data sources
    print('🎯 Sample ads with BOTH Facebook insights AND GHL data:\n')
    
    count = 0
    for ad_doc in all_ads:
        if count >= 10:
            break
        
        ad_id = ad_doc.id
        ad_data = ad_doc.to_dict()
        
        # Check both
        insights = db.collection('advertData').document(ad_id).collection('insights').limit(1).get()
        ghl_docs = db.collection('advertData').document(ad_id).collection('ghlWeekly').get()
        has_ghl = any(doc.id != '_placeholder' for doc in ghl_docs)
        
        if len(insights) > 0 and has_ghl:
            # Get totals
            total_leads = 0
            for ghl_doc in ghl_docs:
                if ghl_doc.id != '_placeholder':
                    total_leads += ghl_doc.to_dict().get('leads', 0)
            
            print(f'   ✅ {ad_data.get("adName", "Unknown")[:50]}')
            print(f'      Ad ID: {ad_id}')
            print(f'      GHL Leads: {total_leads}')
            print()
            count += 1

if __name__ == '__main__':
    verify_backfill()

