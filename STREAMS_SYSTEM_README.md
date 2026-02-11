# MedWave Streams System - Comprehensive Documentation

## Table of Contents
1. [System Overview](#system-overview)
2. [Architecture](#architecture)
3. [Marketing Stream](#marketing-stream)
4. [Sales Stream](#sales-stream)
5. [Stage Management](#stage-management)
6. [Data Flow](#data-flow)
7. [Backend Services](#backend-services)
8. [Notes & History System](#notes--history-system)
9. [Assignment System](#assignment-system)
10. [Implementation Guide](#implementation-guide)

---

## System Overview

The MedWave Streams System is a dual-pipeline Kanban-style workflow management system that tracks leads from initial contact through to conversion. It consists of two main streams:

1. **Marketing Stream**: Manages leads from initial entry through qualification and booking
2. **Sales Stream**: Manages appointments from booking through product selection and operations handoff

### Key Features
- Drag-and-drop stage transitions
- Real-time Firebase synchronization
- Role-based access control (Super Admin, Marketing Admin, Sales Admin)
- Automatic assignment based on user role
- Comprehensive note and history tracking
- Form score-based prioritization
- Booking calendar integration

---

## Architecture

### Component Structure

```
lib/
├── screens/
│   └── admin/
│       └── streams/
│           ├── marketing_stream_screen.dart  # Marketing pipeline UI
│           └── sales_stream_screen.dart      # Sales pipeline UI
├── services/
│   └── firebase/
│       ├── lead_service.dart                 # Lead CRUD & queries
│       ├── sales_appointment_service.dart    # Appointment CRUD & queries
│       ├── lead_channel_service.dart         # Channel management
│       └── lead_booking_service.dart         # Booking management
├── models/
│   ├── leads/
│   │   ├── lead.dart                         # Lead data model
│   │   ├── lead_booking.dart                 # Booking data model
│   │   └── lead_channel.dart                 # Channel data model
│   └── streams/
│       ├── appointment.dart                  # Appointment data model
│       └── stream_stage.dart                 # Stage definitions
├── providers/
│   ├── auth_provider.dart                    # Authentication & user role
│   ├── admin_provider.dart                   # Admin user management
│   ├── product_items_provider.dart           # Product catalog
│   └── inventory_provider.dart               # Stock management
└── widgets/
    ├── leads/
    │   ├── lead_card.dart                    # Lead card UI
    │   ├── lead_detail_dialog.dart           # Lead details view
    │   ├── add_lead_dialog.dart              # Lead creation form
    │   ├── stage_transition_dialog.dart      # Generic transition
    │   ├── contacted_questionnaire_dialog.dart
    │   └── booking_stage_transition_dialog.dart
    └── appointments/
        ├── appointment_detail_dialog.dart    # Appointment details
        └── reschedule_appointment_dialog.dart
```

### Data Models

#### Lead Model
```dart
class Lead {
  String id;
  String channelId;              // Reference to lead channel
  String firstName;
  String lastName;
  String email;
  String phone;
  String currentStage;           // Current stage ID
  DateTime createdAt;
  DateTime updatedAt;
  String? assignedTo;            // User ID of assigned admin
  String? assignedToName;
  int? formScore;                // Priority score (1-10)
  List<LeadNote> notes;          // All notes
  List<LeadStageHistoryEntry> stageHistory;  // Stage transitions
  String? source;                // Lead source (e.g., "Website", "Referral")
  
  // Marketing-specific fields
  int? followUpWeek;             // For follow-up stage
  DateTime? bookingDate;         // When moved to booking stage
  String? bookingId;             // Reference to LeadBooking
  String? bookingStatus;         // scheduled, completed, cancelled
  String? convertedToAppointmentId;  // When converted to sales
}

class LeadNote {
  String text;
  DateTime createdAt;
  String createdBy;              // User ID
  String createdByName;
}

class LeadStageHistoryEntry {
  String stage;                  // Stage ID
  DateTime enteredAt;
  String? note;                  // Optional note when entering stage
}
```

#### Appointment Model
```dart
class SalesAppointment {
  String id;
  String leadId;                 // Reference back to original lead
  String customerName;
  String email;
  String phone;
  String currentStage;           // Current stage ID
  DateTime? appointmentDate;
  String? appointmentTime;
  DateTime createdAt;
  DateTime updatedAt;
  DateTime stageEnteredAt;       // When entered current stage
  List<SalesAppointmentStageHistoryEntry> stageHistory;
  List<SalesAppointmentNote> notes;
  String createdBy;              // User ID
  String createdByName;
  String? assignedTo;            // User ID
  String? assignedToName;
  int? formScore;                // Inherited from lead
  bool manuallyAdded;            // True if added directly to opt-in
  
  // Sales-specific fields
  String paymentType;            // 'deposit' or 'full_payment'
  bool depositPaid;              // Payment received flag
  List<OptInProduct> optInProducts;  // Selected products
  Map<String, String>? optInQuestions;  // Opt-in questionnaire
  String? optInNote;             // Note from opt-in stage
}

class SalesAppointmentNote {
  String text;
  DateTime createdAt;
  String createdBy;
  String createdByName;
}

class SalesAppointmentStageHistoryEntry {
  String stage;
  DateTime enteredAt;
  String? note;
}

class OptInProduct {
  String id;
  String name;
  double price;
}
```

---

## Marketing Stream

### Purpose
Manages the lead nurturing process from initial contact through to booking a sales appointment.

### Stages

```dart
// Defined in StreamStage.getMarketingStages()
1. New Leads (new_leads)        - #4A90E2 (Blue)
2. Contacted (contacted)        - #F5A623 (Orange)
3. Follow-up (follow_up)        - #7B68EE (Purple)
4. Booking (booking)            - #50E3C2 (Teal)
5. Unqualified (unqualified)    - #D0021B (Red) [FINAL]
6. Closed (closed)              - #4A4A4A (Gray) [FINAL]
```

### How Leads Enter the System

#### 1. Manual Entry
```dart
// Via AddLeadDialog - triggered by "Add Lead" button
_showAddLeadDialog() {
  showDialog(
    context: context,
    builder: (context) => AddLeadDialog(channel: _currentChannel!),
  );
}

// In AddLeadDialog, new leads are created with:
Lead newLead = Lead(
  id: '', // Firestore generates ID
  channelId: channel.id,
  currentStage: 'new_leads',  // Always starts here
  createdAt: DateTime.now(),
  formScore: 5,  // Default or calculated
  stageHistory: [
    LeadStageHistoryEntry(
      stage: 'new_leads',
      enteredAt: DateTime.now(),
    ),
  ],
  notes: [],
  // ... other fields
);

await leadService.createLead(newLead);
```

#### 2. Automated Entry (if implemented)
Leads can be automatically created from:
- Web form submissions
- API integrations
- CSV imports
- Third-party lead sources

All automated entries start at `new_leads` stage.

### Stage Transitions

#### Drag-and-Drop Movement
```dart
// Each stage column is a DragTarget
DragTarget<Lead>(
  onWillAcceptWithDetails: (details) {
    // Only allow forward movement to next immediate stage
    return StreamUtils.canMoveToStage(
      details.data.currentStage,
      stage.id,
      _stages,
    );
  },
  onAcceptWithDetails: (details) => _moveLeadToStage(details.data, stage.id),
  // ...
)

// StreamUtils.canMoveToStage ensures:
// - Can only move forward one stage at a time
// - Cannot move from final stages (unqualified, closed)
// - Must follow stage sequence
```

#### Move Lead Process
```dart
Future<void> _moveLeadToStage(Lead lead, String newStageId) async {
  final newStage = _stages.firstWhere((s) => s.id == newStageId);
  final oldStage = _stages.firstWhere((s) => s.id == lead.currentStage);
  
  final authProvider = context.read<AuthProvider>();
  final userId = authProvider.user?.uid ?? '';
  final userName = authProvider.userName;
  
  // Special handling for Booking stage
  if (newStageId == 'booking') {
    // Show booking calendar dialog
    final bookingResult = await showDialog<BookingTransitionResult>(
      context: context,
      builder: (context) => BookingStageTransitionDialog(
        lead: lead,
        newStageName: newStage.name,
      ),
    );
    
    if (bookingResult == null) return; // User cancelled
    
    // Create LeadBooking record
    final booking = LeadBooking(
      leadId: lead.id,
      leadName: lead.fullName,
      bookingDate: bookingResult.bookingDate,
      bookingTime: bookingResult.bookingTime,
      duration: bookingResult.duration,
      status: BookingStatus.scheduled,
      createdBy: userId,
      assignedTo: bookingResult.assignedTo,
      // ...
    );
    
    final bookingId = await _bookingService.createBooking(booking);
    
    // Move lead with booking info
    await _leadService.moveLeadToStage(
      leadId: lead.id,
      newStage: newStageId,
      note: bookingResult.note,
      userId: userId,
      userName: userName,
      bookingId: bookingId,
      bookingDate: bookingResult.bookingDate,
      bookingStatus: 'scheduled',
    );
    return;
  }
  
  // Special questionnaire for Contacted stage
  if (newStageId == 'contacted') {
    final result = await showDialog<StageTransitionResult>(
      context: context,
      builder: (context) => ContactedQuestionnaireDialog(
        fromStage: oldStage.name,
        toStage: newStage.name,
      ),
    );
    
    if (result != null) {
      await _leadService.moveLeadToStage(
        leadId: lead.id,
        newStage: newStageId,
        note: result.note,
        userId: userId,
        userName: userName,
        // Auto-assign if Marketing Admin
        assignedTo: userRole == UserRole.marketingAdmin ? userId : null,
        assignedToName: userRole == UserRole.marketingAdmin ? userName : null,
      );
    }
    return;
  }
  
  // Standard stage transition
  final result = await showDialog<StageTransitionResult>(
    context: context,
    builder: (context) => StageTransitionDialog(
      fromStage: oldStage.name,
      toStage: newStage.name,
      toStageId: newStageId,
    ),
  );
  
  if (result != null) {
    await _leadService.moveLeadToStage(
      leadId: lead.id,
      newStage: newStageId,
      note: result.note,
      userId: userId,
      userName: userName,
      isFollowUpStage: newStage.id == 'follow_up',
    );
  }
}
```

### Lead Detail Dialog

Shows comprehensive lead information:

```dart
LeadDetailDialog(
  lead: lead,
  channel: _currentChannel!,
  onEdit: () => _showEditLeadDialog(lead),
  onDelete: () => _confirmDeleteLead(lead),
  onAssignmentChanged: () {
    setState(() {
      _filterLeads();
    });
  },
)

// Features:
// - Contact information
// - Current stage
// - Form score badge
// - Assignment (Super Admin can reassign)
// - Complete stage history with timestamps
// - All notes with author and timestamp
// - Edit/Delete actions (role-based)
```

### Filtering & Assignment

```dart
void _filterLeads() {
  final authProvider = context.read<AuthProvider>();
  final userRole = authProvider.userRole;
  final currentUserId = authProvider.user?.uid ?? '';
  
  var filtered = _allLeads;
  
  // Marketing Admin sees only their assigned leads + unassigned leads
  if (userRole == UserRole.marketingAdmin) {
    filtered = filtered.where((lead) {
      return lead.assignedTo == null || lead.assignedTo == currentUserId;
    }).toList();
  }
  
  // Super Admin sees all leads
  
  // Apply search filter
  if (_searchQuery.isNotEmpty) {
    filtered = filtered.where((lead) {
      return lead.firstName.toLowerCase().contains(_searchQuery) ||
          lead.lastName.toLowerCase().contains(_searchQuery) ||
          lead.email.toLowerCase().contains(_searchQuery) ||
          lead.phone.contains(_searchQuery);
    }).toList();
  }
  
  _filteredLeads = filtered;
}
```

---

## Sales Stream

### Purpose
Manages the sales process from booked appointments through product selection, payment, and handoff to operations.

### Stages

```dart
// Defined in StreamStage.getSalesStages()
1. Scheduled (scheduled)           - #4A90E2 (Blue)
2. Rescheduled (rescheduled)       - #9013FE (Purple)
3. Confirmed (confirmed)           - #50E3C2 (Teal)
4. Opt In (opt_in)                 - #F5A623 (Orange)
5. Deposit Made (deposit_made)     - #7ED321 (Green)
6. Send to Operations (send_to_operations) - #417505 (Dark Green) [FINAL]
7. No Answer (no_answer)           - #BD10E0 (Magenta)
8. Not Interested (not_interested) - #D0021B (Red) [FINAL]
```

### How Appointments Enter the System

#### 1. From Marketing Stream (Primary Flow)
When a lead reaches the "Booking" stage in Marketing:

```dart
// This creates a LeadBooking record
// The booking is then used to create a SalesAppointment
// This happens automatically or manually depending on implementation

// Automatic creation (recommended):
// Use Firebase Cloud Functions to listen for new LeadBooking documents
// and automatically create SalesAppointment

// Manual approach would involve:
SalesAppointment appointment = SalesAppointment(
  leadId: lead.id,
  customerName: lead.fullName,
  email: lead.email,
  phone: lead.phone,
  currentStage: 'scheduled',  // Always starts here
  appointmentDate: booking.bookingDate,
  appointmentTime: booking.bookingTime,
  formScore: lead.formScore,
  createdAt: DateTime.now(),
  stageHistory: [
    SalesAppointmentStageHistoryEntry(
      stage: 'scheduled',
      enteredAt: DateTime.now(),
    ),
  ],
  paymentType: 'deposit',  // Default
  // ...
);
```

#### 2. Manual Entry (Direct to Opt In)
Sales admins can manually add leads directly to the Opt In stage:

```dart
// Via "+" button on Opt In stage header
_handleManualAddToOptIn() {
  // Search for existing lead or appointment
  // If lead found, create appointment at opt_in stage
  // If appointment found, move it to opt_in
  
  final appointment = SalesAppointment(
    leadId: lead.id,
    currentStage: 'opt_in',  // Starts at opt_in
    manuallyAdded: true,     // Flag for tracking
    optInProducts: selectedProducts,
    optInQuestions: questionnaireAnswers,
    paymentType: selectedPaymentType,
    // ...
  );
}
```

### Stage Transitions

#### Drag-and-Drop Movement
Same DragTarget pattern as Marketing Stream:

```dart
DragTarget<SalesAppointment>(
  onWillAcceptWithDetails: (details) {
    return StreamUtils.canMoveToStage(
      details.data.currentStage,
      stage.id,
      _stages,
    );
  },
  onAcceptWithDetails: (details) => 
    _moveAppointmentToStage(details.data, stage.id),
)
```

#### Move Appointment Process

##### Standard Stages
```dart
Future<void> _moveAppointmentToStage(
  SalesAppointment appointment,
  String newStageId,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Move ${appointment.customerName}'),
      content: Column(
        children: [
          Text('From: ${oldStage.name}'),
          Text('To: ${newStage.name}'),
          TextField(
            controller: noteController,
            decoration: InputDecoration(labelText: 'Note (optional)'),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(false), child: Text('Cancel')),
        ElevatedButton(onPressed: () => Navigator.pop(true), child: Text('Move')),
      ],
    ),
  );
  
  if (confirmed == true) {
    String? assignedToUserId;
    String? assignedToUserName;
    
    // Auto-assign if Sales Admin
    if (authProvider.userRole == UserRole.salesAdmin) {
      assignedToUserId = userId;
      assignedToUserName = userName;
    }
    
    await _appointmentService.moveAppointmentToStage(
      appointmentId: appointment.id,
      newStage: newStageId,
      note: noteController.text,
      userId: userId,
      userName: userName,
      assignedTo: assignedToUserId,
      assignedToName: assignedToUserName,
    );
  }
}
```

##### Rescheduled Stage (Special)
```dart
if (newStageId == 'rescheduled') {
  final rescheduleResult = await showDialog<RescheduleTransitionResult>(
    context: context,
    builder: (context) => RescheduleAppointmentDialog(
      appointment: appointment,
      newStageName: newStage.name,
    ),
  );
  
  if (rescheduleResult == null) return;
  
  // Create new booking for reschedule
  final booking = LeadBooking(
    leadId: appointment.leadId,
    bookingDate: rescheduleResult.bookingDate,
    bookingTime: rescheduleResult.bookingTime,
    duration: rescheduleResult.duration,
    status: BookingStatus.scheduled,
    leadHistory: [
      'Appointment Rescheduled',
      'Previous: ${appointment.appointmentDate}',
      'New: ${rescheduleResult.bookingDate}',
    ],
    assignedTo: rescheduleResult.assignedTo,
    // ...
  );
  
  await _bookingService.createBooking(booking);
  
  // Move appointment with new date/time
  await _appointmentService.moveAppointmentToStage(
    appointmentId: appointment.id,
    newStage: newStageId,
    note: rescheduleResult.note,
    appointmentDate: rescheduleResult.bookingDate,
    appointmentTime: rescheduleResult.bookingTime,
    assignedTo: rescheduleResult.assignedTo,
    assignedToName: rescheduleResult.assignedToName,
  );
}
```

##### Opt In Stage (Special)
```dart
if (newStageId == 'opt_in') {
  // Show product selection dialog
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text('Move ${appointment.customerName}'),
        content: SingleChildScrollView(
          child: Column(
            children: [
              // Note field
              TextField(controller: noteController),
              
              // Payment type selection
              RadioListTile(
                title: Text('Deposit'),
                value: 'deposit',
                groupValue: selectedPaymentType,
                onChanged: (value) => setState(() => selectedPaymentType = value!),
              ),
              RadioListTile(
                title: Text('Full Payment'),
                value: 'full_payment',
                groupValue: selectedPaymentType,
                onChanged: (value) => setState(() => selectedPaymentType = value!),
              ),
              
              // Product selection table
              SizedBox(
                height: 260,
                child: ListView.builder(
                  itemCount: products.length,
                  itemBuilder: (context, index) {
                    final product = products[index];
                    return CheckboxListTile(
                      title: Text(product.name),
                      subtitle: Text(product.description),
                      value: selectedProductIds.contains(product.id),
                      onChanged: (checked) {
                        setState(() {
                          if (checked == true) {
                            selectedProductIds.add(product.id);
                          } else {
                            selectedProductIds.remove(product.id);
                          }
                        });
                      },
                    );
                  },
                ),
              ),
              
              // Opt-in questionnaire
              ...questionControllers.entries.map((entry) {
                return TextField(
                  controller: entry.value,
                  decoration: InputDecoration(labelText: entry.key),
                );
              }),
            ],
          ),
        ),
      ),
    ),
  );
  
  if (confirmed == true) {
    // Build opt-in selections
    List<OptInProduct> optInSelections = selectedProductIds.map((id) {
      final product = products.firstWhere((p) => p.id == id);
      return OptInProduct(
        id: product.id,
        name: product.name,
        price: product.price,
      );
    }).toList();
    
    // Build questionnaire answers
    Map<String, String> optInQuestions = {};
    questionControllers.forEach((question, controller) {
      if (controller.text.trim().isNotEmpty) {
        optInQuestions[question] = controller.text.trim();
      }
    });
    
    await _appointmentService.moveAppointmentToStage(
      appointmentId: appointment.id,
      newStage: newStageId,
      note: noteController.text,
      optInProducts: optInSelections,
      optInQuestions: optInQuestions,
      paymentType: selectedPaymentType,
      assignedTo: assignedToUserId,
      assignedToName: assignedToUserName,
    );
  }
}
```

### Appointment Detail Dialog

```dart
AppointmentDetailDialog(
  appointment: appointment,
  stages: _stages,
  onAssignmentChanged: () => setState(() => _filterAppointments()),
  onDeleted: () => _loadAppointments(),
)

// Features:
// - Contact information
// - Current stage with color coding
// - Appointment date/time
// - Payment type badge (Deposit/Full Payment)
// - Form score
// - Assigned user (with reassignment for Super Admin)
// - Complete stage history with timestamps
// - All notes with author and timestamp
// - Selected products (if at opt_in or beyond)
// - Opt-in questionnaire answers
// - Ready for Operations status (deposit_made stage)
// - Edit/Delete actions
```

### Ready for Operations System

At the "Deposit Made" stage, appointments show readiness status:

```dart
// In appointment card
if (appointment.currentStage == 'deposit_made') {
  ReadyForOpsBadge(appointment: appointment, isCompact: true);
}

// ReadyForOpsBadge checks:
bool isReady = appointment.depositPaid &&  // Payment received
               appointment.optInProducts.isNotEmpty &&  // Products selected
               appointment.optInQuestions != null;  // Questionnaire complete

// Shows green "Ready" or red "Not Ready" badge
```

### View Stock Feature

Sales admins can view real-time inventory:

```dart
// "View Stock" button in header
_showStockDialog() {
  showDialog(
    context: context,
    builder: (context) => Consumer<InventoryProvider>(
      builder: (context, inventoryProvider, child) {
        final stockItems = inventoryProvider.allStockItems;
        final stats = inventoryProvider.stats;
        
        return Dialog(
          child: Column(
            children: [
              // Stats: Total, In Stock, Low Stock, Out of Stock
              _buildStatsRow(stats),
              
              // Stock list with status indicators
              ListView.builder(
                itemCount: stockItems.length,
                itemBuilder: (context, index) {
                  final stock = stockItems[index];
                  return _buildStockListItem(stock);
                },
              ),
            ],
          ),
        );
      },
    ),
  );
}
```

---

## Stage Management

### StreamStage Model

```dart
class StreamStage {
  final String id;
  final String name;
  final String color;  // Hex color code
  final int position;  // For ordering
  final bool isFinal;  // Cannot move from final stages
  
  // Marketing stages
  static List<StreamStage> getMarketingStages() {
    return [
      StreamStage(id: 'new_leads', name: 'New Leads', color: '#4A90E2', position: 0),
      StreamStage(id: 'contacted', name: 'Contacted', color: '#F5A623', position: 1),
      StreamStage(id: 'follow_up', name: 'Follow-up', color: '#7B68EE', position: 2),
      StreamStage(id: 'booking', name: 'Booking', color: '#50E3C2', position: 3),
      StreamStage(id: 'unqualified', name: 'Unqualified', color: '#D0021B', position: 4, isFinal: true),
      StreamStage(id: 'closed', name: 'Closed', color: '#4A4A4A', position: 5, isFinal: true),
    ];
  }
  
  // Sales stages
  static List<StreamStage> getSalesStages() {
    return [
      StreamStage(id: 'scheduled', name: 'Scheduled', color: '#4A90E2', position: 0),
      StreamStage(id: 'rescheduled', name: 'Rescheduled', color: '#9013FE', position: 1),
      StreamStage(id: 'confirmed', name: 'Confirmed', color: '#50E3C2', position: 2),
      StreamStage(id: 'opt_in', name: 'Opt In', color: '#F5A623', position: 3),
      StreamStage(id: 'deposit_made', name: 'Deposit Made', color: '#7ED321', position: 4),
      StreamStage(id: 'send_to_operations', name: 'Send to Operations', color: '#417505', position: 5, isFinal: true),
      StreamStage(id: 'no_answer', name: 'No Answer', color: '#BD10E0', position: 6),
      StreamStage(id: 'not_interested', name: 'Not Interested', color: '#D0021B', position: 7, isFinal: true),
    ];
  }
}
```

### StreamUtils

```dart
class StreamUtils {
  // Check if can move to target stage
  static bool canMoveToStage(
    String currentStageId,
    String targetStageId,
    List<StreamStage> stages,
  ) {
    if (currentStageId == targetStageId) return false;
    
    final currentStage = stages.firstWhere((s) => s.id == currentStageId);
    final targetStage = stages.firstWhere((s) => s.id == targetStageId);
    
    // Cannot move from final stages
    if (currentStage.isFinal) return false;
    
    // Can only move forward by one stage (position + 1)
    // OR to any final stage (for quick exits)
    return targetStage.position == currentStage.position + 1 ||
           targetStage.isFinal;
  }
  
  // Check if stage is final
  static bool isFinalStage(String stageId, List<StreamStage> stages) {
    return stages.firstWhere((s) => s.id == stageId).isFinal;
  }
  
  // Sort items by form score (high to low)
  static List<T> sortByFormScore<T>(
    List<T> items,
    int? Function(T) getScore,
  ) {
    final itemsWithScores = items.where((item) => getScore(item) != null).toList();
    final itemsWithoutScores = items.where((item) => getScore(item) == null).toList();
    
    itemsWithScores.sort((a, b) {
      final scoreA = getScore(a)!;
      final scoreB = getScore(b)!;
      return scoreB.compareTo(scoreA);  // Descending
    });
    
    return [...itemsWithScores, ...itemsWithoutScores];
  }
  
  // Add tier separators (dividers between score groups)
  static List<TieredItem<T>> withTierSeparators<T>(
    List<T> items,
    int? Function(T) getScore,
  ) {
    List<TieredItem<T>> result = [];
    int? lastScore;
    
    for (final item in items) {
      final score = getScore(item);
      
      // Add divider if score drops to next tier
      if (lastScore != null && score != null && score < lastScore - 1) {
        result.add(TieredItem<T>.divider());
      }
      
      result.add(TieredItem<T>(item: item));
      lastScore = score;
    }
    
    return result;
  }
}

class TieredItem<T> {
  final T? item;
  final bool isDivider;
  
  TieredItem({required this.item}) : isDivider = false;
  TieredItem.divider() : item = null, isDivider = true;
}
```

---

## Data Flow

### Lead Journey (End-to-End)

```
1. MARKETING STREAM - New Lead Entry
   ↓
   [Lead Created]
   - channelId: "default_channel"
   - currentStage: "new_leads"
   - formScore: 8
   - stageHistory: [{stage: "new_leads", enteredAt: now}]
   - notes: []
   
2. MARKETING STREAM - Contacted
   ↓
   User drags lead to "Contacted" stage
   ↓
   ContactedQuestionnaireDialog shown
   ↓
   User fills note: "Spoke with customer, interested in product A"
   ↓
   [Lead Updated]
   - currentStage: "contacted"
   - assignedTo: "user123" (if Marketing Admin)
   - stageHistory: [...previous, {stage: "contacted", enteredAt: now, note: "..."}]
   - notes: [...previous, {text: "...", createdBy: "user123", createdAt: now}]
   
3. MARKETING STREAM - Booking
   ↓
   User drags lead to "Booking" stage
   ↓
   BookingStageTransitionDialog shown (calendar + time picker)
   ↓
   User selects: Date: 2026-02-15, Time: "10:00 AM"
   ↓
   [LeadBooking Created]
   - id: "booking456"
   - leadId: "lead123"
   - bookingDate: 2026-02-15
   - bookingTime: "10:00 AM"
   - status: "scheduled"
   ↓
   [Lead Updated]
   - currentStage: "booking"
   - bookingId: "booking456"
   - bookingDate: 2026-02-15
   - bookingStatus: "scheduled"
   - stageHistory: [...previous, {stage: "booking", enteredAt: now, note: "..."}]
   
4. SALES STREAM - Scheduled Appointment (Automatic/Manual Creation)
   ↓
   [SalesAppointment Created]
   - id: "apt789"
   - leadId: "lead123"
   - currentStage: "scheduled"
   - appointmentDate: 2026-02-15
   - appointmentTime: "10:00 AM"
   - formScore: 8 (inherited from lead)
   - paymentType: "deposit" (default)
   - stageHistory: [{stage: "scheduled", enteredAt: now}]
   - notes: []
   
5. SALES STREAM - Confirmed
   ↓
   User drags appointment to "Confirmed"
   ↓
   Dialog shown with note field
   ↓
   User enters: "Customer confirmed attendance"
   ↓
   [SalesAppointment Updated]
   - currentStage: "confirmed"
   - assignedTo: "user456" (if Sales Admin)
   - stageHistory: [...previous, {stage: "confirmed", enteredAt: now, note: "..."}]
   - notes: [...previous, {text: "...", createdBy: "user456", createdAt: now}]
   
6. SALES STREAM - Opt In
   ↓
   User drags appointment to "Opt In"
   ↓
   Product selection dialog shown
   ↓
   User selects:
   - Payment Type: "full_payment"
   - Products: ["Product A", "Product B"]
   - Questionnaire:
     * Best phone number: "555-1234"
     * Shipping address: "123 Main St"
     * Method of payment: "Credit Card"
   ↓
   [SalesAppointment Updated]
   - currentStage: "opt_in"
   - paymentType: "full_payment"
   - optInProducts: [{id: "prod1", name: "Product A", price: 1500}, ...]
   - optInQuestions: {"Best phone number": "555-1234", ...}
   - optInNote: "..."
   - stageHistory: [...previous, {stage: "opt_in", enteredAt: now}]
   
7. SALES STREAM - Deposit Made
   ↓
   User drags appointment to "Deposit Made"
   ↓
   [SalesAppointment Updated]
   - currentStage: "deposit_made"
   - depositPaid: false (initially)
   ↓
   When payment received, Super Admin marks as paid:
   ↓
   [SalesAppointment Updated]
   - depositPaid: true
   ↓
   ReadyForOpsBadge shows "READY"
   
8. SALES STREAM - Send to Operations
   ↓
   User drags appointment to "Send to Operations"
   ↓
   [SalesAppointment Updated]
   - currentStage: "send_to_operations" (FINAL)
   ↓
   [Order Created in Operations Stream]
   - Created from SalesAppointment data
   - Contains all customer info, products, payment details
```

### Firestore Data Structure

```
firestore/
├── lead_channels/
│   └── {channelId}/
│       ├── id: string
│       ├── name: string
│       └── isDefault: boolean
│
├── leads/
│   └── {leadId}/
│       ├── id: string
│       ├── channelId: string (ref)
│       ├── firstName: string
│       ├── lastName: string
│       ├── email: string
│       ├── phone: string
│       ├── currentStage: string
│       ├── createdAt: timestamp
│       ├── updatedAt: timestamp
│       ├── assignedTo: string (optional, user UID)
│       ├── assignedToName: string (optional)
│       ├── formScore: number (optional)
│       ├── source: string (optional)
│       ├── followUpWeek: number (optional)
│       ├── bookingDate: timestamp (optional)
│       ├── bookingId: string (optional, ref)
│       ├── bookingStatus: string (optional)
│       ├── convertedToAppointmentId: string (optional, ref)
│       ├── notes: array [
│       │   {
│       │     text: string,
│       │     createdAt: timestamp,
│       │     createdBy: string (user UID),
│       │     createdByName: string
│       │   }
│       ├── ]
│       └── stageHistory: array [
│           {
│             stage: string,
│             enteredAt: timestamp,
│             note: string (optional)
│           }
│         ]
│
├── lead_bookings/
│   └── {bookingId}/
│       ├── id: string
│       ├── leadId: string (ref)
│       ├── leadName: string
│       ├── leadEmail: string
│       ├── leadPhone: string
│       ├── bookingDate: timestamp
│       ├── bookingTime: string
│       ├── duration: number (minutes)
│       ├── status: string (scheduled/completed/cancelled)
│       ├── createdBy: string (user UID)
│       ├── createdByName: string
│       ├── createdAt: timestamp
│       ├── leadSource: string
│       ├── assignedTo: string (optional)
│       └── assignedToName: string (optional)
│
└── sales_appointments/
    └── {appointmentId}/
        ├── id: string
        ├── leadId: string (ref)
        ├── customerName: string
        ├── email: string
        ├── phone: string
        ├── currentStage: string
        ├── appointmentDate: timestamp (optional)
        ├── appointmentTime: string (optional)
        ├── createdAt: timestamp
        ├── updatedAt: timestamp
        ├── stageEnteredAt: timestamp
        ├── createdBy: string (user UID)
        ├── createdByName: string
        ├── assignedTo: string (optional)
        ├── assignedToName: string (optional)
        ├── formScore: number (optional)
        ├── manuallyAdded: boolean
        ├── paymentType: string (deposit/full_payment)
        ├── depositPaid: boolean
        ├── optInNote: string (optional)
        ├── optInProducts: array [
        │   {
        │     id: string,
        │     name: string,
        │     price: number
        │   }
        ├── ]
        ├── optInQuestions: map {
        │   "question1": "answer1",
        │   "question2": "answer2"
        ├── }
        ├── notes: array [
        │   {
        │     text: string,
        │     createdAt: timestamp,
        │     createdBy: string (user UID),
        │     createdByName: string
        │   }
        ├── ]
        └── stageHistory: array [
            {
              stage: string,
              enteredAt: timestamp,
              note: string (optional)
            }
          ]
```

---

## Backend Services

### LeadService (lead_service.dart)

```dart
class LeadService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'leads';
  
  // Create new lead
  Future<String> createLead(Lead lead) async {
    final docRef = await _firestore.collection(_collection).add({
      'channelId': lead.channelId,
      'firstName': lead.firstName,
      'lastName': lead.lastName,
      'email': lead.email,
      'phone': lead.phone,
      'currentStage': lead.currentStage,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'formScore': lead.formScore,
      'source': lead.source,
      'notes': [],
      'stageHistory': [
        {
          'stage': lead.currentStage,
          'enteredAt': FieldValue.serverTimestamp(),
        }
      ],
    });
    return docRef.id;
  }
  
  // Update lead
  Future<void> updateLead(Lead lead) async {
    await _firestore.collection(_collection).doc(lead.id).update({
      'firstName': lead.firstName,
      'lastName': lead.lastName,
      'email': lead.email,
      'phone': lead.phone,
      'updatedAt': FieldValue.serverTimestamp(),
      'formScore': lead.formScore,
      'source': lead.source,
      // Don't update stage-related fields here
    });
  }
  
  // Move lead to new stage
  Future<void> moveLeadToStage({
    required String leadId,
    required String newStage,
    required String note,
    required String userId,
    required String userName,
    bool isFollowUpStage = false,
    String? assignedTo,
    String? assignedToName,
    String? bookingId,
    DateTime? bookingDate,
    String? bookingStatus,
  }) async {
    final updateData = <String, dynamic>{
      'currentStage': newStage,
      'updatedAt': FieldValue.serverTimestamp(),
      'stageHistory': FieldValue.arrayUnion([
        {
          'stage': newStage,
          'enteredAt': FieldValue.serverTimestamp(),
          'note': note.isNotEmpty ? note : null,
        }
      ]),
    };
    
    // Add note if provided
    if (note.isNotEmpty) {
      updateData['notes'] = FieldValue.arrayUnion([
        {
          'text': note,
          'createdAt': FieldValue.serverTimestamp(),
          'createdBy': userId,
          'createdByName': userName,
        }
      ]);
    }
    
    // Assignment
    if (assignedTo != null) {
      updateData['assignedTo'] = assignedTo;
      updateData['assignedToName'] = assignedToName;
    }
    
    // Follow-up specific
    if (isFollowUpStage) {
      updateData['followUpWeek'] = 1;  // Initialize to week 1
    }
    
    // Booking specific
    if (bookingId != null) {
      updateData['bookingId'] = bookingId;
      updateData['bookingDate'] = Timestamp.fromDate(bookingDate!);
      updateData['bookingStatus'] = bookingStatus;
    }
    
    await _firestore.collection(_collection).doc(leadId).update(updateData);
  }
  
  // Get single lead
  Future<Lead?> getLead(String leadId) async {
    final doc = await _firestore.collection(_collection).doc(leadId).get();
    if (!doc.exists) return null;
    return Lead.fromFirestore(doc);
  }
  
  // Stream leads for a channel
  Stream<List<Lead>> leadsStream(String channelId) {
    return _firestore
        .collection(_collection)
        .where('channelId', isEqualTo: channelId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Lead.fromFirestore(doc))
            .toList());
  }
  
  // Search leads across all channels
  Future<List<Lead>> searchLeadsAcrossAllChannels(String query) async {
    final lowercaseQuery = query.toLowerCase();
    
    // Get all leads
    final snapshot = await _firestore.collection(_collection).get();
    
    // Filter in-memory (Firestore doesn't support OR queries well)
    final results = snapshot.docs
        .map((doc) => Lead.fromFirestore(doc))
        .where((lead) {
          return lead.firstName.toLowerCase().contains(lowercaseQuery) ||
              lead.lastName.toLowerCase().contains(lowercaseQuery) ||
              lead.email.toLowerCase().contains(lowercaseQuery) ||
              lead.phone.contains(query);
        })
        .toList();
    
    return results;
  }
  
  // Delete lead
  Future<void> deleteLead(String leadId) async {
    await _firestore.collection(_collection).doc(leadId).delete();
  }
  
  // Update assignment
  Future<void> updateAssignment({
    required String leadId,
    String? assignedTo,
    String? assignedToName,
  }) async {
    await _firestore.collection(_collection).doc(leadId).update({
      'assignedTo': assignedTo,
      'assignedToName': assignedToName,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
```

### SalesAppointmentService (sales_appointment_service.dart)

```dart
class SalesAppointmentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'sales_appointments';
  
  // Create appointment
  Future<String> createAppointment(SalesAppointment appointment) async {
    final docRef = await _firestore.collection(_collection).add({
      'leadId': appointment.leadId,
      'customerName': appointment.customerName,
      'email': appointment.email,
      'phone': appointment.phone,
      'currentStage': appointment.currentStage,
      'appointmentDate': appointment.appointmentDate != null
          ? Timestamp.fromDate(appointment.appointmentDate!)
          : null,
      'appointmentTime': appointment.appointmentTime,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'stageEnteredAt': FieldValue.serverTimestamp(),
      'createdBy': appointment.createdBy,
      'createdByName': appointment.createdByName,
      'assignedTo': appointment.assignedTo,
      'assignedToName': appointment.assignedToName,
      'formScore': appointment.formScore,
      'manuallyAdded': appointment.manuallyAdded,
      'paymentType': appointment.paymentType,
      'depositPaid': false,
      'optInProducts': appointment.optInProducts
          .map((p) => {'id': p.id, 'name': p.name, 'price': p.price})
          .toList(),
      'optInQuestions': appointment.optInQuestions,
      'optInNote': appointment.optInNote,
      'notes': appointment.notes
          .map((n) => {
                'text': n.text,
                'createdAt': Timestamp.fromDate(n.createdAt),
                'createdBy': n.createdBy,
                'createdByName': n.createdByName,
              })
          .toList(),
      'stageHistory': appointment.stageHistory
          .map((h) => {
                'stage': h.stage,
                'enteredAt': Timestamp.fromDate(h.enteredAt),
                'note': h.note,
              })
          .toList(),
    });
    return docRef.id;
  }
  
  // Move appointment to new stage
  Future<void> moveAppointmentToStage({
    required String appointmentId,
    required String newStage,
    required String note,
    required String userId,
    required String userName,
    String? assignedTo,
    String? assignedToName,
    DateTime? appointmentDate,
    String? appointmentTime,
    List<OptInProduct>? optInProducts,
    Map<String, String>? optInQuestions,
    String? optInNote,
    String? paymentType,
  }) async {
    final updateData = <String, dynamic>{
      'currentStage': newStage,
      'updatedAt': FieldValue.serverTimestamp(),
      'stageEnteredAt': FieldValue.serverTimestamp(),
      'stageHistory': FieldValue.arrayUnion([
        {
          'stage': newStage,
          'enteredAt': FieldValue.serverTimestamp(),
          'note': note.isNotEmpty ? note : null,
        }
      ]),
    };
    
    // Add note
    if (note.isNotEmpty) {
      updateData['notes'] = FieldValue.arrayUnion([
        {
          'text': note,
          'createdAt': FieldValue.serverTimestamp(),
          'createdBy': userId,
          'createdByName': userName,
        }
      ]);
    }
    
    // Assignment
    if (assignedTo != null) {
      updateData['assignedTo'] = assignedTo;
      updateData['assignedToName'] = assignedToName;
    }
    
    // Date/time (for reschedule)
    if (appointmentDate != null) {
      updateData['appointmentDate'] = Timestamp.fromDate(appointmentDate);
    }
    if (appointmentTime != null) {
      updateData['appointmentTime'] = appointmentTime;
    }
    
    // Opt-in data
    if (optInProducts != null) {
      updateData['optInProducts'] = optInProducts
          .map((p) => {'id': p.id, 'name': p.name, 'price': p.price})
          .toList();
    }
    if (optInQuestions != null) {
      updateData['optInQuestions'] = optInQuestions;
    }
    if (optInNote != null) {
      updateData['optInNote'] = optInNote;
    }
    if (paymentType != null) {
      updateData['paymentType'] = paymentType;
    }
    
    await _firestore.collection(_collection).doc(appointmentId).update(updateData);
  }
  
  // Stream all appointments
  Stream<List<SalesAppointment>> appointmentsStream() {
    return _firestore
        .collection(_collection)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => SalesAppointment.fromFirestore(doc))
            .toList());
  }
  
  // Search appointments
  Future<List<SalesAppointment>> searchAppointments(String query) async {
    final lowercaseQuery = query.toLowerCase();
    
    final snapshot = await _firestore.collection(_collection).get();
    
    final results = snapshot.docs
        .map((doc) => SalesAppointment.fromFirestore(doc))
        .where((apt) {
          return apt.customerName.toLowerCase().contains(lowercaseQuery) ||
              apt.email.toLowerCase().contains(lowercaseQuery) ||
              apt.phone.contains(query);
        })
        .toList();
    
    return results;
  }
  
  // Update deposit paid status
  Future<void> updateDepositPaid({
    required String appointmentId,
    required bool depositPaid,
  }) async {
    await _firestore.collection(_collection).doc(appointmentId).update({
      'depositPaid': depositPaid,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
  
  // Delete appointment
  Future<void> deleteAppointment(String appointmentId) async {
    await _firestore.collection(_collection).doc(appointmentId).delete();
  }
  
  // Update assignment
  Future<void> updateAssignment({
    required String appointmentId,
    String? assignedTo,
    String? assignedToName,
  }) async {
    await _firestore.collection(_collection).doc(appointmentId).update({
      'assignedTo': assignedTo,
      'assignedToName': assignedToName,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
```

### LeadBookingService (lead_booking_service.dart)

```dart
class LeadBookingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'lead_bookings';
  
  // Create booking
  Future<String> createBooking(LeadBooking booking) async {
    final docRef = await _firestore.collection(_collection).add({
      'leadId': booking.leadId,
      'leadName': booking.leadName,
      'leadEmail': booking.leadEmail,
      'leadPhone': booking.leadPhone,
      'bookingDate': Timestamp.fromDate(booking.bookingDate),
      'bookingTime': booking.bookingTime,
      'duration': booking.duration,
      'status': booking.status.toString().split('.').last,
      'createdBy': booking.createdBy,
      'createdByName': booking.createdByName,
      'createdAt': FieldValue.serverTimestamp(),
      'leadSource': booking.leadSource,
      'leadHistory': booking.leadHistory,
      'assignedTo': booking.assignedTo,
      'assignedToName': booking.assignedToName,
    });
    return docRef.id;
  }
  
  // Get booking
  Future<LeadBooking?> getBooking(String bookingId) async {
    final doc = await _firestore.collection(_collection).doc(bookingId).get();
    if (!doc.exists) return null;
    return LeadBooking.fromFirestore(doc);
  }
  
  // Stream bookings
  Stream<List<LeadBooking>> bookingsStream() {
    return _firestore
        .collection(_collection)
        .orderBy('bookingDate', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => LeadBooking.fromFirestore(doc))
            .toList());
  }
  
  // Update booking status
  Future<void> updateBookingStatus({
    required String bookingId,
    required BookingStatus status,
  }) async {
    await _firestore.collection(_collection).doc(bookingId).update({
      'status': status.toString().split('.').last,
    });
  }
}
```

---

## Notes & History System

### How Notes are Stored

#### When Moving Between Stages

Notes entered during stage transitions are stored in **two places**:

1. **In the `notes` array** - For display in the notes section
2. **In the `stageHistory` array** - Associated with that stage transition

```dart
// Example: Moving lead from "New Leads" to "Contacted"
// User enters note: "Customer very interested in Product A"

await _leadService.moveLeadToStage(
  leadId: lead.id,
  newStage: 'contacted',
  note: 'Customer very interested in Product A',
  userId: 'user123',
  userName: 'John Admin',
);

// Results in Firestore update:
{
  'currentStage': 'contacted',
  'updatedAt': serverTimestamp,
  'stageHistory': FieldValue.arrayUnion([
    {
      'stage': 'contacted',
      'enteredAt': serverTimestamp,
      'note': 'Customer very interested in Product A'  // <-- Note here
    }
  ]),
  'notes': FieldValue.arrayUnion([
    {
      'text': 'Customer very interested in Product A',  // <-- Also here
      'createdAt': serverTimestamp,
      'createdBy': 'user123',
      'createdByName': 'John Admin'
    }
  ])
}
```

#### Why Two Places?

- **`stageHistory`**: Provides context about what happened during each stage transition. Shows the note inline with the stage progression.
- **`notes`**: Provides a unified chronological feed of all notes, regardless of when/why they were created.

#### Adding Manual Notes

Notes can also be added without stage transitions:

```dart
// In LeadDetailDialog or AppointmentDetailDialog
Future<void> _addNote() async {
  final noteText = _noteController.text.trim();
  if (noteText.isEmpty) return;
  
  await _leadService.addNote(
    leadId: lead.id,
    note: noteText,
    userId: userId,
    userName: userName,
  );
}

// In LeadService:
Future<void> addNote({
  required String leadId,
  required String note,
  required String userId,
  required String userName,
}) async {
  await _firestore.collection('leads').doc(leadId).update({
    'notes': FieldValue.arrayUnion([
      {
        'text': note,
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': userId,
        'createdByName': userName,
      }
    ]),
    'updatedAt': FieldValue.serverTimestamp(),
  });
}
```

### Displaying History & Notes

#### In Detail Dialogs

```dart
// LeadDetailDialog or AppointmentDetailDialog

// Stage History Tab
ListView.builder(
  itemCount: lead.stageHistory.length,
  itemBuilder: (context, index) {
    final history = lead.stageHistory[index];
    final stage = _stages.firstWhere((s) => s.id == history.stage);
    
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Color(int.parse(stage.color.replaceFirst('#', '0xff'))),
          child: Icon(Icons.flag, color: Colors.white),
        ),
        title: Text(stage.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Entered: ${_formatDate(history.enteredAt)}'),
            if (history.note != null && history.note!.isNotEmpty)
              Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(
                  history.note!,
                  style: TextStyle(fontStyle: FontStyle.italic),
                ),
              ),
          ],
        ),
      ),
    );
  },
)

// Notes Tab
ListView.builder(
  itemCount: lead.notes.length,
  itemBuilder: (context, index) {
    final note = lead.notes[index];
    
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          child: Text(note.createdByName[0].toUpperCase()),
        ),
        title: Text(note.text),
        subtitle: Text(
          '${note.createdByName} • ${_formatDate(note.createdAt)}',
        ),
      ),
    );
  },
)
```

### Timeline View (Recommended Enhancement)

For better UX, consider a unified timeline view combining both:

```dart
// Combine stageHistory and notes into single timeline
List<TimelineEvent> buildTimeline(Lead lead) {
  List<TimelineEvent> events = [];
  
  // Add stage transitions
  for (final history in lead.stageHistory) {
    events.add(TimelineEvent(
      type: TimelineEventType.stageChange,
      timestamp: history.enteredAt,
      stage: history.stage,
      note: history.note,
    ));
  }
  
  // Add notes
  for (final note in lead.notes) {
    events.add(TimelineEvent(
      type: TimelineEventType.note,
      timestamp: note.createdAt,
      text: note.text,
      createdBy: note.createdByName,
    ));
  }
  
  // Sort by timestamp
  events.sort((a, b) => b.timestamp.compareTo(a.timestamp)); // Newest first
  
  return events;
}
```

---

## Assignment System

### Role-Based Assignment

#### Super Admin
- Can see all leads/appointments
- Can reassign any lead/appointment to any admin
- Doesn't auto-assign to themselves

#### Marketing Admin
- Sees only:
  - Unassigned leads
  - Leads assigned to them
- Auto-assigned when they move a lead to "Contacted" stage
- Cannot see leads assigned to other Marketing Admins

#### Sales Admin
- Sees only:
  - Unassigned appointments
  - Appointments assigned to them
- Auto-assigned when they move an appointment
- Cannot see appointments assigned to other Sales Admins

### Assignment Logic

```dart
// In _filterLeads (Marketing Stream)
void _filterLeads() {
  final authProvider = context.read<AuthProvider>();
  final userRole = authProvider.userRole;
  final currentUserId = authProvider.user?.uid ?? '';
  
  var filtered = _allLeads;
  
  if (userRole == UserRole.marketingAdmin) {
    filtered = filtered.where((lead) {
      return lead.assignedTo == null || lead.assignedTo == currentUserId;
    }).toList();
  }
  // Super Admin sees all - no filtering
  
  _filteredLeads = filtered;
}

// In _moveLeadToStage
final shouldAssign = userRole == UserRole.marketingAdmin;

await _leadService.moveLeadToStage(
  leadId: lead.id,
  newStage: newStageId,
  assignedTo: shouldAssign ? userId : null,
  assignedToName: shouldAssign ? userName : null,
);
```

### Manual Reassignment

```dart
// In LeadDetailDialog (Super Admin only)
if (authProvider.userRole == UserRole.superAdmin) {
  // Show assignment dropdown
  DropdownButton<String>(
    value: lead.assignedTo,
    items: adminProvider.adminUsers
        .map((admin) => DropdownMenuItem(
              value: admin.uid,
              child: Text(admin.displayName),
            ))
        .toList(),
    onChanged: (newAssignedTo) async {
      final admin = adminProvider.adminUsers
          .firstWhere((a) => a.uid == newAssignedTo);
      
      await _leadService.updateAssignment(
        leadId: lead.id,
        assignedTo: newAssignedTo,
        assignedToName: admin.displayName,
      );
      
      widget.onAssignmentChanged?.call();
    },
  );
}
```

---

## Implementation Guide

### Step 1: Setup Firebase Collections

```dart
// Run this once to initialize collections
Future<void> initializeCollections() async {
  final firestore = FirebaseFirestore.instance;
  
  // Create default lead channel
  await firestore.collection('lead_channels').doc('default').set({
    'id': 'default',
    'name': 'Default Channel',
    'isDefault': true,
    'createdAt': FieldValue.serverTimestamp(),
  });
  
  // Firestore indexes (create in Firebase Console)
  // Collection: leads
  // - Index: channelId (ASC), createdAt (DESC)
  // - Index: assignedTo (ASC), currentStage (ASC)
  
  // Collection: sales_appointments
  // - Index: currentStage (ASC), createdAt (DESC)
  // - Index: assignedTo (ASC), currentStage (ASC)
}
```

### Step 2: Setup Security Rules

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Helper functions
    function isAuthenticated() {
      return request.auth != null;
    }
    
    function isSuperAdmin() {
      return isAuthenticated() && 
             get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'super_admin';
    }
    
    function isMarketingAdmin() {
      return isAuthenticated() && 
             get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'marketing_admin';
    }
    
    function isSalesAdmin() {
      return isAuthenticated() && 
             get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'sales_admin';
    }
    
    // Lead channels - read only
    match /lead_channels/{channelId} {
      allow read: if isAuthenticated();
      allow write: if isSuperAdmin();
    }
    
    // Leads
    match /leads/{leadId} {
      allow read: if isAuthenticated();
      allow create: if isMarketingAdmin() || isSuperAdmin();
      allow update: if isMarketingAdmin() || isSuperAdmin();
      allow delete: if isSuperAdmin();
    }
    
    // Lead bookings
    match /lead_bookings/{bookingId} {
      allow read: if isAuthenticated();
      allow create: if isMarketingAdmin() || isSuperAdmin();
      allow update: if isMarketingAdmin() || isSuperAdmin() || isSalesAdmin();
      allow delete: if isSuperAdmin();
    }
    
    // Sales appointments
    match /sales_appointments/{appointmentId} {
      allow read: if isAuthenticated();
      allow create: if isSalesAdmin() || isSuperAdmin();
      allow update: if isSalesAdmin() || isSuperAdmin();
      allow delete: if isSuperAdmin();
    }
  }
}
```

### Step 3: Setup Providers

```dart
// In main.dart
MultiProvider(
  providers: [
    ChangeNotifierProvider(create: (_) => AuthProvider()),
    ChangeNotifierProvider(create: (_) => AdminProvider()),
    ChangeNotifierProvider(create: (_) => ProductItemsProvider()),
    ChangeNotifierProvider(create: (_) => InventoryProvider()),
  ],
  child: MyApp(),
)
```

### Step 4: Navigation Setup

```dart
// In your navigation/routing
if (userRole == UserRole.superAdmin || 
    userRole == UserRole.marketingAdmin) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => MarketingStreamScreen(),
    ),
  );
}

if (userRole == UserRole.superAdmin || 
    userRole == UserRole.salesAdmin) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => SalesStreamScreen(),
    ),
  );
}
```

### Step 5: Testing Checklist

- [ ] Create lead in Marketing Stream
- [ ] Move lead through all stages (new_leads → contacted → follow_up → booking)
- [ ] Verify notes are saved at each transition
- [ ] Verify stage history records all movements
- [ ] Test assignment (Marketing Admin should be auto-assigned)
- [ ] Test filtering (Marketing Admin should only see their leads + unassigned)
- [ ] Create booking and verify LeadBooking record created
- [ ] Verify appointment appears in Sales Stream
- [ ] Move appointment through stages (scheduled → confirmed → opt_in → deposit_made → send_to_operations)
- [ ] Test product selection in Opt In stage
- [ ] Test questionnaire in Opt In stage
- [ ] Test payment type selection
- [ ] Test deposit paid flag
- [ ] Test "Ready for Ops" badge
- [ ] Test reschedule functionality
- [ ] Test manual add to Opt In
- [ ] Test view stock feature
- [ ] Test search functionality
- [ ] Test detail dialogs
- [ ] Test edit/delete (role-based)
- [ ] Test reassignment (Super Admin only)

### Step 6: Performance Optimization

#### Pagination (For Large Datasets)

```dart
// Instead of loading all leads at once
Stream<List<Lead>> leadsStream(String channelId) {
  return _firestore
      .collection('leads')
      .where('channelId', isEqualTo: channelId)
      .orderBy('createdAt', descending: true)
      .limit(100)  // <-- Add limit
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) => Lead.fromFirestore(doc))
          .toList());
}

