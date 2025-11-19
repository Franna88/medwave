/// Model for a stage in the lead pipeline
class LeadStage {
  final String id;
  final String name;
  final int position;
  final String color;
  final bool isFollowUpStage;

  LeadStage({
    required this.id,
    required this.name,
    required this.position,
    required this.color,
    this.isFollowUpStage = false,
  });

  factory LeadStage.fromMap(Map<String, dynamic> map) {
    return LeadStage(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      position: map['position']?.toInt() ?? 0,
      color: map['color']?.toString() ?? '#2196F3',
      isFollowUpStage: map['isFollowUpStage'] == true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'position': position,
      'color': color,
      'isFollowUpStage': isFollowUpStage,
    };
  }

  LeadStage copyWith({
    String? id,
    String? name,
    int? position,
    String? color,
    bool? isFollowUpStage,
  }) {
    return LeadStage(
      id: id ?? this.id,
      name: name ?? this.name,
      position: position ?? this.position,
      color: color ?? this.color,
      isFollowUpStage: isFollowUpStage ?? this.isFollowUpStage,
    );
  }

  /// Default stages for "New Leads" channel
  static List<LeadStage> getDefaultStages() {
    return [
      LeadStage(
        id: 'new_lead',
        name: 'New Lead',
        position: 0,
        color: '#2196F3', // blue
      ),
      LeadStage(
        id: 'contacted',
        name: 'Contacted',
        position: 1,
        color: '#9C27B0', // purple
      ),
      LeadStage(
        id: 'follow_up',
        name: 'Follow up',
        position: 2,
        color: '#FF9800', // orange
        isFollowUpStage: true,
      ),
      LeadStage(
        id: 'booking',
        name: 'Booking',
        position: 3,
        color: '#009688', // teal
      ),
      LeadStage(
        id: 'deposit_made',
        name: 'Deposit made',
        position: 4,
        color: '#4CAF50', // green
      ),
      LeadStage(
        id: 'cash_collected',
        name: 'Cash collected',
        position: 5,
        color: '#2E7D32', // dark green
      ),
    ];
  }
}

