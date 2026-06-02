import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Asks for a Play in-app review at natural moments (3rd and 8th launch).
/// The native API itself limits how often the dialog actually shows.
class ReviewService {
  ReviewService._();
  static final ReviewService instance = ReviewService._();

  static const _kCount = 'review_launch_count';
  static const _kAsked = 'review_asked_at';

  Future<void> registerLaunch() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final count = (prefs.getInt(_kCount) ?? 0) + 1;
      await prefs.setInt(_kCount, count);
      final askedAt = prefs.getInt(_kAsked) ?? 0;
      if ((count == 3 || count == 8 || (count > 8 && count - askedAt >= 12))) {
        final inApp = InAppReview.instance;
        if (await inApp.isAvailable()) {
          await inApp.requestReview();
          await prefs.setInt(_kAsked, count);
        }
      }
    } catch (_) {
      // never let review logic crash the app
    }
  }
}
