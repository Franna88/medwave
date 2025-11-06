# GHL Data Accuracy Fix - Quick Reference Card

**Quick Start**: `cat GHL_FIX_DEPLOYMENT_CHECKLIST.md`

---

## 🚀 Quick Execution (45 minutes)

```bash
# Setup (2 min)
export GHL_API_KEY='your_key_here'
cd /Users/mac/dev/medwave

# Diagnose (5 min)
python scripts/diagnose_ghl_deposits.py
python scripts/analyze_firebase_ghl_data.py

# Backfill Test (5 min)
python scripts/backfill_historical_opportunities.py  # Dry run

# Backfill Execute (10 min)
# Edit script: DRY_RUN = False
python scripts/backfill_historical_opportunities.py

# Verify (2 min)
python scripts/verify_fix.py

# Deploy (5 min)
firebase deploy --only functions

# Test in App (15 min)
# 1. Open: http://localhost:64922/#/admin/adverts
# 2. Click "Manual Sync"
# 3. Wait ~6 minutes
# 4. Verify counts: ~32 deposits, ~30 cash
```

---

## 📊 Expected Counts

| Pipeline | Deposits | Cash Collected |
|----------|----------|----------------|
| Andries  | 26       | 20             |
| Davide   | 6        | 10             |
| **Total** | **32**   | **30**         |

---

## 📁 Key Files

### Scripts
- `scripts/diagnose_ghl_deposits.py` - Query GHL API
- `scripts/analyze_firebase_ghl_data.py` - Analyze Firebase
- `scripts/backfill_historical_opportunities.py` - Backfill data
- `scripts/verify_fix.py` - Verify counts

### Documentation
- `scripts/README.md` - How to use scripts
- `GHL_DATA_ACCURACY_FIX_SUMMARY.md` - Technical details
- `GHL_FIX_DEPLOYMENT_CHECKLIST.md` - **Step-by-step guide** ⭐
- `IMPLEMENTATION_COMPLETE.md` - Implementation status

### Modified Code
- `functions/lib/opportunityHistoryService.js` - Stage matching & cash calculation

---

## ✅ Verification Checklist

After deployment, verify:

- [ ] `python scripts/verify_fix.py` shows all ✅ PASS
- [ ] Dashboard displays ~32 deposits total
- [ ] Dashboard displays ~30 cash collected total
- [ ] "Deposits" filter shows correct campaigns
- [ ] "Cash" filter shows correct campaigns
- [ ] Individual campaign cards show correct counts
- [ ] Cloud Functions logs show no errors

---

## 🔧 Troubleshooting

| Issue | Solution |
|-------|----------|
| Script fails | Check GHL_API_KEY and Firebase credentials |
| Counts don't match | Re-run diagnostics, check for new GHL data |
| Deploy fails | Check `functions/package.json` dependencies |
| App doesn't update | Hard refresh (Cmd+Shift+R), check sync logs |

---

## 🛟 Emergency Rollback

```bash
# Rollback Cloud Functions
git checkout HEAD~1 -- functions/lib/opportunityHistoryService.js
firebase deploy --only functions

# Rollback Backfilled Data (create script as needed)
# Use saved backfilled_opps_TIMESTAMP.json file
```

---

## 📞 Support

1. Read: `GHL_FIX_DEPLOYMENT_CHECKLIST.md` (detailed guide)
2. Check: Firebase Function logs
3. Review: Script output and JSON reports
4. Verify: GHL API access and Firebase credentials

---

## 🎯 Success Criteria

✅ All 4 scripts run successfully  
✅ Verification script passes  
✅ Cloud Functions deploy  
✅ Manual sync completes  
✅ Dashboard shows correct counts (~32 & ~30)  

---

**Status**: ✅ Ready for Deployment  
**Last Updated**: October 28, 2025

