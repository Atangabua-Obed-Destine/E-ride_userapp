import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/util/app_constants.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens a gateway checkout for a Food & Shops order and pops with true when
/// the backend lands on its success page, false otherwise. Same end detection
/// as the ride and wallet payment screens: the first URL on our server that
/// contains success, fail or cancel.
class StorePaymentScreen extends StatefulWidget {
  final String url;
  const StorePaymentScreen({super.key, required this.url});

  @override
  State<StorePaymentScreen> createState() => _StorePaymentScreenState();
}

class _StorePaymentScreenState extends State<StorePaymentScreen> {
  late final _OrderPaymentBrowser _browser;

  @override
  void initState() {
    super.initState();
    _browser = _OrderPaymentBrowser(onDone: (paid) {
      if (mounted) Get.back(result: paid);
    });
    _browser.openUrlRequest(
      urlRequest: URLRequest(url: WebUri(widget.url)),
      settings: InAppBrowserClassSettings(
        browserSettings: InAppBrowserSettings(hideUrlBar: false),
        webViewSettings: InAppWebViewSettings(javaScriptEnabled: true, isInspectable: kDebugMode, useShouldOverrideUrlLoading: true),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('payment'.tr), backgroundColor: Theme.of(context).cardColor),
      body: Center(child: SpinKitCircle(color: Theme.of(context).primaryColor, size: 40)),
    );
  }
}

class _OrderPaymentBrowser extends InAppBrowser {
  final void Function(bool paid) onDone;
  _OrderPaymentBrowser({required this.onDone});

  bool _finished = false;

  void _check(String url) {
    if (_finished || !url.contains(AppConstants.baseUrl)) return;
    final success = url.contains('success');
    final failed = url.contains('fail') || url.contains('cancel');
    if (success || failed) {
      _finished = true;
      close();
      onDone(success);
    }
  }

  @override
  Future onLoadStart(url) async => _check(url.toString());

  @override
  Future onLoadStop(url) async => _check(url.toString());

  @override
  void onExit() {
    if (!_finished) {
      _finished = true;
      onDone(false);
    }
  }

  @override
  Future<NavigationActionPolicy> shouldOverrideUrlLoading(navigationAction) async {
    final uri = navigationAction.request.url!;
    // Mobile money apps and USSD/tel links open outside the browser.
    if (!['http', 'https', 'file', 'chrome', 'data', 'javascript', 'about'].contains(uri.scheme)) {
      launchUrl(uri, mode: LaunchMode.externalApplication);
      return NavigationActionPolicy.CANCEL;
    }
    return NavigationActionPolicy.ALLOW;
  }
}
