import 'package:flutter/material.dart';
import '../../../models/performance/ad_performance_data.dart';
import '../../../providers/performance_cost_provider.dart';

/// Summary view with KPI total cards
class SummaryView extends StatelessWidget {
  final List<AdPerformanceWithProduct> ads;
  final PerformanceCostProvider provider;

  const SummaryView({
    super.key,
    required this.ads,
    required this.provider,
  });

  @override
  Widget build(BuildContext context) {
    // Calculate totals from split collections or ads
    double totalCost = 0;
    int totalLeads = 0;
    int totalBookings = 0;
    int totalDeposits = 0;
    double totalProfit = 0;

    if (PerformanceCostProvider.USE_SPLIT_COLLECTIONS) {
      // NEW: Calculate from campaigns collection (pre-aggregated)
      if (provider.campaigns.isEmpty) {
        return _buildEmptyState();
      }
      
      for (final campaign in provider.campaigns) {
        totalCost += campaign.totalSpend;
        totalLeads += campaign.totalLeads;
        totalBookings += campaign.totalBookings;
        totalDeposits += campaign.totalDeposits;
        totalProfit += campaign.totalProfit;
      }
    } else {
      // OLD: Calculate from ads
      if (ads.isEmpty) {
        return _buildEmptyState();
      }

    for (final ad in ads) {
      if (ad.facebookStats.spend > 0) {
      totalCost += ad.facebookStats.spend;
      totalProfit += ad.profit;
      if (ad.ghlStats != null) {
        totalLeads += ad.ghlStats!.leads;
        totalBookings += ad.ghlStats!.bookings;
        totalDeposits += ad.ghlStats!.deposits;
          }
        }
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Row 1: Total FB Cost, Total Leads
          Row(
            children: [
              Expanded(
                child: _buildKPICard(
                  'Total FB Cost',
                  '\$${totalCost.toStringAsFixed(0)}',
                  Icons.attach_money,
                  Colors.orange,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: _buildKPICard(
                  'Total Leads',
                  totalLeads.toString(),
                  Icons.people,
                  Colors.blue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          // Row 2: Total Bookings, Total Deposits
          Row(
            children: [
              Expanded(
                child: _buildKPICard(
                  'Total Bookings',
                  totalBookings.toString(),
                  Icons.event_available,
                  Colors.green,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: _buildKPICard(
                  'Total Deposits',
                  totalDeposits.toString(),
                  Icons.account_balance_wallet,
                  Colors.purple,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          // Row 3: Total Profit (centered)
          Row(
            children: [
              const Spacer(),
              Expanded(
                flex: 2,
                child: _buildKPICard(
                  'Total Profit',
                  '\$${totalProfit.toStringAsFixed(0)}',
                  Icons.trending_up,
                  totalProfit >= 0 ? Colors.green : Colors.red,
                ),
              ),
              const Spacer(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.analytics_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No data available',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'Ads with Facebook spend will appear here',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildKPICard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                style: TextStyle(
                    fontSize: 15,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            value,
            style: TextStyle(
              fontSize: 32,
                                fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
