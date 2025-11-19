import 'package:cloud_firestore/cloud_firestore.dart';

/// Attribution data for tracking which ad/campaign led to the submission
class FormAttribution {
  final String? campaignId;
  final String? adSetId;
  final String? adId;

  FormAttribution({
    this.campaignId,
    this.adSetId,
    this.adId,
  });

  Map<String, dynamic> toMap() {
    return {
      'campaignId': campaignId,
      'adSetId': adSetId,
      'adId': adId,
    };
  }

  factory FormAttribution.fromMap(Map<String, dynamic> map) {
    return FormAttribution(
      campaignId: map['campaignId'] as String?,
      adSetId: map['adSetId'] as String?,
      adId: map['adId'] as String?,
    );
  }
}

/// User information from Facebook
class FormUserInfo {
  final String? facebookUserId;
  final String? name;
  final String? email;

  FormUserInfo({
    this.facebookUserId,
    this.name,
    this.email,
  });

  Map<String, dynamic> toMap() {
    return {
      'facebookUserId': facebookUserId,
      'name': name,
      'email': email,
    };
  }

  factory FormUserInfo.fromMap(Map<String, dynamic> map) {
    return FormUserInfo(
      facebookUserId: map['facebookUserId'] as String?,
      name: map['name'] as String?,
      email: map['email'] as String?,
    );
  }
}

/// Represents a form submission from a user
class FormSubmission {
  final String submissionId;
  final String formId;
  final Map<String, dynamic> responses; // questionId -> answer
  final DateTime submittedAt;
  final FormAttribution? attribution;
  final FormUserInfo? userInfo;

  FormSubmission({
    required this.submissionId,
    required this.formId,
    required this.responses,
    required this.submittedAt,
    this.attribution,
    this.userInfo,
  });

  Map<String, dynamic> toMap() {
    return {
      'submissionId': submissionId,
      'formId': formId,
      'responses': responses,
      'submittedAt': Timestamp.fromDate(submittedAt),
      'attribution': attribution?.toMap(),
      'userInfo': userInfo?.toMap(),
    };
  }

  factory FormSubmission.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return FormSubmission.fromMap(data, doc.id);
  }

  factory FormSubmission.fromMap(Map<String, dynamic> map, String id) {
    return FormSubmission(
      submissionId: id,
      formId: map['formId'] as String,
      responses: Map<String, dynamic>.from(map['responses'] as Map),
      submittedAt:
          (map['submittedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      attribution: map['attribution'] != null
          ? FormAttribution.fromMap(map['attribution'] as Map<String, dynamic>)
          : null,
      userInfo: map['userInfo'] != null
          ? FormUserInfo.fromMap(map['userInfo'] as Map<String, dynamic>)
          : null,
    );
  }
}

