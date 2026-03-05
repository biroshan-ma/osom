import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Short delay to show splash; routing handled by parent (AuthBloc / AuthGate)
    Future.delayed(const Duration(milliseconds: 3000), () {
      if (!mounted) return;
      // Do nothing here; AppEntry/AuthGate will show the appropriate next screen
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: SvgPicture.asset(
          'assets/images/logo.svg',
          width: 160,
          height: 160,
          semanticsLabel: 'OSOM Logo',
        ),
      ),
    );
  }
}

