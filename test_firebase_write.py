#!/usr/bin/env python3
"""
Test write to advertData to verify Firebase connection
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

print('\n🧪 Testing Firebase write to advertData...\n')

# Pick a test ad
test_ad_id = '120234435129760335'

print(f'Writing test data to: advertData/{test_ad_id}/ghlData/weekly/weekly/TEST_WEEK\n')

# Write test data
test_ref = db.collection('advertData').document(test_ad_id)\
    .collection('ghlWeekly').document('TEST_WEEK')

test_ref.set({
    'leads': 999,
    'bookedAppointments': 111,
    'deposits': 222,
    'cashCollected': 333,
    'cashAmount': 444,
    'testWrite': True,
    'timestamp': firestore.SERVER_TIMESTAMP
})

print('✅ Test write completed!')
print(f'\n📍 Check in Firebase Console:')
print(f'https://console.firebase.google.com/project/medx-ai/firestore/databases/-default-/data/~2FadvertData~2F{test_ad_id}~2FghlData~2Fweekly~2Fweekly~2FTEST_WEEK')
print('\nIf you can see this document in Firebase, then writes are working.')
print('If not, there is a permissions or initialization issue.\n')

# Now try to read it back
print('🔍 Reading back the test data...\n')
doc = test_ref.get()
if doc.exists:
    print('✅ Successfully read back the test data:')
    print(f'   {doc.to_dict()}')
else:
    print('❌ Could not read back the test data!')

