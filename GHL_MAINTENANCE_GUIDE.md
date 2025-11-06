# GHL System Maintenance Guide

Quick reference for maintaining and troubleshooting the GoHighLevel integration.

---

## 🔍 Diagnostic Commands

### Check Current Pipeline Counts
```bash
export GHL_API_KEY='pit-4cbdedd8-41c4-4528-b9f7-172c4757824c'
python3 scripts/diagnose_ghl_deposits.py
```

### Verify Firebase Data
```bash
python3 scripts/verify_fix.py
```

### Check Cloud Function Logs
```bash
firebase functions:log --only scheduledSync
```

---

## 📋 Pipeline IDs (Critical Reference)

```javascript
ANDRIES_PIPELINE_ID = 'XeAGJWRnUGJ5tuhXam2g'  // Andries Pipeline - DDM
DAVIDE_PIPELINE_ID = 'AUduOJBB2lxlsEaNmlJz'   // Davide's Pipeline - DDM
ERICH_PIPELINE_ID = 'pTbNvnrXqJc9u1oxir3q'    // Erich Pipeline -DDM (DIFFERENT!)
LOCATION_ID = 'QdLXaFEqrdF0JbVbpKLw'           // MedWave Location
```

⚠️ **Important**: Don't confuse "Davide's Pipeline" with "Erich Pipeline"

---

## 🔧 Manual Sync Trigger

If data looks stale, trigger manual sync:

```bash
curl -X POST "https://us-central1-medx-ai.cloudfunctions.net/api/facebook/match-ghl"
```

---

## 📊 Expected Stage Names

These exact stage names are tracked:

1. **Booked Appointments**
2. **Call Completed**
3. **No Show** (or variants like "No Show/Cancelled/Disqualified")
4. **Deposit Received**
5. **Cash Collected**

---

## 🚨 Troubleshooting

### Problem: Counts Don't Match GHL UI

**Solution**:
1. Run diagnostic: `python3 scripts/diagnose_ghl_deposits.py`
2. Check for pagination issues (script handles up to 1500 opps)
3. Verify pipeline IDs are correct
4. Check stage name matching in Cloud Function logs

### Problem: New Stages Not Tracked

**Solution**:
1. Check stage name in GHL UI
2. Update `keyStageNames` in `functions/lib/opportunityHistoryService.js`
3. Redeploy: `cd functions && npm run deploy`

### Problem: Missing Monetary Values

**Solution**:
1. Check Product config: `depositAmount = 1500`
2. Verify Cloud Function uses default value
3. Update opportunities in GHL with actual values

---

## 🔄 Scheduled Jobs

### Every 2 Minutes: `scheduledSync`
- Syncs GHL opportunities to Firebase
- Updates `opportunityStageHistory`
- Matches to Facebook ads
- Updates `adPerformance`

### Every 24 Hours: `scheduledFacebookSync`
- Syncs Facebook ad metrics
- Updates `adPerformance` with ad spend, reach, etc.

---

## 📦 Backfill Process (If Needed)

If historical data is missing:

```bash
# 1. Diagnose
python3 scripts/diagnose_ghl_deposits.py

# 2. Review dry run
# Edit backfill_historical_opportunities.py: DRY_RUN = True
python3 scripts/backfill_historical_opportunities.py

# 3. Execute backfill
# Edit backfill_historical_opportunities.py: DRY_RUN = False
python3 scripts/backfill_historical_opportunities.py

# 4. Trigger sync
curl -X POST "https://us-central1-medx-ai.cloudfunctions.net/api/facebook/match-ghl"

# 5. Verify
python3 scripts/verify_fix.py
```

---

## 🔐 API Keys & Credentials

### GHL API Key
```bash
export GHL_API_KEY='pit-4cbdedd8-41c4-4528-b9f7-172c4757824c'
```

Location: Firebase Functions config
```bash
firebase functions:config:get ghl
```

### Firebase Admin SDK
File: `medx-ai-firebase-adminsdk-fbsvc-a86e7bd050.json`  
Location: Project root (gitignored)

---

## 📈 Monitoring

### Check Sync Health
```python
# Quick Firebase query
import firebase_admin
from firebase_admin import credentials, firestore

cred = credentials.Certificate('medx-ai-firebase-adminsdk-fbsvc-a86e7bd050.json')
if not firebase_admin._apps:
    firebase_admin.initialize_app(cred)

db = firestore.client()

# Get latest sync timestamp
docs = db.collection('adPerformance').limit(1).stream()
for doc in docs:
    ghl_stats = doc.to_dict().get('ghlStats', {})
    print(f"Last sync: {ghl_stats.get('lastSync')}")
```

---

## 🎯 Performance Metrics

### Normal Operation
- Sync time: 30-60 seconds
- Matched opportunities: 150-200
- Errors: 0

### Warning Signs
- Sync time > 2 minutes
- Matched opportunities < 100
- Errors > 0

---

## 📞 Escalation

If automated recovery fails:
1. Check Cloud Function logs
2. Verify GHL API key is valid
3. Check Firebase quotas
4. Review recent code changes
5. Roll back if necessary using git

---

## 🔗 Related Files

- `/functions/lib/opportunityHistoryService.js` - Core sync logic
- `/functions/index.js` - API endpoints
- `/scripts/diagnose_ghl_deposits.py` - Diagnostic tool
- `/scripts/backfill_historical_opportunities.py` - Backfill tool
- `/lib/services/gohighlevel/ghl_service.dart` - Flutter GHL service

---

**Last Updated**: October 28, 2025  
**Maintained By**: Development Team

