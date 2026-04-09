import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_metadata.dart';
import '../../../core/constants.dart';
import '../../../core/supabase_client.dart';

/// Entry route: resolves session + role and navigates (see [appRouter] redirect for guards).
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _routeFromSession());
  }

  Future<void> _routeFromSession() async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;

    final user = supabaseClient.auth.currentSession?.user;
    final role = roleFromSupabaseMetadata(user);

    if (role == kRoleAdmin) {
      context.go('/admin');
    } else if (role == kRoleStudent) {
      context.go('/student');
    } else {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
