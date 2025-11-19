import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../models/leads/lead_channel.dart';
import '../../models/leads/lead_stage.dart';

/// Service for managing lead channels (pipelines) in Firebase
class LeadChannelService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get all channels
  Future<List<LeadChannel>> getAllChannels() async {
    try {
      final snapshot = await _firestore
          .collection('leadChannels')
          .where('isActive', isEqualTo: true)
          .get();

      return snapshot.docs
          .map((doc) => LeadChannel.fromFirestore(doc))
          .toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error getting all channels: $e');
      }
      rethrow;
    }
  }

  /// Get a single channel by ID
  Future<LeadChannel?> getChannel(String channelId) async {
    try {
      final doc =
          await _firestore.collection('leadChannels').doc(channelId).get();

      if (!doc.exists) {
        return null;
      }

      return LeadChannel.fromFirestore(doc);
    } catch (e) {
      if (kDebugMode) {
        print('Error getting channel $channelId: $e');
      }
      rethrow;
    }
  }

  /// Stream of all channels
  Stream<List<LeadChannel>> channelsStream() {
    return _firestore
        .collection('leadChannels')
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => LeadChannel.fromFirestore(doc)).toList());
  }

  /// Create a new channel
  Future<String> createChannel(LeadChannel channel) async {
    try {
      final docRef = await _firestore
          .collection('leadChannels')
          .add(channel.toMap());
      return docRef.id;
    } catch (e) {
      if (kDebugMode) {
        print('Error creating channel: $e');
      }
      rethrow;
    }
  }

  /// Update an existing channel
  Future<void> updateChannel(LeadChannel channel) async {
    try {
      await _firestore
          .collection('leadChannels')
          .doc(channel.id)
          .update(channel.toMap());
    } catch (e) {
      if (kDebugMode) {
        print('Error updating channel: $e');
      }
      rethrow;
    }
  }

  /// Delete a channel (soft delete by setting isActive to false)
  Future<void> deleteChannel(String channelId) async {
    try {
      await _firestore.collection('leadChannels').doc(channelId).update({
        'isActive': false,
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error deleting channel: $e');
      }
      rethrow;
    }
  }

  /// Initialize default "New Leads" channel if it doesn't exist
  Future<LeadChannel> initializeDefaultChannel() async {
    try {
      // Check if default channel already exists
      final existingChannel = await getChannel('new_leads');
      if (existingChannel != null) {
        return existingChannel;
      }

      // Create default channel
      final defaultChannel = LeadChannel.createDefault();
      
      // Use set instead of add to use custom ID
      await _firestore
          .collection('leadChannels')
          .doc('new_leads')
          .set(defaultChannel.toMap());

      if (kDebugMode) {
        print('✅ Default "New Leads" channel created');
      }

      return defaultChannel.copyWith(id: 'new_leads');
    } catch (e) {
      if (kDebugMode) {
        print('Error initializing default channel: $e');
      }
      rethrow;
    }
  }

  /// Add a stage to a channel
  Future<void> addStage(String channelId, LeadStage stage) async {
    try {
      final channel = await getChannel(channelId);
      if (channel == null) {
        throw Exception('Channel not found');
      }

      final updatedStages = [...channel.stages, stage];
      await updateChannel(channel.copyWith(stages: updatedStages));
    } catch (e) {
      if (kDebugMode) {
        print('Error adding stage: $e');
      }
      rethrow;
    }
  }

  /// Update a stage in a channel
  Future<void> updateStage(String channelId, LeadStage stage) async {
    try {
      final channel = await getChannel(channelId);
      if (channel == null) {
        throw Exception('Channel not found');
      }

      final updatedStages = channel.stages.map((s) {
        return s.id == stage.id ? stage : s;
      }).toList();

      await updateChannel(channel.copyWith(stages: updatedStages));
    } catch (e) {
      if (kDebugMode) {
        print('Error updating stage: $e');
      }
      rethrow;
    }
  }

  /// Remove a stage from a channel
  Future<void> removeStage(String channelId, String stageId) async {
    try {
      final channel = await getChannel(channelId);
      if (channel == null) {
        throw Exception('Channel not found');
      }

      final updatedStages =
          channel.stages.where((s) => s.id != stageId).toList();
      await updateChannel(channel.copyWith(stages: updatedStages));
    } catch (e) {
      if (kDebugMode) {
        print('Error removing stage: $e');
      }
      rethrow;
    }
  }

  /// Reorder stages in a channel
  Future<void> reorderStages(
      String channelId, List<LeadStage> newStagesOrder) async {
    try {
      final channel = await getChannel(channelId);
      if (channel == null) {
        throw Exception('Channel not found');
      }

      // Update positions
      final updatedStages = newStagesOrder.asMap().entries.map((entry) {
        return entry.value.copyWith(position: entry.key);
      }).toList();

      await updateChannel(channel.copyWith(stages: updatedStages));
    } catch (e) {
      if (kDebugMode) {
        print('Error reordering stages: $e');
      }
      rethrow;
    }
  }
}

