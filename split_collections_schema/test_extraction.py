#!/usr/bin/env python3
"""
Test script to verify Ad ID extraction from different GHL attribution formats
"""

def extract_ad_id_from_attribution(attr):
    """Extract Ad ID from attribution with multiple field name variations"""
    # Check direct fields
    ad_id = (
        attr.get('h_ad_id') or 
        attr.get('utmAdId') or 
        attr.get('utm_ad_id') or
        attr.get('adId') or 
        attr.get('ad_id') or
        attr.get('Ad Id')
    )
    
    # Check in customField array
    if not ad_id and 'customField' in attr:
        for field in attr.get('customField', []):
            field_name = field.get('name', '').lower()
            if field_name in ['ad_id', 'adid', 'utm_ad_id', 'utmadid', 'h_ad_id']:
                ad_id = field.get('value')
                if ad_id:
                    break
    
    # Check in pageDetails
    if not ad_id:
        page_details = attr.get('pageDetails') or attr.get('page_details') or {}
        ad_id = (
            page_details.get('adId') or 
            page_details.get('ad_id') or
            page_details.get('Ad Id')
        )
    
    return ad_id

# Test Case 1: Direct field (old format)
print("=" * 60)
print("TEST CASE 1: Direct h_ad_id field")
print("=" * 60)
attr1 = {
    'h_ad_id': '120235559827960335',
    'utmCampaignId': '120235556205010335'
}
result1 = extract_ad_id_from_attribution(attr1)
print(f"Input: {attr1}")
print(f"Extracted Ad ID: {result1}")
print(f"✅ PASS" if result1 == '120235559827960335' else "❌ FAIL")
print()

# Test Case 2: pageDetails format (from screenshots)
print("=" * 60)
print("TEST CASE 2: Ad ID in pageDetails")
print("=" * 60)
attr2 = {
    'utmSource': 'facebook',
    'pageDetails': {
        'Ad Id': '120235560268260335',
        'Campaign Id': '120235556205010335',
        'Adset Id': '120235556204830335'
    }
}
result2 = extract_ad_id_from_attribution(attr2)
print(f"Input: {attr2}")
print(f"Extracted Ad ID: {result2}")
print(f"✅ PASS" if result2 == '120235560268260335' else "❌ FAIL")
print()

# Test Case 3: camelCase format
print("=" * 60)
print("TEST CASE 3: camelCase adId")
print("=" * 60)
attr3 = {
    'adId': '120235559827960335',
    'campaignId': '120235556205010335'
}
result3 = extract_ad_id_from_attribution(attr3)
print(f"Input: {attr3}")
print(f"Extracted Ad ID: {result3}")
print(f"✅ PASS" if result3 == '120235559827960335' else "❌ FAIL")
print()

# Test Case 4: customField array format
print("=" * 60)
print("TEST CASE 4: Ad ID in customField array")
print("=" * 60)
attr4 = {
    'utmSource': 'facebook',
    'customField': [
        {'name': 'utm_source', 'value': 'facebook'},
        {'name': 'ad_id', 'value': '120235559827960335'},
        {'name': 'campaign_id', 'value': '120235556205010335'}
    ]
}
result4 = extract_ad_id_from_attribution(attr4)
print(f"Input: {attr4}")
print(f"Extracted Ad ID: {result4}")
print(f"✅ PASS" if result4 == '120235559827960335' else "❌ FAIL")
print()

# Test Case 5: No Ad ID (should return None)
print("=" * 60)
print("TEST CASE 5: No Ad ID present")
print("=" * 60)
attr5 = {
    'utmSource': 'facebook',
    'utmCampaignId': '120235556205010335'
}
result5 = extract_ad_id_from_attribution(attr5)
print(f"Input: {attr5}")
print(f"Extracted Ad ID: {result5}")
print(f"✅ PASS" if result5 is None else "❌ FAIL")
print()

print("=" * 60)
print("ALL TESTS COMPLETED")
print("=" * 60)

