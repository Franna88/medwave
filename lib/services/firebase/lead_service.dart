import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../models/leads/lead.dart';
import '../../models/leads/lead_note.dart';
import '../../models/leads/lead_channel.dart';
import '../../models/form/form_submission.dart';
import '../../models/streams/appointment.dart' as models;
import 'sales_appointment_service.dart';

/// Service for managing leads in Firebase
class LeadService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final SalesAppointmentService _appointmentService = SalesAppointmentService();

  /// Get all leads
  Future<List<Lead>> getAllLeads({
    String? channelId,
    String? orderBy = 'createdAt',
    bool descending = true,
  }) async {
    try {
      Query query = _firestore.collection('leads');

      if (channelId != null) {
        query = query.where('channelId', isEqualTo: channelId);
      }

      if (orderBy != null) {
        query = query.orderBy(orderBy, descending: descending);
      }

      final snapshot = await query.get();
      return snapshot.docs.map((doc) => Lead.fromFirestore(doc)).toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error getting all leads: $e');
      }
      rethrow;
    }
  }

  /// Get leads by stage
  Future<List<Lead>> getLeadsByStage(String channelId, String stage) async {
    try {
      final snapshot = await _firestore
          .collection('leads')
          .where('channelId', isEqualTo: channelId)
          .where('currentStage', isEqualTo: stage)
          .get();

      final leads = snapshot.docs.map((doc) => Lead.fromFirestore(doc)).toList();
      // Sort in memory to avoid index requirement
      leads.sort((a, b) => a.stageEnteredAt.compareTo(b.stageEnteredAt));
      return leads;
    } catch (e) {
      if (kDebugMode) {
        print('Error getting leads by stage: $e');
      }
      rethrow;
    }
  }

  /// Get leads in follow-up stage by week
  Future<List<Lead>> getLeadsByFollowUpWeek(
      String channelId, String followUpStageId, int week) async {
    try {
      final snapshot = await _firestore
          .collection('leads')
          .where('channelId', isEqualTo: channelId)
          .where('currentStage', isEqualTo: followUpStageId)
          .where('followUpWeek', isEqualTo: week)
          .get();

      final leads = snapshot.docs.map((doc) => Lead.fromFirestore(doc)).toList();
      // Sort in memory to avoid index requirement
      leads.sort((a, b) => a.stageEnteredAt.compareTo(b.stageEnteredAt));
      return leads;
    } catch (e) {
      if (kDebugMode) {
        print('Error getting leads by follow-up week: $e');
      }
      rethrow;
    }
  }

  /// Get a single lead by ID
  Future<Lead?> getLead(String leadId) async {
    try {
      final doc = await _firestore.collection('leads').doc(leadId).get();

      if (!doc.exists) {
        return null;
      }

      return Lead.fromFirestore(doc);
    } catch (e) {
      if (kDebugMode) {
        print('Error getting lead $leadId: $e');
      }
      rethrow;
    }
  }

  /// Stream of all leads for a channel
  Stream<List<Lead>> leadsStream(String channelId) {
    return _firestore
        .collection('leads')
        .where('channelId', isEqualTo: channelId)
        .snapshots()
        .map((snapshot) {
          final leads = snapshot.docs.map((doc) => Lead.fromFirestore(doc)).toList();
          // Sort in memory instead of using orderBy to avoid index requirement
          leads.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return leads;
        });
  }

  /// Create a new lead
  Future<String> createLead(Lead lead) async {
    try {
      final docRef = await _firestore.collection('leads').add(lead.toMap());
      return docRef.id;
    } catch (e) {
      if (kDebugMode) {
        print('Error creating lead: $e');
      }
      rethrow;
    }
  }

  /// Update an existing lead
  Future<void> updateLead(Lead lead) async {
    try {
      await _firestore
          .collection('leads')
          .doc(lead.id)
          .update(lead.toMap());
    } catch (e) {
      if (kDebugMode) {
        print('Error updating lead: $e');
      }
      rethrow;
    }
  }

  /// Update lead assignment (assignedTo and assignedToName fields only)
  Future<void> updateLeadAssignment({
    required String leadId,
    String? assignedTo,
    String? assignedToName,
  }) async {
    try {
      final lead = await getLead(leadId);
      if (lead == null) {
        throw Exception('Lead not found');
      }

      final updatedLead = lead.copyWith(
        assignedTo: assignedTo,
        assignedToName: assignedToName,
        updatedAt: DateTime.now(),
      );

      await updateLead(updatedLead);

      if (kDebugMode) {
        print('Updated lead assignment: $leadId -> ${assignedToName ?? "Unassigned"}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error updating lead assignment: $e');
      }
      rethrow;
    }
  }

  /// Delete a lead
  Future<void> deleteLead(String leadId) async {
    try {
      await _firestore.collection('leads').doc(leadId).delete();
    } catch (e) {
      if (kDebugMode) {
        print('Error deleting lead: $e');
      }
      rethrow;
    }
  }

  /// Move lead to a new stage with note
  Future<void> moveLeadToStage({
    required String leadId,
    required String newStage,
    required dynamic note, // Can be String or Map<String, dynamic> for questionnaire
    required String userId,
    String? userName,
    bool isFollowUpStage = false,
    double? amount,
    String? invoiceNumber,
    String? bookingId,
    DateTime? bookingDate,
    String? bookingStatus,
    String? assignedTo, // userId of assigned marketing admin
    String? assignedToName, // name of assigned marketing admin
  }) async {
    try {
      final lead = await getLead(leadId);
      if (lead == null) {
        throw Exception('Lead not found');
      }

      final now = DateTime.now();

      // Create stage history entry for current stage exit
      final updatedHistory = [...lead.stageHistory];
      if (updatedHistory.isNotEmpty) {
        final lastEntry = updatedHistory.last;
        if (lastEntry.exitedAt == null) {
          updatedHistory[updatedHistory.length - 1] =
              lastEntry.copyWith(exitedAt: now, note: note);
        }
      }

      // Add new stage history entry
      updatedHistory.add(StageHistoryEntry(
        stage: newStage,
        enteredAt: now,
        note: note,
      ));

      // Create note for the transition
      final transitionNote = LeadNote(
        text: note,
        createdAt: now,
        createdBy: userId,
        createdByName: userName,
        stageTransition: '${lead.currentStage} → $newStage',
      );

      final updatedNotes = [...lead.notes, transitionNote];

      // Update lead with payment info and booking info if provided
      final updatedLead = lead.copyWith(
        currentStage: newStage,
        stageEnteredAt: now,
        updatedAt: now,
        stageHistory: updatedHistory,
        notes: updatedNotes,
        followUpWeek: isFollowUpStage ? (lead.followUpWeek ?? 1) : null,
        depositAmount: newStage == 'deposit_made' ? amount : lead.depositAmount,
        depositInvoiceNumber: newStage == 'deposit_made' ? invoiceNumber : lead.depositInvoiceNumber,
        cashCollectedAmount: newStage == 'cash_collected' ? amount : lead.cashCollectedAmount,
        cashCollectedInvoiceNumber: newStage == 'cash_collected' ? invoiceNumber : lead.cashCollectedInvoiceNumber,
        bookingId: bookingId ?? lead.bookingId,
        bookingDate: bookingDate ?? lead.bookingDate,
        bookingStatus: bookingStatus ?? lead.bookingStatus,
        assignedTo: assignedTo ?? lead.assignedTo, // Set assignment if provided, otherwise keep existing
        assignedToName: assignedToName ?? lead.assignedToName, // Set assignment name if provided, otherwise keep existing
      );

      await updateLead(updatedLead);

      // Check if we need to convert to Appointment (final stage in Marketing)
      if (newStage == 'booking') {
        await convertToAppointment(
          leadId: leadId,
          userId: userId,
          userName: userName,
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error moving lead to stage: $e');
      }
      rethrow;
    }
  }

  /// Update follow-up week for a lead
  Future<void> updateFollowUpWeek(String leadId, int week) async {
    try {
      await _firestore.collection('leads').doc(leadId).update({
        'followUpWeek': week,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error updating follow-up week: $e');
      }
      rethrow;
    }
  }

  /// Update follow-up week with note
  Future<void> updateFollowUpWeekWithNote({
    required String leadId,
    required int newWeek,
    required String note,
    required String userId,
    String? userName,
  }) async {
    try {
      final lead = await getLead(leadId);
      if (lead == null) {
        throw Exception('Lead not found');
      }

      final now = DateTime.now();
      final oldWeek = lead.followUpWeek ?? 1;

      // Create note for the week change
      final weekChangeNote = LeadNote(
        text: note,
        createdAt: now,
        createdBy: userId,
        createdByName: userName,
        stageTransition: 'Week $oldWeek → Week $newWeek',
      );

      final updatedNotes = [...lead.notes, weekChangeNote];

      // Update lead
      final updatedLead = lead.copyWith(
        followUpWeek: newWeek,
        updatedAt: now,
        notes: updatedNotes,
      );

      await updateLead(updatedLead);
    } catch (e) {
      if (kDebugMode) {
        print('Error updating follow-up week with note: $e');
      }
      rethrow;
    }
  }

  /// Add a note to a lead
  Future<void> addNote({
    required String leadId,
    required String noteText,
    required String userId,
    String? userName,
  }) async {
    try {
      final lead = await getLead(leadId);
      if (lead == null) {
        throw Exception('Lead not found');
      }

      final note = LeadNote(
        text: noteText,
        createdAt: DateTime.now(),
        createdBy: userId,
        createdByName: userName,
      );

      final updatedNotes = [...lead.notes, note];

      await _firestore.collection('leads').doc(leadId).update({
        'notes': updatedNotes.map((n) => n.toMap()).toList(),
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error adding note: $e');
      }
      rethrow;
    }
  }

  /// Search leads by name, email, or phone
  Future<List<Lead>> searchLeads(String channelId, String query) async {
    try {
      // Get all leads for the channel
      final allLeads = await getAllLeads(channelId: channelId);

      // Filter by query
      final lowerQuery = query.toLowerCase();
      return allLeads.where((lead) {
        return lead.firstName.toLowerCase().contains(lowerQuery) ||
            lead.lastName.toLowerCase().contains(lowerQuery) ||
            lead.email.toLowerCase().contains(lowerQuery) ||
            lead.phone.contains(query);
      }).toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error searching leads: $e');
      }
      rethrow;
    }
  }

  /// Get lead count by stage
  Future<Map<String, int>> getLeadCountsByStage(String channelId) async {
    try {
      final leads = await getAllLeads(channelId: channelId);
      final counts = <String, int>{};

      for (final lead in leads) {
        counts[lead.currentStage] = (counts[lead.currentStage] ?? 0) + 1;
      }

      return counts;
    } catch (e) {
      if (kDebugMode) {
        print('Error getting lead counts by stage: $e');
      }
      rethrow;
    }
  }

  /// Convert lead to appointment (when reaching "Booking" stage)
  Future<String> convertToAppointment({
    required String leadId,
    required String userId,
    String? userName,
  }) async {
    try {
      final lead = await getLead(leadId);
      if (lead == null) {
        throw Exception('Lead not found');
      }

      // Check if already converted
      if (lead.convertedToAppointmentId != null) {
        return lead.convertedToAppointmentId!;
      }

      final now = DateTime.now();

      // Create new appointment from lead data
      final appointment = models.SalesAppointment(
        id: '',
        leadId: leadId,
        customerName: lead.fullName,
        email: lead.email,
        phone: lead.phone,
        currentStage: 'appointments', // First stage in Sales stream
        appointmentDate: lead.bookingDate,
        createdAt: now,
        updatedAt: now,
        stageEnteredAt: now,
        stageHistory: [
          models.SalesAppointmentStageHistoryEntry(
            stage: 'appointments',
            enteredAt: now,
            note: 'Converted from Marketing lead',
          ),
        ],
        notes: [
          models.SalesAppointmentNote(
            text: 'Appointment created from lead ${lead.id}',
            createdAt: now,
            createdBy: userId,
            createdByName: userName,
          ),
        ],
        createdBy: userId,
        createdByName: userName,
      );

      // Create the appointment
      final appointmentId = await _appointmentService.createAppointment(appointment);

      // Update lead with appointment reference
      final updatedLead = lead.copyWith(
        convertedToAppointmentId: appointmentId,
        updatedAt: now,
      );
      await updateLead(updatedLead);

      if (kDebugMode) {
        print('Converted lead $leadId to appointment $appointmentId');
      }

      return appointmentId;
    } catch (e) {
      if (kDebugMode) {
        print('Error converting lead to appointment: $e');
      }
      rethrow;
    }
  }

  /// Create a lead from a form submission
  Future<String> createLeadFromFormSubmission({
    required FormSubmission submission,
    required Map<String, dynamic> formAnswers,
    required LeadChannel channel,
    required String firstStageId,
  }) async {
    try {
      final firstName = formAnswers['firstName']?.toString() ?? '';
      final lastName = formAnswers['lastName']?.toString() ?? '';
      final email = formAnswers['email']?.toString() ?? '';
      final phone = formAnswers['phone']?.toString() ?? '';
      final source = submission.attribution?.utmSource ?? 'organic';
      final attribution = submission.attribution;

      final now = DateTime.now();

      // Create new lead
      final newLead = Lead(
        id: '',
        firstName: firstName,
        lastName: lastName,
        email: email,
        phone: phone,
        source: source,
        channelId: channel.id,
        currentStage: firstStageId,
        createdAt: now,
        updatedAt: now,
        stageEnteredAt: now,
        stageHistory: [
          StageHistoryEntry(
            stage: firstStageId,
            enteredAt: now,
          ),
        ],
        createdBy: 'form_submission',
        createdByName: 'Form Submission',
        submissionId: submission.submissionId,
        // UTM tracking fields
        utmSource: attribution?.utmSource,
        utmMedium: attribution?.utmMedium,
        utmCampaign: attribution?.utmCampaign,
        utmCampaignId: attribution?.utmCampaignId,
        utmAdset: attribution?.utmAdset,
        utmAdsetId: attribution?.utmAdsetId,
        utmAd: attribution?.utmAd,
        utmAdId: attribution?.utmAdId,
        fbclid: attribution?.fbclid,
      );

      final leadId = await createLead(newLead);

      return leadId;
    } catch (e) {
      if (kDebugMode) {
        print('Error creating lead from form submission: $e');
      }
      rethrow;
    }
  }
}

