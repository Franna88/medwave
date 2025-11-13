#!/usr/bin/env python3
"""
GHL Opportunities API Data Inspector
Connects to GHL API and displays all available data for opportunities
"""

import requests
import json
from datetime import datetime

# GHL API Configuration
GHL_API_KEY = 'pit-22f8af95-3244-41e7-9a52-22c87b166f5a'
GHL_LOCATION_ID = 'QdLXaFEqrdF0JbVbpKLw'
GHL_BASE_URL = 'https://services.leadconnectorhq.com'
GHL_API_VERSION = '2021-07-28'

# Pipeline IDs
ANDRIES_PIPELINE_ID = 'XeAGJWRnUGJ5tuhXam2g'
DAVIDE_PIPELINE_ID = 'AUduOJBB2lxlsEaNmlJz'
ERICH_PIPELINE_ID = 'pTbNvnrXqJc9u1oxir3q'

def print_section(title):
    """Print a formatted section header"""
    print("\n" + "="*100)
    print(f"  {title}")
    print("="*100)

def print_json(data, indent=2):
    """Pretty print JSON data"""
    print(json.dumps(data, indent=indent, default=str))

def get_headers():
    """Get GHL API headers"""
    return {
        'Authorization': f'Bearer {GHL_API_KEY}',
        'Version': GHL_API_VERSION,
        'Content-Type': 'application/json'
    }

def fetch_opportunities(limit=10, page=1):
    """Fetch opportunities from GHL"""
    print_section(f"FETCHING OPPORTUNITIES (Page {page}, Limit {limit})")
    
    url = f"{GHL_BASE_URL}/opportunities/search"
    
    params = {
        'location_id': GHL_LOCATION_ID,
        'limit': limit,
        'page': page
    }
    
    try:
        response = requests.get(url, headers=get_headers(), params=params)
        response.raise_for_status()
        data = response.json()
        
        opportunities = data.get('opportunities', [])
        total = data.get('total', 0)
        
        print(f"\n✅ Found {len(opportunities)} opportunities (Total: {total})\n")
        
        # Show summary
        for i, opp in enumerate(opportunities[:5], 1):
            print(f"{i}. {opp.get('name', 'N/A')}")
            print(f"   ID: {opp.get('id', 'N/A')}")
            print(f"   Pipeline: {opp.get('pipelineId', 'N/A')}")
            print(f"   Stage: {opp.get('pipelineStageId', 'N/A')}")
            print(f"   Value: R {opp.get('monetaryValue', 0):,.2f}")
            print()
        
        return opportunities, data
    
    except requests.exceptions.RequestException as e:
        print(f"❌ Error fetching opportunities: {e}")
        if hasattr(e, 'response') and e.response is not None:
            print(f"Response: {e.response.text}")
        return [], {}

def fetch_single_opportunity(opportunity_id):
    """Fetch a single opportunity with all details"""
    print_section(f"FETCHING SINGLE OPPORTUNITY: {opportunity_id}")
    
    url = f"{GHL_BASE_URL}/opportunities/{opportunity_id}"
    
    try:
        response = requests.get(url, headers=get_headers())
        response.raise_for_status()
        opportunity = response.json()
        
        print("\n📦 COMPLETE OPPORTUNITY DATA:")
        print_json(opportunity)
        
        return opportunity
    
    except requests.exceptions.RequestException as e:
        print(f"❌ Error fetching opportunity: {e}")
        if hasattr(e, 'response') and e.response is not None:
            print(f"Response: {e.response.text}")
        return None

def fetch_opportunity_with_monetary_value():
    """Find and fetch an opportunity with monetary value"""
    print_section("SEARCHING FOR OPPORTUNITY WITH MONETARY VALUE")
    
    url = f"{GHL_BASE_URL}/opportunities/search"
    
    params = {
        'location_id': GHL_LOCATION_ID,
        'limit': 100,
        'page': 1
    }
    
    try:
        response = requests.get(url, headers=get_headers(), params=params)
        response.raise_for_status()
        data = response.json()
        
        opportunities = data.get('opportunities', [])
        
        # Find opportunities with monetary value
        opps_with_value = [
            opp for opp in opportunities 
            if opp.get('monetaryValue', 0) > 0
        ]
        
        print(f"\n✅ Found {len(opps_with_value)} opportunities with monetary value\n")
        
        # Show top 10 by value
        sorted_opps = sorted(opps_with_value, key=lambda x: x.get('monetaryValue', 0), reverse=True)
        
        for i, opp in enumerate(sorted_opps[:10], 1):
            print(f"{i}. {opp.get('name', 'N/A')}")
            print(f"   ID: {opp.get('id', 'N/A')}")
            print(f"   Value: R {opp.get('monetaryValue', 0):,.2f}")
            print(f"   Stage ID: {opp.get('pipelineStageId', 'N/A')}")
            print()
        
        if sorted_opps:
            return sorted_opps[0]
        
        return None
    
    except requests.exceptions.RequestException as e:
        print(f"❌ Error searching opportunities: {e}")
        if hasattr(e, 'response') and e.response is not None:
            print(f"Response: {e.response.text}")
        return None