// Implement "Load More" button for additional items
```

#### Caching

```dart
// Use cached data to reduce Firestore reads
Stream<List<Lead>> leadsStream(String channelId) {
  return _firestore
      .collection('leads')
      .where('channelId', isEqualTo: channelId)
      .snapshots(includeMetadataChanges: true)  // <-- Include cache
      .map((snapshot) {
        if (snapshot.metadata.isFromCache) {
          // Handle cached data
        }
        return snapshot.docs
            .map((doc) => Lead.fromFirestore(doc))
            .toList();
      });
}
```

### Step 7: Error Handling

```dart
// Wrap all service calls in try-catch
try {
  await _leadService.moveLeadToStage(...);
  
  if (mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Lead moved successfully')),
    );
  }
} on FirebaseException catch (e) {
  if (mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Firebase error: ${e.message}'),
        backgroundColor: Colors.red,
      ),
    );
  }
} catch (e) {
  if (mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Error: $e'),
        backgroundColor: Colors.red,
      ),
    );
  }
}
```

---

## Advanced Features

### 1. Analytics & Reporting

Track stage conversion rates, average time in stage, etc:

```dart
class StreamAnalytics {
  Future<Map<String, dynamic>> getMarketingMetrics() async {
    // Conversion rate: contacted → booking
    // Average time in each stage
    // Total leads by source
    // Form score distribution
  }
  
