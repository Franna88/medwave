import 'package:cloud_firestore/cloud_firestore.dart';

/// GHL Opportunity model for the split collections schema
class GHLOpportunity {
  final String opportunityId;
  final String opportunityName;
  final String contactId;
  final String contactName;
  
  // Ad Assignment (from mapping - ONE ad only)
  final String adId;
  final String adName;
  final String adSetId;
  final String adSetName;
  final String campaignId;
  final String campaignName;
  
  // Stage Info
  final String currentStage;
  final String stageCategory; // leads, bookedAppointments, deposits, cashCollected
  final String pipelineId;
  final String pipelineName;
  
  // Financial
  final double monetaryValue;
  
  // Attribution
  final String utmSource;
  final String utmMedium;
  final String utmCampaign;
  final String hAdId; // Original h_ad_id if available
  
  // Timestamps
  final DateTime? createdAt;
  final DateTime? lastStageChange;
  final DateTime? lastUpdated;
  
  GHLOpportunity({
    required this.opportunityId,
    required this.opportunityName,
    required this.contactId,
    required this.contactName,
    required this.adId,
    required this.adName,
    required this.adSetId,
    required this.adSetName,
    required this.campaignId,
    required this.campaignName,
    required this.currentStage,
    required this.stageCategory,
    required this.pipelineId,
    required this.pipelineName,
    required this.monetaryValue,
    required this.utmSource,
    required this.utmMedium,
    required this.utmCampaign,
    required this.hAdId,
    this.createdAt,
    this.lastStageChange,
    this.lastUpdated,
  });
  
  factory GHLOpportunity.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return GHLOpportunity(
      opportunityId: doc.id,
      opportunityName: data['opportunityName'] ?? '',
      contactId: data['contactId'] ?? '',
      contactName: data['contactName'] ?? '',
      adId: data['adId'] ?? '',
      adName: data['adName'] ?? '',
      adSetId: data['adSetId'] ?? '',
      adSetName: data['adSetName'] ?? '',
      campaignId: data['campaignId'] ?? '',
      campaignName: data['campaignName'] ?? '',
      currentStage: data['currentStage'] ?? '',
      stageCategory: data['stageCategory'] ?? '',
      pipelineId: data['pipelineId'] ?? '',
      pipelineName: data['pipelineName'] ?? '',
      monetaryValue: (data['monetaryValue'] ?? 0).toDouble(),
      utmSource: data['utmSource'] ?? '',
      utmMedium: data['utmMedium'] ?? '',
      utmCampaign: data['utmCampaign'] ?? '',
      hAdId: data['h_ad_id'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      lastStageChange: (data['lastStageChange'] as Timestamp?)?.toDate(),
      lastUpdated: (data['lastUpdated'] as Timestamp?)?.toDate(),
    );
  }
  
  Map<String, dynamic> toMap() {
    return {
      'opportunityId': opportunityId,
      'opportunityName': opportunityName,
      'contactId': contactId,
      'contactName': contactName,
      'adId': adId,
      'adName': adName,
      'adSetId': adSetId,
      'adSetName': adSetName,
      'campaignId': campaignId,
      'campaignName': campaignName,
      'currentStage': currentStage,
      'stageCategory': stageCategory,
      'pipelineId': pipelineId,
      'pipelineName': pipelineName,
      'monetaryValue': monetaryValue,
      'utmSource': utmSource,
      'utmMedium': utmMedium,
      'utmCampaign': utmCampaign,
      'h_ad_id': hAdId,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
      'lastStageChange': lastStageChange != null ? Timestamp.fromDate(lastStageChange!) : null,
      'lastUpdated': lastUpdated != null ? Timestamp.fromDate(lastUpdated!) : null,
    };
  }
}

