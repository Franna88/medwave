import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../models/form/lead_form.dart';
import '../../models/form/form_column.dart';

/// Service for managing lead forms in Firebase
class FormService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get all forms
  Future<List<LeadForm>> getAllForms({
    String? orderBy = 'updatedAt',
    bool descending = true,
  }) async {
    try {
      Query query = _firestore.collection('forms');

      if (orderBy != null) {
        query = query.orderBy(orderBy, descending: descending);
      }

      final snapshot = await query.get();
      return snapshot.docs.map((doc) => LeadForm.fromFirestore(doc)).toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error getting all forms: $e');
      }
      rethrow;
    }
  }

  /// Get forms by status
  Future<List<LeadForm>> getFormsByStatus(
    FormStatus status, {
    String? orderBy = 'updatedAt',
    bool descending = true,
  }) async {
    try {
      Query query = _firestore
          .collection('forms')
          .where('status', isEqualTo: status.toStringValue());

      if (orderBy != null) {
        query = query.orderBy(orderBy, descending: descending);
      }

      final snapshot = await query.get();
      return snapshot.docs.map((doc) => LeadForm.fromFirestore(doc)).toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error getting forms by status: $e');
      }
      rethrow;
    }
  }

  /// Get a single form by ID
  Future<LeadForm?> getForm(String formId) async {
    try {
      final doc = await _firestore.collection('forms').doc(formId).get();

      if (!doc.exists) {
        return null;
      }

      return LeadForm.fromFirestore(doc);
    } catch (e) {
      if (kDebugMode) {
        print('Error getting form $formId: $e');
      }
      rethrow;
    }
  }

  /// Create a new form
  Future<String> createForm(LeadForm form) async {
    try {
      final docRef = await _firestore.collection('forms').add(form.toMap());
      return docRef.id;
    } catch (e) {
      if (kDebugMode) {
        print('Error creating form: $e');
      }
      rethrow;
    }
  }

  /// Update an existing form
  Future<void> updateForm(LeadForm form) async {
    try {
      await _firestore
          .collection('forms')
          .doc(form.formId)
          .update(form.toMap());
    } catch (e) {
      if (kDebugMode) {
        print('Error updating form: $e');
      }
      rethrow;
    }
  }

  /// Delete a form
  Future<void> deleteForm(String formId) async {
    try {
      await _firestore.collection('forms').doc(formId).delete();
    } catch (e) {
      if (kDebugMode) {
        print('Error deleting form: $e');
      }
      rethrow;
    }
  }

  /// Duplicate a form
  Future<String> duplicateForm(String formId, String newName) async {
    try {
      final originalForm = await getForm(formId);
      if (originalForm == null) {
        throw Exception('Form not found');
      }

      final duplicatedForm = originalForm.copyWith(
        formId: '', // Will be assigned by Firestore
        formName: newName,
        status: FormStatus.draft,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      return await createForm(duplicatedForm);
    } catch (e) {
      if (kDebugMode) {
        print('Error duplicating form: $e');
      }
      rethrow;
    }
  }

  /// Update form status
  Future<void> updateFormStatus(String formId, FormStatus status) async {
    try {
      await _firestore.collection('forms').doc(formId).update({
        'status': status.toStringValue(),
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error updating form status: $e');
      }
      rethrow;
    }
  }

  /// Validate form structure
  bool validateForm(LeadForm form) {
    // Check if form has at least one column
    if (form.columns.isEmpty) {
      if (kDebugMode) {
        print('Validation failed: Form must have at least one column');
      }
      return false;
    }

    // Check if first column exists
    final firstColumn = form.columns.firstWhere(
      (col) => col.isFirstColumn,
      orElse: () => FormColumn(columnId: '', columnIndex: -1),
    );

    if (firstColumn.columnIndex == -1) {
      if (kDebugMode) {
        print('Validation failed: Form must have a first column');
      }
      return false;
    }

    // Check if first column has at least one question
    if (firstColumn.questions.isEmpty) {
      if (kDebugMode) {
        print('Validation failed: First column must have at least one question');
      }
      return false;
    }

    // Check for required fields (firstName, lastName, email, phone)
    final requiredFieldIds = {'firstName', 'lastName', 'email', 'phone'};
    final questionIds = firstColumn.questions
        .map((q) => q.questionId)
        .toSet();

    for (final requiredId in requiredFieldIds) {
      if (!questionIds.contains(requiredId)) {
        if (kDebugMode) {
          print('Validation failed: Required field "$requiredId" is missing');
        }
        return false;
      }
    }

    // Validate that required fields are marked as required
    for (final question in firstColumn.questions) {
      if (requiredFieldIds.contains(question.questionId) && !question.required) {
        if (kDebugMode) {
          print('Validation failed: Required field "${question.questionId}" must be marked as required');
        }
        return false;
      }
    }

    // Validate each column
    for (final column in form.columns) {
      // Check if column has questions
      if (column.questions.isEmpty) {
        if (kDebugMode) {
          print(
              'Validation failed: Column ${column.columnId} has no questions');
        }
        return false;
      }

      // Validate each question
      for (final question in column.questions) {
        // Check if question text is not empty
        if (question.questionText.trim().isEmpty) {
          if (kDebugMode) {
            print(
                'Validation failed: Question ${question.questionId} has empty text');
          }
          return false;
        }

        // Check if choice questions have options
        if (question.isChoiceType && question.options.isEmpty) {
          if (kDebugMode) {
            print(
                'Validation failed: Choice question ${question.questionId} has no options');
          }
          return false;
        }

        // Validate options
        for (final option in question.options) {
          if (option.optionText.trim().isEmpty) {
            if (kDebugMode) {
              print(
                  'Validation failed: Option ${option.optionId} has empty text');
            }
            return false;
          }
        }
      }
    }

    return true;
  }

  /// Stream forms
  Stream<List<LeadForm>> streamForms({
    String? orderBy = 'updatedAt',
    bool descending = true,
  }) {
    try {
      Query query = _firestore.collection('forms');

      if (orderBy != null) {
        query = query.orderBy(orderBy, descending: descending);
      }

      return query.snapshots().map((snapshot) =>
          snapshot.docs.map((doc) => LeadForm.fromFirestore(doc)).toList());
    } catch (e) {
      if (kDebugMode) {
        print('Error streaming forms: $e');
      }
      rethrow;
    }
  }

  /// Search forms by name
  Future<List<LeadForm>> searchForms(String searchTerm) async {
    try {
      final snapshot = await _firestore.collection('forms').get();
      final allForms =
          snapshot.docs.map((doc) => LeadForm.fromFirestore(doc)).toList();

      // Filter forms by name (case-insensitive)
      return allForms
          .where((form) =>
              form.formName.toLowerCase().contains(searchTerm.toLowerCase()))
          .toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error searching forms: $e');
      }
      rethrow;
    }
  }
}

