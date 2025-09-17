import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../models/patient.dart';
import '../../theme/app_theme.dart';
import '../ai/ai_report_chat_screen.dart';
import '../../services/firebase/patient_service.dart';
import '../../services/wound_management_service.dart';
import '../../widgets/wound_progress_card.dart';
import '../../widgets/multi_wound_summary.dart';
import '../../widgets/firebase_image.dart';

class SessionDetailScreen extends StatefulWidget {
  final String patientId;
  final String sessionId;
  final Patient patient;
  final Session session;

  const SessionDetailScreen({
    super.key,
    required this.patientId,
    required this.sessionId,
    required this.patient,
    required this.session,
  });

  @override
  State<SessionDetailScreen> createState() => _SessionDetailScreenState();
}

class _SessionDetailScreenState extends State<SessionDetailScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  Session? _previousSession;
  List<Session> _allSessions = [];
  bool _isLoadingSessions = true;
  bool _isMultiWound = false;
  int _expandedWoundIndex = 0;

  @override
  void initState() {
    super.initState();
    _isMultiWound = WoundManagementService.hasMultipleWounds(widget.patient);
    _tabController = TabController(length: _isMultiWound ? 4 : 3, vsync: this);
    _loadAllSessions();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAllSessions() async {
    try {
      print('🔍 DEBUG: Loading all sessions for patient ${widget.patientId}...');
      _allSessions = await PatientService.getPatientSessions(widget.patientId);
      print('✅ DEBUG: Loaded ${_allSessions.length} sessions from Firebase');
      
      if (mounted) {
        setState(() {
          _isLoadingSessions = false;
        });
        _findPreviousSession();
      }
    } catch (e) {
      print('❌ DEBUG: Error loading sessions: $e');
      // Fallback to using the sessions from the patient object
      _allSessions = widget.patient.sessions;
      if (mounted) {
        setState(() {
          _isLoadingSessions = false;
        });
        _findPreviousSession();
      }
    }
  }

  void _findPreviousSession() {
    print('🔍 DEBUG: Finding previous session...');
    print('🔍 DEBUG: Current session number: ${widget.session.sessionNumber}');
    print('🔍 DEBUG: Total sessions available: ${_allSessions.length}');
    
    // Try to find by session number first (more reliable)
    final previousByNumber = _allSessions
        .where((s) => s.sessionNumber < widget.session.sessionNumber)
        .toList();
    previousByNumber.sort((a, b) => b.sessionNumber.compareTo(a.sessionNumber));
    
    if (previousByNumber.isNotEmpty) {
      _previousSession = previousByNumber.first;
      print('✅ DEBUG: Found previous session by number: ${_previousSession!.sessionNumber}');
      return;
    }
    
    // Fallback to date-based search
    final sessions = _allSessions
        .where((s) => s.date.isBefore(widget.session.date))
        .toList();
    sessions.sort((a, b) => b.date.compareTo(a.date));
    
    if (sessions.isNotEmpty) {
      _previousSession = sessions.first;
      print('✅ DEBUG: Found previous session by date: ${_previousSession!.sessionNumber}');
    } else {
      print('❌ DEBUG: No previous session found');
      print('🔍 DEBUG: Available session numbers: ${_allSessions.map((s) => s.sessionNumber).toList()}');
    }
  }

  void _generateAIReport() {
    HapticFeedback.mediumImpact();
    
    // Show confirmation dialog first
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.smart_toy, color: AppTheme.primaryColor),
            SizedBox(width: 12),
            Text('Generate AI Report'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Generate a clinical motivation report for ${widget.patient.name}?',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, 
                           color: AppTheme.primaryColor, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'This will use patient data from their file and ask 3-5 questions about this session.',
                          style: TextStyle(
                            color: AppTheme.primaryColor,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.schedule, 
                           color: AppTheme.primaryColor, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Estimated time: 2-3 minutes',
                          style: TextStyle(
                            color: AppTheme.primaryColor,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              _launchAIChat();
            },
            icon: const Icon(Icons.smart_toy),
            label: const Text('Start AI Chat'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
            ),
          ),
        ],
      ),
    );
  }

  void _launchAIChat() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AIReportChatScreen(
          patientId: widget.patientId,
          sessionId: widget.sessionId,
          patient: widget.patient,
          session: widget.session,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          _buildSliverAppBar(),
        ],
        body: _buildTabBarView(),
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 200,
      collapsedHeight: 80,
      floating: false,
      pinned: true,
      backgroundColor: Colors.white,
      foregroundColor: AppTheme.textColor,
      elevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle.dark,
      leading: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.9),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Icon(Icons.arrow_back, color: AppTheme.textColor),
        ),
        onPressed: () {
          HapticFeedback.lightImpact();
          context.pop();
        },
      ),
      title: Text(
        'Session ${widget.session.sessionNumber}',
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: AppTheme.textColor,
        ),
      ),
      actions: [
        Container(
          margin: const EdgeInsets.only(right: 16),
          child: IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryColor.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(Icons.smart_toy, color: Colors.white, size: 20),
            ),
            onPressed: _generateAIReport,
            tooltip: 'Generate AI Report',
          ),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppTheme.primaryColor.withOpacity(0.1),
                Colors.white,
              ],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 80, 20, 20),
              child: Column(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.primaryColor.withOpacity(0.8),
                          AppTheme.primaryColor,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryColor.withOpacity(0.3),
                          offset: const Offset(0, 8),
                          blurRadius: 16,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.medical_services,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    DateFormat('EEEE, MMM d, yyyy').format(widget.session.date),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textColor,
                    ),
                  ),
                  if (_previousSession != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Compared to Session ${_previousSession!.sessionNumber}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.secondaryColor,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(50),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: TabBar(
            controller: _tabController,
            labelColor: AppTheme.primaryColor,
            unselectedLabelColor: AppTheme.secondaryColor,
            indicatorColor: AppTheme.primaryColor,
            indicatorWeight: 3,
            labelStyle: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
            tabs: [
              const Tab(text: 'Overview', icon: Icon(Icons.dashboard_outlined, size: 20)),
              if (_isMultiWound)
                const Tab(text: 'Wounds', icon: Icon(Icons.medical_information_outlined, size: 20)),
              const Tab(text: 'Comparisons', icon: Icon(Icons.compare_arrows, size: 20)),
              const Tab(text: 'Photos', icon: Icon(Icons.photo_library_outlined, size: 20)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabBarView() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
      ),
      child: TabBarView(
        controller: _tabController,
        children: [
          _buildOverviewTab(),
          if (_isMultiWound) _buildWoundsTab(),
          _buildComparisonsTab(),
          _buildPhotosTab(),
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _buildSessionMetricsCard(),
          const SizedBox(height: 20),
          if (_isMultiWound) 
            MultiWoundSummary(
              currentWounds: widget.session.wounds,
              previousWounds: _previousSession?.wounds,
              currentSession: widget.session,
              previousSession: _previousSession,
            )
          else
            _buildWoundDetailsCard(),
          const SizedBox(height: 20),
          if (widget.session.notes.isNotEmpty) _buildNotesCard(),
        ],
      ),
    );
  }

  Widget _buildWoundsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Individual Wound Assessment',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textColor,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${widget.session.wounds.length} wounds',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Detailed assessment of each wound with progress tracking',
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.secondaryColor,
            ),
          ),
          const SizedBox(height: 24),
          
          // Individual wound cards
          ...widget.session.wounds.asMap().entries.map((entry) {
            final index = entry.key;
            final wound = entry.value;
            final previousWound = _findMatchingPreviousWound(wound);
            
            return WoundProgressCard(
              currentWound: wound,
              previousWound: previousWound,
              woundIndex: index,
              isExpanded: _expandedWoundIndex == index,
              onToggleExpanded: () {
                setState(() {
                  _expandedWoundIndex = _expandedWoundIndex == index ? -1 : index;
                });
              },
            );
          }).toList(),
        ],
      ),
    );
  }

  Wound? _findMatchingPreviousWound(Wound currentWound) {
    if (_previousSession == null || _previousSession!.wounds.isEmpty) {
      return null;
    }
    
    // Try to find wound by ID first
    try {
      return _previousSession!.wounds.firstWhere((w) => w.id == currentWound.id);
    } catch (e) {
      // If no ID match, return null (no previous wound data)
      return null;
    }
  }

  Widget _buildSessionMetricsCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            offset: const Offset(0, 2),
            blurRadius: 8,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Session Metrics',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.textColor,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _buildMetricTile(
                    'Weight',
                    '${widget.session.weight.toStringAsFixed(1)} kg',
                    Icons.monitor_weight_outlined,
                    AppTheme.infoColor,
                    _getWeightChange(),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildMetricTile(
                    'Pain Score',
                    '${widget.session.vasScore}/10',
                    Icons.healing_outlined,
                    _getPainColor(widget.session.vasScore),
                    _getPainChange(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildMetricTile(
                    'Photos',
                    '${widget.session.photos.length}',
                    Icons.photo_camera_outlined,
                    AppTheme.secondaryColor,
                    null,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildMetricTile(
                    'Session #',
                    '${widget.session.sessionNumber}',
                    Icons.numbers_outlined,
                    AppTheme.primaryColor,
                    null,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricTile(String label, String value, IconData icon, Color color, String? change) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          if (change != null) ...[
            const SizedBox(height: 4),
            Text(
              change,
              style: TextStyle(
                fontSize: 10,
                color: change.startsWith('+') ? AppTheme.errorColor : 
                       change.startsWith('-') ? AppTheme.successColor : 
                       AppTheme.secondaryColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildWoundDetailsCard() {
    if (widget.session.wounds.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            offset: const Offset(0, 2),
            blurRadius: 8,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Wound Assessment',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.textColor,
              ),
            ),
            const SizedBox(height: 20),
            ...widget.session.wounds.map((wound) => _buildWoundTile(wound)),
          ],
        ),
      ),
    );
  }

  Widget _buildWoundTile(Wound wound) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getWoundStageColor(wound.stage).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _getWoundStageColor(wound.stage).withOpacity(0.3)),
                ),
                child: Text(
                  wound.stage.description,
                  style: TextStyle(
                    color: _getWoundStageColor(wound.stage),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                '${wound.area.toStringAsFixed(1)} cm²',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${wound.location} - ${wound.type}',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 16,
              color: AppTheme.textColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${wound.length} × ${wound.width} × ${wound.depth} cm',
            style: const TextStyle(
              color: AppTheme.secondaryColor,
              fontSize: 14,
            ),
          ),
          if (wound.description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              wound.description,
              style: const TextStyle(
                color: AppTheme.secondaryColor,
                fontSize: 14,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNotesCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            offset: const Offset(0, 2),
            blurRadius: 8,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.notes_outlined, size: 20, color: AppTheme.primaryColor),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Session Notes',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.cardColor.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                widget.session.notes,
                style: const TextStyle(
                  fontSize: 16,
                  color: AppTheme.textColor,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComparisonsTab() {
    if (_isLoadingSessions) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
              ),
              SizedBox(height: 24),
              Text(
                'Loading Session Data...',
                style: TextStyle(
                  fontSize: 16,
                  color: AppTheme.secondaryColor,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_previousSession == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: AppTheme.secondaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(50),
                ),
                child: Icon(
                  Icons.compare_arrows,
                  size: 50,
                  color: AppTheme.secondaryColor.withOpacity(0.7),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'No Previous Session',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textColor,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'This is the first session for this patient',
                style: TextStyle(
                  fontSize: 16,
                  color: AppTheme.secondaryColor,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _buildComparisonSummaryCard(),
          const SizedBox(height: 20),
          _buildWeightComparisonChart(),
          const SizedBox(height: 20),
          _buildPainComparisonChart(),
          const SizedBox(height: 20),
          _buildWoundComparisonCard(),
        ],
      ),
    );
  }

  Widget _buildComparisonSummaryCard() {
    final weightChange = widget.session.weight - _previousSession!.weight;
    final painChange = widget.session.vasScore - _previousSession!.vasScore;
    final daysBetween = widget.session.date.difference(_previousSession!.date).inDays;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primaryColor.withOpacity(0.1),
            AppTheme.primaryColor.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.compare_arrows,
                    color: AppTheme.primaryColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Session Comparison',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textColor,
                        ),
                      ),
                      Text(
                        '$daysBetween days since last session',
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppTheme.secondaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _buildComparisonMetric(
                    'Weight Change',
                    '${weightChange >= 0 ? '+' : ''}${weightChange.toStringAsFixed(1)} kg',
                    Icons.monitor_weight_outlined,
                    weightChange == 0 ? AppTheme.secondaryColor :
                    weightChange > 0 ? AppTheme.warningColor : AppTheme.successColor,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildComparisonMetric(
                    'Pain Change',
                    '${painChange >= 0 ? '+' : ''}$painChange points',
                    Icons.healing_outlined,
                    painChange == 0 ? AppTheme.secondaryColor :
                    painChange > 0 ? AppTheme.errorColor : AppTheme.successColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComparisonMetric(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeightComparisonChart() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            offset: const Offset(0, 2),
            blurRadius: 8,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.infoColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.monitor_weight_outlined, size: 20, color: AppTheme.infoColor),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Weight Comparison',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              height: 200,
              margin: const EdgeInsets.symmetric(horizontal: 8),
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: [_previousSession!.weight, widget.session.weight].reduce((a, b) => a > b ? a : b) * 1.1,
                  barTouchData: BarTouchData(enabled: false),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          switch (value.toInt()) {
                            case 0:
                              return Text(
                                'Session ${_previousSession!.sessionNumber}',
                                style: const TextStyle(
                                  color: AppTheme.secondaryColor,
                                  fontSize: 12,
                                ),
                              );
                            case 1:
                              return Text(
                                'Session ${widget.session.sessionNumber}',
                                style: const TextStyle(
                                  color: AppTheme.secondaryColor,
                                  fontSize: 12,
                                ),
                              );
                            default:
                              return const Text('');
                          }
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 50,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            '${value.toStringAsFixed(0)}kg',
                            style: const TextStyle(
                              color: AppTheme.secondaryColor,
                              fontSize: 12,
                            ),
                          );
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: [
                    BarChartGroupData(
                      x: 0,
                      barRods: [
                        BarChartRodData(
                          toY: _previousSession!.weight,
                          color: AppTheme.secondaryColor.withOpacity(0.7),
                          width: 40,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                        ),
                      ],
                    ),
                    BarChartGroupData(
                      x: 1,
                      barRods: [
                        BarChartRodData(
                          toY: widget.session.weight,
                          color: AppTheme.infoColor,
                          width: 40,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPainComparisonChart() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            offset: const Offset(0, 2),
            blurRadius: 8,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.errorColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.healing_outlined, size: 20, color: AppTheme.errorColor),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Pain Score Comparison',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              height: 200,
              margin: const EdgeInsets.symmetric(horizontal: 8),
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: 10,
                  barTouchData: BarTouchData(enabled: false),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          switch (value.toInt()) {
                            case 0:
                              return Text(
                                'Session ${_previousSession!.sessionNumber}',
                                style: const TextStyle(
                                  color: AppTheme.secondaryColor,
                                  fontSize: 12,
                                ),
                              );
                            case 1:
                              return Text(
                                'Session ${widget.session.sessionNumber}',
                                style: const TextStyle(
                                  color: AppTheme.secondaryColor,
                                  fontSize: 12,
                                ),
                              );
                            default:
                              return const Text('');
                          }
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        interval: 2,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            value.toInt().toString(),
                            style: const TextStyle(
                              color: AppTheme.secondaryColor,
                              fontSize: 12,
                            ),
                          );
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: [
                    BarChartGroupData(
                      x: 0,
                      barRods: [
                        BarChartRodData(
                          toY: _previousSession!.vasScore.toDouble(),
                          color: AppTheme.secondaryColor.withOpacity(0.7),
                          width: 40,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                        ),
                      ],
                    ),
                    BarChartGroupData(
                      x: 1,
                      barRods: [
                        BarChartRodData(
                          toY: widget.session.vasScore.toDouble(),
                          color: _getPainColor(widget.session.vasScore),
                          width: 40,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWoundComparisonCard() {
    // Get wound comparison data
    final currentWounds = widget.session.wounds;
    final previousWounds = _previousSession?.wounds ?? [];
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            offset: const Offset(0, 2),
            blurRadius: 8,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.warningColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.healing, size: 20, color: AppTheme.warningColor),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Wound Progress',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (currentWounds.isEmpty && previousWounds.isEmpty)
              _buildNoWoundsMessage()
            else if (previousWounds.isEmpty)
              _buildFirstSessionWounds(currentWounds)
            else
              _buildWoundProgressComparison(currentWounds, previousWounds),
          ],
        ),
      ),
    );
  }

  Widget _buildNoWoundsMessage() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.successColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.successColor.withOpacity(0.2)),
      ),
      child: const Row(
        children: [
          Icon(Icons.check_circle_outline, color: AppTheme.successColor, size: 24),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'No wounds recorded in this session',
              style: TextStyle(
                fontSize: 16,
                color: AppTheme.successColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFirstSessionWounds(List<Wound> wounds) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.infoColor.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline, color: AppTheme.infoColor, size: 20),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Baseline measurements - no previous session to compare',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.infoColor,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ...wounds.map((wound) => _buildWoundBaselineCard(wound)),
      ],
    );
  }

  Widget _buildWoundBaselineCard(Wound wound) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getWoundStageColor(wound.stage).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _getWoundStageColor(wound.stage).withOpacity(0.3)),
                ),
                child: Text(
                  wound.stage.description,
                  style: TextStyle(
                    color: _getWoundStageColor(wound.stage),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                '${wound.area.toStringAsFixed(1)} cm²',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${wound.location} - ${wound.type}',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 16,
              color: AppTheme.textColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${wound.length} × ${wound.width} × ${wound.depth} cm',
            style: const TextStyle(
              color: AppTheme.secondaryColor,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWoundProgressComparison(List<Wound> currentWounds, List<Wound> previousWounds) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Overall progress summary
        _buildOverallWoundProgress(currentWounds, previousWounds),
        const SizedBox(height: 20),
        // Individual wound comparisons
        const Text(
          'Individual Wound Progress',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppTheme.textColor,
          ),
        ),
        const SizedBox(height: 12),
        ..._buildIndividualWoundComparisons(currentWounds, previousWounds),
      ],
    );
  }

  Widget _buildOverallWoundProgress(List<Wound> currentWounds, List<Wound> previousWounds) {
    final totalPreviousArea = previousWounds.fold(0.0, (sum, wound) => sum + wound.area);
    final totalCurrentArea = currentWounds.fold(0.0, (sum, wound) => sum + wound.area);
    final areaChange = totalCurrentArea - totalPreviousArea;
    final percentageChange = totalPreviousArea > 0 ? (areaChange / totalPreviousArea) * 100 : 0.0;
    
    final healingColor = areaChange < 0 ? AppTheme.successColor : 
                       areaChange > 0 ? AppTheme.errorColor : AppTheme.secondaryColor;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            healingColor.withOpacity(0.1),
            healingColor.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: healingColor.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                areaChange < 0 ? Icons.trending_down : 
                areaChange > 0 ? Icons.trending_up : Icons.trending_flat,
                color: healingColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                'Overall Progress',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildProgressMetric(
                  'Total Area',
                  '${totalCurrentArea.toStringAsFixed(1)} cm²',
                  '${areaChange >= 0 ? '+' : ''}${areaChange.toStringAsFixed(1)} cm²',
                  healingColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildProgressMetric(
                  'Change',
                  '${percentageChange.toStringAsFixed(1)}%',
                  areaChange < 0 ? 'Healing' : areaChange > 0 ? 'Enlarging' : 'Stable',
                  healingColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgressMetric(String label, String value, String subtitle, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 10,
              color: color.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildIndividualWoundComparisons(List<Wound> currentWounds, List<Wound> previousWounds) {
    final comparisons = <Widget>[];
    
    // Match wounds by location and type for comparison
    for (final currentWound in currentWounds) {
      final matchingPrevious = previousWounds.cast<Wound?>().firstWhere(
        (prevWound) => prevWound?.location == currentWound.location && 
                      prevWound?.type == currentWound.type,
        orElse: () => null,
      );
      
      if (matchingPrevious != null) {
        comparisons.add(_buildWoundComparisonItem(currentWound, matchingPrevious));
      } else {
        comparisons.add(_buildNewWoundItem(currentWound));
      }
    }
    
    // Check for wounds that were present previously but not now (healed)
    for (final previousWound in previousWounds) {
      final stillPresent = currentWounds.any(
        (current) => current.location == previousWound.location && 
                    current.type == previousWound.type,
      );
      if (!stillPresent) {
        comparisons.add(_buildHealedWoundItem(previousWound));
      }
    }
    
    return comparisons;
  }

  Widget _buildWoundComparisonItem(Wound currentWound, Wound previousWound) {
    final areaChange = currentWound.area - previousWound.area;
    final percentageChange = previousWound.area > 0 ? (areaChange / previousWound.area) * 100 : 0.0;
    final stageImproved = currentWound.stage.index < previousWound.stage.index;
    final stageWorsened = currentWound.stage.index > previousWound.stage.index;
    
    final progressColor = areaChange < 0 ? AppTheme.successColor : 
                         areaChange > 0 ? AppTheme.errorColor : AppTheme.secondaryColor;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: progressColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: progressColor.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${currentWound.location} - ${currentWound.type}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: AppTheme.textColor,
                  ),
                ),
              ),
              Icon(
                areaChange < 0 ? Icons.trending_down : 
                areaChange > 0 ? Icons.trending_up : Icons.trending_flat,
                color: progressColor,
                size: 16,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              // Stage comparison
              if (stageImproved || stageWorsened)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: stageImproved ? AppTheme.successColor.withOpacity(0.1) : 
                           AppTheme.warningColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        stageImproved ? Icons.arrow_downward : Icons.arrow_upward,
                        size: 10,
                        color: stageImproved ? AppTheme.successColor : AppTheme.warningColor,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        'Stage ${stageImproved ? 'Improved' : 'Changed'}',
                        style: TextStyle(
                          fontSize: 8,
                          color: stageImproved ? AppTheme.successColor : AppTheme.warningColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              const Spacer(),
              Text(
                '${percentageChange >= 0 ? '+' : ''}${percentageChange.toStringAsFixed(1)}%',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: progressColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Previous: ${previousWound.area.toStringAsFixed(1)} cm²',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.secondaryColor,
                      ),
                    ),
                    Text(
                      'Current: ${currentWound.area.toStringAsFixed(1)} cm²',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${areaChange >= 0 ? '+' : ''}${areaChange.toStringAsFixed(1)} cm²',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: progressColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNewWoundItem(Wound wound) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.warningColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.warningColor.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.add_circle_outline, color: AppTheme.warningColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${wound.location} - ${wound.type}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: AppTheme.textColor,
                  ),
                ),
                Text(
                  'New wound: ${wound.area.toStringAsFixed(1)} cm²',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.secondaryColor,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.warningColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'NEW',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: AppTheme.warningColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHealedWoundItem(Wound wound) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.successColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.successColor.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle_outline, color: AppTheme.successColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${wound.location} - ${wound.type}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: AppTheme.textColor,
                  ),
                ),
                Text(
                  'Previously: ${wound.area.toStringAsFixed(1)} cm²',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.secondaryColor,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.successColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'HEALED',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: AppTheme.successColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotosTab() {
    if (widget.session.photos.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: AppTheme.secondaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(50),
                ),
                child: Icon(
                  Icons.photo_library_outlined,
                  size: 50,
                  color: AppTheme.secondaryColor.withOpacity(0.7),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'No Photos Available',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textColor,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'No photos were taken during this session',
                style: TextStyle(
                  fontSize: 16,
                  color: AppTheme.secondaryColor,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.75, // Reduced to give more height for content
      ),
      itemCount: widget.session.photos.length,
      itemBuilder: (context, index) {
        return _buildSessionPhotoCard(index);
      },
    );
  }

  Widget _buildSessionPhotoCard(int index) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            offset: const Offset(0, 2),
            blurRadius: 8,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            _showSessionPhotoViewer(index);
          },
          borderRadius: BorderRadius.circular(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Photo area
              Expanded(
                flex: 4,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppTheme.cardColor.withOpacity(0.5),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                  ),
                  child: Stack(
                    children: [
                      // Main photo
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(16),
                        ),
                        child: FirebaseImage(
                          imagePath: widget.session.photos[index],
                          fit: BoxFit.cover,
                          loadingWidget: const Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                          errorWidget: const Center(
                            child: Icon(
                              Icons.broken_image_outlined,
                              size: 40,
                              color: AppTheme.secondaryColor,
                            ),
                          ),
                        ),
                      ),
                      // Session badge
                      Positioned(
                        top: 6,
                        left: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.medical_services,
                                size: 10,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                '${widget.session.sessionNumber}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Photo number badge
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.7),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${index + 1}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Info area
              Container(
                height: 60, // Fixed height to prevent overflow
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Photo ${index + 1}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(
                          Icons.access_time,
                          size: 9,
                          color: AppTheme.secondaryColor,
                        ),
                        const SizedBox(width: 3),
                        Expanded(
                          flex: 2,
                          child: Text(
                            DateFormat('MMM d').format(widget.session.date),
                            style: const TextStyle(
                              fontSize: 9,
                              color: AppTheme.secondaryColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Expanded(
                          flex: 1,
                          child: Text(
                            DateFormat('HH:mm').format(widget.session.date),
                            style: const TextStyle(
                              fontSize: 9,
                              color: AppTheme.secondaryColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSessionPhotoViewer(int index) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.9),
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Photo header
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Text(
                    'Session ${widget.session.sessionNumber} - Photo ${index + 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${DateFormat('EEEE, MMM d, yyyy').format(widget.session.date)} at ${DateFormat('HH:mm').format(widget.session.date)}',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            // Photo display
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: FirebaseImage(
                    imagePath: widget.session.photos[index],
                    fit: BoxFit.contain,
                    loadingWidget: const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(
                            color: AppTheme.primaryColor,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Loading photo...',
                            style: TextStyle(
                              color: AppTheme.secondaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    errorWidget: const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.broken_image_outlined,
                            size: 80,
                            color: AppTheme.secondaryColor,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Failed to load photo',
                            style: TextStyle(
                              fontSize: 16,
                              color: AppTheme.secondaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Navigation and close buttons
            Container(
              margin: const EdgeInsets.only(top: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (index > 0)
                    ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        _showSessionPhotoViewer(index - 1);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white.withOpacity(0.9),
                        foregroundColor: AppTheme.textColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Previous'),
                    ),
                  if (index > 0) const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppTheme.textColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Close'),
                  ),
                  if (index < widget.session.photos.length - 1) const SizedBox(width: 16),
                  if (index < widget.session.photos.length - 1)
                    ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        _showSessionPhotoViewer(index + 1);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white.withOpacity(0.9),
                        foregroundColor: AppTheme.textColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Next'),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper methods
  String _getWeightChange() {
    if (_previousSession == null) return '';
    final change = widget.session.weight - _previousSession!.weight;
    return '${change >= 0 ? '+' : ''}${change.toStringAsFixed(1)} kg';
  }

  String _getPainChange() {
    if (_previousSession == null) return '';
    final change = widget.session.vasScore - _previousSession!.vasScore;
    return '${change >= 0 ? '+' : ''}$change points';
  }

  Color _getPainColor(int painScore) {
    if (painScore <= 3) return AppTheme.successColor;
    if (painScore <= 6) return AppTheme.warningColor;
    return AppTheme.errorColor;
  }

  Color _getWoundStageColor(WoundStage stage) {
    switch (stage) {
      case WoundStage.stage1:
        return AppTheme.successColor;
      case WoundStage.stage2:
        return AppTheme.warningColor;
      case WoundStage.stage3:
        return Colors.orange;
      case WoundStage.stage4:
        return AppTheme.errorColor;
      default:
        return AppTheme.secondaryColor;
    }
  }
}

