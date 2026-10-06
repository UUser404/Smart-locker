import 'package:flutter/material.dart';
import '../services/fcm_service.dart';
import 'dashboard_screen.dart';

/// Prototipe belum pakai login/PIN staf penuh — cukup catat nama/NIP
/// sekali di awal supaya push notification bisa ditandai per petugas.
class PetugasIdScreen extends StatefulWidget {
  final FcmService fcmService;

  const PetugasIdScreen({super.key, required this.fcmService});

  @override
  State<PetugasIdScreen> createState() => _PetugasIdScreenState();
}

class _PetugasIdScreenState extends State<PetugasIdScreen> {
  final _controller = TextEditingController();
  bool _loading = false;
  String? _error;

  Future<void> _submit() async {
    final value = _controller.text.trim();
    if (value.isEmpty) {
      setState(() => _error = 'Nama/NIP tidak boleh kosong');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await widget.fcmService.initAndRegister(value);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => DashboardScreen(fcmService: widget.fcmService),
        ),
      );
    } catch (e) {
      setState(() => _error = 'Gagal mendaftarkan device: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Identitas Petugas')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Masukkan nama atau NIP kamu untuk menerima notifikasi '
              'locker yang perlu perhatian.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              decoration: InputDecoration(
                labelText: 'Nama / NIP Petugas',
                border: const OutlineInputBorder(),
                errorText: _error,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Lanjut'),
            ),
          ],
        ),
      ),
    );
  }
}
