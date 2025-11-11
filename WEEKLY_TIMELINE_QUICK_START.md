# Weekly Ad Timeline - Quick Start Guide

## What's New

Your MedWave system now tracks ad performance **week by week** for the past 6 months, enabling you to:
- Compare Week 1 vs Week 2 performance
- See trends over time with interactive charts
- Analyze which weeks performed best
- Track cost and performance changes week-over-week

---

## Getting Started

### 1. Run the Backfill (First Time Only)

Populate 6 months of historical weekly data:

```bash
cd /Users/mac/dev/medwave/functions
node backfillWeeklyInsights.js
```

**Time:** 30-60 minutes for all ads  
**What it does:** Fetches weekly breakdown from Facebook API and stores in Firestore

---

### 2. View Weekly Performance

#### Option A: From Code
```dart
import 'package:your_app/services/firebase/weekly_insights_service.dart';
import 'package:your_app/widgets/admin/weekly_performance_chart.dart';

// Fetch weekly data
final weeklyData = await WeeklyInsightsService.fetchWeeklyInsightsForAd(
  'your_ad_id',
  startDate: DateTime.now().subtract(Duration(days: 180)),
  endDate: DateTime.now(),
);

// Display chart
WeeklyPerformanceChart(
  weeklyData: weeklyData,
  metric: 'spend',  // or 'impressions', 'clicks', 'cpm', 'cpc', 'ctr'
  title: 'Weekly Spend Analysis',
)
```

#### Option B: Use Comparison Screen
```dart
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => AdWeeklyComparisonScreen(
      adId: adId,
      adName: adName,
    ),
  ),
);
```

---

## Features

### 📊 Interactive Timeline Chart
- Line chart showing performance over weeks
- Hover to see exact values
- Switch between metrics (spend, impressions, clicks, etc.)
- Date range selector (4 weeks, 12 weeks, 6 months)

### 🔄 Week Comparison
- Select any two weeks to compare
- See percentage change for each metric
- Color-coded indicators (green = increase, red = decrease)
- Compare Week 1 vs Week 2, or any combination

### 📋 Data Table
- Complete weekly breakdown
- All metrics in one view
- Sortable columns
- Easy to scan and analyze

---

## Example Use Cases

### 1. Find Best Performing Week
```dart
final weeklyData = await WeeklyInsightsService.fetchWeeklyInsightsForAd(adId);

// Find week with lowest CPC
final bestWeek = weeklyData.reduce((a, b) => 
  a.cpc < b.cpc ? a : b
);

print('Best week: ${bestWeek.weekLabel} with CPC of \$${bestWeek.cpc}');
```

### 2. Calculate Week-over-Week Growth
```dart
if (weeklyData.length >= 2) {
  final lastWeek = weeklyData[weeklyData.length - 1];
  final previousWeek = weeklyData[weeklyData.length - 2];
  
  final spendChange = lastWeek.calculateChangePercent(previousWeek, 'spend');
  print('Spend changed by ${spendChange.toStringAsFixed(1)}%');
}
```

### 3. Get Aggregated Metrics
```dart
final metrics = await WeeklyInsightsService.getAggregatedMetrics(
  adId,
  startDate: DateTime.now().subtract(Duration(days: 90)),
  endDate: DateTime.now(),
);

print('Total spend over 3 months: \$${metrics['totalSpend']}');
print('Average CPM: \$${metrics['avgCpm']}');
```

---

## Data Structure

### Firestore Path
```
adPerformance/{adId}/weeklyInsights/{weekId}
```

### Document Format
```json
{
  "adId": "120234375398550335",
  "weekNumber": 1,
  "dateStart": "2025-10-14T00:00:00Z",
  "dateStop": "2025-10-20T23:59:59Z",
  "spend": 45.50,
  "impressions": 1250,
  "reach": 980,
  "clicks": 85,
  "cpm": 36.40,
  "cpc": 0.54,
  "ctr": 6.80,
  "fetchedAt": "2025-11-07T12:00:00Z"
}
```

---

## Automatic Updates

Weekly data is automatically updated during regular Facebook syncs:
- **Frequency:** Every sync (typically every 15 minutes)
- **Scope:** Last 4 weeks are refreshed
- **Historical data:** Remains unchanged

No manual intervention needed after initial backfill!

---

## API Reference

### WeeklyInsightsService

```dart
// Fetch weekly data for single ad
Future<List<FacebookWeeklyInsight>> fetchWeeklyInsightsForAd(
  String adId, {
  DateTime? startDate,
  DateTime? endDate,
})

// Fetch for multiple ads
Future<Map<String, List<FacebookWeeklyInsight>>> fetchWeeklyInsightsForAds(
  List<String> adIds, {
  DateTime? startDate,
  DateTime? endDate,
})

// Get latest week
Future<FacebookWeeklyInsight?> getLatestWeekForAd(String adId)

// Count weeks
Future<int> getWeekCountForAd(String adId)

// Get aggregated metrics
Future<Map<String, dynamic>> getAggregatedMetrics(
  String adId, {
  DateTime? startDate,
  DateTime? endDate,
})

// Stream for real-time updates
Stream<List<FacebookWeeklyInsight>> streamWeeklyInsightsForAd(
  String adId, {
  DateTime? startDate,
  DateTime? endDate,
})
```

### FacebookWeeklyInsight Model

```dart
class FacebookWeeklyInsight {
  final String adId;
  final int weekNumber;
  final DateTime dateStart;
  final DateTime dateStop;
  final double spend;
  final int impressions;
  final int reach;
  final int clicks;
  final double cpm;
  final double cpc;
  final double ctr;
  final DateTime fetchedAt;
  
  // Helper properties
  String get dateRangeString;  // "Nov 1-7"
  String get weekLabel;         // "Week 1"
  
  // Calculate change from previous week
  double calculateChangePercent(
    FacebookWeeklyInsight previousWeek,
    String metric  // 'spend', 'impressions', etc.
  );
}
```

---

## Troubleshooting

### Q: No weekly data showing?
**A:** Run the backfill script first:
```bash
cd /Users/mac/dev/medwave/functions
node backfillWeeklyInsights.js
```

### Q: Some ads have 0 weeks?
**A:** Normal - those ads weren't active in the past 6 months or have no spend.

### Q: Weekly totals don't match aggregated data?
**A:** Expected - they use different date ranges. Variance of 10-20% is normal.

### Q: How to refresh data?
**A:** Data auto-refreshes during regular syncs. To force refresh:
```dart
final weeklyData = await FacebookAdsService.fetchWeeklyInsightsForAd(
  adId,
  forceRefresh: true,
);
```

---

## Performance Tips

1. **Use date filters** when querying large date ranges
2. **Cache results** in your UI state management
3. **Paginate** when displaying many weeks
4. **Stream data** for real-time updates instead of polling

---

## Support

For issues or questions:
1. Check the full implementation summary: `WEEKLY_AD_TIMELINE_IMPLEMENTATION_SUMMARY.md`
2. Run test script: `node functions/testSingleAdWeekly.js`
3. Check Firestore console for data verification

---

**Ready to analyze your ad performance week by week!** 📊✨

