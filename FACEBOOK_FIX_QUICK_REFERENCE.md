# 🚀 Facebook Ads - Quick Fix Reference

## ❌ Problem
**No ads showing** because `campaignKey` values don't match Facebook Campaign IDs.

---

## ✅ Solution (5 Minutes)

### 1. Open Firebase
Go to: **Firestore Database** → **`ad_performance_costs`** collection

### 2. Update These 3 Ads

| Ad Name | Change campaignKey To |
|---------|----------------------|
| **Obesity - Andries - DDM** | `120234435129520335` |
| **Health Providers** | `120234166546100335` |
| **120232883487010335** | `120232882927590335` |

### 3. Click "Save" for Each

### 4. Refresh App
Click the 🔄 button in "Add Performance Cost" header

---

## ✅ You'll See
- ✅ All 3 ads visible
- ✅ Blue "FB Spend" showing live costs
- ✅ Facebook metrics (impressions, clicks, CPM, etc.)
- ✅ "Live FB Data" badge
- ✅ CPL/CPB/CPA calculated from Facebook spend

---

## 📋 Available Campaign IDs

Copy these IDs to match your ads:

```
120234497185340335 - Targeted Audiences ($1885.66)
120234487479280335 - Physiotherapist ($284.20)
120234485362420335 - Retargeting ($187.81)
120234435129520335 - Afrikaans ($842.04)
120234319834310335 - Grouped ($623.88)
120234166546100335 - HCP > Weight Loss ($178.70)
120232882927590335 - Varied ($325.89)
```

---

## 🔍 How to Find Campaign ID

1. Look at the **blue box** at top of "Add Performance Cost"
2. Find your campaign name
3. Copy the number in parentheses: `(ID: 120234...)`
4. Paste into Firebase `campaignKey` field

---

## ⚠️ Important Rules

✅ **DO:** Use ONLY the numeric Campaign ID  
❌ **DON'T:** Use campaign names, pipe-separated values, or partial IDs

**Correct:** `120234435129520335`  
**Wrong:** `Matthys - 15102025 - ABOLEADFORMZA (DDM) - Afrikaans`

---

## 🆘 Still Not Working?

Check terminal logs for:
```
❌ No FB match for: [Your Ad Name] (campaignKey: [Value])
```

This tells you which ads aren't matching and what their current `campaignKey` is.

---

**That's it!** 5 minutes to fix, then you'll see all your Facebook data live! 🎉


