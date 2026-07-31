import 'package:flutter/foundation.dart';

/// Tracks whether the user has unlocked Premium.
///
/// This is a lightweight **in-memory stub, not a real purchase flow**.
/// Wiring up actual billing (App Store / Google Play Billing) needs
/// store-side setup this codebase can't do for you - registering
/// in-app-purchase product IDs, tax/banking info, and signing in each
/// developer console. When you're ready for that, swap this class out
/// for the `in_app_purchase` package's real purchase stream and call
/// `isPremium.value = true` from its "purchase successful" callback
/// instead of from [unlock]. Nothing else in the app needs to change -
/// every gated feature only ever reads `PremiumService.instance.isPremium`.
class PremiumService {
  PremiumService._();
  static final PremiumService instance = PremiumService._();

  final ValueNotifier<bool> isPremium = ValueNotifier<bool>(false);

  /// Stand-in for a successful purchase. See the class doc.
  void unlock() => isPremium.value = true;

  void reset() => isPremium.value = false;
}
