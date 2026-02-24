import '../../../../../models/streams/appointment.dart';

/// Pure helpers for Deposits analytics (no Firestore).

/// Returns the [DateTime] when this appointment entered the deposit_made stage, or null.
DateTime? getDepositMadeEnteredAt(SalesAppointment a) {
  for (final entry in a.stageHistory) {
    if (entry.stage == 'deposit_made') {
      return entry.enteredAt;
    }
  }
  return null;
}

/// True if this appointment has ever entered the deposit_made stage.
bool hasEverEnteredDepositMade(SalesAppointment a) {
  return getDepositMadeEnteredAt(a) != null;
}
