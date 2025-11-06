# GHL Custom Fields Investigation Results

**Date:** November 4, 2025  
**Issue:** Cash collected values not appearing in dashboard

---

## 🔍 Investigation Summary

### Problem Identified
Cash amounts (R 300,000 for Jenny Alves, etc.) are stored in **custom fields** in GHL but are **NOT accessible via the standard GHL API**.

### What We Found

1. **Custom Fields Location**: Cash values are stored as custom fields on opportunities/contacts
   - Field names: "Cash Collected", "Contract Value"
   - Example: Jenny Alves has R 300,000 in "Cash Collected" field

2. **API Limitation**: 
   - ❌ `/opportunities/search` endpoint does NOT return custom fields
   - ❌ `/opportunities/{id}` endpoint does NOT return custom fields  
   - ❌ `/contacts/{id}` endpoint returns empty `customField` object

3. **Current Sync Behavior**:
   - Firebase sync (`fullGHLSync.py`) only tracks **pipeline stages**
   - It counts opportunities IN "Cash Collected" stage
   - It does NOT read the actual cash amount from custom fields
   - Result: Dashboard shows `deposits: 1` but `cashAmount: 0`

---

## 💡 Solutions

### Option 1: Use `monetaryValue` Field (RECOMMENDED)

**What to do:**
1. In GHL, when moving opportunities to "Deposit Received" or "Cash Collected" stages
2. **Populate the `monetaryValue` field** with the actual cash amount
3. The sync script already reads `monetaryValue` and stores it in Firebase
4. Dashboard will automatically show the correct amounts

**Advantages:**
- ✅ Works with current API
- ✅ No code changes needed
- ✅ Standard GHL field
- ✅ Already supported by sync script

**Implementation:**
```javascript
// In GHL workflow or manually:
// When opportunity moves to "Cash Collected" stage
// Set opportunity.monetaryValue = cashAmount
```

### Option 2: Custom Fields via Advanced API

**Requirements:**
- Need GHL OAuth app with proper permissions
- Use `/custom-fields` or `/custom-values` endpoints (if available)
- Requires GHL Enterprise/Agency plan features

**Status:** ⚠️  Needs further investigation with GHL support

### Option 3: Manual Data Entry

**Workaround:**
- Export opportunities from GHL with custom fields (CSV)
- Import cash values into Firebase manually
- Not sustainable long-term

---

## 🎯 Recommended Action Plan

### Immediate Fix (Option 1)

1. **Update GHL Workflow**:
   - When opportunity reaches "Deposit Received" → Set `Opportunity Value` = deposit amount
   - When opportunity reaches "Cash Collected" → Set `Opportunity Value` = cash amount

2. **Run Sync**:
   ```bash
   cd /Users/mac/dev/medwave/functions
   python3 fullGHLSync.py --dry-run
   ```

3. **Verify in Dashboard**:
   - Check that cash amounts now appear
   - Verify totals are correct

### Long-term Solution

1. **Standardize Data Entry**:
   - Train team to use `Opportunity Value` field
   - Or create GHL automation to copy custom field → monetaryValue

2. **Enhanced Sync Script**:
   - Created: `fullGHLSync_with_custom_fields.py`
   - Ready to use if GHL API access improves
   - Includes threading for faster sync
   - Extracts custom fields when available

---

## 📊 Current Status

### What Works
- ✅ GHL API connection  
- ✅ Fetching opportunities
- ✅ Pipeline stage tracking
- ✅ Firebase sync
- ✅ Dashboard display

### What Doesn't Work
- ❌ Reading custom field values via API
- ❌ Automatic cash amount extraction
- ❌ Syncing historical custom field data

### Files Created
1. `investigate_cash_received.py` - Investigation script
2. `fullGHLSync_with_custom_fields.py` - Enhanced sync (ready for future use)
3. This document - Investigation results

---

## 🔧 Technical Details

### API Endpoints Tested

```python
# Tested and working
GET /opportunities/search ✅
GET /opportunities/{id} ✅  
GET /opportunities/pipelines ✅
GET /contacts/{id} ✅

# Custom fields status
customFields in opportunity response: ❌ Empty/null
customFields in contact response: ❌ Empty object
customField in contact response: ❌ Empty object
```

### GHL Token Used
```
pit-e305020a-9a42-4290-a052-daf828c3978e
```

### Test Results
- Jenny Alves (ID: KtV0fNx4tZXcYVtYBZe7)
  - Has R 300,000 in GHL UI custom field
  - API returns: `monetaryValue: 0`
  - API returns: `customFields: []` or `{}`
  - Contact API: `customField: {}`

---

## 📞 Next Steps

1. **Contact GHL Support**: Ask about custom field API access
2. **Check GHL Plan**: Verify if custom fields API requires specific plan
3. **Implement Option 1**: Use monetaryValue field as workaround
4. **Update Workflows**: Automate copying custom field → monetaryValue

---

## Questions for GHL Support

1. How do we access custom field values via API?
2. Does the API token need specific permissions for custom fields?
3. Is there a different endpoint for reading custom field values?
4. Are custom fields only available in specific GHL plans?
5. Can we use webhooks to get custom field updates?

