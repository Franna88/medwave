# Cumulative Metrics Setup Guide

## ✅ Completed Steps

1. ✅ Created `opportunityStageHistory` Firestore collection schema
2. ✅ Added Firestore security rules for the collection
3. ✅ Created composite indexes for efficient queries
4. ✅ Deployed webhook endpoint to Firebase Functions
5. ✅ Deployed cumulative analytics calculation endpoint
6. ✅ Created `opportunityHistoryService.js` module

## 🚀 Next Steps to Complete Setup

### 1. Configure GoHighLevel Webhook

**Webhook URL:**
```
https://us-central1-medx-ai.cloudfunctions.net/api/ghl/webhooks/opportunity-stage-update
```

**Steps to configure:**

1. Go to GoHighLevel Settings → Integrations → Webhooks
2. Click **Add Webhook**
3. Configure:
   - **Event Type**: `OpportunityStageUpdate`
   - **URL**: `https://us-central1-medx-ai.cloudfunctions.net/api/ghl/webhooks/opportunity-stage-update`
   - **Method**: `POST`
4. Save the webhook

### 2. Test the Webhook

**Manual test:**

1. Go to any opportunity in GoHighLevel
2. Move it to a different stage
3. Check Firebase Console → Firestore → `opportunityStageHistory`
4. Verify a new document was created

**Alternative - Use curl:**

```bash
curl -X GET \
  'https://us-central1-medx-ai.cloudfunctions.net/api/ghl/analytics/pipeline-performance?startDate=2024-01-01&endDate=2025-12-31'
```

### 3. API Endpoints Available

#### Cumulative Pipeline Performance (NEW)
```
GET https://us-central1-medx-ai.cloudfunctions.net/api/ghl/analytics/pipeline-performance

Query Parameters:
- startDate: ISO date string (default: 30 days ago)
- endDate: ISO date string (default: now)
- altusPipelineId: string (default: AUduOJBB2lxlsEaNmlJz)
- andriesPipelineId: string (default: XeAGJWRnUGJ5tuhXam2g)

Returns:
{
  overview: {
    totalOpportunities: number,
    bookedAppointments: number,
    callCompleted: number,
    noShowCancelledDisqualified: number,
    deposits: number,
    cashCollected: number,
    totalMonetaryValue: number
  },
  byPipeline: {
    altus: { ... },
    andries: { ... }
  },
  campaignsList: [ ... ],
  salesAgentsList: [ ... ],
  dateRange: { startDate, endDate }
}
```

#### Snapshot Pipeline Performance (DEPRECATED)
```
GET https://us-central1-medx-ai.cloudfunctions.net/api/ghl/analytics/pipeline-performance-snapshot
```
*This endpoint shows current stage counts (old behavior)*

## 📊 How It Works

### Cumulative Tracking

**Before (Snapshot):**
- Booked: 4 (opportunities currently IN Booked stage)
- Call: 2 (opportunities currently IN Call stage)
- Moving from Booked → Call reduces Booked to 3

**After (Cumulative):**
- Booked: 8 (total opportunities that ever reached Booked)
- Call: 5 (total opportunities that ever reached Call)
- Moving from Booked → Call keeps Booked at 8, increases Call to 6

### Date Filtering

The cumulative totals are calculated within a date range:
- Last 30 days (default)
- Last 90 days
- Custom date range
- All time

Only opportunities that moved to a stage within the date range are counted.

## 🔧 Troubleshooting

### Webhook Not Firing

1. Check GoHighLevel webhook configuration
2. Verify URL is correct
3. Check Firebase Functions logs:
   ```bash
   cd /Users/mac/dev/medwave
   firebase functions:log
   ```

### No Data Showing

If you just deployed:
- Data will accumulate as opportunities move through stages
- Historical data is not available (no backfill completed)
- To see immediate results, manually move some opportunities in GoHighLevel

### Firestore Indexes

If you see index-related errors:
```bash
cd /Users/mac/dev/medwave
firebase deploy --only firestore:indexes
```

## 📝 Frontend Integration

To use the cumulative metrics in your Flutter app:

1. **Update GoHighLevel Provider** (`lib/providers/gohighlevel_provider.dart`):
   - Add date range parameters to API calls
   - Switch from `pipeline-performance-snapshot` to `pipeline-performance`

2. **Update Admin Screen** (`lib/screens/admin/admin_advert_performance_screen.dart`):
   - Connect date filter dropdown to API calls (lines 1398-1409)
   - Update UI labels if needed

## 🔄 Backfill Historical Data (Optional)

If you need historical data, the backfill script needs Firebase credentials:

```bash
cd /Users/mac/dev/medwave/functions
# Make sure you have the correct service account JSON file
# Then run:
node backfillOpportunityHistory.js
```

**Note:** The backfill is optional. The system works perfectly without it - data accumulates naturally as opportunities change stages.

## 📚 Data Structure

Each document in `opportunityStageHistory`:

```javascript
{
  opportunityId: "abc123",
  opportunityName: "John Doe",
  pipelineId: "AUduOJBB2lxlsEaNmlJz",
  pipelineName: "Altus Pipeline - DDM",
  newStageId: "stage_123",
  newStageName: "Booked - Appointment Scheduled",
  stageCategory: "bookedAppointments", // Standardized category
  campaignName: "Facebook - December",
  campaignSource: "facebook",
  adId: "ad_12345",
  assignedTo: "user_456",
  assignedToName: "Jane Smith",
  monetaryValue: 5000,
  timestamp: Timestamp,
  year: 2025,
  month: 10,
  week: 42,
  isBackfilled: false
}
```

## 🎯 Stage Categories

The system maps raw stage names to standardized categories:

- `bookedAppointments`: "Booked", "Appointment", "Scheduled"
- `callCompleted`: "Call", "Completed", "Consulted"
- `noShowCancelledDisqualified`: "No Show", "Cancelled", "Disqualified"
- `deposits`: "Deposit", "Paid Deposit"
- `cashCollected`: "Cash", "Collected", "Payment"

See `functions/lib/opportunityHistoryService.js` for the full mapping.

## 🚀 Quick Start

**Minimal steps to get started:**

1. Configure webhook in GoHighLevel (Step 1 above)
2. Move an opportunity to test
3. Check Firestore for new documents
4. Call the API endpoint to see cumulative data

That's it! The system will build historical data naturally from this point forward.
