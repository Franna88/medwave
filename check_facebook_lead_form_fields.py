#!/usr/bin/env python3
"""
Check Facebook Lead Form Field Configuration
=============================================

This script checks what fields are configured in Facebook Lead Forms
to understand what data is being captured and passed to GHL.

Purpose: Identify why h_ad_id is missing from some opportunities

Author: MedWave Development Team
Date: November 11, 2025
"""

import os
import json
import requests
from collections import defaultdict

# Facebook API Configuration
FB_ACCESS_TOKEN = os.environ.get('FB_ACCESS_TOKEN', 'EAAc9pw8rgA0BP0S8U9s2cLzSJbCYmJZBKZCTFUNDD2zVXVqkC45q1BIQaPdZAmtXKbZBk6wjprLclIUUafHJ4icQZAXuuePybTL38pNQIcjQQZCbRGGhAtLcLVSGeJP59nMdpt8KNEoMQtvDfZBwBgpLNhQboPpaaeU8fW2rCEEhZA9pRN4RjZAAnwnLqEDaP8Fueo0cZD')
FB_AD_ACCOUNT_ID = 'act_220298027464902'
FB_PAGE_ID = '100391263069899'  # From the JSON files we saw earlier


def get_lead_forms_from_page():
    """Fetch all lead forms from Facebook Page"""
    print("📋 Fetching Lead Forms from Facebook Page...", flush=True)
    print(f"   Page ID: {FB_PAGE_ID}", flush=True)
    print()
    
    url = f'https://graph.facebook.com/v18.0/{FB_PAGE_ID}/leadgen_forms'
    
    params = {
        'access_token': FB_ACCESS_TOKEN,
        'fields': 'id,name,status,questions,privacy_policy,locale,created_time,tracking_parameters',
        'limit': 100
    }
    
    forms = []
    
    try:
        response = requests.get(url, params=params, timeout=30)
        
        if response.status_code == 200:
            data = response.json()
            forms = data.get('data', [])
            
            print(f"✅ Found {len(forms)} lead forms", flush=True)
            return forms
        else:
            print(f"❌ Error: {response.status_code}", flush=True)
            print(f"   Response: {response.text}", flush=True)
            return []
            
    except Exception as e:
        print(f"❌ Exception: {e}", flush=True)
        return []


def get_lead_form_details(form_id):
    """Get detailed information about a specific lead form"""
    url = f'https://graph.facebook.com/v18.0/{form_id}'
    
    params = {
        'access_token': FB_ACCESS_TOKEN,
        'fields': 'id,name,status,questions,privacy_policy,locale,created_time,tracking_parameters,context_card'
    }
    
    try:
        response = requests.get(url, params=params, timeout=30)
        
        if response.status_code == 200:
            return response.json()
        else:
            return None
            
    except Exception as e:
        print(f"❌ Error fetching form {form_id}: {e}", flush=True)
        return None


