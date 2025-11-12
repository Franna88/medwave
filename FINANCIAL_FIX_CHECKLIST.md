# Financial Calculations Fix - Quick Checklist

**Priority:** CRITICAL  
**Estimated Time:** 2-3 hours  
**Difficulty:** Medium

---

## 🎯 The Problem (In 30 Seconds)

The monthly revenue aggregation script uses **lifetime GHL totals** from ads instead of querying opportunities by their **creation date**. This causes incorrect monthly profit calculations.

**Impact:** Monthly reports show wrong revenue/profit numbers, making business decisions unreliable.

---

## ✅ Quick Fix Steps

### 1️⃣ Backup Current Data (5 min)
```bash
# In Firebase Console or CLI
firebase firestore:export gs://your-backup-bucket/before-fix-$(date +%Y%m%d)
```

### 2️⃣ Fix Python Script (30 min)

**File:** `populate_monthly_totals.py`

**Line 77-84** and **Line 191-197** - Replace:
```python
# OLD CODE (WRONG)
ghl_stats = ad.get('ghlStats', {})
monthly_data[month]['cashAmount'] += ghl_stats.get('cashAmount', 0)
```

**With:** (See FINANCIAL_CALCULATIONS_GUIDE.md, Fix 1 for complete code)
```python
# NEW CODE (CORRECT)
# Query opportunities by adId and filter by createdAt date
opportunities_ref = db.collection('ghlOpportunities').where('adId', '==', ad_id).stream()
for opp_doc in opportunities_ref:
    # ... filter by opp.createdAt month ...
    # ... add to monthly_data[month]['cashAmount'] ...
```

### 3️⃣ Fix Dart Provider (20 min)

**File:** `lib/providers/performance_cost_provider.dart`

**Method:** `loadCampaignsWithDateRange` (line ~1173)

**Add month detection:**
```dart
final isSingleMonth = startDate != null && 
                       endDate != null &&
                       startDate.year == endDate.year &&
                       startDate.month == endDate.month;

if (isSingleMonth) {
  final monthStr = '${startDate.year}-${startDate.month.toString().padLeft(2, '0')}';
  _campaigns = await _campaignService.getCampaignsWithMonthTotals(
    month: monthStr,
    // ...
  );
} else {
  _campaigns = await _campaignService.getCampaignsByDateRange(
    // ...
  );
}
```

**Same fix for:** `loadAdSetsForCampaign` method

### 4️⃣ Run Aggregation Scripts (30 min)
```bash
cd /path/to/medwave

# 1. Sync GHL data from API
python split_collections_schema/sync_ghl_monetary_values.py

# 2. Aggregate GHL to ads (lifetime)
python split_collections_schema/reaggregate_ghl_to_ads.py

# 3. Populate monthly totals (WITH YOUR FIX)
python populate_monthly_totals.py

# 4. Roll up to campaigns/ad sets
python recalculate_campaign_adset_totals.py
```

### 5️⃣ Verify in Firebase (10 min)

1. Open Firebase Console → Firestore
2. Check: `campaigns/{any_id}/monthlyTotals/2025-11`
3. Manually verify:
   ```
   Query ghlOpportunities:
   - Where adId IN [campaign's ad IDs]
   - Where createdAt between Nov 1-30
   - Where stageCategory IN ['deposits', 'cashCollected']
   - Sum monetaryValue
   
   Compare to: monthlyTotals/2025-11/cashAmount
   ```

### 6️⃣ Test in UI (15 min)

1. Flutter: `flutter run`
2. Navigate to Campaign Performance
3. Select "This Month" filter
4. Verify:
   - [ ] Numbers load quickly (<2 seconds)
   - [ ] Profit = Cash - Spend
   - [ ] Drill down works (campaign → ad set → ad)
   - [ ] Switching filters doesn't break anything

---

## 🚨 What Could Go Wrong

| Issue | Solution |
|-------|----------|
| Python script timeout | Increase batch size or add pagination |
| "No monthlyTotals field" | Re-run `populate_monthly_totals.py` |
| UI shows 0 for everything | Check if campaigns have data for selected month |
| Profit is negative | Verify GHL `monetaryValue` is populated |
| Numbers still wrong | Double-check you applied ALL THREE fixes |

---

## 📊 Success Criteria

- [ ] Monthly totals in Firebase have different `cashAmount` than before
- [ ] November 2025 profit matches manual calculation
- [ ] UI "This Month" filter loads in <2 seconds
- [ ] Profit = totalCashAmount - totalSpend at all levels
- [ ] Historical months (Oct, Sep) also show correct data

---

## 🔗 Full Documentation

See **FINANCIAL_CALCULATIONS_GUIDE.md** for:
- Detailed architecture explanation
- Complete code examples
- Step-by-step verification procedures
- Troubleshooting guide

---

**TL;DR:** Change `populate_monthly_totals.py` to query `ghlOpportunities` by `createdAt` instead of using ad's lifetime `ghlStats`. Then update Dart code to use monthly totals for single-month filters.

