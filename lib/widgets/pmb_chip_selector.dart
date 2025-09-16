import 'package:flutter/material.dart';
import '../models/pmb_condition.dart';
import '../services/pmb_service.dart';
import '../theme/app_theme.dart';

class PMBChipSelector extends StatefulWidget {
  final List<String> selectedConditionIds;
  final Function(List<String>) onSelectionChanged;
  final bool showCategories;
  final bool showSearch;

  const PMBChipSelector({
    super.key,
    required this.selectedConditionIds,
    required this.onSelectionChanged,
    this.showCategories = true,
    this.showSearch = true,
  });

  @override
  State<PMBChipSelector> createState() => _PMBChipSelectorState();
}

class _PMBChipSelectorState extends State<PMBChipSelector> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedCategory;
  List<PMBCondition> _filteredConditions = [];
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _updateFilteredConditions();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _updateFilteredConditions() {
    List<PMBCondition> conditions;
    
    if (_searchQuery.isNotEmpty) {
      conditions = PMBService.searchConditions(_searchQuery);
    } else if (_selectedCategory != null) {
      conditions = PMBService.getConditionsByCategory(_selectedCategory!);
    } else {
      conditions = PMBService.getAllConditions();
    }

    setState(() {
      _filteredConditions = conditions;
    });
  }

  void _toggleCondition(String conditionId) {
    final List<String> newSelection = List.from(widget.selectedConditionIds);
    
    if (newSelection.contains(conditionId)) {
      newSelection.remove(conditionId);
    } else {
      newSelection.add(conditionId);
    }
    
    widget.onSelectionChanged(newSelection);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with count
        Row(
          children: [
            const Icon(
              Icons.medical_services,
              color: AppTheme.primaryColor,
              size: 24,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Prescribed Minimum Benefits (PMB)',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textColor,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
              ),
              child: Text(
                '${widget.selectedConditionIds.length} selected',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primaryColor,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        
        // Description
        Text(
          'Select applicable conditions that qualify for guaranteed medical aid coverage.',
          style: TextStyle(
            fontSize: 14,
            color: AppTheme.textColor.withOpacity(0.7),
          ),
        ),
        const SizedBox(height: 16),

        // Search bar
        if (widget.showSearch) ...[
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search PMB conditions...',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 20),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _searchQuery = '';
                        });
                        _updateFilteredConditions();
                      },
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: AppTheme.borderColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppTheme.primaryColor),
              ),
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
                _selectedCategory = null; // Clear category filter when searching
              });
              _updateFilteredConditions();
            },
          ),
          const SizedBox(height: 16),
        ],

        // Category filter
        if (widget.showCategories && _searchQuery.isEmpty) ...[
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _buildCategoryChip('All', null),
                const SizedBox(width: 8),
                ...PMBService.getCategories().map((category) => 
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _buildCategoryChip(category, category),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Conditions count
        if (_filteredConditions.isNotEmpty) ...[
          Text(
            'Showing ${_filteredConditions.length} condition${_filteredConditions.length != 1 ? 's' : ''}',
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.textColor.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 12),
        ],

        // PMB Conditions Chips
        if (_filteredConditions.isEmpty)
          _buildEmptyState()
        else
          _buildConditionsGrid(),
      ],
    );
  }

  Widget _buildCategoryChip(String label, String? category) {
    final isSelected = _selectedCategory == category;
    
    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: isSelected ? Colors.white : AppTheme.textColor,
        ),
      ),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedCategory = selected ? category : null;
        });
        _updateFilteredConditions();
      },
      backgroundColor: Colors.grey[100],
      selectedColor: AppTheme.primaryColor,
      checkmarkColor: Colors.white,
      side: BorderSide(
        color: isSelected ? AppTheme.primaryColor : AppTheme.borderColor,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Icon(
            Icons.search_off,
            size: 48,
            color: AppTheme.textColor.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty 
              ? 'No conditions found for "$_searchQuery"'
              : 'No conditions available',
            style: TextStyle(
              fontSize: 16,
              color: AppTheme.textColor.withOpacity(0.6),
            ),
            textAlign: TextAlign.center,
          ),
          if (_searchQuery.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Try adjusting your search terms',
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.textColor.withOpacity(0.5),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildConditionsGrid() {
    return Container(
      constraints: const BoxConstraints(maxHeight: 400),
      child: Scrollbar(
        controller: _scrollController,
        thumbVisibility: true,
        child: SingleChildScrollView(
          controller: _scrollController,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _filteredConditions.map((condition) {
              final isSelected = widget.selectedConditionIds.contains(condition.id);
              
              return _buildConditionChip(condition, isSelected);
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildConditionChip(PMBCondition condition, bool isSelected) {
    return GestureDetector(
      onTap: () => _toggleCondition(condition.id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor : Colors.grey[50],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor : AppTheme.borderColor,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected ? [
            BoxShadow(
              color: AppTheme.primaryColor.withOpacity(0.3),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ] : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected) ...[
              const Icon(
                Icons.check_circle,
                size: 16,
                color: Colors.white,
              ),
              const SizedBox(width: 6),
            ],
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    condition.name,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white : AppTheme.textColor,
                    ),
                  ),
                  if (condition.description.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      condition.description,
                      style: TextStyle(
                        fontSize: 11,
                        color: isSelected 
                          ? Colors.white.withOpacity(0.9)
                          : AppTheme.textColor.withOpacity(0.6),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 2),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isSelected 
                        ? Colors.white.withOpacity(0.2)
                        : AppTheme.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      condition.category,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: isSelected 
                          ? Colors.white
                          : AppTheme.primaryColor,
                      ),
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
}