  Future<Map<String, dynamic>> getSalesMetrics() async {
    // Opt-in rate
    // Average deal value
    // Payment type distribution
    // Time to close
  }
}
```

### 2. Notifications

```dart
// Firebase Cloud Functions
exports.notifyNewLead = functions.firestore
  .document('leads/{leadId}')
  .onCreate(async (snap, context) => {
    const lead = snap.data();
    
    // Send notification to all Marketing Admins
    await sendPushNotification({
      title: 'New Lead',
      body: `${lead.firstName} ${lead.lastName} just signed up`,
      recipients: await getMarketingAdmins(),
    });
  });

exports.notifyBookingCreated = functions.firestore
  .document('lead_bookings/{bookingId}')
  .onCreate(async (snap, context) => {
    const booking = snap.data();
    
    // Auto-create appointment in sales stream
    await createSalesAppointment(booking);
    
    // Notify assigned sales admin
    if (booking.assignedTo) {
      await sendPushNotification({
        title: 'New Appointment',
        body: `${booking.leadName} scheduled for ${booking.bookingDate}`,
        recipient: booking.assignedTo,
      });
    }
  });
```

### 3. Automated Follow-ups

```dart
// Schedule follow-ups based on stage
exports.scheduleFollowUps = functions.pubsub
  .schedule('every day 09:00')
  .onRun(async (context) => {
    // Get all leads in follow-up stage
    const leads = await getFollowUpLeads();
    
    for (const lead of leads) {
      // Check if follow-up is due
      if (shouldFollowUp(lead)) {
        // Send email/SMS reminder to assigned admin
        await sendFollowUpReminder(lead);
      }
    }
  });