def analyze_lead_form_fields():
    """Main analysis function"""
    
    print("\n" + "=" * 80)
    print("FACEBOOK LEAD FORM FIELD CONFIGURATION ANALYSIS")
    print("=" * 80)
    print()
    
    # Get all lead forms
    forms = get_lead_forms_from_page()
    
    if not forms:
        print("❌ No lead forms found or error fetching forms")
        print()
        print("🔍 Possible reasons:")
        print("   1. Access token doesn't have 'leads_retrieval' permission")
        print("   2. Page ID is incorrect")
        print("   3. No lead forms exist on this page")
        print()
        return
    
    print()
    print("=" * 80)
    print("LEAD FORM DETAILS")
    print("=" * 80)
    print()
    
    all_questions = defaultdict(int)
    forms_with_tracking = 0
    forms_with_h_ad_id = 0
    
    for i, form in enumerate(forms, 1):
        form_id = form.get('id')
        form_name = form.get('name', 'Unknown')
        form_status = form.get('status', 'Unknown')
        
        print(f"📋 Form {i}: {form_name}")
        print(f"   ID: {form_id}")
        print(f"   Status: {form_status}")
        print(f"   Created: {form.get('created_time', 'Unknown')}")
        
        # Check tracking parameters
        tracking_params = form.get('tracking_parameters', [])
        if tracking_params:
            forms_with_tracking += 1
            print(f"   ✅ Tracking Parameters: {len(tracking_params)}")
            for param in tracking_params:
                print(f"      - {param.get('key', 'unknown')}: {param.get('value', 'unknown')}")
                
                # Check for h_ad_id
                if param.get('key') == 'h_ad_id' or param.get('value') == '{{ad.id}}':
                    forms_with_h_ad_id += 1
        else:
            print(f"   ❌ NO tracking parameters configured")
        
        # Check questions (including hidden fields)
        questions = form.get('questions', [])
        if questions:
            print(f"   📝 Questions: {len(questions)}")
            
            hidden_fields = []
            visible_fields = []
            
            for q in questions:
                q_type = q.get('type', 'unknown')
                q_key = q.get('key', 'unknown')
                q_label = q.get('label', 'No label')
                
                all_questions[q_type] += 1
                
                # Check if it's a hidden field
                if q_type == 'CUSTOM' and 'dependent_conditional_questions' not in q:
                    # Might be a hidden field - check for dynamic values
                    if '{{' in str(q):
                        hidden_fields.append(q)
                    else:
                        visible_fields.append(q)
                else:
                    visible_fields.append(q)
            
            if hidden_fields:
                print(f"   🔒 Hidden Fields: {len(hidden_fields)}")
                for hf in hidden_fields:
                    print(f"      - {hf.get('key', 'unknown')}: {hf.get('label', 'No label')}")
            
            if visible_fields:
                print(f"   👁️  Visible Fields: {len(visible_fields)}")
                for vf in visible_fields[:5]:  # Show first 5
                    print(f"      - {vf.get('type', 'unknown')}: {vf.get('label', 'No label')}")
                if len(visible_fields) > 5:
                    print(f"      ... and {len(visible_fields) - 5} more")
        
        print()
    
    # Summary
    print("=" * 80)
    print("SUMMARY")
    print("=" * 80)
    print()
    print(f"📊 Total Lead Forms: {len(forms)}")
    print(f"   ✅ Forms with tracking parameters: {forms_with_tracking}")
    print(f"   ✅ Forms with h_ad_id configured: {forms_with_h_ad_id}")
    print(f"   ❌ Forms WITHOUT tracking: {len(forms) - forms_with_tracking}")
    print()
    
    if all_questions:
        print("📝 Question Types Used:")
        for q_type, count in sorted(all_questions.items(), key=lambda x: x[1], reverse=True):
            print(f"   - {q_type}: {count}")
        print()
    
    # Analysis
    print("=" * 80)
    print("ROOT CAUSE ANALYSIS")
    print("=" * 80)
    print()
    
    if forms_with_h_ad_id == len(forms):
        print("✅ ALL lead forms have h_ad_id configured!")
        print("   → Facebook Lead Forms are set up correctly")
        print()
        print("🔍 If GHL is still not receiving h_ad_id, the problem is:")
        print("   1. GHL integration not mapping the tracking parameters")
        print("   2. Facebook not passing tracking parameters in webhook")
        print("   3. GHL custom field mapping is incorrect")
    elif forms_with_h_ad_id > 0:
        print(f"⚠️  Only {forms_with_h_ad_id}/{len(forms)} forms have h_ad_id configured")
        print("   → Some forms are missing tracking parameters")
        print("   → Need to update remaining forms")
    else:
        print("❌ NO lead forms have h_ad_id configured!")
        print("   → Need to add tracking parameters to all forms")
        print()
        print("🎯 HOW TO FIX:")
        print("   1. Go to Facebook Ads Manager")
        print("   2. Select each Lead Form")
        print("   3. Edit Form → Settings → Tracking Parameters")
        print("   4. Add these parameters:")
        print("      - Key: h_ad_id, Value: {{ad.id}}")
        print("      - Key: campaign_id, Value: {{campaign.id}}")
        print("      - Key: adset_id, Value: {{adset.id}}")
    
    print()
    
    # Check if we can access lead data
    print("=" * 80)
    print("CHECKING LEAD DATA ACCESS")
    print("=" * 80)
    print()
    
    if forms:
        sample_form_id = forms[0].get('id')
        print(f"🔍 Checking leads for form: {forms[0].get('name')}", flush=True)
        print(f"   Form ID: {sample_form_id}", flush=True)
        
        url = f'https://graph.facebook.com/v18.0/{sample_form_id}/leads'
        params = {
            'access_token': FB_ACCESS_TOKEN,
            'fields': 'id,created_time,field_data,ad_id,adset_id,campaign_id,form_id',
            'limit': 5
        }
        
        try:
            response = requests.get(url, params=params, timeout=30)
            
            if response.status_code == 200:
                data = response.json()
                leads = data.get('data', [])
                
                if leads:
                    print(f"   ✅ Found {len(leads)} recent leads", flush=True)
                    print()
                    
                    # Check first lead
                    lead = leads[0]
                    print(f"   📊 Sample Lead Data:")
                    print(f"      Lead ID: {lead.get('id')}")
                    print(f"      Created: {lead.get('created_time')}")
                    print(f"      Ad ID: {lead.get('ad_id', 'NOT PROVIDED')}")
                    print(f"      Campaign ID: {lead.get('campaign_id', 'NOT PROVIDED')}")
                    print(f"      AdSet ID: {lead.get('adset_id', 'NOT PROVIDED')}")
                    print()
                    
                    # Check field data
                    field_data = lead.get('field_data', [])
                    if field_data:
                        print(f"      Field Data ({len(field_data)} fields):")
                        for field in field_data:
                            field_name = field.get('name', 'unknown')
                            field_values = field.get('values', [])
                            field_value = field_values[0] if field_values else 'empty'
                            
                            # Highlight tracking fields
                            if field_name in ['h_ad_id', 'campaign_id', 'adset_id', 'ad_id']:
                                print(f"         ✅ {field_name}: {field_value}")
                            else:
                                print(f"         - {field_name}: {field_value[:50] if len(str(field_value)) > 50 else field_value}")
                    
                    print()
                    print("   🎯 KEY INSIGHT:")
                    if lead.get('ad_id'):
                        print("      ✅ Facebook IS providing ad_id in the lead data!")
                        print("      → GHL should be able to capture this")
                    else:
                        print("      ❌ Facebook is NOT providing ad_id in the lead data")
                        print("      → Need to configure tracking parameters in the form")
                else:
                    print(f"   ⚠️  No recent leads found for this form", flush=True)
            else:
                print(f"   ❌ Error: {response.status_code}", flush=True)
                print(f"   Response: {response.text[:200]}", flush=True)
                
        except Exception as e:
            print(f"   ❌ Exception: {e}", flush=True)
    
    print()
    
    # Save detailed report
    output_file = f"facebook_lead_forms_analysis_{os.getpid()}.json"
    with open(output_file, 'w') as f:
        json.dump({
            'total_forms': len(forms),
            'forms_with_tracking': forms_with_tracking,
            'forms_with_h_ad_id': forms_with_h_ad_id,
            'question_types': dict(all_questions),
            'forms': forms
        }, f, indent=2, default=str)
    
    print(f"📄 Detailed report saved to: {output_file}")
    print()


if __name__ == "__main__":
    analyze_lead_form_fields()

