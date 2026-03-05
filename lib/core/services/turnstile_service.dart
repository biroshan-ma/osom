import '../utils/logger.dart';
import 'package:cloudflare_turnstile/cloudflare_turnstile.dart';

/// Turnstile service that retrieves a Cloudflare Turnstile token using invisible mode.
///
/// Note: Replace the `siteKey` value with your real site key before releasing.
class TurnstileService {
  /// Retrieves the CloudFlare Turnstile token using invisible mode.
  static Future<String?> get token async {
    // Initialize an instance of invisible Cloudflare Turnstile with your site key
    final turnstile = CloudflareTurnstile.invisible(
      siteKey: '0x4AAAAAAAfGaE18tbkrUnve', // TODO: replace with your actual site key
    );

    try {
      // Get the Turnstile token
      final token = await turnstile.getToken();
      return token; // Return the token upon success
    } on TurnstileException catch (e) {
      // Handle Turnstile failure (UI callers will treat null as failure)
      Logger.e('Turnstile challenge failed: ${e.message}');
    } finally {
      // Ensure the Turnstile instance is properly disposed of
      turnstile.dispose();
    }

    // Return null if the token couldn't be generated
    return null;
  }
}

// Backwards-compatible top-level helper in case other code relied on the previous
// `getTurnstileToken` signature. This simply delegates to the new service.
Future<String?> getTurnstileToken({
  required String siteKey,
}) async {
  // If callers previously passed different siteKey, update TurnstileService to accept it
  return await TurnstileService.token;
}
