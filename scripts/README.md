# GHL Data Diagnostic & Backfill Scripts

This directory contains Python scripts for diagnosing and fixing GHL (GoHighLevel) data discrepancies, specifically for Deposit Received and Cash Collected stages.

## Prerequisites

```bash
# Install required packages
pip install requests firebase-admin google-cloud-firestore

# Set environment variables
export GHL_API_KEY='your_ghl_api_key_here'
export FIREBASE_CRED_PATH='medx-ai-firebase-adminsdk-fbsvc-a86e7bd050.json'
```

## Scripts Overview

### 1. `diagnose_ghl_deposits.py`
**Purpose**: Query GHL API to get current pipeline state and identify opportunities in Deposit/Cash stages.

**What it does**:
- Fetches all opportunities from Andries and Davide pipelines
- Categorizes them by the 5 key stages
- Generates detailed report showing counts and opportunity details
- Saves results to `ghl_diagnostic_report_TIMESTAMP.json`

**Usage**:
```bash
python scripts/diagnose_ghl_deposits.py
```

**Expected Output**:
```
GHL DEPOSITS & CASH COLLECTED DIAGNOSTIC
========================================
✅ Built stage mapping with X stages

ANALYZING: Andries Pipeline - DDM
========================================
📊 Andries Pipeline:
  Total Opportunities: X
  Booked Appointments: X
  Call Completed: X
  No Show/Cancelled: X
  🎯 Deposit Received: 26
  🎯 Cash Collected: 20

ANALYZING: Davide's Pipeline - DDM
========================================
📊 Davide Pipeline:
  Total Opportunities: X
  Booked Appointments: X
  Call Completed: X
  No Show/Cancelled: X
  🎯 Deposit Received: 6
  🎯 Cash Collected: 10
```

### 2. `analyze_firebase_ghl_data.py`
**Purpose**: Analyze Firebase `opportunityStageHistory` collection and compare with GHL API data.

**What it does**:
- Queries Firebase to count opportunities per stage
- Determines latest stage for each unique opportunity
- Compares Firebase counts with GHL API counts
- Identifies missing opportunities (in GHL but not in Firebase)
- Saves results to `firebase_analysis_report_TIMESTAMP.json`

**Usage**:
```bash
python scripts/analyze_firebase_ghl_data.py
```

**Expected Output**:
```
COMPARISON: GHL API vs Firebase
========================================
📊 Andries Pipeline:
  Booked Appointments:  GHL= 50  Firebase= 50  ✅
  Call Completed:       GHL= 40  Firebase= 40  ✅
  No Show/Cancelled:    GHL= 15  Firebase= 15  ✅
  🎯 Deposit Received:  GHL= 26  Firebase=  4  ❌ MISMATCH
  🎯 Cash Collected:    GHL= 20  Firebase=  2  ❌ MISMATCH

MISSING OPPORTUNITIES (in GHL but not in Firebase)
========================================
❌ Andries - Missing Deposits (22):
  • John Smith
    ID: abc123
    Stage: Deposit Received
```

### 3. `backfill_historical_opportunities.py`
**Purpose**: Backfill missing opportunities to Firebase with proper timestamps.

**What it does**:
- Loads missing opportunities from diagnostic reports
- Fetches full details from GHL API
- Writes to Firebase `opportunityStageHistory` collection
- Uses opportunity's last modified date as timestamp
- Marks records with `isBackfilled: true` flag
- Saves list of backfilled IDs for rollback

**Usage**:
```bash
# DRY RUN (preview only - no writes)
python scripts/backfill_historical_opportunities.py

# ACTUAL BACKFILL (modify script: set DRY_RUN = False)
# Edit the script and change line: DRY_RUN = False
python scripts/backfill_historical_opportunities.py
```

