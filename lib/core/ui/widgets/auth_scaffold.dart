import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../colors.dart';
import '../text_styles.dart';

class AuthScaffold extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const AuthScaffold({Key? key, required this.title, required this.subtitle, required this.child}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final horizontalPadding = 24.0;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight - 48),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 8),
                      // Logo + title
                      _buildHeader(context),
                      const SizedBox(height: 24),
                      Text(title, style: AppTextStyles.title),
                      const SizedBox(height: 8),
                      Text(subtitle, style: AppTextStyles.subtitle),
                      const SizedBox(height: 24),

                      // Form child
                      Expanded(child: child),

                      const SizedBox(height: 24),

                      // Footer
                      Column(
                        children: const [
                          Text('OSOM GLOBAL ENTERPRISE PLATFORM', style: TextStyle(letterSpacing: 1.5, color: AppColors.textSecondary)),
                          SizedBox(height: 6),
                          Text('© 2024 OSOM Solutions', style: TextStyle(color: AppColors.textSecondary)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    // Use SVG logo if available, otherwise draw the existing gradient circle as fallback
    return Row(
      children: [
        // Attempt to load logo.svg from assets/images/logo.svg
        SizedBox(
          width: 48,
          height: 48,
          child: Builder(builder: (ctx) {
            try {
              return Semantics(
                label: 'OSOM logo',
                child: SvgPicture.asset(
                  'assets/images/logo.svg',
                  width: 48,
                  height: 48,
                  fit: BoxFit.contain,
                ),
              );
            } catch (e) {
              // If svg package or asset isn't available for any reason, render the gradient circle fallback
              return Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: [AppColors.primary.withOpacity(0.9), AppColors.primary.withOpacity(0.6)]),
                ),
              );
            }
          }),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Text('OSOM', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            SvgPicture.asset(
              'assets/images/osom_watermark.svg',
              width: 20,
              height: 20,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 2),
            SizedBox(height: 2),
            Text('ENTERPRISE', style: TextStyle(fontSize: 12, color: AppColors.textSecondary, letterSpacing: 1.5)),
          ],
        )
      ],
    );
  }
}
