import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class PaymentWebViewPage extends StatefulWidget {
  final String paymentUrl;
  final VoidCallback? onPaymentComplete;

  const PaymentWebViewPage({
    Key? key,
    required this.paymentUrl,
    this.onPaymentComplete,
  }) : super(key: key);

  @override
  State<PaymentWebViewPage> createState() => _PaymentWebViewPageState();
}

class _PaymentWebViewPageState extends State<PaymentWebViewPage> {
  bool _isLoading = true;
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            setState(() => _isLoading = true);
          },
          onPageFinished: (_) {
            setState(() => _isLoading = false);
          },
          onNavigationRequest: (NavigationRequest request) {
            // Detect payment completion by URL patterns
            if (request.url.contains('success') ||
                request.url.contains('paid') ||
                request.url.contains('completed') ||
                request.url.contains('successful')) {
              widget.onPaymentComplete?.call();
              // Show success message and navigate back to dashboard
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Payment completed successfully!'),
                  backgroundColor: Colors.green,
                  duration: Duration(seconds: 2),
                ),
              );
              // Navigate back to dashboard after a short delay
              Future.delayed(const Duration(seconds: 1), () {
                if (mounted) {
                  Navigator.popUntil(context, (route) => route.isFirst);
                }
              });
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.paymentUrl));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('GCash Payment'),
        backgroundColor: const Color(0xFF5D8AA8),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            // Navigate back to dashboard
            Navigator.popUntil(context, (route) => route.isFirst);
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.home),
            onPressed: () {
              // Navigate back to dashboard
              Navigator.popUntil(context, (route) => route.isFirst);
            },
            tooltip: 'Back to Dashboard',
          ),
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading) const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}
