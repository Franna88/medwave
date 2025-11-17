#!/usr/bin/env python3
"""
Check ghl_opportunities collection for records with monetary values
"""

import firebase_admin
from firebase_admin import credentials, firestore

# Initialize Firebase
try:
    cred = credentials.Certificate('../medx-ai-firebase-adminsdk-fbsvc-a86e7bd050.json')
    firebase_admin.initialize_app(cred)
    print('✅ Firebase initialized successfully\n')
except Exception as e:
    print(f'⚠️  Firebase already initialized or error: {e}\n')
    pass

try:
    db = firestore.client()
except Exception as e:
    print(f'❌ Error getting Firestore client: {e}')
    print('Trying alternative initialization...\n')
    firebase_admin.delete_app(firebase_admin.get_app())
    cred = credentials.Certificate('../medx-ai-firebase-adminsdk-fbsvc-a86e7bd050.json')
    firebase_admin.initialize_app(cred)
    db = firestore.client()

print('='*80)
print('CHECKING MONETARY VALUES IN GHL_OPPORTUNITIES')
print('='*80 + '\n')

# Fetch all opportunities
print('📄 Fetching all documents from ghl_opportunities collection...\n')

opp_ref = db.collection('ghl_opportunities')
docs = opp_ref.stream()

opportunities = []
total_count = 0
with_value = 0
without_value = 0

for doc in docs:
    total_count += 1
    data = doc.to_dict()
    
    monetary_value = data.get('monetaryValue', 0)
    
    opp_data = {
        'contactId': data.get('contactId'),
        'opportunityId': data.get('opportunityId'),
        'name': data.get('name', 'Unknown'),
        'monetaryValue': monetary_value,
        'pipelineId': data.get('pipelineId'),
        'stageName': data.get('stageName', 'Unknown'),
        'status': data.get('status', 'Unknown'),
        'createdAt': data.get('createdAt', ''),
        'updatedAt': data.get('updatedAt', '')
    }
    
    opportunities.append(opp_data)
    
    if monetary_value and monetary_value > 0:
        with_value += 1
    else:
        without_value += 1

print(f'✅ Scan complete!\n')
print(f'📊 Summary:')
print(f'   Total opportunities: {total_count}')
print(f'   With monetary value (> 0): {with_value}')
print(f'   Without monetary value (= 0): {without_value}\n')

# Sort by monetary value (descending)
opportunities.sort(key=lambda x: x['monetaryValue'], reverse=True)

if with_value > 0:
    print('='*80)
    print(f'OPPORTUNITIES WITH MONETARY VALUES ({with_value} total)')
    print('='*80 + '\n')
    
    for i, opp in enumerate([o for o in opportunities if o['monetaryValue'] > 0], 1):
        pipeline_name = 'Andries' if opp['pipelineId'] == 'XeAGJWRnUGJ5tuhXam2g' else 'Davide'
        
        print(f'{i}. {opp["name"][:40]}')
        print(f'   Contact ID: {opp["contactId"]}')
        print(f'   💰 Value: R {opp["monetaryValue"]:,.2f}')
        print(f'   Pipeline: {pipeline_name}')
        print(f'   Stage: {opp["stageName"]}')
        print(f'   Status: {opp["status"]}')
        print(f'   Created: {opp["createdAt"][:19]}')
        print(f'   Updated: {opp["updatedAt"][:19]}')
        print()
    
    # Calculate total value
    total_value = sum(o['monetaryValue'] for o in opportunities if o['monetaryValue'] > 0)
    print(f'💵 Total Value: R {total_value:,.2f}\n')
else:
    print('⚠️  No opportunities with monetary values found!\n')
    print('Sample opportunities (first 10):')
    print('='*80 + '\n')
    
    for i, opp in enumerate(opportunities[:10], 1):
        pipeline_name = 'Andries' if opp['pipelineId'] == 'XeAGJWRnUGJ5tuhXam2g' else 'Davide'
        
        print(f'{i}. {opp["name"][:40]}')
        print(f'   Contact ID: {opp["contactId"]}')
        print(f'   💰 Value: R {opp["monetaryValue"]:,.2f}')
        print(f'   Pipeline: {pipeline_name}')
        print(f'   Stage: {opp["stageName"]}')
        print(f'   Status: {opp["status"]}')
        print()

print('='*80)
print('CHECK COMPLETE')
print('='*80 + '\n')