**Expected Output**:
```
BACKFILLING 28 OPPORTUNITIES
========================================
[1/28] John Smith
  Pipeline: Andries
  Stage: deposits
  📦 Fetching details for: John Smith
  ✅ Created document: abc123_1698765432000

✅ Successfully backfilled: 28
❌ Errors: 0
```

## Step-by-Step Workflow

### Phase 1: Diagnosis
1. Run the GHL diagnostic script:
   ```bash
   python scripts/diagnose_ghl_deposits.py
   ```
   This creates `ghl_diagnostic_report_TIMESTAMP.json`

2. Run the Firebase analysis script:
   ```bash
   python scripts/analyze_firebase_ghl_data.py
   ```
   This creates `firebase_analysis_report_TIMESTAMP.json` and compares with GHL data

3. Review the comparison report to see:
   - How many opportunities are missing
   - Which specific opportunities need backfilling

### Phase 2: Backfill (DRY RUN)
4. Run backfill script in DRY RUN mode:
   ```bash
   python scripts/backfill_historical_opportunities.py
   ```
   This previews what would be backfilled WITHOUT writing to Firebase

5. Review the dry run output to ensure it looks correct

### Phase 3: Actual Backfill
6. Edit `backfill_historical_opportunities.py`:
   ```python
   # Change this line
   DRY_RUN = False  # Set to False for actual backfill
   ```

7. Run the actual backfill:
   ```bash
   python scripts/backfill_historical_opportunities.py
   ```
   This writes the missing opportunities to Firebase

8. Keep the generated `backfilled_opps_TIMESTAMP.json` file for rollback

### Phase 4: Verification
9. Run the Firebase analysis again to verify:
   ```bash
   python scripts/analyze_firebase_ghl_data.py
   ```
   Counts should now match!

10. Trigger manual sync in the app:
    - Navigate to Advertisement Performance screen
    - Click "Manual Sync" button
    - Wait for sync to complete (~5-6 minutes)

11. Verify the dashboard shows correct counts

## Important Notes

### Stage Name Matching
The scripts use exact stage name matching with fallbacks:
- **Booked Appointments**: Exact match or contains "booked"/"appointment"
- **Call Completed**: Exact match or contains "call completed"
- **No Show**: Exact match or contains "no show"/"cancelled"/"disqualified"
- **Deposit Received**: Exact match or contains "deposit"
- **Cash Collected**: Exact match or contains "cash collected"/"sold"/"purchased"

### Monetary Values
- Uses opportunity's `monetaryValue` if available
- Falls back to Product's `depositAmount` (default R1500)
- Calculation happens during matching phase

### Backfill Safety
- **Dry Run Mode**: Always test first with `DRY_RUN = True`
- **Timestamps**: Uses opportunity's `lastStatusChangeAt` or `dateAdded`
- **Rollback**: Keep `backfilled_opps_TIMESTAMP.json` to identify backfilled records
- **Rate Limiting**: Script includes 0.5s delay between API calls

## Troubleshooting

### Error: "GHL_API_KEY not set"
```bash
export GHL_API_KEY='your_key_here'
```

### Error: "No GHL diagnostic report found"
Run `diagnose_ghl_deposits.py` first to generate the report.

### Error: "Firebase credentials not found"
```bash
export FIREBASE_CRED_PATH='path/to/credentials.json'
# Or copy credentials file to project root
```

### Counts still don't match after backfill
1. Check if new opportunities were added to GHL after diagnosis
2. Re-run diagnosis scripts to get latest data
3. Verify stage name matching is working correctly

## Files Generated

- `ghl_diagnostic_report_TIMESTAMP.json` - GHL API data snapshot
- `firebase_analysis_report_TIMESTAMP.json` - Firebase data snapshot
- `backfilled_opps_TIMESTAMP.json` - List of backfilled opportunity IDs

Keep these files for audit trail and potential rollback.

## Support

If you encounter issues:
1. Check the script output for error messages
2. Verify GHL API key has proper permissions
3. Ensure Firebase credentials are correct
4. Review the generated JSON reports for data integrity

