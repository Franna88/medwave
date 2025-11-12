#!/usr/bin/env python3
"""Monitor the progress of backfill script by checking Firebase"""

import firebase_admin
from firebase_admin import credentials, firestore
import time

try:
    cred = credentials.Certificate('medx-ai-firebase-adminsdk-fbsvc-a86e7bd050.json')
    firebase_admin.initialize_app(cred)
except:
    pass

db = firestore.client()

def check_progress():
    ads_ref = db.collection('advertData')
    all_ads = list(ads_ref.stream())
    
    ads_with_insights = 0
    ads_without_insights = 0
    
    for ad_doc in all_ads:
        insights_ref = db.collection('advertData').document(ad_doc.id).collection('insights')
        insights = list(insights_ref.limit(1).stream())
        if len(insights) > 0:
            ads_with_insights += 1
        else:
            ads_without_insights += 1
    
    total = len(all_ads)
    progress_pct = (ads_with_insights * 100 // total) if total > 0 else 0
    
    print(f'\n{"="*60}')
    print(f'BACKFILL PROGRESS MONITOR')
    print(f'{"="*60}')
    print(f'Total ads in advertData: {total}')
    print(f'✅ Ads WITH insights:     {ads_with_insights}')
    print(f'❌ Ads WITHOUT insights:  {ads_without_insights}')
    print(f'📊 Progress:              {progress_pct}%')
    print(f'{"="*60}\n')
    
    if ads_without_insights == 0:
        print('🎉 All ads have insights! Backfill complete!')
    else:
        print(f'⏳ Still processing {ads_without_insights} ads...')

if __name__ == '__main__':
    check_progress()




