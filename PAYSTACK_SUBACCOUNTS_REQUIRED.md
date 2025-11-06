# 🚨 IMPORTANT: Paystack Subaccounts Required

## ❌ Current Implementation Issue

The current Paystack integration has a **critical flaw**:

### What Happens Now:
```
Patient Payment (R100)
    ↓
Single Paystack Account (whoever's API keys are used)
    ↓
Money STAYS in Paystack account
    ↓ (manual payout required)
Bank account linked to API keys
```

### ⚠️ Problems:
1. ❌ All payments go to **ONE account** (not the practitioner's)
2. ❌ Money **does NOT automatically** reach practitioner
3. ❌ Requires **manual payouts** or scheduled settlements
4. ❌ Practitioner doesn't receive funds directly
5. ❌ Not scalable for multiple practitioners

## ✅ Correct Implementation: Paystack Subaccounts

### What Should Happen:
```
Patient Payment (R100)
    ↓
Main Paystack Account (Platform/Admin)
    ↓ (automatic split via subaccount)
    ├─→ Practitioner Bank Account (R95-100) - Direct & Automatic
    └─→ Platform Commission (R0-5) - Optional
```

### ✅ Benefits:
1. ✅ **Automatic payouts** to practitioner's bank account
2. ✅ **Direct settlement** - no manual intervention
3. ✅ Each practitioner links **their own bank account**
4. ✅ Platform can take **optional commission**
5. ✅ Full **transaction tracking** per practitioner
6. ✅ Scalable for **unlimited practitioners**

## 🏗️ How Paystack Subaccounts Work

### 1. Create Subaccount for Each Practitioner

**API Endpoint:** `POST https://api.paystack.co/subaccount`

**Request:**
```json
{
  "business_name": "Dr. John Doe",
  "settlement_bank": "058", // Bank code (e.g., GTBank)
  "account_number": "0123456789",
  "percentage_charge": 5, // Platform takes 5% (optional, can be 0)
  "description": "Wound Care Practitioner - Johannesburg",
  "primary_contact_email": "john.doe@example.com",
  "primary_contact_name": "John Doe",
  "primary_contact_phone": "+27821234567"
}
```

**Response:**
```json
{
  "status": true,
  "message": "Subaccount created",
  "data": {
    "subaccount_code": "ACCT_8f4k1eq7ml0rlzj",
    "business_name": "Dr. John Doe",
    "settlement_bank": "GTBank",
    "account_number": "0123456789",
    "percentage_charge": 5,
    "is_verified": false,
    "settlement_schedule": "auto",
    "active": true,
    "migrate": false,
    "id": 37614,
    "createdAt": "2024-10-31T12:00:00.000Z",
    "updatedAt": "2024-10-31T12:00:00.000Z"
  }
}
```

### 2. Store Subaccount Code in Practitioner Profile

Add to `UserProfile` model:
```dart
class UserProfile {
  // ... existing fields
  
  // Paystack Integration
  final String? paystackSubaccountCode; // e.g., "ACCT_8f4k1eq7ml0rlzj"
  final bool paystackSubaccountVerified;
  final String? bankName;
  final String? bankAccountNumber;
  final String? bankAccountName;
  
  // ...
}
```

### 3. Use Subaccount in Payment Initialization

**Modified Payment Request:**
```dart
// When initializing payment, include subaccount
await PayWithPayStack().now(
  context: context,
  secretKey: platformSecretKey, // Platform's secret key
  customerEmail: patientEmail,
  reference: uniqueTransRef,
  currency: 'ZAR',
  amount: (amount * 100).toInt(), // Amount in cents
  subaccountCode: practitionerSubaccountCode, // ✅ Key addition!
  bearer: PaystackBearer.subaccount, // Subaccount pays transaction fees
  transactionCharge: 500, // Platform fee in kobo (R5 = 500 kobo) - optional
  // ...
);
```

### 4. Payment Flow with Subaccount

```
Patient scans QR (R100)
    ↓
Payment processed via Platform Paystack Account
    ↓
Paystack automatically splits:
    ├─→ Practitioner Subaccount: R95 (95%)
    │   ↓ (automatic settlement)
    │   Practitioner's Bank Account
    │
    └─→ Platform Account: R5 (5% commission)
        ↓ (automatic settlement)
        Platform's Bank Account
```

## 🔧 Implementation Changes Required

### Phase 1: Update Data Models

#### 1.1 Update `UserProfile` Model
```dart
// lib/models/user_profile.dart

class UserProfile {
  // ... existing fields
  
  // Paystack Subaccount Integration
  final String? paystackSubaccountCode;
  final bool paystackSubaccountVerified;
  final String? bankName;
  final String? bankCode; // Paystack bank code (e.g., "058")
  final String? bankAccountNumber;
  final String? bankAccountName;
  final double platformCommissionPercentage; // e.g., 5.0 for 5%
  
  // ...
}
```

#### 1.2 Update `Payment` Model
```dart
// lib/models/payment.dart

class Payment {
  // ... existing fields
  
  final String? subaccountCode; // Practitioner's subaccount
  final double? platformCommission; // Amount kept by platform
  final double? practitionerAmount; // Amount to practitioner
  final String? settlementStatus; // 'pending', 'settled', 'failed'
  final DateTime? settlementDate;
  
  // ...
}
```

### Phase 2: Create Subaccount Management Service

```dart
// lib/services/paystack_subaccount_service.dart

class PaystackSubaccountService {
  final String _secretKey;
  final String _baseUrl = 'https://api.paystack.co';
  
  PaystackSubaccountService(this._secretKey);
  
  /// Create a subaccount for a practitioner
  Future<SubaccountResponse> createSubaccount({
    required String businessName,
    required String bankCode,
    required String accountNumber,
    required String email,
    required String phone,
    double percentageCharge = 0, // Platform commission
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/subaccount'),
      headers: {
        'Authorization': 'Bearer $_secretKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'business_name': businessName,
        'settlement_bank': bankCode,
        'account_number': accountNumber,
        'percentage_charge': percentageCharge,
        'primary_contact_email': email,
        'primary_contact_name': businessName,
        'primary_contact_phone': phone,
      }),
    );
    
    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(response.body);
      return SubaccountResponse.fromJson(data['data']);
    } else {
      throw Exception('Failed to create subaccount: ${response.body}');
    }
  }
  
  /// Verify bank account details
  Future<BankAccountVerification> verifyBankAccount({
    required String accountNumber,
    required String bankCode,
  }) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/bank/resolve?account_number=$accountNumber&bank_code=$bankCode'),
      headers: {
        'Authorization': 'Bearer $_secretKey',
      },
    );
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return BankAccountVerification.fromJson(data['data']);
    } else {
      throw Exception('Failed to verify bank account: ${response.body}');
    }
  }
  
  /// Get list of supported banks
  Future<List<Bank>> getBanks({String country = 'south-africa'}) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/bank?country=$country'),
      headers: {
        'Authorization': 'Bearer $_secretKey',
      },
    );
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return (data['data'] as List)
          .map((bank) => Bank.fromJson(bank))
          .toList();
    } else {
      throw Exception('Failed to get banks: ${response.body}');
    }
  }
  
  /// Update subaccount
  Future<bool> updateSubaccount({
    required String subaccountCode,
    String? businessName,
    String? bankCode,
    String? accountNumber,
    double? percentageCharge,
  }) async {
    final body = <String, dynamic>{};
    if (businessName != null) body['business_name'] = businessName;
    if (bankCode != null) body['settlement_bank'] = bankCode;
    if (accountNumber != null) body['account_number'] = accountNumber;
    if (percentageCharge != null) body['percentage_charge'] = percentageCharge;
    
    final response = await http.put(
      Uri.parse('$_baseUrl/subaccount/$subaccountCode'),
      headers: {
        'Authorization': 'Bearer $_secretKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );
    
    return response.statusCode == 200;
  }
}

class SubaccountResponse {
  final String subaccountCode;
  final String businessName;
  final String settlementBank;
  final String accountNumber;
  final double percentageCharge;
  final bool isVerified;
  
  SubaccountResponse({
    required this.subaccountCode,
    required this.businessName,
    required this.settlementBank,
    required this.accountNumber,
    required this.percentageCharge,
    required this.isVerified,
  });
  
  factory SubaccountResponse.fromJson(Map<String, dynamic> json) {
    return SubaccountResponse(
      subaccountCode: json['subaccount_code'],
      businessName: json['business_name'],
      settlementBank: json['settlement_bank'],
      accountNumber: json['account_number'],
      percentageCharge: json['percentage_charge'].toDouble(),
      isVerified: json['is_verified'] ?? false,
    );
  }
}

class BankAccountVerification {
  final String accountNumber;
  final String accountName;
  final String bankCode;
  
  BankAccountVerification({
    required this.accountNumber,
    required this.accountName,
    required this.bankCode,
  });
  
  factory BankAccountVerification.fromJson(Map<String, dynamic> json) {
    return BankAccountVerification(
      accountNumber: json['account_number'],
      accountName: json['account_name'],
      bankCode: json['bank_id'].toString(),
    );
  }
}

class Bank {
  final String name;
  final String code;
  final String country;
  
  Bank({
    required this.name,
    required this.code,
    required this.country,
  });
  
  factory Bank.fromJson(Map<String, dynamic> json) {
    return Bank(
      name: json['name'],
      code: json['code'],
      country: json['country'] ?? 'South Africa',
    );
  }
}
```

### Phase 3: Update Payment Service

```dart
// lib/services/paystack_service.dart

class PaystackService {
  // ... existing code
  
  Future<String?> initializePayment({
    required BuildContext context,
    required String publicKey,
    required String secretKey,
    required String customerEmail,
    required double amount,
    required String currency,
    required String appointmentId,
    required String patientId,
    required String practitionerId,
    required String? subaccountCode, // ✅ NEW: Practitioner's subaccount
    double platformCommissionPercentage = 0, // ✅ NEW: Platform commission
    String? callbackUrl,
  }) async {
    final uniqueTransRef = _uuid.v4();
    
    // Calculate commission
    final platformCommission = (amount * platformCommissionPercentage) / 100;
    final practitionerAmount = amount - platformCommission;
    
    // Create payment record
    final newPayment = Payment(
      id: uniqueTransRef,
      appointmentId: appointmentId,
      patientId: patientId,
      practitionerId: practitionerId,
      amount: amount,
      currency: currency,
      status: 'pending',
      paystackReference: uniqueTransRef,
      createdAt: DateTime.now(),
      paymentMethod: 'qr_code',
      subaccountCode: subaccountCode, // ✅ NEW
      platformCommission: platformCommission, // ✅ NEW
      practitionerAmount: practitionerAmount, // ✅ NEW
    );
    
    await _firestore.collection('payments').doc(uniqueTransRef).set(newPayment.toFirestore());
    
    try {
      await PayWithPayStack().now(
        context: context,
        secretKey: secretKey,
        customerEmail: customerEmail,
        reference: uniqueTransRef,
        currency: currency,
        amount: (amount * 100).toInt(),
        subaccountCode: subaccountCode, // ✅ NEW: Route to practitioner
        bearer: PaystackBearer.subaccount, // ✅ NEW: Subaccount pays fees
        transactionCharge: (platformCommission * 100).toInt(), // ✅ NEW: Platform fee
        callbackUrl: callbackUrl,
        transactionCompleted: (paymentData) async {
          await _updatePaymentStatus(uniqueTransRef, 'completed', paymentData['message']);
        },
        transactionNotCompleted: (paymentData) async {
          await _updatePaymentStatus(uniqueTransRef, 'failed', paymentData['message']);
        },
      );
      
      return 'https://paystack.com/pay/$uniqueTransRef';
    } catch (e) {
      await _updatePaymentStatus(uniqueTransRef, 'failed', e.toString());
      rethrow;
    }
  }
}
```

### Phase 4: Add Bank Account Setup UI

Create a new screen for practitioners to link their bank account:

```dart
// lib/screens/profile/bank_account_setup_screen.dart

class BankAccountSetupScreen extends StatefulWidget {
  @override
  State<BankAccountSetupScreen> createState() => _BankAccountSetupScreenState();
}

class _BankAccountSetupScreenState extends State<BankAccountSetupScreen> {
  List<Bank> _banks = [];
  Bank? _selectedBank;
  final _accountNumberController = TextEditingController();
  String? _accountName;
  bool _isVerifying = false;
  bool _isCreatingSubaccount = false;
  
  @override
  void initState() {
    super.initState();
    _loadBanks();
  }
  
  Future<void> _loadBanks() async {
    // Load South African banks from Paystack
    final subaccountService = PaystackSubaccountService(platformSecretKey);
    final banks = await subaccountService.getBanks(country: 'south-africa');
    setState(() {
      _banks = banks;
    });
  }
  
  Future<void> _verifyBankAccount() async {
    if (_selectedBank == null || _accountNumberController.text.isEmpty) {
      return;
    }
    
    setState(() {
      _isVerifying = true;
      _accountName = null;
    });
    
    try {
      final subaccountService = PaystackSubaccountService(platformSecretKey);
      final verification = await subaccountService.verifyBankAccount(
        accountNumber: _accountNumberController.text,
        bankCode: _selectedBank!.code,
      );
      
      setState(() {
        _accountName = verification.accountName;
        _isVerifying = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Account verified: ${verification.accountName}'),
          backgroundColor: AppTheme.successColor,
        ),
      );
    } catch (e) {
      setState(() {
        _isVerifying = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Verification failed: $e'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }
  
  Future<void> _createSubaccount() async {
    if (_accountName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please verify your bank account first'),
          backgroundColor: AppTheme.warningColor,
        ),
      );
      return;
    }
    
    setState(() {
      _isCreatingSubaccount = true;
    });
    
    try {
      final userProfile = context.read<UserProfileProvider>().userProfile!;
      final subaccountService = PaystackSubaccountService(platformSecretKey);
      
      final response = await subaccountService.createSubaccount(
        businessName: userProfile.fullName,
        bankCode: _selectedBank!.code,
        accountNumber: _accountNumberController.text,
        email: userProfile.email,
        phone: userProfile.phoneNumber,
        percentageCharge: 5, // Platform takes 5% commission
      );
      
      // Update user profile with subaccount code
      await _updateUserProfileWithSubaccount(
        subaccountCode: response.subaccountCode,
        bankName: _selectedBank!.name,
        bankCode: _selectedBank!.code,
        accountNumber: _accountNumberController.text,
        accountName: _accountName!,
      );
      
      setState(() {
        _isCreatingSubaccount = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bank account linked successfully!'),
          backgroundColor: AppTheme.successColor,
        ),
      );
      
      Navigator.of(context).pop();
    } catch (e) {
      setState(() {
        _isCreatingSubaccount = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to link bank account: $e'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }
  
  // ... UI implementation
}
```

## 📋 Implementation Checklist

### ✅ Phase 1: Data Models (1-2 hours)
- [ ] Update `UserProfile` model with subaccount fields
- [ ] Update `Payment` model with split payment fields
- [ ] Update Firestore security rules for subaccounts
- [ ] Test model serialization/deserialization

### ✅ Phase 2: Subaccount Service (2-3 hours)
- [ ] Create `PaystackSubaccountService` class
- [ ] Implement `createSubaccount` method
- [ ] Implement `verifyBankAccount` method
- [ ] Implement `getBanks` method
- [ ] Implement `updateSubaccount` method
- [ ] Add error handling and logging
- [ ] Test all API endpoints

### ✅ Phase 3: Update Payment Flow (2-3 hours)
- [ ] Update `PaystackService.initializePayment` to use subaccounts
- [ ] Add subaccount parameter to payment initialization
- [ ] Calculate and store platform commission
- [ ] Update payment verification to check settlement status
- [ ] Test payment flow with subaccount

### ✅ Phase 4: Bank Account Setup UI (3-4 hours)
- [ ] Create `BankAccountSetupScreen`
- [ ] Add bank selection dropdown
- [ ] Add account number input
- [ ] Implement account verification
- [ ] Add subaccount creation flow
- [ ] Update profile screen with "Link Bank Account" button
- [ ] Show bank account status in profile
- [ ] Test complete UI flow

### ✅ Phase 5: Testing & Validation (2-3 hours)
- [ ] Test subaccount creation with test data
- [ ] Test payment with subaccount
- [ ] Verify automatic settlement
- [ ] Test commission calculation
- [ ] Test error scenarios
- [ ] Verify Firestore data integrity
- [ ] Test on multiple devices

### ✅ Phase 6: Documentation (1 hour)
- [ ] Document subaccount setup process
- [ ] Create practitioner onboarding guide
- [ ] Document commission structure
- [ ] Create troubleshooting guide

## 🎯 Estimated Total Time: 12-16 hours

## 🚨 Critical Notes

### 1. Platform API Keys
- Use **ONE set of platform API keys** (not individual practitioner keys)
- All payments route through platform account
- Platform manages all subaccounts

### 2. Commission Structure
- Decide on platform commission (e.g., 5%)
- Can be 0% if no commission desired
- Can vary per practitioner if needed

### 3. Settlement Schedule
- Paystack default: T+1 (next business day)
- Can enable instant settlement (additional fees)
- Practitioner receives funds automatically

### 4. Bank Account Verification
- **Always verify** bank account before creating subaccount
- Prevents errors and failed settlements
- Shows account holder name for confirmation

### 5. Supported Banks (South Africa)
- ABSA
- Capitec
- FNB
- Nedbank
- Standard Bank
- And more...

## 📞 Next Steps

### Option A: Implement Subaccounts (Recommended)
**Pros:**
- ✅ Automatic payouts to practitioners
- ✅ Scalable for multiple practitioners
- ✅ Platform can take commission
- ✅ Professional and automated

**Cons:**
- ⏱️ Requires 12-16 hours implementation
- 🔧 More complex setup
- 📝 Requires bank account linking

### Option B: Manual Payouts (Not Recommended)
**Pros:**
- ✅ No code changes needed
- ✅ Simple setup

**Cons:**
- ❌ Manual work for every payment
- ❌ Not scalable
- ❌ Delayed payments to practitioners
- ❌ Accounting nightmare

## 🎯 Recommendation

**Implement Paystack Subaccounts immediately** before launching to practitioners. This is essential for:
1. ✅ Automatic practitioner payouts
2. ✅ Professional payment experience
3. ✅ Scalability
4. ✅ Proper financial tracking
5. ✅ Practitioner trust and satisfaction

**Without subaccounts, the payment system is incomplete and not production-ready.**

---

**Would you like me to implement the Paystack Subaccounts integration now?** 🚀

