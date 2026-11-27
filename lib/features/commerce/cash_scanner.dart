import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Opens the camera and returns what the collector scanned: the QR code that
/// the payer shows (null when the person backs out).
Future<String?> scanCashQr(BuildContext context) => Navigator.of(context)
    .push<String>(MaterialPageRoute(builder: (context) => const _ScanScreen()));

class _ScanScreen extends StatefulWidget {
  const _ScanScreen();

  @override
  State<_ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<_ScanScreen> {
  final _controller = MobileScannerController(formats: [BarcodeFormat.qrCode]);
  bool _done = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_done) {
      return;
    }
    final value = capture.barcodes.firstOrNull?.rawValue;
    if (value == null || value.isEmpty) {
      return;
    }
    _done = true;
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Scanner le code du client')),
    body: Stack(
      children: [
        MobileScanner(
          controller: _controller,
          onDetect: _onDetect,
          errorBuilder: (context, error) => const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'La caméra n’est pas disponible. Autorisez l’accès à la '
                'caméra dans les réglages, ou confirmez la réception avec '
                'le bouton.',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
        const Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Cadrez le code QR affiché sur le téléphone du client.',
              style: TextStyle(color: Colors.white),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ],
    ),
  );
}
