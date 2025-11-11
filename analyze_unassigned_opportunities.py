#!/usr/bin/env python3
"""
Analyze Unassigned Opportunities by Date
=========================================

This script analyzes the 487 unassigned opportunities to understand:
1. Total count of unassigned opportunities
2. Date distribution (when they were created)
3. Pipeline breakdown
4. Stage breakdown
5. Why they couldn't be assigned

Author: MedWave Development Team
Date: November 11, 2025
"""

import os
import json
import requests
from datetime import datetime
from collections import defaultdict
import firebase_admin
from firebase_admin import credentials, firestore

# Initialize Firebase
if not firebase_admin._apps:
    cred = credentials.Certificate('medx-ai-firebase-adminsdk-fbsvc-a86e7bd050.json')
    firebase_admin.initialize_app(cred)

db = firestore.client()

# GHL API Configuration
GHL_API_KEY = os.environ.get('GHL_API_KEY', 'pit-22f8af95-3244-41e7-9a52-22c87b166f5a')
GHL_LOCATION_ID = os.environ.get('GHL_LOCATION_ID', 'QdLXaFEqrdF0JbVbpKLw')

# Pipeline IDs
ANDRIES_PIPELINE_ID = 'XeAGJWRnUGJ5tuhXam2g'
DAVIDE_PIPELINE_ID = 'AUduOJBB2lxlsEaNmlJz'

def fetch_all_opportunities():
    """Fetch all opportunities from GHL API (Andries & Davide only)."""
    print("📊 Fetching opportunities from GHL API...", flush=True)
    
    headers = {
        'Authorization': f'Bearer {GHL_API_KEY}',
        'Version': '2021-07-28',
        'Content-Type': 'application/json'
    }
    
    all_opportunities = []
    page = 1
    
    while True:
        params = {
            'location_id': GHL_LOCATION_ID,
            'page': page,
            'limit': 100
        }
        
        response = requests.get(
            'https://services.leadconnectorhq.com/opportunities/search',
            headers=headers,
            params=params
        )
        
        if response.status_code != 200:
            print(f"   ❌ Error: {response.status_code} - {response.text}", flush=True)
            break
        
        data = response.json()
        opportunities = data.get('opportunities', [])
        
        if not opportunities:
            break
        
        all_opportunities.extend(opportunities)
        print(f"   Page {page}: {len(opportunities)} opportunities (Total: {len(all_opportunities)})", flush=True)
        page += 1
        
        # Safety limit
        if page > 100:
            break
    
    # Filter for Andries & Davide only
    filtered = [
        opp for opp in all_opportunities
        if opp.get('pipelineId') in [ANDRIES_PIPELINE_ID, DAVIDE_PIPELINE_ID]
    ]
    
    print(f"   ✅ Total opportunities: {len(all_opportunities)}", flush=True)
    print(f"   ✅ Andries & Davide: {len(filtered)}", flush=True)
    print(flush=True)
    
    return filtered

def extract_h_ad_id_from_attributions(opportunity):
    """Extract h_ad_id from opportunity attributions."""
    attributions = opportunity.get('attributions', [])
    
    for attr in reversed(attributions):
        # Check various possible fields
        for field in ['h_ad_id', 'utmAdId', 'adId']:
            if attr.get(field):
                return attr[field]
    
    return None

def extract_utm_data(opportunity):
    """Extract all UTM data from opportunity."""
    attributions = opportunity.get('attributions', [])
    
    utm_data = {
        'h_ad_id': None,
        'utmCampaignId': None,
        'utmCampaign': None,
        'utmMedium': None,
        'utmSource': None
    }
    
    for attr in reversed(attributions):
        if not utm_data['h_ad_id']:
            utm_data['h_ad_id'] = extract_h_ad_id_from_attributions(opportunity)
        if not utm_data['utmCampaignId'] and attr.get('utmCampaignId'):
            utm_data['utmCampaignId'] = attr.get('utmCampaignId')
        if not utm_data['utmCampaign'] and attr.get('utmCampaign'):
            utm_data['utmCampaign'] = attr.get('utmCampaign')
        if not utm_data['utmMedium'] and attr.get('utmMedium'):
            utm_data['utmMedium'] = attr.get('utmMedium')
        if not utm_data['utmSource'] and attr.get('utmSource'):
            utm_data['utmSource'] = attr.get('utmSource')
    
    return utm_data