```

### 4. Duplicate Detection

```dart
// Before creating lead, check for duplicates
Future<bool> checkDuplicate(String email, String phone) async {
  final existingByEmail = await _firestore
      .collection('leads')
      .where('email', isEqualTo: email)
      .limit(1)
      .get();
  
  if (existingByEmail.docs.isNotEmpty) {
    return true;  // Duplicate found
  }
  
  final existingByPhone = await _firestore
      .collection('leads')
      .where('phone', isEqualTo: phone)
      .limit(1)
      .get();
  
  return existingByPhone.docs.isNotEmpty;
}
```

### 5. Export Functionality

```dart
// Export leads/appointments to CSV
Future<void> exportToCSV(List<Lead> leads) async {
  final csv = [];
  
  // Header
  csv.add(['Name', 'Email', 'Phone', 'Stage', 'Form Score', 'Created At']);
  
  // Data
  for (final lead in leads) {
    csv.add([
      lead.fullName,
      lead.email,
      lead.phone,
      lead.currentStage,
      lead.formScore?.toString() ?? '',
      lead.createdAt.toIso8601String(),
    ]);
  }
  
  final csvString = const ListToCsvConverter().convert(csv);
  
  // Save to file or share
  // ...
}
```

---

## Best Practices

### 1. Consistent Naming
- Stage IDs: `snake_case` (e.g., `new_leads`, `opt_in`)
- Stage Names: `Title Case` (e.g., "New Leads", "Opt In")
- Firebase fields: `camelCase` (e.g., `currentStage`, `assignedTo`)

### 2. Timestamps
- Always use `FieldValue.serverTimestamp()` for consistency
- Store as Firestore Timestamp, convert to DateTime in app

### 3. Null Safety
- Use `?` for optional fields
- Provide default values where appropriate
- Check `mounted` before showing dialogs/snackbars

### 4. State Management
- Use Provider for shared state (auth, products, inventory)
- Use local state (setState) for screen-specific data
- Stream Firebase data directly into widgets

### 5. User Experience
- Show loading indicators during operations
- Provide clear success/error messages
- Confirm destructive actions (delete)
- Disable actions during processing

### 6. Security
- Never trust client-side role checks alone
- Enforce security rules in Firebase
- Validate all user inputs
- Sanitize data before storing

---

## Troubleshooting

### Issue: Leads not appearing for Marketing Admin
**Solution**: Check assignment filter logic. Verify `assignedTo` field is correctly set when moving to "Contacted" stage.

### Issue: Drag-and-drop not working
**Solution**: Ensure `StreamUtils.canMoveToStage()` returns true. Check that stage is not final and target is next stage or final.

### Issue: Notes not saving
**Solution**: Check Firebase security rules. Verify `FieldValue.arrayUnion()` is used correctly. Ensure user is authenticated.

### Issue: Stage history showing wrong times
**Solution**: Use `FieldValue.serverTimestamp()` instead of `DateTime.now()` for consistent server-side timestamps.

### Issue: Search not finding results
**Solution**: Search is case-sensitive. Use `.toLowerCase()` on both query and data fields.

---

## Conclusion

This streams system provides a powerful, flexible framework for managing leads and sales appointments. Key strengths:

- **Visual Workflow**: Kanban board provides clear visibility
- **Flexible Movement**: Drag-and-drop with validation
- **Comprehensive Tracking**: Full history and notes
- **Role-Based Access**: Secure, appropriate visibility
- **Real-Time Sync**: Firebase streams for live updates
- **Scalable**: Works for small teams and large operations

By following this guide, you can implement a similar system or extend the existing one with additional features like analytics, automation, and integrations.

For questions or issues, refer to the specific service files and model definitions in the codebase.
