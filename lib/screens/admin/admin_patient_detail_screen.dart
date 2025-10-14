import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/patient.dart';
import '../../theme/app_theme.dart';

/// Admin Patient Detail Screen
/// Displays comprehensive patient information including all sessions and session data
class AdminPatientDetailScreen extends StatelessWidget {
  final Patient patient;

  const AdminPatientDetailScreen({
    super.key,
    required this.patient,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text('${patient.fullNames} ${patient.surname}'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.print),
            onPressed: () => _exportPatientData(context),
            tooltip: 'Export Patient Data',
          ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () => _sharePatientData(context),
            tooltip: 'Share',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPatientInfoCard(),
            const SizedBox(height: 24),
            _buildWoundInformationCard(),
            const SizedBox(height: 24),
            _buildSessionsOverviewCard(),
            const SizedBox(height: 24),
            _buildSessionsList(),
          ],
        ),
      ),
    );
  }

  Widget _buildPatientInfoCard() {
    final age = _calculateAge(patient.dateOfBirth);
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
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
                radius: 40,
                backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                child: Text(
                  '${patient.fullNames[0]}${patient.surname[0]}',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${patient.fullNames} ${patient.surname}',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$age years old • ${_getGender()}',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Patient ID: ${patient.id}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),
              _buildStatusBadge(),
            ],
          ),
          const Divider(height: 32),
          Row(
            children: [
              Expanded(
                child: _buildInfoItem(
                  Icons.phone,
                  'Contact',
                  patient.patientCell,
                ),
              ),
              Expanded(
                child: _buildInfoItem(
                  Icons.medical_information,
                  'Medical Aid',
                  patient.medicalAidSchemeName,
                ),
              ),
              Expanded(
                child: _buildInfoItem(
                  Icons.numbers,
                  'Medical Aid Number',
                  patient.medicalAidNumber,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildInfoItem(
                  Icons.location_on,
                  'Location',
                  '${patient.province ?? "Unknown Province"}, ${patient.countryName ?? "Unknown"}',
                ),
              ),
              Expanded(
                child: _buildInfoItem(
                  Icons.calendar_today,
                  'Registered',
                  _formatDate(patient.createdAt),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWoundInformationCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.healing, color: AppTheme.primaryColor, size: 28),
              const SizedBox(width: 12),
              const Text(
                'Wound Information',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const Divider(height: 32),
          if (patient.currentWounds.isNotEmpty)
            ...patient.currentWounds.map((wound) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildInfoItem(
                        Icons.label,
                        'Wound Type',
                        wound.type,
                      ),
                    ),
                    Expanded(
                      child: _buildInfoItem(
                        Icons.location_on_outlined,
                        'Location',
                        wound.location,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildInfoItem(
                        Icons.straighten,
                        'Size',
                        '${wound.length.toStringAsFixed(1)} x ${wound.width.toStringAsFixed(1)} cm',
                      ),
                    ),
                    Expanded(
                      child: _buildInfoItem(
                        Icons.layers,
                        'Depth',
                        '${wound.depth.toStringAsFixed(1)} cm',
                      ),
                    ),
                  ],
                ),
                if (wound.description.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _buildInfoItem(
                    Icons.note,
                    'Description',
                    wound.description,
                  ),
                ],
                if (patient.currentWounds.length > 1 && wound != patient.currentWounds.last)
                  const Divider(height: 32),
              ],
            )).toList()
          else
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  'No wound information available',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSessionsOverviewCard() {
    final totalSessions = patient.sessions.length;
    final completedSessions = patient.sessions.length; // All recorded sessions are considered complete
    final averageWoundImprovement = _calculateAverageImprovement();
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.analytics, color: AppTheme.primaryColor, size: 28),
              const SizedBox(width: 12),
              const Text(
                'Treatment Overview',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const Divider(height: 32),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Total Sessions',
                  totalSessions.toString(),
                  Icons.event,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatCard(
                  'Completed',
                  completedSessions.toString(),
                  Icons.check_circle,
                  Colors.green,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatCard(
                  'Avg. Improvement',
                  '${averageWoundImprovement.toStringAsFixed(1)}%',
                  Icons.trending_up,
                  Colors.orange,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSessionsList() {
    if (patient.sessions.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.event_busy, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                'No Sessions Recorded',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Sort sessions by date (newest first)
    final sortedSessions = List<Session>.from(patient.sessions)
      ..sort((a, b) => b.date.compareTo(a.date));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.history, color: AppTheme.primaryColor, size: 28),
            const SizedBox(width: 12),
            const Text(
              'Session History',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ...sortedSessions.asMap().entries.map((entry) {
          final index = entry.key;
          final session = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _buildSessionCard(session, index + 1, sortedSessions.length),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildSessionCard(Session session, int sessionNumber, int totalSessions) {
    final reversedNumber = totalSessions - sessionNumber + 1;
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: Colors.green.withOpacity(0.1),
          child: Text(
            '#$reversedNumber',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.green,
            ),
          ),
        ),
        title: Text(
          _formatDate(session.date),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          'Session #${session.sessionNumber}',
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 12,
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Session Measurements',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 12),
                _buildSessionDetailRow('Weight', '${session.weight.toStringAsFixed(1)} kg'),
                _buildSessionDetailRow('VAS Pain Score', '${session.vasScore}/10'),
                const Divider(height: 24),
                const Text(
                  'Wound Assessment',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 12),
                if (session.wounds.isNotEmpty) ...[
                  ...session.wounds.map((wound) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${wound.location} - ${wound.type}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        _buildSessionDetailRow('Size', '${wound.length.toStringAsFixed(1)} x ${wound.width.toStringAsFixed(1)} cm'),
                        _buildSessionDetailRow('Depth', '${wound.depth.toStringAsFixed(1)} cm'),
                        _buildSessionDetailRow('Stage', wound.stage.description),
                        if (wound.description.isNotEmpty)
                          _buildSessionDetailRow('Description', wound.description),
                      ],
                    ),
                  )).toList(),
                ] else
                  const Text('No wounds assessed in this session', style: TextStyle(color: Colors.grey)),
                const Divider(height: 24),
                if (session.notes.isNotEmpty) ...[
                  const Text(
                    'Practitioner Notes',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(session.notes),
                  ),
                ],
                if (session.photos.isNotEmpty) ...[
                  const Divider(height: 24),
                  const Text(
                    'Session Images',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: session.photos.map((imageUrl) => Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Icon(
                            Icons.image_not_supported,
                            color: Colors.grey[400],
                          ),
                        ),
                      ),
                    )).toList(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionDetailRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 14,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: Colors.grey[600]),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[700],
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge() {
    final hasRecentSession = patient.sessions.isNotEmpty && 
        DateTime.now().difference(patient.sessions.last.date).inDays < 30;
    final status = hasRecentSession ? 'Active' : 'Inactive';
    final color = hasRecentSession ? Colors.green : Colors.grey;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  int _calculateAge(DateTime? dateOfBirth) {
    if (dateOfBirth == null) return 0;
    final now = DateTime.now();
    int age = now.year - dateOfBirth.year;
    if (now.month < dateOfBirth.month || 
        (now.month == dateOfBirth.month && now.day < dateOfBirth.day)) {
      age--;
    }
    return age;
  }

  String _getGender() {
    // Derive gender from South African ID number (position 7 indicates gender)
    // 0-4999 = Female, 5000-9999 = Male
    if (patient.idNumber.length >= 10) {
      final genderDigit = int.tryParse(patient.idNumber.substring(6, 10)) ?? 0;
      return genderDigit >= 5000 ? 'Male' : 'Female';
    }
    return 'Unknown';
  }

  String _formatDate(DateTime date) {
    return DateFormat('dd MMM yyyy').format(date);
  }

  double _calculateAverageImprovement() {
    if (patient.sessions.isEmpty || patient.sessions.length < 2) return 0.0;
    
    // Calculate improvement based on wound size reduction over sessions
    final firstSession = patient.sessions.first;
    final lastSession = patient.sessions.last;
    
    if (firstSession.wounds.isEmpty || lastSession.wounds.isEmpty) return 0.0;
    
    // Calculate average wound size for first and last sessions
    final firstSize = firstSession.wounds.fold<double>(
      0.0, 
      (sum, w) => sum + (w.length * w.width)
    ) / firstSession.wounds.length;
    
    final lastSize = lastSession.wounds.fold<double>(
      0.0, 
      (sum, w) => sum + (w.length * w.width)
    ) / lastSession.wounds.length;
    
    if (firstSize == 0) return 0.0;
    
    // Calculate percentage improvement
    final improvement = ((firstSize - lastSize) / firstSize) * 100;
    return improvement.clamp(0.0, 100.0);
  }

  void _exportPatientData(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Exporting patient data...'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _sharePatientData(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Sharing patient data...'),
        backgroundColor: Colors.blue,
      ),
    );
  }
}

