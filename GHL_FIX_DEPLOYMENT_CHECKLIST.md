# GHL Data Accuracy Fix - Deployment Checklist

**Status**: Ready for Deployment  
**Date**: October 28, 2025  
**Estimated Time**: 30-45 minutes

---

## Pre-Deployment

### 1. Environment Setup
- [ ] GHL API key exported: `export GHL_API_KEY='your_key'`
- [ ] Firebase credentials available: `medx-ai-firebase-adminsdk-fbsvc-a86e7bd050.json`
- [ ] Python packages installed: `pip install requests firebase-admin google-cloud-firestore`
- [ ] Node.js packages installed: `cd functions && npm install`

### 2. Backup Firebase Data
- [ ] Export `opportunityStageHistory` collection (optional but recommended)
  ```bash
  # Via Firebase Console: Firestore > Export Data
  # Or via CLI (if configured)
  ```

### 3. Review Changes
- [ ] Review `functions/lib/opportunityHistoryService.js` changes
- [ ] Review new scripts in `scripts/` directory
- [ ] Review `GHL_DATA_ACCURACY_FIX_SUMMARY.md`

---

## Phase 1: Diagnosis (Est. 5 minutes)

### Step 1: Run GHL Diagnostic
```bash
cd /Users/mac/dev/medwave
export GHL_API_KEY='your_ghl_api_key_here'
python scripts/diagnose_ghl_deposits.py
```

**Expected Output**:
- ✅ Report generated: `ghl_diagnostic_report_TIMESTAMP.json`
- ✅ Andries deposits: ~26
- ✅ Andries cash: ~20
- ✅ Davide deposits: ~6
- ✅ Davide cash: ~10

**Verification**:
- [ ] Report file created
- [ ] Counts match expectations (approximately)
- [ ] No errors in output

### Step 2: Analyze Firebase Data
```bash
python scripts/analyze_firebase_ghl_data.py
```

**Expected Output**:
- ✅ Report generated: `firebase_analysis_report_TIMESTAMP.json`
- ✅ Comparison shows discrepancies
- ✅ Missing opportunities listed

**Verification**:
- [ ] Report file created
- [ ] Comparison shows missing deposits/cash
- [ ] Specific opportunity IDs listed

---

## Phase 2: Backfill Testing (Est. 5 minutes)

### Step 3: Dry Run Backfill
```bash
# Verify DRY_RUN = True in script (line ~25)
python scripts/backfill_historical_opportunities.py
```

**Expected Output**:
- ✅ Preview of ~30-60 backfill operations
- ✅ No actual writes to Firebase
- ✅ Timestamp and stage information displayed

**Verification**:
- [ ] Dry run completed without errors
- [ ] Number of opportunities seems reasonable
- [ ] Stage categorization looks correct
- [ ] No "Created document" messages (only "Would create")

---

## Phase 3: Actual Backfill (Est. 10 minutes)

### Step 4: Execute Backfill
```bash
# Edit script: Change DRY_RUN = False (line ~25)
vim scripts/backfill_historical_opportunities.py
# or
nano scripts/backfill_historical_opportunities.py

# Run actual backfill
python scripts/backfill_historical_opportunities.py
```

**Expected Output**:
- ✅ Backfilled: ~30-60 opportunities
- ✅ Errors: 0
- ✅ File created: `backfilled_opps_TIMESTAMP.json`

**Verification**:
- [ ] Success count matches expected
- [ ] Zero errors
- [ ] Rollback file created and saved securely

### Step 5: Verify Backfill
```bash
python scripts/verify_fix.py
```

**Expected Output**:
```
✅ VERIFICATION PASSED - All counts match expected values!

📊 Andries Pipeline:
  ✅ Deposits: 26/26 - PASS
  ✅ Cash Collected: 20/20 - PASS

📊 Davide Pipeline:
  ✅ Deposits: 6/6 - PASS
  ✅ Cash Collected: 10/10 - PASS
```

**Verification**:
- [ ] All counts match (✅ PASS)
- [ ] Backfilled records counted correctly
- [ ] Product configuration checked

**If verification fails**:
- Review error messages
- Check if additional opportunities need backfilling
- Re-run diagnostic scripts for latest data

---

## Phase 4: Deploy Cloud Functions (Est. 5 minutes)

### Step 6: Test Locally (Optional)
```bash
cd functions
npm test  # If tests exist
```

### Step 7: Deploy to Firebase
```bash
# From project root
firebase deploy --only functions
```

**Expected Output**:
```
✔  functions: Finished running predeploy script.
✔  functions[api(us-central1)] Successful update operation.
✔  functions[scheduledSync(us-central1)] Successful update operation.
✔  functions[scheduledFacebookSync(us-central1)] Successful update operation.

✔  Deploy complete!
```

**Verification**:
- [ ] Deployment successful
- [ ] No errors in deployment log
- [ ] All functions deployed

**Check Function Logs**:
```bash
# View function logs
firebase functions:log --limit 50
```

---

## Phase 5: App Testing (Est. 10-15 minutes)

### Step 8: Trigger Manual Sync
1. [ ] Navigate to `localhost:64922/#/admin/adverts`
2. [ ] Click "Manual Sync" button (top-right corner)
3. [ ] Wait for sync to complete (~5-6 minutes)
4. [ ] Watch for success message

