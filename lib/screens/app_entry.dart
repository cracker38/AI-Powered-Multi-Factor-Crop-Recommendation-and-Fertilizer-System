import 'package:flutter/material.dart';

import '../models/user_profile.dart';
import '../widgets/shared/app_loading_screen.dart';
import 'admin/admin_shell.dart';
import 'auth/login_screen.dart';
import 'farmer/farmer_shell.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import 'splash/splash_flow.dart';

/// Splash → auth gate → farmer or admin home.
class AppEntry extends StatefulWidget {
  const AppEntry({super.key});

  @override
  State<AppEntry> createState() => _AppEntryState();
}

class _AppEntryState extends State<AppEntry> {
  final _auth = AuthService();
  bool _showSplash = true;
  bool _loading = true;
  String? _bootstrapError;
  UserProfile? _profile;
  ApiService? _api;

  @override
  void initState() {
    super.initState();
    _auth.authStateChanges().listen((user) {
      if (user == null && mounted) {
        setState(() {
          _profile = null;
          _api = null;
          _bootstrapError = null;
        });
      }
    });
  }

  void _onSplashDone() {
    setState(() => _showSplash = false);
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    setState(() {
      _loading = true;
      _bootstrapError = null;
    });
    final user = _auth.currentUser;
    if (user == null) {
      setState(() => _loading = false);
      return;
    }
    await _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _loading = true;
      _bootstrapError = null;
    });
    try {
      final base = await _auth.readApiBase();
      final api = ApiService(baseUrl: base, getToken: _auth.getIdToken);
      final profile = await api.syncProfile();
      await FirestoreService().syncCurrentAuthUser(profile);
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _api = api;
        _loading = false;
      });
    } on ApiException catch (e) {
      await _auth.signOut();
      if (!mounted) return;
      setState(() {
        _profile = null;
        _api = null;
        _loading = false;
        _bootstrapError = e.message;
      });
    } catch (e) {
      await _auth.signOut();
      if (!mounted) return;
      setState(() {
        _profile = null;
        _api = null;
        _loading = false;
        _bootstrapError = 'Could not connect to the server. Ensure the API is running.';
      });
    }
  }

  Future<void> _logout() async {
    await _auth.signOut();
    setState(() {
      _profile = null;
      _api = null;
      _bootstrapError = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_showSplash) {
      return SplashFlow(onFinished: _onSplashDone);
    }

    if (_loading) {
      return const AppLoadingScreen(message: 'Securing your session…');
    }

    if (_profile == null || _api == null) {
      return LoginScreen(
        onAuthenticated: _loadProfile,
        initialError: _bootstrapError,
      );
    }

    if (_profile!.isAdmin) {
      return AdminShell(profile: _profile!, api: _api!, onLogout: _logout);
    }

    return FarmerShell(profile: _profile!, api: _api!, onLogout: _logout);
  }
}
