import 'dart:async';
import 'package:flutter/material.dart';
import '../../utils/logger.dart';

/// Shows a small WebView that loads the Cloudflare Turnstile widget (assets/turnstile.html)
/// and returns the captcha token when the widget completes. Call using:
/// final token = await TurnstileWidget.show(context, siteKey: '...');
class TurnstileWidget extends StatefulWidget {
  final String siteKey;
  final String? baseUrl;
  const TurnstileWidget({super.key, required this.siteKey, this.baseUrl});

  static Future<String?> show(BuildContext ctx, {required String siteKey, String? baseUrl}) async {
    Logger.i('TurnstileWidget disabled: returning null');
    return null;
  }

  @override
  State<TurnstileWidget> createState() => _TurnstileWidgetState();
}

class _TurnstileWidgetState extends State<TurnstileWidget> {
  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
