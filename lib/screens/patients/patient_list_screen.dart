import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../providers/patient_provider.dart';
import '../../models/patient.dart';
import '../../theme/app_theme.dart';

import '../../widgets/responsive_patient_list.dart';

class PatientListScreen extends StatefulWidget {
  const PatientListScreen({super.key});

  @override
  State<PatientListScreen> createState() => _PatientListScreenState();
}

class _PatientListScreenState extends State<PatientListScreen>
    with TickerProviderStateMixin {
  String _searchQuery = '';
  String _sortBy = 'name'; // name, lastUpdated, sessions
  bool _showOnlyImproving = false;
  bool _isSearchExpanded = false;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  late AnimationController _searchAnimationController;

  @override
  void initState() {
    super.initState();
    _searchAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _searchAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Column(
        children: [
          _buildModernHeader(),
          Expanded(child: _buildBody()),
        ],
      ),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  Widget _buildModernHeader() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppTheme.headerGradientStart,
            AppTheme.headerGradientEnd,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: _isSearchExpanded
                          ? _buildSearchField()
                          : Column(
                              key: const ValueKey('title'),
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Patients',
                                  style: TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Manage your patient records',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.white.withOpacity(0.8),
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                  Row(
                    children: [
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: _isSearchExpanded
                            ? IconButton(
                                key: const ValueKey('close'),
                                icon: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.8),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(Icons.close, color: AppTheme.textColor),
                                ),
                                onPressed: _toggleSearch,
                              )
                            : IconButton(
                                key: const ValueKey('search'),
                                icon: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.8),
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.1),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(Icons.search, color: AppTheme.textColor),
                                ),
                                onPressed: _toggleSearch,
                              ),
                      ),
                      const SizedBox(width: 8),
                      _buildSortButton(),
                    ],
                  ),
                ],
              ),
              if (!_isSearchExpanded) ...[
                const SizedBox(height: 16),
                _buildModernFilterChips(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchField() {
    return Container(
      key: const ValueKey('search_field'),
      height: 40,
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        decoration: const InputDecoration(
          hintText: 'Search patients...',
          prefixIcon: Icon(Icons.search, color: AppTheme.secondaryColor, size: 20),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        style: const TextStyle(fontSize: 16),
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
          });
        },
      ),
    );
  }

  Widget _buildSortButton() {
    return PopupMenuButton<String>(
      icon: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.8),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Icon(Icons.tune, color: AppTheme.textColor, size: 20),
      ),
      onSelected: (value) {
        setState(() {
          _sortBy = value;
        });
        HapticFeedback.lightImpact();
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'name',
          child: Row(
            children: [
              Icon(Icons.sort_by_alpha, 
                   color: _sortBy == 'name' ? AppTheme.primaryColor : AppTheme.secondaryColor),
              const SizedBox(width: 12),
              Text('Sort by Name', 
                   style: TextStyle(color: _sortBy == 'name' ? AppTheme.primaryColor : AppTheme.textColor)),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'lastUpdated',
          child: Row(
            children: [
              Icon(Icons.update, 
                   color: _sortBy == 'lastUpdated' ? AppTheme.primaryColor : AppTheme.secondaryColor),
              const SizedBox(width: 12),
              Text('Sort by Last Updated', 
                   style: TextStyle(color: _sortBy == 'lastUpdated' ? AppTheme.primaryColor : AppTheme.textColor)),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'sessions',
          child: Row(
            children: [
              Icon(Icons.event_note, 
                   color: _sortBy == 'sessions' ? AppTheme.primaryColor : AppTheme.secondaryColor),
              const SizedBox(width: 12),
              Text('Sort by Sessions', 
                   style: TextStyle(color: _sortBy == 'sessions' ? AppTheme.primaryColor : AppTheme.textColor)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBody() {
    return Consumer<PatientProvider>(
      builder: (context, patientProvider, child) {
        if (patientProvider.isLoading) {
          return _buildLoadingState();
        }



        return ResponsivePatientList(
          searchQuery: _searchQuery,
          sortBy: _sortBy,
          showOnlyImproving: _showOnlyImproving,
        );
      },
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: AppTheme.primaryColor,
            strokeWidth: 3,
          ),
          SizedBox(height: 16),
          Text(
            'Loading patients...',
            style: TextStyle(
              color: AppTheme.secondaryColor,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }



  Widget _buildFloatingActionButton() {
    return FloatingActionButton.extended(
      onPressed: () => context.push('/patients/add'),
      backgroundColor: AppTheme.primaryColor,
      foregroundColor: Colors.white,
      elevation: 8,
      icon: const Icon(Icons.add),
      label: const Text(
        'Add Patient',
        style: TextStyle(fontWeight: FontWeight.w600),
      ),
    );
  }

  void _toggleSearch() {
    setState(() {
      _isSearchExpanded = !_isSearchExpanded;
    });
    
    if (_isSearchExpanded) {
      _searchAnimationController.forward();
      _searchFocusNode.requestFocus();
    } else {
      _searchAnimationController.reverse();
      _searchController.clear();
      _searchQuery = '';
      _searchFocusNode.unfocus();
    }
    
    HapticFeedback.lightImpact();
  }

  Widget _buildModernFilterChips() {
    return Row(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: _showOnlyImproving 
                ? AppTheme.successColor.withOpacity(0.15)
                : Colors.white.withOpacity(0.8),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _showOnlyImproving 
                  ? AppTheme.successColor
                  : AppTheme.borderColor.withOpacity(0.5),
              width: _showOnlyImproving ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: InkWell(
            onTap: () {
              setState(() {
                _showOnlyImproving = !_showOnlyImproving;
              });
              HapticFeedback.lightImpact();
            },
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      _showOnlyImproving 
                          ? Icons.trending_up 
                          : Icons.filter_list,
                      color: _showOnlyImproving 
                          ? AppTheme.successColor
                                                      : Colors.white.withOpacity(0.8),
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _showOnlyImproving 
                        ? 'Showing Improvement' 
                        :                         'All Patients',
                      style: TextStyle(
                        color: _showOnlyImproving 
                            ? AppTheme.successColor
                            : Colors.white,
                      fontWeight: _showOnlyImproving 
                          ? FontWeight.w600 
                          : FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }





  Widget _buildModernMetricChip(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: color.withOpacity(0.2),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getPainColor(int painScore) {
    if (painScore <= 3) return AppTheme.successColor;
    if (painScore <= 6) return AppTheme.warningColor;
    return AppTheme.errorColor;
  }


}
