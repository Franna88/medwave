#!/usr/bin/env python3
"""
Analyze unmatched GHL opportunities by date range
"""

import firebase_admin
from firebase_admin import credentials, firestore
from datetime import datetime, timedelta
from collections import defaultdict
import os

# Initialize Firebase
script_dir = os.path.dirname(os.path.abspath(__file__))
creds_path = os.path.join(script_dir, '..', 'medx-ai-firebase-adminsdk-fbsvc-a86e7bd050.json')
cred = credentials.Certificate(creds_path)

try:
    firebase_admin.get_app()
except ValueError:
    firebase_admin.initialize_app(cred)

db = firestore.client()

print("=" * 80)
print("ANALYZING UNMATCHED GHL OPPORTUNITIES BY DATE")
print("=" * 80)
print()

# Fetch all ghlOpportunities
print("📊 Fetching all ghlOpportunities...")
print()

ghl_opps_ref = db.collection('ghlOpportunities').stream()

unmatched_opportunities = []
matched_opportunities = []

for opp_doc in ghl_opps_ref:
    opp_data = opp_doc.to_dict()
    opp_id = opp_doc.id
    
    assigned_ad_id = opp_data.get('assignedAdId')
    created_at = opp_data.get('createdAt')
    name = opp_data.get('name', 'Unknown')
    
    if not assigned_ad_id:
        unmatched_opportunities.append({
            'id': opp_id,
            'name': name,
            'createdAt': created_at,
            'data': opp_data
        })
    else:
        matched_opportunities.append({
            'id': opp_id,
            'name': name,
            'createdAt': created_at,
            'assignedAdId': assigned_ad_id
        })

print(f"✅ Found {len(matched_opportunities)} matched opportunities")
print(f"✅ Found {len(unmatched_opportunities)} unmatched opportunities")
print()

# Analyze unmatched by date
print("=" * 80)
print("UNMATCHED OPPORTUNITIES BY DATE RANGE")
print("=" * 80)
print()

# Define date ranges (timezone-aware)
from datetime import timezone
now = datetime.now(timezone.utc)
two_months_ago = now - timedelta(days=60)
six_months_ago = now - timedelta(days=180)
one_year_ago = now - timedelta(days=365)

# Categorize by date
date_buckets = {
    'last_2_months': [],
    'last_6_months': [],
    'last_year': [],
    'older_than_year': [],
    'no_date': []
}

for opp in unmatched_opportunities:
    created_at = opp['createdAt']
    
    if not created_at:
        date_buckets['no_date'].append(opp)
        continue
    
    # Parse the date (format: "2025-11-10T11:06:39.741Z")
    try:
        opp_date = datetime.fromisoformat(created_at.replace('Z', '+00:00'))
    except:
        date_buckets['no_date'].append(opp)
        continue
    
    if opp_date >= two_months_ago:
        date_buckets['last_2_months'].append(opp)
    elif opp_date >= six_months_ago:
        date_buckets['last_6_months'].append(opp)
    elif opp_date >= one_year_ago:
        date_buckets['last_year'].append(opp)
    else:
        date_buckets['older_than_year'].append(opp)

# Print summary
print(f"📅 Last 2 months (Oct-Nov 2025): {len(date_buckets['last_2_months'])} unmatched")
print(f"📅 Last 6 months: {len(date_buckets['last_6_months'])} unmatched")
print(f"📅 Last year: {len(date_buckets['last_year'])} unmatched")
print(f"📅 Older than 1 year: {len(date_buckets['older_than_year'])} unmatched")
print(f"📅 No date available: {len(date_buckets['no_date'])} unmatched")
print()

# Show details for last 2 months
if date_buckets['last_2_months']:
    print("=" * 80)
    print(f"DETAILS: UNMATCHED OPPORTUNITIES FROM LAST 2 MONTHS ({len(date_buckets['last_2_months'])} total)")
    print("=" * 80)
    print()
    
    # Sort by date (newest first)
    date_buckets['last_2_months'].sort(key=lambda x: x['createdAt'], reverse=True)
    
    for i, opp in enumerate(date_buckets['last_2_months'][:50], 1):  # Show first 50
        print(f"{i}. {opp['name']}")
        print(f"   Created: {opp['createdAt']}")
        print(f"   Opportunity ID: {opp['id']}")
        
        # Check if they have any attribution data
        opp_data = opp['data']
        contact_id = opp_data.get('contactId')
        pipeline = opp_data.get('source', 'Unknown')
        
        print(f"   Pipeline: {pipeline}")
        print(f"   Contact ID: {contact_id}")
        
        # Check attributions
        attributions = opp_data.get('attributions', [])
        if attributions:
            last_attr = attributions[-1] if attributions else {}
            utm_source = last_attr.get('utmSource', 'N/A')
            utm_medium = last_attr.get('utmMedium', 'N/A')
            utm_campaign = last_attr.get('utmCampaign', 'N/A')
            print(f"   UTM Source: {utm_source}")
            print(f"   UTM Medium: {utm_medium}")
            print(f"   UTM Campaign: {utm_campaign}")
        else:
            print(f"   ⚠️  No attribution data")
        
        print()
    
    if len(date_buckets['last_2_months']) > 50:
        print(f"... and {len(date_buckets['last_2_months']) - 50} more")
        print()

# Monthly breakdown for last 6 months
print("=" * 80)
print("MONTHLY BREAKDOWN (Last 6 Months)")
print("=" * 80)
print()

monthly_counts = defaultdict(int)

for opp in date_buckets['last_2_months'] + date_buckets['last_6_months']:
    created_at = opp['createdAt']
    try:
        opp_date = datetime.fromisoformat(created_at.replace('Z', '+00:00'))
        month_key = opp_date.strftime('%Y-%m')
        monthly_counts[month_key] += 1
    except:
        pass

for month in sorted(monthly_counts.keys(), reverse=True):
    print(f"📅 {month}: {monthly_counts[month]} unmatched opportunities")

print()
print("=" * 80)
print("ANALYSIS COMPLETE")
print("=" * 80)

