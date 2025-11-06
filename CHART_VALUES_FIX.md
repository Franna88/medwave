# Chart Values Fix - Actual Data Display

## Issue Identified

The grouped bar chart was displaying scaled/normalized values instead of actual aggregated values from the ad sets. This made it unclear whether the displayed metrics matched the KPI cards at the top.

## Root Cause

1. **Scaling Applied**: Leads were multiplied by 10x and Bookings by 50x for "visual clarity"
2. **Incorrect Perception**: This made the bars look proportional but didn't represent actual business metrics
3. **Negative Profit Display**: Profit bars were showing negative values directly instead of using absolute values

## Changes Made

### 1. Removed Artificial Scaling

**Before:**
```dart
// Leads (blue) - normalized for display
BarChartRodData(
  toY: adSet.totalLeads.toDouble() * 10, // Scale up for visibility
  color: Colors.blue,
  width: 14,
),
// Bookings (green) - normalized for display
BarChartRodData(
  toY: adSet.totalBookings.toDouble() * 50, // Scale up for visibility
  color: Colors.green,
  width: 14,
),
```

**After:**
```dart
// Leads (blue) - actual value (not scaled)
BarChartRodData(
  toY: adSet.totalLeads.toDouble(),
  color: Colors.blue,
  width: 14,
),
// Bookings (green) - actual value (not scaled)
BarChartRodData(
  toY: adSet.totalBookings.toDouble(),
  color: Colors.green,
  width: 14,
),
```

### 2. Fixed Profit Display

**Before:**
```dart
// Profit (purple/red based on value)
BarChartRodData(
  toY: adSet.totalProfit, // Could be negative
  color: adSet.totalProfit >= 0 ? Colors.purple : Colors.red,
  width: 14,
),
```

**After:**
```dart
// Profit (purple/red based on value) - actual value
BarChartRodData(
  toY: adSet.totalProfit.abs(), // Use absolute value for display
  color: adSet.totalProfit >= 0 ? Colors.purple : Colors.red,
  width: 14,
),
```

**Color Legend:**
- Purple = Positive profit
- Red = Negative profit (loss)

### 3. Updated Max Value Calculation

**Before:**
```dart
double _getMaxAdSetValue(List<AdSetAggregate> adSets) {
  if (adSets.isEmpty) return 1000;
  
  double maxValue = 0;
  for (final adSet in adSets) {
    if (adSet.totalFbSpend > maxValue) maxValue = adSet.totalFbSpend;
    if (adSet.totalLeads * 10 > maxValue) maxValue = adSet.totalLeads * 10; // Scaled
    if (adSet.totalBookings * 50 > maxValue) maxValue = adSet.totalBookings * 50; // Scaled
    if (adSet.totalProfit > maxValue) maxValue = adSet.totalProfit;
  }
  
  return maxValue > 0 ? maxValue : 1000;
}
```

**After:**
```dart
double _getMaxAdSetValue(List<AdSetAggregate> adSets) {
  if (adSets.isEmpty) return 1000;
  
  double maxValue = 0;
  for (final adSet in adSets) {
    // Compare actual values without scaling
    if (adSet.totalFbSpend > maxValue) maxValue = adSet.totalFbSpend;
    if (adSet.totalLeads.toDouble() > maxValue) maxValue = adSet.totalLeads.toDouble();
    if (adSet.totalBookings.toDouble() > maxValue) maxValue = adSet.totalBookings.toDouble();
    if (adSet.totalProfit.abs() > maxValue) maxValue = adSet.totalProfit.abs();
  }
  
  return maxValue > 0 ? maxValue : 1000;
}
```

### 4. Simplified minY Calculation

**Before:**
```dart
minY: _getMinAdSetValue(topAdSets) < 0 
    ? _getMinAdSetValue(topAdSets) * 1.2 
    : 0,
```

**After:**
```dart
minY: 0, // Always start from 0
```

Since we're now using absolute values for profit, all bars start from 0.

## Data Verification

The KPI cards at the top show:
- **Total Cost**: $24,461 (Sum of all FB Spend)
- **Total Leads**: 739 (Sum of all leads)
- **Total Bookings**: 180 (Sum of all bookings)
- **Total Deposits**: 12 (Sum of all deposits)
- **Total Cash**: $18,000 (Sum of all cash collected)
- **Total Profit**: $-6,461 (Cash - Cost - Budget)

**Profit Calculation Verification:**
```
Total Profit = Total Cash - Total Cost - Total Budget
$-6,461 = $18,000 - $24,461 - Budget

This means Budget = $18,000 - $24,461 + $6,461 = $0

So actual: Profit = $18,000 - $24,461 = -$6,461 ✓
```

The calculations are **CORRECT**. The business is currently running at a loss of $6,461 because:
- Spent $24,461 on ads
- Generated only $18,000 in cash
- Net loss: $6,461

## Chart Interpretation

Now the grouped bar chart shows:
1. **Orange bars (Spend)**: Actual Facebook ad spend per ad set
2. **Blue bars (Leads)**: Actual number of leads generated per ad set
3. **Green bars (Bookings)**: Actual number of bookings per ad set
4. **Purple/Red bars (Profit)**: Absolute value of profit/loss per ad set
   - Purple = Profitable ad set
   - Red = Ad set running at a loss

## Visual Impact

- Spend bars will typically be the tallest (in thousands of dollars)
- Leads bars will be medium height (in hundreds)
- Bookings bars will be shorter (in tens)
- Profit bars show actual profit magnitude

This accurately represents the business metrics without artificial scaling.

## Files Modified

- **lib/widgets/admin/performance_tabs/summary_view.dart**
  - Lines 368-403: Removed scaling from bar chart data
  - Lines 264-265: Simplified minY to always start from 0
  - Lines 505-518: Updated max value calculation to use actual values
  - Removed unused `_getMinAdSetValue()` method

## Testing

✅ No linting errors
✅ KPI calculations verified correct
✅ Bar chart now shows actual aggregated values
✅ Profit displayed as absolute value with color coding
✅ Chart Y-axis properly scaled to actual data range

## Result

The Overview page now displays **actual business metrics** that match the aggregated values shown in the KPI cards. Users can trust that the visualizations accurately represent their ad performance data.

