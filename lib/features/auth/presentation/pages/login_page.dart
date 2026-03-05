import 'package:flutter/material.dart';

import '../../../../core/ui/widgets/auth_scaffold.dart';
import '../widgets/login_form.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Welcome',
      subtitle: 'Please sign in to your corporate account.',
      child: Builder(
        builder: (context) => const LoginForm(),
      ),
    );
  }
}
