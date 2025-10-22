# Add Performance Cost System - Quick Start Guide

## 🚀 Get Started in 3 Steps

### Step 1: Deploy Firebase Rules
```bash
cd /Users/mac/dev/medwave
firebase deploy --only firestore:rules
```

This will deploy the security rules for the new `products` and `adPerformanceCosts` collections.

---

### Step 2: Run the App
```bash
flutter run
```

Or build for your target platform.

---

### Step 3: Access the Feature

1. **Login as Admin**
   - The Performance Cost feature is admin-only

2. **Navigate to Admin Panel**
   - Go to Admin → Advert Performance

3. **You'll see the new section at the TOP:**
   - Product Setup
   - Add Performance Cost (Detailed View / Summary)

---

## 📝 Quick Usage Example

### Create Your First Product

1. Click **"Add Product"** in the Product Setup section
2. Fill in:
   - **Product Name**: `bed`
   - **Deposit Amount**: `2000`
   - **Expense Cost**: `900`
3. Click **"Create"**

### Add Your First Ad Budget

1. Click **"Add Entry"** in the Performance Cost Table
2. Select:
   - **Campaign**: Choose from dropdown (your existing campaigns)
   - **Ad**: Choose from dropdown (ads in that campaign)
   - **Budget**: `1500`
   - **Linked Product** (optional): Select "bed"
3. Click **"Create"**

### View Results

The system automatically:
- Pulls performance data (leads, bookings, deposits) from your cumulative campaign data
- Calculates CPL, CPB, CPA
- Calculates actual profit: Cash Deposits - (Budget + Product Expense)
- Shows results in the table

---

## 🎯 Understanding the Metrics

| Metric | What It Shows | Good Value |
|--------|---------------|------------|
| **CPL** | Cost per lead | Under R50 |
| **CPB** | Cost per booking | Under R100 |
| **CPA** | Cost per acquisition (deposit) | Under R300 |
| **Profit** | Net profit after all costs | Green = positive |

---

## 🔄 View Modes

### Detailed View
Shows all 11 columns with complete data:
- Ad Name, Budget, Leads, CPL, Booking, CPB, Deposit, CPA, Cash Deposit Amount, Product Expense Cost, Actual Profit

### Summary View
Shows condensed 6 columns for quick overview:
- Ad Name, Budget, CPL, CPB, CPA, Actual Profit

Toggle between views using the buttons above the table.

---

## 💡 Pro Tips

1. **Create Products First**
   - Set up all your products before creating ad budget entries
   - Link products to calculate accurate profit

2. **Use Cumulative Mode**
   - Make sure GoHighLevel is in cumulative mode for accurate metrics
   - Sync your data regularly

3. **Sort Columns**
   - Click column headers in detailed view to sort
   - Find your best and worst performing ads quickly

4. **Color Indicators**
   - Green = Good performance
   - Orange = Average performance
   - Red = Poor performance or negative profit

5. **Refresh Data**
   - Click the refresh button to reload latest campaign data
   - Do this after syncing GoHighLevel data

---

## 🔧 Troubleshooting

### No Campaigns/Ads in Dropdown?
- Make sure you've synced GoHighLevel data
- Check that you're viewing the correct timeframe
- Campaigns must have UTM tracking data

### Metrics Show Zero?
- The ad may not have any performance data yet
- Check that the campaign/ad names match exactly
- Sync cumulative data in GoHighLevel section

### Can't See the Feature?
- Make sure you're logged in as an admin
- Check that you're on the Admin → Advert Performance screen
- The section is at the very top after filters

---

## 📊 Data Requirements

For the system to work, you need:
1. ✅ GoHighLevel integration active
2. ✅ Cumulative data synced
3. ✅ Campaigns with UTM tracking
4. ✅ Admin user account
5. ✅ Firebase rules deployed

---

## 🎓 Learning Resources

### Full Documentation
See `ADD_PERFORMANCE_COST_IMPLEMENTATION_SUMMARY.md` for complete details

### Implementation Plan
See `add-performance-cost-system.plan.md` for technical architecture

### Screenshots Reference
Check the original screenshots for UI design reference

---

**Ready to Track Your Ad Profitability!** 🎉

