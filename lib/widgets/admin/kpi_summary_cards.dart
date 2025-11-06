import 'package:flutter/material.dart';
import '../../models/performance/ad_performance_data.dart';

/// Reusable KPI Summary Cards Widget
class KPISummaryCards extends StatelessWidget {
  final List<AdPerformanceWithProduct> ads;

  const KPISummaryCards({
    super.key,
    required this.ads,
  });

  @override
  Widget build(BuildContext context) {
    // Calculate totals from ads with FB spend > 0
    double totalCost = 0;
    int totalLeads = 0;
    int totalBookings = 0;
    int totalDeposits = 0;
    double totalProfit = 0;

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

    return Column(
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

