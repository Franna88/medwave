import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../models/contracts/contract.dart';
import '../../../providers/contract_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/role_manager.dart';

/// SuperAdmin contracts overview dashboard
class ContractsOverviewScreen extends StatefulWidget {
  const ContractsOverviewScreen({super.key});

  @override
  State<ContractsOverviewScreen> createState() =>
      _ContractsOverviewScreenState();
}

class _ContractsOverviewScreenState extends State<ContractsOverviewScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  ContractStatus? _selectedStatus;
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _loadContracts();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _loadContracts() {
    final provider = context.read<ContractProvider>();
    provider.subscribeToAllContracts();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase();
    });
  }

  List<Contract> _filterContracts(List<Contract> contracts) {
    return contracts.where((contract) {
      // Search filter
      if (_searchQuery.isNotEmpty) {
        final matchesSearch =
            contract.customerName.toLowerCase().contains(_searchQuery) ||
            contract.email.toLowerCase().contains(_searchQuery) ||
            contract.id.toLowerCase().contains(_searchQuery);

        if (!matchesSearch) return false;
      }

      // Status filter
      if (_selectedStatus != null && contract.status != _selectedStatus) {
        return false;
      }

      // Date range filter
      if (_startDate != null && contract.createdAt.isBefore(_startDate!)) {
        return false;
      }
      if (_endDate != null && contract.createdAt.isAfter(_endDate!)) {
        return false;
      }

      return true;
    }).toList();
  }

  Future<void> _copyLink(Contract contract) async {
    final provider = context.read<ContractProvider>();
    final url = provider.getFullContractUrl(contract);

    await Clipboard.setData(ClipboardData(text: url));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Contract link copied to clipboard!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _voidContract(Contract contract) async {
    final TextEditingController reasonController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Void Contract for ${contract.customerName}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Are you sure you want to void this contract? This action cannot be undone.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason (optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Void Contract'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) {
      reasonController.dispose();
      return;
    }

    final authProvider = context.read<AuthProvider>();
    final userId = authProvider.user?.uid ?? '';
    final reason = reasonController.text.trim();
    reasonController.dispose();

    final provider = context.read<ContractProvider>();
    final success = await provider.voidContract(
      contractId: contract.id,
      voidedBy: userId,
      voidReason: reason.isEmpty ? null : reason,
    );

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Contract voided successfully'),
          backgroundColor: Colors.orange,
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.error ?? 'Failed to void contract'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _viewContractDetails(Contract contract) {
    final provider = context.read<ContractProvider>();
    final url = provider.getFullContractUrl(contract);

    showDialog(
      context: context,
      builder: (context) => _ContractDetailsDialog(
        contract: contract,
        url: url,
        onCopyLink: () => _copyLink(contract),
        onVoid:
            contract.status != ContractStatus.voided &&
                contract.status != ContractStatus.signed
            ? () {
                Navigator.of(context).pop();
                _voidContract(contract);
              }
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final userRole = authProvider.userRole;

    // Only SuperAdmin can access this screen
    if (userRole != UserRole.superAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Contracts Overview')),
        body: const Center(child: Text('Access Denied: SuperAdmin only')),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text(
          'Contracts Overview',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Consumer<ContractProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading && provider.allContracts.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          final filteredContracts = _filterContracts(provider.allContracts);

          return Column(
            children: [
              // Stats cards
              _buildStatsCards(provider.allContracts),

              // Filters
              _buildFilters(),

              // Contracts list
              Expanded(
                child: filteredContracts.isEmpty
                    ? _buildEmptyState()
                    : _buildContractsList(filteredContracts),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatsCards(List<Contract> allContracts) {
    final pending = allContracts
        .where(
          (c) =>
              c.status == ContractStatus.pending ||
              c.status == ContractStatus.viewed,
        )
        .length;

    final today = DateTime.now();
    final startOfToday = DateTime(today.year, today.month, today.day);
    final signedToday = allContracts.where((c) {
      return c.status == ContractStatus.signed &&
          c.signedAt != null &&
          c.signedAt!.isAfter(startOfToday);
    }).length;

    final startOfWeek = startOfToday.subtract(
      Duration(days: today.weekday - 1),
    );
    final signedThisWeek = allContracts.where((c) {
      return c.status == ContractStatus.signed &&
          c.signedAt != null &&
          c.signedAt!.isAfter(startOfWeek);
    }).length;

    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              'Total Contracts',
              allContracts.length.toString(),
              Icons.description,
              Colors.blue,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              'Pending Signatures',
              pending.toString(),
              Icons.pending_actions,
              Colors.amber,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              'Signed Today',
              signedToday.toString(),
              Icons.check_circle,
              Colors.green,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              'Signed This Week',
              signedThisWeek.toString(),
              Icons.trending_up,
              Colors.purple,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Column(
        children: [
          Row(
            children: [
              // Search
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by name, email, or ID...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Status filter
              Expanded(
                child: DropdownButtonFormField<ContractStatus?>(
                  value: _selectedStatus,
                  decoration: InputDecoration(
                    labelText: 'Status',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('All')),
                    ...ContractStatus.values.map((status) {
                      return DropdownMenuItem(
                        value: status,
                        child: Text(status.displayName),
                      );
                    }).toList(),
                  ],
                  onChanged: (value) {
                    setState(() => _selectedStatus = value);
                  },
                ),
              ),
              const SizedBox(width: 12),

              // Clear filters button
              if (_searchQuery.isNotEmpty ||
                  _selectedStatus != null ||
                  _startDate != null ||
                  _endDate != null)
                OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      _searchController.clear();
                      _selectedStatus = null;
                      _startDate = null;
                      _endDate = null;
                    });
                  },
                  icon: const Icon(Icons.clear),
                  label: const Text('Clear'),
                ),
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
          Icon(Icons.description_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No contracts found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContractsList(List<Contract> contracts) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(8),
                  ),
                ),
                child: const Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text(
                        'Customer',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'Status',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'Products',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'Deposit',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'Created',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'Actions',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),

              // Rows
              ...contracts
                  .map((contract) => _buildContractRow(contract))
                  .toList(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContractRow(Contract contract) {
    final dateFormat = DateFormat('MMM dd, yyyy');

    return InkWell(
      onTap: () => _viewContractDetails(contract),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
        ),
        child: Row(
          children: [
            // Customer
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    contract.customerName,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  Text(
                    contract.email,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),

            // Status
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Color(
                    int.parse(contract.statusColor.replaceFirst('#', '0xff')),
                  ).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  contract.status.displayName,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(
                      int.parse(contract.statusColor.replaceFirst('#', '0xff')),
                    ),
                  ),
                ),
              ),
            ),

            // Products
            Expanded(
              child: Text(
                '${contract.products.length} item${contract.products.length != 1 ? 's' : ''}',
                style: const TextStyle(fontSize: 14),
              ),
            ),

            // Deposit
            Expanded(
              child: Text(
                'R ${contract.depositAmount.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),

            // Created
            Expanded(
              child: Text(
                dateFormat.format(contract.createdAt),
                style: const TextStyle(fontSize: 14),
              ),
            ),

            // Actions
            Expanded(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.visibility, size: 20),
                    onPressed: () => _viewContractDetails(contract),
                    tooltip: 'View',
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy, size: 20),
                    onPressed: () => _copyLink(contract),
                    tooltip: 'Copy Link',
                  ),
                  if (contract.status != ContractStatus.voided &&
                      contract.status != ContractStatus.signed)
                    IconButton(
                      icon: Icon(Icons.block, size: 20, color: Colors.red[400]),
                      onPressed: () => _voidContract(contract),
                      tooltip: 'Void',
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContractDetailsDialog extends StatelessWidget {
  final Contract contract;
  final String url;
  final VoidCallback onCopyLink;
  final VoidCallback? onVoid;

  const _ContractDetailsDialog({
    required this.contract,
    required this.url,
    required this.onCopyLink,
    this.onVoid,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM dd, yyyy \'at\' hh:mm a');

    return Dialog(
      child: Container(
        width: 600,
        constraints: const BoxConstraints(maxHeight: 700),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(24),
              color: AppTheme.primaryColor,
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Contract Details',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          contract.customerName,
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Status
                    _buildSection('Status', [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Color(
                            int.parse(
                              contract.statusColor.replaceFirst('#', '0xff'),
                            ),
                          ).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          contract.status.displayName,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(
                              int.parse(
                                contract.statusColor.replaceFirst('#', '0xff'),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 20),

                    // Contact info
                    _buildSection('Contact Information', [
                      _buildInfoRow('Email', contract.email),
                      _buildInfoRow('Phone', contract.phone),
                    ]),
                    const SizedBox(height: 20),

                    // Products & Quote
                    _buildSection('Products & Quote', [
                      ...contract.products.map((p) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(p.name),
                              Text('R ${p.price.toStringAsFixed(2)}'),
                            ],
                          ),
                        );
                      }).toList(),
                      const Divider(),
                      _buildInfoRow(
                        'Subtotal',
                        'R ${contract.subtotal.toStringAsFixed(2)}',
                      ),
                      _buildInfoRow(
                        'Deposit (40%)',
                        'R ${contract.depositAmount.toStringAsFixed(2)}',
                        isBold: true,
                      ),
                      _buildInfoRow(
                        'Balance (60%)',
                        'R ${contract.remainingBalance.toStringAsFixed(2)}',
                      ),
                    ]),
                    const SizedBox(height: 20),

                    // Timestamps
                    _buildSection('Timeline', [
                      _buildInfoRow(
                        'Created',
                        dateFormat.format(contract.createdAt),
                      ),
                      if (contract.viewedAt != null)
                        _buildInfoRow(
                          'Viewed',
                          dateFormat.format(contract.viewedAt!),
                        ),
                      if (contract.signedAt != null)
                        _buildInfoRow(
                          'Signed',
                          dateFormat.format(contract.signedAt!),
                        ),
                      if (contract.voidedAt != null)
                        _buildInfoRow(
                          'Voided',
                          dateFormat.format(contract.voidedAt!),
                        ),
                    ]),
                    const SizedBox(height: 20),

                    // Signature details (if signed)
                    if (contract.hasSigned) ...[
                      _buildSection('Signature Details', [
                        _buildInfoRow(
                          'Signed by',
                          contract.digitalSignature ?? '-',
                        ),
                        _buildInfoRow(
                          'Signature ID',
                          contract.digitalSignatureToken ?? '-',
                        ),
                        if (contract.ipAddress != null)
                          _buildInfoRow('IP Address', contract.ipAddress!),
                      ]),
                      const SizedBox(height: 20),
                    ],

                    // Contract link
                    _buildSection('Contract Link', [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: SelectableText(
                          url,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ]),
                  ],
                ),
              ),
            ),

            // Actions
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                border: Border(top: BorderSide(color: Colors.grey[300]!)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (onVoid != null)
                    OutlinedButton.icon(
                      onPressed: onVoid,
                      icon: const Icon(Icons.block),
                      label: const Text('Void'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                      ),
                    ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: onCopyLink,
                    icon: const Icon(Icons.copy),
                    label: const Text('Copy Link'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
