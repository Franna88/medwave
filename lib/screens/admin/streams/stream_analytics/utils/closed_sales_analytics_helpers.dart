import '../../../../../models/streams/order.dart';

/// Pure helpers for Closed Sales analytics (no Firestore).

/// Returns the [DateTime] when this order entered the payment stage, or null.
DateTime? getPaymentEnteredAt(Order o) {
  for (final entry in o.stageHistory) {
    if (entry.stage == 'payment') {
      return entry.enteredAt;
    }
  }
  return null;
}

/// True if this order has ever entered the payment stage (closed sale).
bool hasEverEnteredPayment(Order o) {
  return getPaymentEnteredAt(o) != null;
}

/// Order value: subtotal when present, else sum of price * quantity from items.
double getOrderValue(Order o) {
  if (o.subtotal != null) return o.subtotal!;
  return o.items.fold<double>(
    0,
    (sum, i) => sum + ((i.price ?? 0) * i.quantity),
  );
}
