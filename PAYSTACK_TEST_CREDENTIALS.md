# 🧪 Paystack Test Credentials

## Test API Keys

Use these credentials for testing the payment integration in **test mode only**.

### Test Secret Key
```
sk_test_ac22dfb632bdf746bc0bcb2834fff58827a06f7e
```

### Test Public Key
```
pk_test_56da7f16c90f66bf8fd6a88c2e1a893dad0858fb
```

### Test Callback URL
```
https://example.com
```

## ⚠️ Important Notes

- **DO NOT** use these keys in production
- These keys are for **testing only**
- No real money will be charged
- Transactions are simulated

## 🚀 Quick Test Setup

### Step 1: Configure Test Keys in App

1. Open MedWave app
2. Go to **Profile** → **Payment Settings**
3. Toggle **Enable Session Fees** to ON
4. Enter **Default Session Fee**: `100` (R100 for testing)
5. Paste **Test Public Key**: `pk_test_56da7f16c90f66bf8fd6a88c2e1a893dad0858fb`
6. Paste **Test Secret Key**: `sk_test_ac22dfb632bdf746bc0bcb2834fff58827a06f7e`
7. Click **Save Changes**

### Step 2: Test Payment Flow

1. **Create Test Appointment**
   - Go to Calendar
   - Create a new appointment with any patient
   - Save the appointment

2. **Show Payment QR**
   - Open the appointment
   - Click **Payment QR** button
   - QR code should display successfully

3. **Simulate Payment**
   - Click **Mark as Paid (Cash)** button
   - Confirm the action
   - Verify success message appears

4. **Complete Session**
   - Click **Complete** on the appointment
   - Fill in session details
   - Payment should be verified automatically
   - Session should complete successfully

5. **Verify Payment Status**
   - Go to Patients → Select patient
   - View the completed session
   - Verify **"Paid"** badge appears in green
   - Verify payment amount shows: R100.00

## 🧪 Test Scenarios

### ✅ Scenario 1: Happy Path
```
1. Enable session fees (R100)
2. Create appointment
3. Show payment QR
4. Mark as paid
5. Complete session
6. Verify "Paid" badge
```
**Expected**: All steps complete successfully

### ✅ Scenario 2: Payment Required
```
1. Enable session fees
2. Create appointment
3. Try to complete session WITHOUT payment
4. Should prompt: "Payment Required"
5. Click "Show Payment QR"
6. Mark as paid
7. Complete session
```
**Expected**: Payment prompt appears, session completes after payment

### ✅ Scenario 3: Manual Cash Payment
```
1. Enable session fees
2. Create appointment
3. Show payment QR
4. Click "Mark as Paid (Cash)"
5. Confirm action
6. Complete session
```
**Expected**: Payment recorded as cash, session completes

### ✅ Scenario 4: Payment Cancellation
```
1. Enable session fees
2. Create appointment
3. Show payment QR
4. Click "Cancel Payment"
5. Confirm cancellation
```
**Expected**: Payment cancelled, can create new payment

### ✅ Scenario 5: View Payment History
```
1. Complete session with payment
2. Go to session details
3. Check payment badge
4. Verify amount displayed
```
**Expected**: Payment status visible in session

## 🔍 What to Verify

### In the App
- ✅ Payment settings save correctly
- ✅ QR code displays properly
- ✅ Payment status updates in real-time
- ✅ Success messages appear
- ✅ Payment badges show correct colors
- ✅ Session completion works with payment

### In Firestore Console
1. Go to Firebase Console → Firestore Database
2. Check `payments` collection
3. Verify payment document created with:
   - ✅ Correct amount (10000 cents = R100)
   - ✅ Status: "completed"
   - ✅ Payment method: "cash" or "qrCode"
   - ✅ Patient and practitioner IDs
   - ✅ Payment reference (MEDWAVE_...)
   - ✅ Timestamps

4. Check `sessions` subcollection
5. Verify session has:
   - ✅ paymentId linked
   - ✅ paymentStatus: "completed"
   - ✅ paymentAmount: 100

## 📊 Expected Firestore Structure

### Payment Document
```json
{
  "id": "payment_123...",
  "appointmentId": "appointment_456...",
  "patientId": "patient_789...",
  "patientName": "John Doe",
  "practitionerId": "practitioner_abc...",
  "amount": 100,
  "currency": "ZAR",
  "status": "completed",
  "paymentMethod": "cash",
  "paymentReference": "MEDWAVE_1730419200000_patient78",
  "createdAt": "2024-10-31T12:00:00Z",
  "completedAt": "2024-10-31T12:05:00Z"
}
```

### Session Document
```json
{
  "id": "session_123...",
  "patientId": "patient_789...",
  "sessionNumber": 1,
  "paymentId": "payment_123...",
  "paymentStatus": "completed",
  "paymentAmount": 100,
  ...
}
```

## 🐛 Troubleshooting

### Issue: QR Code Not Showing
**Solution**: 
- Verify API keys are saved in profile
- Check session fees are enabled
- Restart the app

### Issue: Payment Not Saving
**Solution**:
- Check Firebase console for errors
- Verify Firestore rules are deployed
- Check network connection

### Issue: Session Won't Complete
**Solution**:
- Verify payment status is "completed"
- Check payment is linked to appointment
- Try marking as paid manually

### Issue: API Key Error
**Solution**:
- Copy keys exactly as shown (no spaces)
- Use test keys (starting with sk_test_ and pk_test_)
- Regenerate keys if needed

## 📱 Test on Different Devices

- ✅ iOS device/simulator
- ✅ Android device/emulator
- ✅ Different screen sizes
- ✅ Different network conditions

## ✅ Testing Checklist

Before marking as complete, verify:

- [ ] Test keys configured in app
- [ ] Session fees enabled (R100)
- [ ] QR code displays correctly
- [ ] "Mark as Paid" works
- [ ] Payment status updates
- [ ] Session completion works
- [ ] Payment badge shows in session detail
- [ ] Payment amount displays correctly
- [ ] Firestore payment document created
- [ ] Session linked to payment
- [ ] Payment can be cancelled
- [ ] Multiple payments can be created
- [ ] Payment history is accurate

## 🎓 Next Steps After Testing

1. **Verify All Scenarios** - Complete all test scenarios above
2. **Check Firestore Data** - Verify all payment records
3. **Test Edge Cases** - Try unusual scenarios
4. **Document Issues** - Note any bugs found
5. **Get Live Keys** - When ready, switch to production keys

## 🔄 Switching to Production

When ready to go live:

1. Get live keys from Paystack dashboard
2. Replace test keys with live keys:
   - `pk_live_...` (Public Key)
   - `sk_live_...` (Secret Key)
3. Test with small amounts first
4. Monitor Paystack dashboard
5. Verify real payments work

## 📞 Support

If you encounter issues during testing:

1. Check Firebase Console logs
2. Review Firestore security rules
3. Verify API keys are correct
4. Check network connectivity
5. Review implementation docs

---

**🎉 Ready to test! Follow the scenarios above and verify everything works correctly.**

**Note**: These are TEST credentials - no real money will be processed!