**Expected Behavior**:
- Button changes to "Syncing..."
- Progress visible in browser console (F12)
- "Last updated: Just now" appears after completion

### Step 9: Verify Dashboard Display

#### Check "Ad Campaign Performance by Stage" Table
- [ ] Table displays campaigns
- [ ] "Sort by" dropdown includes all filter options
- [ ] Each filter shows correct counts when selected:
  - [ ] **Recent**: Shows all campaigns
  - [ ] **Total**: Shows all opportunities count
  - [ ] **Booked**: Shows campaigns with bookings
  - [ ] **Call**: Shows campaigns with call completed
  - [ ] **No Show**: Shows campaigns with no shows
  - [ ] **Deposits**: Shows ~8-12 campaigns (Andries + Davide)
  - [ ] **Cash**: Shows ~8-12 campaigns (Andries + Davide)

#### Check Individual Campaign Cards
Select a campaign with known deposits/cash (e.g., "Matthy's - ABLEADFORMZA - Afrikaans"):

- [ ] **Leads** count is > 0
- [ ] **Bookings** count is displayed
- [ ] **Deposits** count is displayed (should be > 0 for relevant campaigns)
- [ ] **Cash** amount is displayed (should be > R0 for relevant campaigns)

#### Verify "Deposits" Filter
1. [ ] Click "Deposits" filter button
2. [ ] Verify ~32 total deposits shown across campaigns
3. [ ] Check individual campaigns show correct deposit counts

#### Verify "Cash" Filter
1. [ ] Click "Cash" filter button
2. [ ] Verify ~30 total cash collected shown across campaigns
3. [ ] Check individual campaigns show correct cash amounts

### Step 10: Cross-Check with GHL Pipelines

Open GHL dashboard side-by-side:
- [ ] Andries Pipeline: Deposit stage has ~26 opportunities
- [ ] Andries Pipeline: Cash Collected stage has ~20 opportunities
- [ ] Davide Pipeline: Deposit stage has ~6 opportunities
- [ ] Davide Pipeline: Cash Collected stage has ~10 opportunities

Compare with app dashboard - counts should match!

---

## Phase 6: Monitoring (Est. 5 minutes)

### Step 11: Check Cloud Function Logs
```bash
firebase functions:log --only scheduledSync --limit 20
```

**Look for**:
- [ ] Scheduled sync running every 2 minutes
- [ ] No errors in sync operations
- [ ] Opportunities being synced successfully

### Step 12: Check Firebase Console

Navigate to Firebase Console > Firestore:

1. [ ] Check `opportunityStageHistory` collection
   - Should have increased document count
   - Look for documents with `isBackfilled: true`

2. [ ] Check `adPerformance` collection
   - Documents should have `ghlStats` field
   - `ghlStats.deposits` and `ghlStats.cashAmount` should be > 0 for matched ads

---

## Post-Deployment

### Documentation
- [ ] Save rollback file: `backfilled_opps_TIMESTAMP.json`
- [ ] Save diagnostic reports for audit trail
- [ ] Update team on changes deployed

### Verification Summary
```
Total Backfilled: _____ opportunities
Andries Deposits: _____ / 26
Andries Cash: _____ / 20
Davide Deposits: _____ / 6
Davide Cash: _____ / 10

Dashboard Status: ✅ / ❌
Filters Working: ✅ / ❌
Counts Accurate: ✅ / ❌
```

---

## Rollback Procedure (If Needed)

If critical issues arise:

### Option 1: Rollback Backfilled Data
```bash
# See rollback section in GHL_DATA_ACCURACY_FIX_SUMMARY.md
python scripts/rollback_backfill.py  # (create if needed)
```

### Option 2: Rollback Cloud Functions
```bash
git checkout HEAD~1 -- functions/lib/opportunityHistoryService.js
firebase deploy --only functions
```

### Option 3: Restore from Backup
```bash
# Restore opportunityStageHistory from backup
# Via Firebase Console: Firestore > Import Data
```

---

## Success Criteria

All items below should be ✅:

- [ ] Diagnostic scripts run without errors
- [ ] Backfill completed successfully
- [ ] Verification script passes
- [ ] Cloud Functions deployed
- [ ] Manual sync completes in app
- [ ] Dashboard displays correct counts (~32 deposits, ~30 cash)
- [ ] Filters work correctly
- [ ] Individual campaign cards show accurate data
- [ ] Cloud Functions continue to sync automatically
- [ ] No errors in function logs

---

## Troubleshooting

### Issue: Backfill script fails
**Solution**: Check GHL API key, Firebase credentials, network connectivity

### Issue: Verification fails
**Solution**: Re-run diagnostic scripts, check for new opportunities in GHL

### Issue: Dashboard doesn't update
**Solution**: Hard refresh browser (Cmd+Shift+R), check network tab for API errors

### Issue: Counts still don't match
**Solution**: Check Cloud Function logs, verify stage matching logic, re-run sync

---

## Contact & Support

**Implementation Date**: October 28, 2025  
**Implemented By**: AI Assistant  
**Documentation**: `GHL_DATA_ACCURACY_FIX_SUMMARY.md`, `scripts/README.md`  
**Scripts Location**: `/scripts/`

---

**Deployment Status**: ⬜ Not Started / 🔄 In Progress / ✅ Complete

