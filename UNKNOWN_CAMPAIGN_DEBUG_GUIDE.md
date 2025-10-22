# Unknown Campaign Debug Guide

## Purpose
This guide explains how to identify and debug the "Unknown Campaign" leads that appear in your ad performance dashboard.

## What Was Added
Detailed logging has been added to both the GHL proxy server and Firebase Functions to help identify leads that don't have proper UTM campaign tracking.

## Where Logging Was Added
1. **ghl-proxy/server.js** - Lines 479-494 (Pipeline Performance endpoint)
2. **ghl-proxy/server.js** - Lines 777-799 (Campaign Performance endpoint)
3. **functions/index.js** - Lines 292-307 (Firebase Functions)

## How to Use

### Step 1: Restart Your GHL Proxy Server
```bash
cd /Users/mac/dev/medwave
./stop-ghl-proxy.sh
./start-ghl-proxy.sh
```

### Step 2: View the Logs
```bash
# View real-time logs
tail -f ghl-proxy/ghl-proxy.log

# Or search for unknown campaign entries
grep "UNKNOWN CAMPAIGN" ghl-proxy/ghl-proxy.log
```

### Step 3: Access Your Dashboard
Open your admin panel and navigate to the "Advertisement Performance" section. When the page loads, it will fetch data from GoHighLevel and log details about any "Unknown Campaign" leads.

### Step 4: Analyze the Output
For each "Unknown Campaign" lead, you'll see:
- **Opportunity ID** - The GHL opportunity ID
- **Opportunity Name** - The name of the opportunity
- **Contact Name** - Who the lead is
- **Contact Email** - Their email address
- **Contact Phone** - Their phone number
- **Pipeline Stage** - Current stage in the pipeline
- **Source** - Where the lead came from (if available)
- **Lead Source** - Additional source information
- **Created Date** - When the opportunity was created
- **Attribution Data** - Full attribution details (if any)
- **Tags** - Any tags applied to the opportunity
- **Custom Fields** - Any custom field data

## What to Look For

### Common Patterns for "Unknown Campaign" Leads:

1. **Manual Entry Leads**
   - Source: "manual" or empty
   - No attribution data
   - These are leads entered directly by staff

2. **Website Form Submissions**
   - Source: "website" or form name
   - Missing UTM parameters
   - Forms need proper tracking setup

3. **Phone Calls**
   - Source: "phone" or "call"
   - Direct calls don't have digital attribution

4. **Imported Leads**
   - May have import-related source
   - Lost original tracking during import

5. **Old Leads**
   - Created before tracking was implemented
   - No attribution data available

## Next Steps After Identifying Leads

Once you identify the pattern, you can:

1. **Categorize Manually** - If these are legitimate non-ad leads (manual entry, phone calls), you might want to create a separate category for them

2. **Fix Tracking** - If they should have UTM data, fix your tracking setup:
   - Add UTM parameters to your ad links
   - Configure form tracking
   - Set up proper attribution

3. **Update GoHighLevel** - Add tags or custom fields to help categorize these leads in the future

4. **Filter in Dashboard** - Modify the code to filter out or separately categorize known non-ad sources

## Removing the Logging

Once you've identified the issue, you can remove the logging to reduce log clutter:

1. Open `ghl-proxy/server.js` and `functions/index.js`
2. Search for "🔍 LOG UNKNOWN CAMPAIGNS"
3. Delete the logging blocks (but keep the campaign name assignment)

## Example Log Output

```
🔍 UNKNOWN CAMPAIGN LEAD DETECTED:
  - Opportunity ID: abc123xyz
  - Opportunity Name: John Doe - Medical Consultation
  - Contact Name: John Doe
  - Contact Email: john@example.com
  - Contact Phone: +1234567890
  - Pipeline Stage: New Lead
  - Source: phone
  - Lead Source: Direct Call
  - Created Date: 2025-10-15T10:30:00Z
  - Has Attributions?: No
  - Attribution Data: NONE
  - Tags: urgent, new-patient
  - Custom Fields: {"referral_source": "Friend"}
  ---
```

## Support
If you need help interpreting the logs or making changes, consult this guide or review the code comments in the modified files.

