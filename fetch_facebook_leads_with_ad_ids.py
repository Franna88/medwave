#!/usr/bin/env python3
"""
Fetch Facebook Lead Ads Data with Ad IDs
=========================================

This script fetches leads from Facebook Lead Ads API to get the ad_id, 
campaign_id, and adset_id that Facebook provides, then matches them 
to GHL opportunities to backfill missing Ad IDs.

Purpose: Fix the 746 opportunities that don't have Ad IDs because GHL 
         isn't capturing them from Facebook Lead Forms.

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

# Facebook API Configuration
FB_ACCESS_TOKEN = os.environ.get('FB_ACCESS_TOKEN', 'EAAc9pw8rgA0BP0S8U9s2cLzSJbCYmJZBKZCTFUNDD2zVXVqkC45q1BIQaPdZAmtXKbZBk6wjprLclIUUafHJ4icQZAXuuePybTL38pNQIcjQQZCbRGGhAtLcLVSGeJP59nMdpt8KNEoMQtvDfZBwBgpLNhQboPpaaeU8fW2rCEEhZA9pRN4RjZAAnwnLqEDaP8Fueo0cZD')
FB_PAGE_ID = '100391263069899'

# GHL API Configuration
GHL_API_KEY = os.environ.get('GHL_API_KEY', 'pit-22f8af95-3244-41e7-9a52-22c87b166f5a')
GHL_LOCATION_ID = os.environ.get('GHL_LOCATION_ID', 'QdLXaFEqrdF0JbVbpKLw')

# Pipeline IDs
ANDRIES_PIPELINE_ID = 'XeAGJWRnUGJ5tuhXam2g'
DAVIDE_PIPELINE_ID = 'AUduOJBB2lxlsEaNmlJz'


def get_facebook_lead_forms():
    """Fetch all lead forms from Facebook Page"""
    print("📋 Fetching Lead Forms from Facebook...", flush=True)
    
    url = f'https://graph.facebook.com/v18.0/{FB_PAGE_ID}/leadgen_forms'
    
    params = {
        'access_token': FB_ACCESS_TOKEN,
        'fields': 'id,name,status,created_time',
        'limit': 100
    }
    
    forms = []
    
    try:
        response = requests.get(url, params=params, timeout=30)
        
        if response.status_code == 200:
            data = response.json()
            forms = data.get('data', [])
            
            print(f"✅ Found {len(forms)} lead forms", flush=True)
            for form in forms:
                print(f"   - {form.get('name')} (ID: {form.get('id')})", flush=True)
            
            return forms
        else:
            print(f"❌ Error: {response.status_code}", flush=True)
            print(f"   Response: {response.text}", flush=True)
            return []
            
    except Exception as e:
        print(f"❌ Exception: {e}", flush=True)
        return []


def get_leads_for_form(form_id, form_name):
    """Fetch all leads for a specific form with ad tracking data"""
    print(f"\n📊 Fetching leads for form: {form_name}", flush=True)
    print(f"   Form ID: {form_id}", flush=True)
    
    url = f'https://graph.facebook.com/v18.0/{form_id}/leads'
    
    params = {
        'access_token': FB_ACCESS_TOKEN,
        'fields': 'id,created_time,field_data,ad_id,adset_id,campaign_id,form_id,ad_name,adset_name,campaign_name',
        'limit': 100
    }
    
    all_leads = []
    
    try:
        while True:
            response = requests.get(url, params=params, timeout=30)
            
            if response.status_code == 200:
                data = response.json()
                leads = data.get('data', [])
                
                all_leads.extend(leads)
                print(f"   Fetched {len(leads)} leads (Total: {len(all_leads)})", flush=True)
                
                # Check for next page
                paging = data.get('paging', {})
                next_url = paging.get('next')
                
                if not next_url:
                    break
                
                # Update URL for next page
                url = next_url
                params = {}  # Next URL already has params
                
            else:
                print(f"   ❌ Error: {response.status_code}", flush=True)
                print(f"   Response: {response.text[:200]}", flush=True)
                break
                
    except Exception as e:
        print(f"   ❌ Exception: {e}", flush=True)
    
    print(f"   ✅ Total leads fetched: {len(all_leads)}", flush=True)
    return all_leads


def extract_lead_email(lead):
    """Extract email from lead field_data"""
    field_data = lead.get('field_data', [])
    
    for field in field_data:
        field_name = field.get('name', '').lower()
        if 'email' in field_name:
            values = field.get('values', [])
            if values:
                return values[0]
    
    return None


def extract_lead_name(lead):
    """Extract name from lead field_data"""
    field_data = lead.get('field_data', [])
    
    first_name = ''
    last_name = ''
    
    for field in field_data:
        field_name = field.get('name', '').lower()
        values = field.get('values', [])
        
        if values:
            if 'first' in field_name or field_name == 'name':
                first_name = values[0]
            elif 'last' in field_name:
                last_name = values[0]
    
    full_name = f"{first_name} {last_name}".strip()
    return full_name if full_name else None


def fetch_ghl_opportunities():
    """Fetch all opportunities from GHL API"""
    print("\n📊 Fetching opportunities from GHL API...", flush=True)
    
    url = 'https://services.leadconnectorhq.com/opportunities/search'
    headers = {
        'Authorization': f'Bearer {GHL_API_KEY}',
        'Version': '2021-07-28',
        'Content-Type': 'application/json',
        'Accept': 'application/json'
    }
    
    opportunities = []
    page = 1
    
    while True:
        params = {
            'location_id': GHL_LOCATION_ID,
            'page': page,
            'limit': 100
        }
        
        try:
            response = requests.get(url, headers=headers, params=params, timeout=30)
            
            if response.status_code == 200:
                data = response.json()
                opps = data.get('opportunities', [])
                
                if not opps:
                    break
                
                # Filter for Andries and Davide pipelines
                for opp in opps:
                    pipeline_id = opp.get('pipelineId', '')
                    if pipeline_id in [ANDRIES_PIPELINE_ID, DAVIDE_PIPELINE_ID]:
                        opportunities.append(opp)
                
                print(f"   Page {page}: {len(opps)} opportunities (Total Andries/Davide: {len(opportunities)})", flush=True)
                
                page += 1
                
                # Safety limit
                if page > 100:
                    break
            else:
                print(f"   ❌ Error: {response.status_code}", flush=True)
                break
                
        except Exception as e:
            print(f"   ❌ Exception: {e}", flush=True)
            break
    
    print(f"✅ Total Andries & Davide opportunities: {len(opportunities)}", flush=True)
    return opportunities


def match_leads_to_opportunities():
    """Main function to fetch Facebook leads and match to GHL opportunities"""
    
    print("\n" + "=" * 80)
    print("FACEBOOK LEAD ADS DATA RETRIEVAL & MATCHING")
    print("=" * 80)
    print()
    
    # Step 1: Fetch Facebook Lead Forms
    forms = get_facebook_lead_forms()
    
    if not forms:
        print("\n❌ No forms found or error fetching forms")
        print("\n🔍 This could be due to:")
        print("   1. Access token doesn't have 'leads_retrieval' permission")
        print("   2. Access token doesn't have 'pages_read_engagement' permission")
        print("   3. Page ID is incorrect")
        return
    
    # Step 2: Fetch leads for each form
    all_facebook_leads = []
    leads_by_form = {}
    
    for form in forms:
        form_id = form.get('id')
        form_name = form.get('name')
        
        leads = get_leads_for_form(form_id, form_name)
        
        if leads:
            all_facebook_leads.extend(leads)
            leads_by_form[form_id] = {
                'form_name': form_name,
                'leads': leads
            }
    
    print()
    print("=" * 80)
    print("FACEBOOK LEADS SUMMARY")
    print("=" * 80)
    print()
    print(f"📊 Total Facebook Leads: {len(all_facebook_leads)}")
    print()
    
    # Analyze what data Facebook provides
    leads_with_ad_id = 0
    leads_with_campaign_id = 0
    leads_with_adset_id = 0
    leads_with_no_tracking = 0
    
    for lead in all_facebook_leads:
        has_ad_id = bool(lead.get('ad_id'))
        has_campaign_id = bool(lead.get('campaign_id'))
        has_adset_id = bool(lead.get('adset_id'))
        
        if has_ad_id:
            leads_with_ad_id += 1
        if has_campaign_id:
            leads_with_campaign_id += 1
        if has_adset_id:
            leads_with_adset_id += 1
        
        if not (has_ad_id or has_campaign_id or has_adset_id):
            leads_with_no_tracking += 1
    
    print(f"📊 Facebook Tracking Data Coverage:")
    print(f"   ✅ Leads WITH ad_id: {leads_with_ad_id} ({leads_with_ad_id/len(all_facebook_leads)*100:.1f}%)")
    print(f"   ✅ Leads WITH campaign_id: {leads_with_campaign_id} ({leads_with_campaign_id/len(all_facebook_leads)*100:.1f}%)")
    print(f"   ✅ Leads WITH adset_id: {leads_with_adset_id} ({leads_with_adset_id/len(all_facebook_leads)*100:.1f}%)")
    print(f"   ❌ Leads with NO tracking: {leads_with_no_tracking} ({leads_with_no_tracking/len(all_facebook_leads)*100:.1f}%)")
    print()
    
    # Show sample lead data
    if all_facebook_leads:
        print("📋 SAMPLE LEAD DATA (First Lead):")
        sample_lead = all_facebook_leads[0]
        print(f"   Lead ID: {sample_lead.get('id')}")
        print(f"   Created: {sample_lead.get('created_time')}")
        print(f"   Ad ID: {sample_lead.get('ad_id', 'NOT PROVIDED')}")
        print(f"   Campaign ID: {sample_lead.get('campaign_id', 'NOT PROVIDED')}")
        print(f"   AdSet ID: {sample_lead.get('adset_id', 'NOT PROVIDED')}")
        print(f"   Ad Name: {sample_lead.get('ad_name', 'NOT PROVIDED')}")
        print(f"   Campaign Name: {sample_lead.get('campaign_name', 'NOT PROVIDED')}")
        print()
        
        # Show field data
        field_data = sample_lead.get('field_data', [])
        if field_data:
            print(f"   Field Data ({len(field_data)} fields):")
            for field in field_data[:5]:  # Show first 5
                field_name = field.get('name', 'unknown')
                field_values = field.get('values', [])
                field_value = field_values[0] if field_values else 'empty'
                print(f"      - {field_name}: {field_value[:50] if len(str(field_value)) > 50 else field_value}")
        print()
    
    # Step 3: Fetch GHL opportunities
    ghl_opportunities = fetch_ghl_opportunities()
    
    # Step 4: Match leads to opportunities
    print()
    print("=" * 80)
    print("MATCHING FACEBOOK LEADS TO GHL OPPORTUNITIES")
    print("=" * 80)
    print()
    
    # Build email index for GHL opportunities
    ghl_by_email = {}
    ghl_by_name = {}
    
    for opp in ghl_opportunities:
        email = opp.get('contact', {}).get('email', '').lower().strip()
        name = opp.get('contact', {}).get('name', '').lower().strip()
        
        if email:
            ghl_by_email[email] = opp
        if name:
            if name not in ghl_by_name:
                ghl_by_name[name] = []
            ghl_by_name[name].append(opp)
    
    print(f"📊 GHL Opportunities Index:")
    print(f"   By Email: {len(ghl_by_email)} unique emails")
    print(f"   By Name: {len(ghl_by_name)} unique names")
    print()
    
    # Match leads
    matched_by_email = 0
    matched_by_name = 0
    unmatched = 0
    new_mappings = []
    
    for lead in all_facebook_leads:
        lead_email = extract_lead_email(lead)
        lead_name = extract_lead_name(lead)
        
        matched_opp = None
        match_method = None
        
        # Try email match first
        if lead_email:
            lead_email_clean = lead_email.lower().strip()
            if lead_email_clean in ghl_by_email:
                matched_opp = ghl_by_email[lead_email_clean]
                match_method = 'email'
                matched_by_email += 1
        
        # Try name match if email didn't work
        if not matched_opp and lead_name:
            lead_name_clean = lead_name.lower().strip()
            if lead_name_clean in ghl_by_name:
                # Take first match
                matched_opp = ghl_by_name[lead_name_clean][0]
                match_method = 'name'
                matched_by_name += 1
        
        if matched_opp:
            # Check if lead has ad_id
            ad_id = lead.get('ad_id')
            campaign_id = lead.get('campaign_id')
            adset_id = lead.get('adset_id')
            
            if ad_id:
                new_mappings.append({
                    'opportunity_id': matched_opp.get('id'),
                    'opportunity_name': matched_opp.get('contact', {}).get('name'),
                    'facebook_lead_id': lead.get('id'),
                    'ad_id': ad_id,
                    'campaign_id': campaign_id,
                    'adset_id': adset_id,
                    'ad_name': lead.get('ad_name'),
                    'campaign_name': lead.get('campaign_name'),
                    'adset_name': lead.get('adset_name'),
                    'match_method': match_method,
                    'lead_created': lead.get('created_time'),
                    'form_id': lead.get('form_id')
                })
        else:
            unmatched += 1
    
    print(f"📊 Matching Results:")
    print(f"   ✅ Matched by Email: {matched_by_email}")
    print(f"   ✅ Matched by Name: {matched_by_name}")
    print(f"   ❌ Unmatched: {unmatched}")
    print(f"   📝 New Mappings with Ad ID: {len(new_mappings)}")
    print()
    
    # Show sample mappings
    if new_mappings:
        print("=" * 80)
        print("SAMPLE NEW MAPPINGS (First 10)")
        print("=" * 80)
        print()
        
        for i, mapping in enumerate(new_mappings[:10], 1):
            print(f"{i}. {mapping['opportunity_name']}")
            print(f"   Opportunity ID: {mapping['opportunity_id']}")
            print(f"   Facebook Lead ID: {mapping['facebook_lead_id']}")
            print(f"   Ad ID: {mapping['ad_id']}")
            print(f"   Campaign: {mapping['campaign_name']}")
            print(f"   Match Method: {mapping['match_method']}")
            print()
    
    # Save results
    output_file = f"facebook_leads_matching_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
    with open(output_file, 'w') as f:
        json.dump({
            'summary': {
                'total_facebook_leads': len(all_facebook_leads),
                'leads_with_ad_id': leads_with_ad_id,
                'leads_with_campaign_id': leads_with_campaign_id,
                'leads_with_adset_id': leads_with_adset_id,
                'total_ghl_opportunities': len(ghl_opportunities),
                'matched_by_email': matched_by_email,
                'matched_by_name': matched_by_name,
                'unmatched': unmatched,
                'new_mappings_count': len(new_mappings)
            },
            'new_mappings': new_mappings,
            'leads_by_form': {
                form_id: {
                    'form_name': data['form_name'],
                    'lead_count': len(data['leads'])
                }
                for form_id, data in leads_by_form.items()
            }
        }, f, indent=2, default=str)
    
    print(f"📄 Detailed results saved to: {output_file}")
    print()
    
    # Final summary
    print("=" * 80)
    print("NEXT STEPS")
    print("=" * 80)
    print()
    
    if new_mappings:
        print(f"✅ Found {len(new_mappings)} opportunities that can be mapped to Facebook Ad IDs!")
        print()
        print("🎯 To apply these mappings:")
        print("   1. Review the JSON file to verify mappings")
        print("   2. Run a script to update ghlOpportunityMapping in Firebase")
        print("   3. Re-run populate_ghl_data.py to update advertData")
    else:
        print("⚠️  No new mappings found.")
        print()
        print("🔍 This could mean:")
        print("   1. Facebook is not providing ad_id in the Lead Ads API")
        print("   2. Leads don't match GHL opportunities (different emails/names)")
        print("   3. Access token permissions are insufficient")
    
    print()


if __name__ == "__main__":
    match_leads_to_opportunities()

