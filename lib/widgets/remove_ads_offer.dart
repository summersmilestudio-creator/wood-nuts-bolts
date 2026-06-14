import 'package:flutter/material.dart';
import '../services/iap_service.dart';

/// The "no ads" upsell. Shown as a sheet right after a full-screen interstitial
/// is dismissed ("if they don't want to buy, the No-Ads option appears"), and
/// also reachable as a button on the home screen.
class RemoveAdsOffer {
  RemoveAdsOffer._();

  /// Once the user declines during a session we stop nagging until next launch.
  static bool _silencedForSession = false;

  /// Rate-limit for the global "ad closed" upsell trigger so it never spams.
  static DateTime? _lastShown;
  static const Duration _cooldown = Duration(minutes: 2);

  /// Driven by the global `adClosedTick` listener (App Open / interstitial
  /// dismissed). Rate-limited to once every 2 minutes and skipped when ads are
  /// already removed or the store is unavailable.
  static Future<void> maybeShow(BuildContext? context) async {
    if (context == null || !context.mounted) return;
    final iap = IapService.instance;
    if (iap.noAds || _silencedForSession || !iap.storeAvailable) return;
    if (_lastShown != null &&
        DateTime.now().difference(_lastShown!) < _cooldown) {
      return;
    }
    _lastShown = DateTime.now();
    await show(context, fromAd: true);
  }

  /// Call right after an interstitial closes. No-op if ads already removed,
  /// already declined this session, or the store has nothing to sell.
  static Future<void> maybeShowAfterAd(BuildContext context) async {
    final iap = IapService.instance;
    if (iap.noAds || _silencedForSession || !iap.storeAvailable) return;
    if (!context.mounted) return;
    await show(context, fromAd: true);
  }

  /// Opens the offer sheet. [fromAd] tweaks the copy + remembers a decline.
  static Future<void> show(BuildContext context, {bool fromAd = false}) async {
    final iap = IapService.instance;
    if (iap.noAds) return;
    final bought = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: const Color(0xFF3A2614),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _OfferSheet(fromAd: fromAd),
    );
    if (fromAd && bought != true) _silencedForSession = true;
  }
}

class _OfferSheet extends StatefulWidget {
  const _OfferSheet({required this.fromAd});
  final bool fromAd;

  @override
  State<_OfferSheet> createState() => _OfferSheetState();
}

class _OfferSheetState extends State<_OfferSheet> {
  @override
  void initState() {
    super.initState();
    IapService.instance.addListener(_onIap);
  }

  @override
  void dispose() {
    IapService.instance.removeListener(_onIap);
    super.dispose();
  }

  void _onIap() {
    if (!mounted) return;
    if (IapService.instance.noAds) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {}); // refresh pending state / price
    }
  }

  @override
  Widget build(BuildContext context) {
    final iap = IapService.instance;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 22, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44, height: 5,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(height: 22),
            const Icon(Icons.block_rounded, size: 56, color: Color(0xFFFFCA3A)),
            const SizedBox(height: 14),
            const Text(
              'Joacă fără reclame',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              widget.fromAd
                  ? 'Nu vrei reclame? Elimină-le definitiv și bucură-te de joc fără întreruperi.'
                  : 'Elimină definitiv reclamele din joc. Plată unică.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 15, height: 1.35),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8AC926),
                  foregroundColor: Colors.black87,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: iap.purchasePending ? null : () => iap.buyRemoveAds(),
                child: iap.purchasePending
                    ? const SizedBox(
                        height: 22, width: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.4, color: Colors.black54),
                      )
                    : Text(
                        'Elimină reclamele · ${iap.removeAdsPrice}',
                        style: const TextStyle(
                            fontSize: 17, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => iap.restore(),
              child: const Text('Restaurează achiziția',
                  style: TextStyle(color: Colors.white54, fontSize: 13)),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Nu acum',
                  style: TextStyle(color: Colors.white70, fontSize: 15)),
            ),
          ],
        ),
      ),
    );
  }
}
