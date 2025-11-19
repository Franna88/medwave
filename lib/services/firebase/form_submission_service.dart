import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../models/form/form_submission.dart';

/// Service for managing form submissions in Firebase
class FormSubmissionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Save a form submission
  Future<String> saveSubmission(FormSubmission submission) async {
    try {
      final docRef = await _firestore
          .collection('formSubmissions')
          .add(submission.toMap());
      return docRef.id;
    } catch (e) {
      if (kDebugMode) {
        print('Error saving form submission: $e');
      }
      rethrow;
    }
  }

  /// Get all submissions for a form
  Future<List<FormSubmission>> getSubmissionsByForm(
    String formId, {
    String? orderBy = 'submittedAt',
    bool descending = true,
    int? limit,
  }) async {
    try {
      Query query = _firestore
          .collection('formSubmissions')
          .where('formId', isEqualTo: formId);

      if (orderBy != null) {
        query = query.orderBy(orderBy, descending: descending);
      }

      if (limit != null) {
        query = query.limit(limit);
      }

      final snapshot = await query.get();
      return snapshot.docs
          .map((doc) => FormSubmission.fromFirestore(doc))
          .toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error getting submissions for form: $e');
      }
      rethrow;
    }
  }

  /// Get submissions by campaign attribution
  Future<List<FormSubmission>> getSubmissionsByCampaign(
    String campaignId, {
    String? orderBy = 'submittedAt',
    bool descending = true,
  }) async {
    try {
      Query query = _firestore
          .collection('formSubmissions')
          .where('attribution.campaignId', isEqualTo: campaignId);

      if (orderBy != null) {
        query = query.orderBy(orderBy, descending: descending);
      }

      final snapshot = await query.get();
      return snapshot.docs
          .map((doc) => FormSubmission.fromFirestore(doc))
          .toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error getting submissions by campaign: $e');
      }
      rethrow;
    }
  }

  /// Get submissions by ad set attribution
  Future<List<FormSubmission>> getSubmissionsByAdSet(
    String adSetId, {
    String? orderBy = 'submittedAt',
    bool descending = true,
  }) async {
    try {
      Query query = _firestore
          .collection('formSubmissions')
          .where('attribution.adSetId', isEqualTo: adSetId);

      if (orderBy != null) {
        query = query.orderBy(orderBy, descending: descending);
      }

      final snapshot = await query.get();
      return snapshot.docs
          .map((doc) => FormSubmission.fromFirestore(doc))
          .toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error getting submissions by ad set: $e');
      }
      rethrow;
    }
  }

  /// Get submissions by ad attribution
  Future<List<FormSubmission>> getSubmissionsByAd(
    String adId, {
    String? orderBy = 'submittedAt',
    bool descending = true,
  }) async {
    try {
      Query query = _firestore
          .collection('formSubmissions')
          .where('attribution.adId', isEqualTo: adId);

      if (orderBy != null) {
        query = query.orderBy(orderBy, descending: descending);
      }

      final snapshot = await query.get();
      return snapshot.docs
          .map((doc) => FormSubmission.fromFirestore(doc))
          .toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error getting submissions by ad: $e');
      }
      rethrow;
    }
  }

  /// Get a single submission
  Future<FormSubmission?> getSubmission(String submissionId) async {
    try {
      final doc = await _firestore
          .collection('formSubmissions')
          .doc(submissionId)
          .get();

      if (!doc.exists) {
        return null;
      }

      return FormSubmission.fromFirestore(doc);
    } catch (e) {
      if (kDebugMode) {
        print('Error getting submission: $e');
      }
      rethrow;
    }
  }

  /// Delete a submission
  Future<void> deleteSubmission(String submissionId) async {
    try {
      await _firestore
          .collection('formSubmissions')
          .doc(submissionId)
          .delete();
    } catch (e) {
      if (kDebugMode) {
        print('Error deleting submission: $e');
      }
      rethrow;
    }
  }

  /// Stream submissions for a form
  Stream<List<FormSubmission>> streamSubmissionsByForm(
    String formId, {
    String? orderBy = 'submittedAt',
    bool descending = true,
  }) {
    try {
      Query query = _firestore
          .collection('formSubmissions')
          .where('formId', isEqualTo: formId);

      if (orderBy != null) {
        query = query.orderBy(orderBy, descending: descending);
      }

      return query.snapshots().map((snapshot) => snapshot.docs
          .map((doc) => FormSubmission.fromFirestore(doc))
          .toList());
    } catch (e) {
      if (kDebugMode) {
        print('Error streaming submissions: $e');
      }
      rethrow;
    }
  }

  /// Get submission count for a form
  Future<int> getSubmissionCount(String formId) async {
    try {
      final snapshot = await _firestore
          .collection('formSubmissions')
          .where('formId', isEqualTo: formId)
          .count()
          .get();

      return snapshot.count ?? 0;
    } catch (e) {
      if (kDebugMode) {
        print('Error getting submission count: $e');
      }
      rethrow;
    }
  }

  /// Export submissions to CSV format (returns CSV string)
  Future<String> exportSubmissionsToCSV(String formId) async {
    try {
      final submissions = await getSubmissionsByForm(formId);

      if (submissions.isEmpty) {
        return '';
      }

      // Get all unique question IDs from responses
      final Set<String> questionIds = {};
      for (final submission in submissions) {
        questionIds.addAll(submission.responses.keys);
      }

      // Create CSV header
      final headers = [
        'Submission ID',
        'Submitted At',
        'Campaign ID',
        'Ad Set ID',
        'Ad ID',
        'User Name',
        'User Email',
        ...questionIds.map((id) => 'Q: $id'),
      ];

      // Create CSV rows
      final rows = submissions.map((submission) {
        return [
          submission.submissionId,
          submission.submittedAt.toIso8601String(),
          submission.attribution?.campaignId ?? '',
          submission.attribution?.adSetId ?? '',
          submission.attribution?.adId ?? '',
          submission.userInfo?.name ?? '',
          submission.userInfo?.email ?? '',
          ...questionIds.map((id) => submission.responses[id]?.toString() ?? ''),
        ];
      });

      // Combine headers and rows
      final csvLines = [
        headers.join(','),
        ...rows.map((row) => row.map(_escapeCsvValue).join(',')),
      ];

      return csvLines.join('\n');
    } catch (e) {
      if (kDebugMode) {
        print('Error exporting submissions to CSV: $e');
      }
      rethrow;
    }
  }

  /// Escape CSV values
  String _escapeCsvValue(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }
}

