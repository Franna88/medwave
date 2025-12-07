import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/streams/appointment.dart' as models;
import '../../../models/streams/stream_stage.dart';
import '../../../services/firebase/sales_appointment_service.dart';
import '../../../providers/auth_provider.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/stream_utils.dart';

class SalesStreamScreen extends StatefulWidget {
  const SalesStreamScreen({super.key});

  @override
  State<SalesStreamScreen> createState() => _SalesStreamScreenState();
}

class _SalesStreamScreenState extends State<SalesStreamScreen> {
  final SalesAppointmentService _appointmentService = SalesAppointmentService();
  final TextEditingController _searchController = TextEditingController();

  List<models.SalesAppointment> _allAppointments = [];
  List<models.SalesAppointment> _filteredAppointments = [];
  bool _isLoading = true;
  String _searchQuery = '';

  final List<StreamStage> _stages = StreamStage.getSalesStages();

  @override
  void initState() {
    super.initState();
    _loadAppointments();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _loadAppointments() {
    _appointmentService.appointmentsStream().listen((appointments) {
      setState(() {
        _allAppointments = appointments;
        _filterAppointments();
        _isLoading = false;
      });
    });
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase();
      _filterAppointments();
    });
  }

  void _filterAppointments() {
    if (_searchQuery.isEmpty) {
      _filteredAppointments = _allAppointments;
    } else {
      _filteredAppointments = _allAppointments.where((appointment) {
        return appointment.customerName.toLowerCase().contains(_searchQuery) ||
            appointment.email.toLowerCase().contains(_searchQuery) ||
            appointment.phone.contains(_searchQuery);
      }).toList();
    }
  }

  List<models.SalesAppointment> _getAppointmentsForStage(String stageId) {
    return _filteredAppointments
        .where((apt) => apt.currentStage == stageId)
        .toList();
  }

  Future<void> _moveAppointmentToStage(
    models.SalesAppointment appointment,
    String newStageId,
  ) async {
    final newStage = _stages.firstWhere((s) => s.id == newStageId);
    final oldStage = _stages.firstWhere(
      (s) => s.id == appointment.currentStage,
    );

    final authProvider = context.read<AuthProvider>();
    final userId = authProvider.user?.uid ?? '';
    final userName = authProvider.userName;

    final noteController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Move ${appointment.customerName}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('From: ${oldStage.name}'),
            Text('To: ${newStage.name}'),
            const SizedBox(height: 16),
            TextField(
              controller: noteController,
              decoration: const InputDecoration(
                labelText: 'Note (optional)',
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
            child: const Text('Move'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _appointmentService.moveAppointmentToStage(
          appointmentId: appointment.id,
          newStage: newStageId,
          note: noteController.text.isEmpty
              ? 'Moved to ${newStage.name}'
              : noteController.text,
          userId: userId,
          userName: userName,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${appointment.customerName} moved to ${newStage.name}',
              ),
            ),
          );

          // Show success message if converted to order
          if (newStageId == 'send_to_operations') {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Appointment converted to Operations order!'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 3),
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error moving appointment: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildKanbanBoard(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final totalAppointments = _filteredAppointments.length;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Sales Stream',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              // Search
              Container(
                width: 300,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search appointments...',
                    hintStyle: TextStyle(fontSize: 14, color: Colors.grey[400]),
                    prefixIcon: Icon(Icons.search, color: Colors.grey[400]),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Count badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.attach_money,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$totalAppointments appointments',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Appointments from Marketing booking stage',
            style: TextStyle(fontSize: 14, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _buildKanbanBoard() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.all(24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: _stages.map((stage) {
          final appointments = _getAppointmentsForStage(stage.id);
          return _buildStageColumn(stage, appointments);
        }).toList(),
      ),
    );
  }

  Widget _buildStageColumn(
    StreamStage stage,
    List<models.SalesAppointment> appointments,
  ) {
    return Container(
      width: 320,
      margin: const EdgeInsets.only(right: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stage header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Color(int.parse(stage.color.replaceFirst('#', '0xff'))),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    stage.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${appointments.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Appointments list with DragTarget
          Expanded(
            child: DragTarget<models.SalesAppointment>(
              onWillAcceptWithDetails: (details) {
                // Only allow forward movement to next immediate stage
                return StreamUtils.canMoveToStage(
                  details.data.currentStage,
                  stage.id,
                  _stages,
                );
              },
              onAcceptWithDetails: (details) =>
                  _moveAppointmentToStage(details.data, stage.id),
              builder: (context, candidateData, rejectedData) {
                return Container(
                  decoration: BoxDecoration(
                    color: candidateData.isNotEmpty
                        ? Color(
                            int.parse(stage.color.replaceFirst('#', '0xff')),
                          ).withOpacity(0.1)
                        : Colors.white,
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(12),
                    ),
                    border: Border.all(
                      color: candidateData.isNotEmpty
                          ? Color(
                              int.parse(stage.color.replaceFirst('#', '0xff')),
                            )
                          : Colors.grey.shade200,
                      width: candidateData.isNotEmpty ? 2 : 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: appointments.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              'No appointments in ${stage.name.toLowerCase()}',
                              style: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 14,
                              ),
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: appointments.length,
                          itemBuilder: (context, index) {
                            final appointment = appointments[index];
                            final isFinal = StreamUtils.isFinalStage(
                              appointment.currentStage,
                              _stages,
                            );
                            final card = _buildAppointmentCard(appointment);

                            // Gray out final stage cards
                            final styledCard = isFinal
                                ? Opacity(opacity: 0.6, child: card)
                                : card;

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: isFinal
                                  ? styledCard // Non-draggable for final stage
                                  : Draggable<models.SalesAppointment>(
                                      data: appointment,
                                      feedback: Material(
                                        elevation: 8,
                                        borderRadius: BorderRadius.circular(12),
                                        child: SizedBox(
                                          width: 280,
                                          child: Opacity(
                                            opacity: 0.8,
                                            child: _buildAppointmentCard(
                                              appointment,
                                            ),
                                          ),
                                        ),
                                      ),
                                      childWhenDragging: Opacity(
                                        opacity: 0.3,
                                        child: _buildAppointmentCard(
                                          appointment,
                                        ),
                                      ),
                                      child: styledCard,
                                    ),
                            );
                          },
                        ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppointmentCard(models.SalesAppointment appointment) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                child: Text(
                  appointment.customerName.isNotEmpty
                      ? appointment.customerName[0].toUpperCase()
                      : 'A',
                  style: TextStyle(
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      appointment.customerName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      appointment.email,
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (appointment.appointmentDate != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.calendar_today, size: 14, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  '${appointment.appointmentDate!.day}/${appointment.appointmentDate!.month}/${appointment.appointmentDate!.year}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.access_time, size: 12, color: Colors.grey[400]),
              const SizedBox(width: 4),
              Text(
                appointment.timeInStageDisplay,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              const Spacer(),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, size: 18, color: Colors.grey[600]),
                onSelected: (stageId) =>
                    _moveAppointmentToStage(appointment, stageId),
                itemBuilder: (context) => _stages
                    .where((s) => s.id != appointment.currentStage)
                    .map(
                      (stage) => PopupMenuItem(
                        value: stage.id,
                        child: Text('Move to ${stage.name}'),
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