def analyze_unassigned_opportunities():
    """Analyze unassigned opportunities by date and other factors."""
    
    print("=" * 80, flush=True)
    print("ANALYZING UNASSIGNED OPPORTUNITIES", flush=True)
    print("=" * 80, flush=True)
    print(flush=True)
    
    # Fetch all opportunities
    opportunities = fetch_all_opportunities()
    
    # Load existing assignments from Firebase
    print("📊 Loading existing assignments from Firebase...", flush=True)
    assignments_ref = db.collection('ghlOpportunityMapping')
    assignments_docs = assignments_ref.stream()
    assigned_ids = {doc.id for doc in assignments_docs}
    print(f"   ✅ Found {len(assigned_ids)} assigned opportunities", flush=True)
    print(flush=True)
    
    # Identify unassigned opportunities
    unassigned = []
    for opp in opportunities:
        opp_id = opp.get('id')
        if opp_id not in assigned_ids:
            unassigned.append(opp)
    
    print(f"📊 Total Opportunities: {len(opportunities)}", flush=True)
    if len(opportunities) > 0:
        print(f"   ✅ Assigned: {len(assigned_ids)} ({len(assigned_ids)/len(opportunities)*100:.1f}%)", flush=True)
        print(f"   ❌ Unassigned: {len(unassigned)} ({len(unassigned)/len(opportunities)*100:.1f}%)", flush=True)
    else:
        print(f"   ❌ ERROR: No opportunities fetched from GHL API!", flush=True)
        return
    print(flush=True)
    
    # Analyze by date
    print("=" * 80, flush=True)
    print("UNASSIGNED OPPORTUNITIES BY DATE", flush=True)
    print("=" * 80, flush=True)
    print(flush=True)
    
    by_month = defaultdict(int)
    by_year = defaultdict(int)
    by_pipeline = defaultdict(int)
    by_stage = defaultdict(int)
    by_reason = defaultdict(int)
    
    unassigned_details = []
    
    for opp in unassigned:
        opp_id = opp.get('id')
        name = opp.get('name', 'Unknown')
        created_at = opp.get('createdAt', '')
        pipeline_id = opp.get('pipelineId')
        stage_name = opp.get('pipelineStageName', 'Unknown')
        monetary_value = opp.get('monetaryValue', 0)
        
        # Parse date
        try:
            date_obj = datetime.fromisoformat(created_at.replace('Z', '+00:00'))
            month_key = date_obj.strftime('%Y-%m')
            year_key = date_obj.strftime('%Y')
            date_str = date_obj.strftime('%Y-%m-%d')
        except:
            month_key = 'Unknown'
            year_key = 'Unknown'
            date_str = 'Unknown'
        
        by_month[month_key] += 1
        by_year[year_key] += 1
        
        # Pipeline
        pipeline_name = 'Andries' if pipeline_id == ANDRIES_PIPELINE_ID else 'Davide'
        by_pipeline[pipeline_name] += 1
        
        # Stage
        by_stage[stage_name] += 1
        
        # Determine why it couldn't be assigned
        utm_data = extract_utm_data(opp)
        reason = []
        
        if not utm_data['h_ad_id']:
            reason.append('No Ad ID')
        if not utm_data['utmCampaignId']:
            reason.append('No Campaign ID')
        if not utm_data['utmCampaign']:
            reason.append('No Ad Name')
        if not utm_data['utmMedium']:
            reason.append('No AdSet Name')
        
        reason_str = ', '.join(reason) if reason else 'Unknown'
        by_reason[reason_str] += 1
        
        unassigned_details.append({
            'opportunity_id': opp_id,
            'name': name,
            'created_at': created_at,
            'date': date_str,
            'pipeline': pipeline_name,
            'stage': stage_name,
            'monetary_value': monetary_value,
            'utm_data': utm_data,
            'reason': reason_str
        })
    
    # Print by year
    print("📅 BY YEAR:", flush=True)
    for year in sorted(by_year.keys()):
        count = by_year[year]
        pct = count / len(unassigned) * 100
        print(f"   {year}: {count} ({pct:.1f}%)", flush=True)
    print(flush=True)
    
    # Print by month
    print("📅 BY MONTH:", flush=True)
    for month in sorted(by_month.keys(), reverse=True)[:12]:  # Last 12 months
        count = by_month[month]
        pct = count / len(unassigned) * 100
        print(f"   {month}: {count} ({pct:.1f}%)", flush=True)
    print(flush=True)
    
    # Print by pipeline
    print("🔀 BY PIPELINE:", flush=True)
    for pipeline in sorted(by_pipeline.keys()):
        count = by_pipeline[pipeline]
        pct = count / len(unassigned) * 100
        print(f"   {pipeline}: {count} ({pct:.1f}%)", flush=True)
    print(flush=True)
    
    # Print by stage (top 10)
    print("📊 BY STAGE (Top 10):", flush=True)
    sorted_stages = sorted(by_stage.items(), key=lambda x: x[1], reverse=True)[:10]
    for stage, count in sorted_stages:
        pct = count / len(unassigned) * 100
        print(f"   {stage}: {count} ({pct:.1f}%)", flush=True)
    print(flush=True)
    
    # Print by reason
    print("❓ WHY COULDN'T BE ASSIGNED:", flush=True)
    sorted_reasons = sorted(by_reason.items(), key=lambda x: x[1], reverse=True)
    for reason, count in sorted_reasons:
        pct = count / len(unassigned) * 100
        print(f"   {reason}: {count} ({pct:.1f}%)", flush=True)
    print(flush=True)
    
    # Recent unassigned (last 30 days)
    print("=" * 80, flush=True)
    print("RECENT UNASSIGNED (Last 30 Days)", flush=True)
    print("=" * 80, flush=True)
    print(flush=True)
    
    now = datetime.now()
    recent = [
        opp for opp in unassigned_details
        if opp['date'] != 'Unknown'
    ]
    recent.sort(key=lambda x: x['date'], reverse=True)
    recent = recent[:30]
    
    for i, opp in enumerate(recent, 1):
        print(f"{i}. {opp['name'][:50]}", flush=True)
        print(f"   Date: {opp['date']}", flush=True)
        print(f"   Pipeline: {opp['pipeline']} | Stage: {opp['stage']}", flush=True)
        print(f"   Monetary Value: R{opp['monetary_value']:,.2f}", flush=True)
        print(f"   Reason: {opp['reason']}", flush=True)
        print(f"   UTM Data:", flush=True)
        print(f"      Ad ID: {opp['utm_data']['h_ad_id'] or 'None'}", flush=True)
        print(f"      Campaign ID: {opp['utm_data']['utmCampaignId'] or 'None'}", flush=True)
        print(f"      Ad Name: {opp['utm_data']['utmCampaign'] or 'None'}", flush=True)
        print(f"      AdSet: {opp['utm_data']['utmMedium'] or 'None'}", flush=True)
        print(flush=True)
    
    # Save to file
    timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
    output_file = f"unassigned_analysis_{timestamp}.json"
    
    with open(output_file, 'w') as f:
        json.dump({
            'summary': {
                'total_opportunities': len(opportunities),
                'assigned': len(assigned_ids),
                'unassigned': len(unassigned),
                'unassigned_percentage': len(unassigned) / len(opportunities) * 100
            },
            'by_year': dict(by_year),
            'by_month': dict(by_month),
            'by_pipeline': dict(by_pipeline),
            'by_stage': dict(by_stage),
            'by_reason': dict(by_reason),
            'unassigned_details': unassigned_details
        }, f, indent=2, default=str)
    
    print("=" * 80, flush=True)
    print("ANALYSIS COMPLETE", flush=True)
    print("=" * 80, flush=True)
    print(flush=True)
    print(f"📄 Detailed report saved to: {output_file}", flush=True)
    print(flush=True)

if __name__ == '__main__':
    print(flush=True)
    print("🔍 Analyzing Unassigned Opportunities...", flush=True)
    print("📦 Initializing Firebase...", flush=True)
    print("✅ Firebase initialized", flush=True)
    print(flush=True)
    
    analyze_unassigned_opportunities()

