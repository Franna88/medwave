# 🚨 CRITICAL BUG: Monthly Revenue Aggregation

**Status:** Identified but NOT Fixed  
**Priority:** HIGH  
**Date Identified:** November 12, 2025

---

## ⚡ Quick Summary

The monthly revenue totals in Firebase are **incorrect** because the aggregation script uses lifetime GHL totals instead of filtering opportunities by creation date.

**Result:** Monthly profit reports are unreliable for business decisions.

---

## 📖 Documentation

### For Implementation:
1. **Start here:** [`FINANCIAL_FIX_CHECKLIST.md`](./FINANCIAL_FIX_CHECKLIST.md)
   - Quick action steps
   - ~2-3 hours to implement
   
2. **For details:** [`FINANCIAL_CALCULATIONS_GUIDE.md`](./FINANCIAL_CALCULATIONS_GUIDE.md)
   - Complete technical explanation
   - Architecture diagrams
   - Full code examples

---

## 🔍 The Issue

```python
# Current code in populate_monthly_totals.py (WRONG):
ghl_stats = ad.get('ghlStats', {})  # ❌ Lifetime totals
monthly_data[month]['cashAmount'] += ghl_stats.get('cashAmount', 0)

# Should be (CORRECT):
opportunities = query('ghlOpportunities', adId=ad_id)
for opp in opportunities:
    if opp.createdAt.month == target_month:  # ✅ Filter by creation date
        monthly_data[month]['cashAmount'] += opp.monetaryValue
```

---

## ✅ Files to Modify

1. **Backend:** `populate_monthly_totals.py` (lines 77-84, 191-197)
2. **Frontend:** `lib/providers/performance_cost_provider.dart` (line ~1173)

---

## 🎯 Impact When Fixed

- ✅ Accurate monthly revenue reports
- ✅ Reliable profit calculations
- ✅ Fast UI performance (uses pre-aggregated data)
- ✅ Trustworthy business metrics for decision-making

---

## 🚀 Next Steps

1. Read [`FINANCIAL_FIX_CHECKLIST.md`](./FINANCIAL_FIX_CHECKLIST.md)
2. Backup Firebase data
3. Apply the three fixes
4. Run aggregation scripts
5. Verify and test

---

**Don't make changes without reading the full documentation!**

