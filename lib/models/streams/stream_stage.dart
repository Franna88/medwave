/// Enum for different stream types
enum StreamType { marketing, sales, operations, support }

/// Model for a stage in any stream pipeline
class StreamStage {
  final String id;
  final String name;
  final int position;
  final String color;
  final StreamType streamType;
  final bool
  isFinalStage; // Indicates if this stage triggers conversion to next stream

  StreamStage({
    required this.id,
    required this.name,
    required this.position,
    required this.color,
    required this.streamType,
    this.isFinalStage = false,
  });

  factory StreamStage.fromMap(Map<String, dynamic> map) {
    return StreamStage(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      position: map['position']?.toInt() ?? 0,
      color: map['color']?.toString() ?? '#2196F3',
      streamType: StreamType.values.firstWhere(
        (e) => e.toString() == 'StreamType.${map['streamType']}',
        orElse: () => StreamType.marketing,
      ),
      isFinalStage: map['isFinalStage'] == true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'position': position,
      'color': color,
      'streamType': streamType.toString().split('.').last,
      'isFinalStage': isFinalStage,
    };
  }

  StreamStage copyWith({
    String? id,
    String? name,
    int? position,
    String? color,
    StreamType? streamType,
    bool? isFinalStage,
  }) {
    return StreamStage(
      id: id ?? this.id,
      name: name ?? this.name,
      position: position ?? this.position,
      color: color ?? this.color,
      streamType: streamType ?? this.streamType,
      isFinalStage: isFinalStage ?? this.isFinalStage,
    );
  }

  /// Get default stages for Marketing stream
  static List<StreamStage> getMarketingStages() {
    return [
      StreamStage(
        id: 'new_lead',
        name: 'New Lead',
        position: 0,
        color: '#2196F3', // blue
        streamType: StreamType.marketing,
      ),
      StreamStage(
        id: 'contacted',
        name: 'Contacted',
        position: 1,
        color: '#9C27B0', // purple
        streamType: StreamType.marketing,
      ),
      StreamStage(
        id: 'follow_up',
        name: 'Follow up',
        position: 2,
        color: '#FF9800', // orange
        streamType: StreamType.marketing,
      ),
      StreamStage(
        id: 'booking',
        name: 'Booking',
        position: 3,
        color: '#009688', // teal
        streamType: StreamType.marketing,
        isFinalStage: true, // Triggers conversion to Sales
      ),
    ];
  }

  /// Get default stages for Sales stream
  static List<StreamStage> getSalesStages() {
    return [
      StreamStage(
        id: 'appointments',
        name: 'Appointments',
        position: 0,
        color: '#2196F3', // blue
        streamType: StreamType.sales,
      ),
      StreamStage(
        id: 'rescheduled',
        name: 'Rescheduled',
        position: 1,
        color: '#FF9800', // orange
        streamType: StreamType.sales,
      ),
      StreamStage(
        id: 'opt_in',
        name: 'Opt In',
        position: 2,
        color: '#7E57C2', // deep purple
        streamType: StreamType.sales,
      ),
      StreamStage(
        id: 'deposit_requested',
        name: 'Deposit Requested',
        position: 3,
        color: '#FFC107', // amber
        streamType: StreamType.sales,
      ),
      StreamStage(
        id: 'deposit_made',
        name: 'Deposit Made',
        position: 4,
        color: '#4CAF50', // green
        streamType: StreamType.sales,
      ),
      StreamStage(
        id: 'send_to_operations',
        name: 'Send to Operations',
        position: 5,
        color: '#2E7D32', // dark green
        streamType: StreamType.sales,
        isFinalStage: true, // Triggers conversion to Operations
      ),
    ];
  }

  /// Get default stages for Operations stream
  static List<StreamStage> getOperationsStages() {
    return [
      StreamStage(
        id: 'order_placed',
        name: 'Order Placed',
        position: 0,
        color: '#2196F3', // blue
        streamType: StreamType.operations,
      ),
      StreamStage(
        id: 'items_selected',
        name: 'Items Selected',
        position: 1,
        color: '#9C27B0', // purple
        streamType: StreamType.operations,
      ),
      StreamStage(
        id: 'out_for_delivery',
        name: 'Out for Delivery',
        position: 2,
        color: '#FF9800', // orange
        streamType: StreamType.operations,
      ),
      StreamStage(
        id: 'invoice_sent',
        name: 'Invoice Sent',
        position: 3,
        color: '#FFC107', // amber
        streamType: StreamType.operations,
      ),
      StreamStage(
        id: 'installed',
        name: 'Installed',
        position: 4,
        color: '#4CAF50', // green
        streamType: StreamType.operations,
        isFinalStage: true, // Triggers conversion to Support
      ),
    ];
  }

  /// Get default stages for Support stream
  static List<StreamStage> getSupportStages() {
    return [
      StreamStage(
        id: 'welcome',
        name: 'Welcome',
        position: 0,
        color: '#2196F3', // blue
        streamType: StreamType.support,
      ),
      StreamStage(
        id: 'assistance',
        name: 'Assistance',
        position: 1,
        color: '#FF9800', // orange
        streamType: StreamType.support,
      ),
      StreamStage(
        id: 'feedback',
        name: 'Feedback',
        position: 2,
        color: '#9C27B0', // purple
        streamType: StreamType.support,
      ),
      StreamStage(
        id: 'reporting',
        name: 'Reporting',
        position: 3,
        color: '#4CAF50', // green
        streamType: StreamType.support,
        isFinalStage: true, // Final stage in Support stream
      ),
    ];
  }
}
