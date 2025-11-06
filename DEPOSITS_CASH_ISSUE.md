# 💰 Deposits & Cash Issue - Root Cause Found

## 🔍 Problem Summary

**You're not seeing Deposits or Cash in the app because the GHL API is returning `monetaryValue: 0` for ALL opportunities.**

---

## ✅ What's Working

1. ✅ **CORS Error Fixed** - GHL API connection successful
2. ✅ **415 Opportunities synced** from GHL to Firebase
3. ✅ **173 Ads matched** with GHL data
4. ✅ **Stage categories correct** (deposits, cashCollected identified)
5. ✅ **Leads and Bookings** showing correctly

---

## ❌ What's NOT Working

**Firebase Data:**
```
Deposits: 0 (should be > 0)
Cash: $0.00 (should be > 0)
```

**Reason:** All opportunities in `opportunityStageHistory` have `monetaryValue: 0`

---

## 🎯 Root Cause

### The GHL API Response

When we fetch opportunities from GHL, the response looks like this:

```javascript
{
  opportunityId: "BTndijYGyQwNmV5MUUpx",
  opportunityName: "Inni Ismail",
  pipelineStageName: "Booked Appointments",
  monetaryValue: 0,  // ❌ THIS IS ALWAYS 0!
  ...
}
```

### Why is `monetaryValue` Always 0?

**Possible reasons:**

1. **Field Name Mismatch**
   - GHL might use a different field name: `value`, `amount`, `price`, `monetary_value`
   - Need to check actual GHL API docs

2. **Not Included by Default**
   - GHL API might require specific query parameters to include monetary values
   - Example: `includeMonetaryValue=true` or similar

3. **Different Endpoint Needed**
   - Monetary values might be in a separate API endpoint
   - Might need to call `/opportunities/{id}/value` or similar

4. **GHL Data Not Set**
   - Your team might not be setting values in GHL CRM
   - Need to check GHL interface to confirm values exist

---

## 🔧 How to Fix

### Step 1: Check GHL API Documentation

Look for:
- Field names for opportunity value/amount
- Query parameters needed to include monetary data
- Whether a separate API call is needed

### Step 2: Test Direct API Call

Run this to see the raw GHL API response:

```bash
curl -X GET "https://services.leadconnectorhq.com/opportunities/search?location_id=QdLXaFEqrdF0JbVbpKLw&limit=5" \
  -H "Authorization: Bearer pit-4cbdedd8-41c4-4528-b9f7-172c4757824c" \
  -H "Version: 2021-07-28"
```

Look for any field that contains the monetary value.

### Step 3: Update Cloud Function

Once you find the correct field name, update `functions/index.js` line 879:

```javascript
// BEFORE:
monetaryValue: opportunity.monetaryValue || 0,

// AFTER (example if field is 'value'):
monetaryValue: opportunity.value || opportunity.monetaryValue || 0,
```

### Step 4: Re-sync Data

After fixing the field name:

```bash
# Re-sync opportunities
curl -X POST https://us-central1-medx-ai.cloudfunctions.net/api/ghl/sync-opportunity-history

# Re-match to Facebook ads
curl -X POST https://us-central1-medx-ai.cloudfunctions.net/api/facebook/match-ghl
```

---

## 📋 Immediate Action Items

1. **Check GHL CRM Interface**
   - Log in to your GHL account
   - Open an opportunity that should have a deposit
   - Verify that monetary values are actually set
   - Note the field name/label used

2. **Check GHL API Docs**
   - https://highlevel.stoplight.io/docs/integrations/
   - Search for "monetary" or "value" or "amount"
   - Check the Opportunities endpoint documentation

3. **Test API Response**
   - Use the curl command above
   - Paste the raw JSON response
   - I can help identify the correct field name

---

## 🎯 Expected Outcome

After finding and using the correct field name:

```
✅ Deposits: 5
✅ Cash: $12,500.00
```

These will then show in your app's ad performance cards.

---

**Next Step:** Please check your GHL CRM to confirm that monetary values are actually set on opportunities, then we can investigate the API field name.

