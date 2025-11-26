import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../models/streams/support_ticket.dart';

/// Service for managing support tickets in Firebase
class SupportTicketService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get all support tickets
  Future<List<SupportTicket>> getAllTickets({
    String? orderBy = 'createdAt',
    bool descending = true,
  }) async {
    try {
      Query query = _firestore.collection('support_tickets');

      if (orderBy != null) {
        query = query.orderBy(orderBy, descending: descending);
      }

      final snapshot = await query.get();
      return snapshot.docs.map((doc) => SupportTicket.fromFirestore(doc)).toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error getting all support tickets: $e');
      }
      rethrow;
    }
  }

  /// Get tickets by stage
  Future<List<SupportTicket>> getTicketsByStage(String stage) async {
    try {
      final snapshot = await _firestore
          .collection('support_tickets')
          .where('currentStage', isEqualTo: stage)
          .get();

      final tickets = snapshot.docs.map((doc) => SupportTicket.fromFirestore(doc)).toList();
      // Sort in memory to avoid index requirement
      tickets.sort((a, b) => a.stageEnteredAt.compareTo(b.stageEnteredAt));
      return tickets;
    } catch (e) {
      if (kDebugMode) {
        print('Error getting tickets by stage: $e');
      }
      rethrow;
    }
  }

  /// Get tickets by priority
  Future<List<SupportTicket>> getTicketsByPriority(TicketPriority priority) async {
    try {
      final snapshot = await _firestore
          .collection('support_tickets')
          .where('priority', isEqualTo: priority.toString().split('.').last)
          .get();

      final tickets = snapshot.docs.map((doc) => SupportTicket.fromFirestore(doc)).toList();
      tickets.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return tickets;
    } catch (e) {
      if (kDebugMode) {
        print('Error getting tickets by priority: $e');
      }
      rethrow;
    }
  }

  /// Get a single ticket by ID
  Future<SupportTicket?> getTicket(String ticketId) async {
    try {
      final doc = await _firestore.collection('support_tickets').doc(ticketId).get();

      if (!doc.exists) {
        return null;
      }

      return SupportTicket.fromFirestore(doc);
    } catch (e) {
      if (kDebugMode) {
        print('Error getting ticket $ticketId: $e');
      }
      rethrow;
    }
  }

  /// Stream of all support tickets
  Stream<List<SupportTicket>> ticketsStream() {
    return _firestore
        .collection('support_tickets')
        .snapshots()
        .map((snapshot) {
          final tickets = snapshot.docs.map((doc) => SupportTicket.fromFirestore(doc)).toList();
          // Sort in memory instead of using orderBy to avoid index requirement
          tickets.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return tickets;
        });
  }

  /// Create a new support ticket
  Future<String> createTicket(SupportTicket ticket) async {
    try {
      final docRef = await _firestore.collection('support_tickets').add(ticket.toMap());
      return docRef.id;
    } catch (e) {
      if (kDebugMode) {
        print('Error creating support ticket: $e');
      }
      rethrow;
    }
  }

  /// Update an existing support ticket
  Future<void> updateTicket(SupportTicket ticket) async {
    try {
      await _firestore
          .collection('support_tickets')
          .doc(ticket.id)
          .update(ticket.toMap());
    } catch (e) {
      if (kDebugMode) {
        print('Error updating support ticket: $e');
      }
      rethrow;
    }
  }

  /// Delete a support ticket
  Future<void> deleteTicket(String ticketId) async {
    try {
      await _firestore.collection('support_tickets').doc(ticketId).delete();
    } catch (e) {
      if (kDebugMode) {
        print('Error deleting support ticket: $e');
      }
      rethrow;
    }
  }

  /// Move ticket to a new stage with note
  Future<void> moveTicketToStage({
    required String ticketId,
    required String newStage,
    required String note,
    required String userId,
    String? userName,
    String? issueDescription,
    TicketPriority? priority,
    String? resolution,
    int? satisfactionRating,
  }) async {
    try {
      final ticket = await getTicket(ticketId);
      if (ticket == null) {
        throw Exception('Support ticket not found');
      }

      final now = DateTime.now();

      // Create stage history entry for current stage exit
      final updatedHistory = [...ticket.stageHistory];
      if (updatedHistory.isNotEmpty) {
        final lastEntry = updatedHistory.last;
        if (lastEntry.exitedAt == null) {
          updatedHistory[updatedHistory.length - 1] =
              TicketStageHistoryEntry(
                stage: lastEntry.stage,
                enteredAt: lastEntry.enteredAt,
                exitedAt: now,
                note: note,
              );
        }
      }

      // Add new stage history entry
      updatedHistory.add(TicketStageHistoryEntry(
        stage: newStage,
        enteredAt: now,
        note: note,
      ));

      // Create note for the transition
      final transitionNote = TicketNote(
        text: note,
        createdAt: now,
        createdBy: userId,
        createdByName: userName,
      );

      final updatedNotes = [...ticket.notes, transitionNote];

      // Update ticket
      final updatedTicket = ticket.copyWith(
        currentStage: newStage,
        stageEnteredAt: now,
        updatedAt: now,
        stageHistory: updatedHistory,
        notes: updatedNotes,
        issueDescription: issueDescription ?? ticket.issueDescription,
        priority: priority ?? ticket.priority,
        resolution: resolution ?? ticket.resolution,
        satisfactionRating: satisfactionRating ?? ticket.satisfactionRating,
      );

      await updateTicket(updatedTicket);
    } catch (e) {
      if (kDebugMode) {
        print('Error moving ticket to stage: $e');
      }
      rethrow;
    }
  }

  /// Add a note to a support ticket
  Future<void> addNote({
    required String ticketId,
    required String noteText,
    required String userId,
    String? userName,
  }) async {
    try {
      final ticket = await getTicket(ticketId);
      if (ticket == null) {
        throw Exception('Support ticket not found');
      }

      final note = TicketNote(
        text: noteText,
        createdAt: DateTime.now(),
        createdBy: userId,
        createdByName: userName,
      );

      final updatedNotes = [...ticket.notes, note];

      await _firestore.collection('support_tickets').doc(ticketId).update({
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

  /// Search tickets by customer name, email, or phone
  Future<List<SupportTicket>> searchTickets(String query) async {
    try {
      // Get all tickets
      final allTickets = await getAllTickets();

      // Filter by query
      final lowerQuery = query.toLowerCase();
      return allTickets.where((ticket) {
        return ticket.customerName.toLowerCase().contains(lowerQuery) ||
            ticket.email.toLowerCase().contains(lowerQuery) ||
            ticket.phone.contains(query);
      }).toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error searching tickets: $e');
      }
      rethrow;
    }
  }

  /// Get ticket count by stage
  Future<Map<String, int>> getTicketCountsByStage() async {
    try {
      final tickets = await getAllTickets();
      final counts = <String, int>{};

      for (final ticket in tickets) {
        counts[ticket.currentStage] = (counts[ticket.currentStage] ?? 0) + 1;
      }

      return counts;
    } catch (e) {
      if (kDebugMode) {
        print('Error getting ticket counts by stage: $e');
      }
      rethrow;
    }
  }

  /// Get ticket count by priority
  Future<Map<TicketPriority, int>> getTicketCountsByPriority() async {
    try {
      final tickets = await getAllTickets();
      final counts = <TicketPriority, int>{};

      for (final priority in TicketPriority.values) {
        counts[priority] = 0;
      }

      for (final ticket in tickets) {
        counts[ticket.priority] = (counts[ticket.priority] ?? 0) + 1;
      }

      return counts;
    } catch (e) {
      if (kDebugMode) {
        print('Error getting ticket counts by priority: $e');
      }
      rethrow;
    }
  }
}

