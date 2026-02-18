import '../../../../../models/streams/appointment.dart';

/// Pure helpers for Opt In analytics (no Firestore).

/// Stages that count as "moved to deposit requested or later" for conversion.
const _depositOrLaterStages = {
  'deposit_requested',
  'deposit_made',
  'send_to_operations',
};

/// Returns the [DateTime] when this appointment entered the opt_in stage, or null.
DateTime? getOptInEnteredAt(SalesAppointment a) {
  for (final entry in a.stageHistory) {
    if (entry.stage == 'opt_in') {
      return entry.enteredAt;
    }
  }
  return null;
}

/// True if this appointment has ever entered the opt_in stage.
bool hasEverEnteredOptIn(SalesAppointment a) {
  return getOptInEnteredAt(a) != null;
}

/// True if this appointment has reached deposit_requested or a later stage (converted).
bool hasMovedToDepositRequestedOrLater(SalesAppointment a) {
  return a.stageHistory.any((e) => _depositOrLaterStages.contains(e.stage));
}