def analyze_opportunity_fields(opportunity):
    """Analyze and categorize all fields in an opportunity"""
    print_section("OPPORTUNITY FIELD ANALYSIS")
    
    if not opportunity:
        print("❌ No opportunity data to analyze")
        return
    
    print("\n✅ AVAILABLE FIELDS:\n")
    
    # Categorize fields
    basic_fields = []
    pipeline_fields = []
    contact_fields = []
    attribution_fields = []
    monetary_fields = []
    date_fields = []
    other_fields = []
    
    for key, value in opportunity.items():
        if key in ['id', 'name', 'status']:
            basic_fields.append((key, type(value).__name__, value))
        elif 'pipeline' in key.lower() or 'stage' in key.lower():
            pipeline_fields.append((key, type(value).__name__, value))
        elif 'contact' in key.lower():
            contact_fields.append((key, type(value).__name__, value))
        elif 'attribution' in key.lower() or 'utm' in key.lower() or 'source' in key.lower():
            attribution_fields.append((key, type(value).__name__, value))
        elif 'monetary' in key.lower() or 'value' in key.lower() or 'amount' in key.lower():
            monetary_fields.append((key, type(value).__name__, value))
        elif 'date' in key.lower() or 'time' in key.lower() or 'At' in key:
            date_fields.append((key, type(value).__name__, value))
        else:
            other_fields.append((key, type(value).__name__, value))
    
    # Print categorized fields
    if basic_fields:
        print("📋 BASIC FIELDS:")
        for field, field_type, value in basic_fields:
            if isinstance(value, (dict, list)):
                print(f"   - {field} ({field_type})")
            else:
                print(f"   - {field} ({field_type}): {value}")
    
    if pipeline_fields:
        print("\n🔄 PIPELINE FIELDS:")
        for field, field_type, value in pipeline_fields:
            if isinstance(value, (dict, list)):
                print(f"   - {field} ({field_type})")
            else:
                print(f"   - {field} ({field_type}): {value}")
    
    if contact_fields:
        print("\n👤 CONTACT FIELDS:")
        for field, field_type, value in contact_fields:
            if isinstance(value, (dict, list)):
                print(f"   - {field} ({field_type})")
            else:
                print(f"   - {field} ({field_type}): {value}")
    
    if monetary_fields:
        print("\n💰 MONETARY FIELDS:")
        for field, field_type, value in monetary_fields:
            if isinstance(value, (dict, list)):
                print(f"   - {field} ({field_type})")
            else:
                print(f"   - {field} ({field_type}): {value}")
    
    if attribution_fields:
        print("\n🎯 ATTRIBUTION FIELDS:")
        for field, field_type, value in attribution_fields:
            if isinstance(value, (dict, list)):
                print(f"   - {field} ({field_type})")
                if isinstance(value, list) and len(value) > 0:
                    print(f"     Sample: {value[0]}")
            else:
                print(f"   - {field} ({field_type}): {value}")
    
    if date_fields:
        print("\n📅 DATE/TIME FIELDS:")
        for field, field_type, value in date_fields:
            print(f"   - {field} ({field_type}): {value}")
    
    if other_fields:
        print("\n📦 OTHER FIELDS:")
        for field, field_type, value in other_fields:
            if isinstance(value, (dict, list)):
                print(f"   - {field} ({field_type})")
            else:
                print(f"   - {field} ({field_type}): {value}")

def main():
    """Main execution"""
    print_section("GHL OPPORTUNITIES API DATA INSPECTOR")
    print(f"API Base URL: {GHL_BASE_URL}")
    print(f"Location ID: {GHL_LOCATION_ID}")
    print(f"API Version: {GHL_API_VERSION}")
    print(f"Timestamp: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    
    # Step 1: Fetch recent opportunities
    opportunities, search_response = fetch_opportunities(limit=10, page=1)
    
    if not opportunities:
        print("\n❌ No opportunities found")
        return
    
    # Step 2: Show complete search response structure
    print_section("COMPLETE SEARCH RESPONSE STRUCTURE")
    print("\n📦 SEARCH RESPONSE KEYS:")
    for key in search_response.keys():
        print(f"   - {key}")
    
    # Step 3: Find opportunity with monetary value
    opp_with_value = fetch_opportunity_with_monetary_value()
    
    if opp_with_value:
        selected_opp_id = opp_with_value['id']
    else:
        selected_opp_id = opportunities[0]['id']
    
    # Step 4: Fetch single opportunity with all details
    complete_opp = fetch_single_opportunity(selected_opp_id)
    
    # Step 5: Analyze fields
    if complete_opp:
        analyze_opportunity_fields(complete_opp)
    
    # Step 6: Show sample opportunity from search
    print_section("SAMPLE OPPORTUNITY FROM SEARCH")
    if opportunities:
        print("\n📦 FIRST OPPORTUNITY (from search endpoint):")
        print_json(opportunities[0])
    
    # Step 7: Summary
    print_section("DATA SUMMARY")
    
    if complete_opp:
        print("\n✅ COMPLETE FIELD LIST:")
        for key in sorted(complete_opp.keys()):
            value = complete_opp[key]
            if isinstance(value, (dict, list)):
                print(f"   - {key}: {type(value).__name__}")
            else:
                print(f"   - {key}")
    
    print_section("INSPECTION COMPLETE")
    print("\n✅ All available opportunity data has been retrieved and displayed")
    print("📝 Review the complete payloads to see what data GHL API provides")
    print("\n💡 KEY FINDINGS:")
    print("   - Opportunity details include: pipeline, stage, contact, monetary value")
    print("   - Attribution data may include: UTM parameters, source info")
    print("   - Stage information returned as pipelineStageId (requires mapping)")
    print("   - Monetary values stored in cents (divide by 100 for currency)")

if __name__ == '__main__':
    main()
