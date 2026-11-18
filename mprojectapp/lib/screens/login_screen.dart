import 'package:flutter/material.dart';
import '../models/session.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/fcm_service.dart';
import 'admin_home_screen.dart';
import 'dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  final AuthService authService;
  final FcmService fcmService;
  final String? notice;

  const LoginScreen({
    super.key,
    required this.authService,
    required this.fcmService,
    this.notice,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _loading = false;
  String? _error;

  Future<void> _submit() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    if (username.isEmpty || password.isEmpty) {
      setState(() => _error = 'Username dan password wajib diisi');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final session = await widget.authService.login(username, password);

      // Push notification cuma relevan buat role petugas (yang turun ke
      // lapangan) -- admin tidak perlu didaftarkan sebagai penerima FCM.
      if (session.role == UserRole.petugas) {
        await widget.fcmService.initAndRegister(session.nama);
      }

      if (!mounted) return;
      _navigateByRole(session);
    } catch (e) {
      setState(() => _error = 'Gagal login: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _navigateByRole(AuthSession session) {
    final target = session.role == UserRole.admin
        ? AdminHomeScreen(session: session)
        : DashboardScreen(fcmService: widget.fcmService, session: session);

    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => target));
  }

  Widget _buildBranding() {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.lock_outline, size: 48),
        SizedBox(height: 8),
        Text(
          'Masuk sebagai Admin atau Petugas',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildLoginFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.notice != null)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(widget.notice!),
          ),
        TextField(
          controller: _usernameController,
          decoration: const InputDecoration(
            labelText: 'Username',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.person_outline),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          decoration: InputDecoration(
            labelText: 'Password',
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
              ),
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
            ),
            errorText: _error,
          ),
          onSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: _loading ? null : _submit,
          child: _loading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Login'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Smart Locker - Login')),
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= 600) {
            return Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 900),
                  child: Row(
                    children: [
                      Expanded(child: _buildBranding()),
                      const SizedBox(width: 32),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              'Login',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            _buildLoginFields(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          return Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildBranding(),
                    const SizedBox(height: 24),
                    _buildLoginFields(),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
