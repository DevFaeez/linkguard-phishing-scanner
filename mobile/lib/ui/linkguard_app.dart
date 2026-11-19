import 'dart:async';

import 'package:flutter/material.dart';

import 'app_copy.dart';

import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../application/linkguard_controller.dart';
import '../core/notification_policy.dart';
import '../core/scan_engine.dart';
import '../platform/device_bridge.dart';
import '../qr/qr_reader.dart';
import 'qr_camera_page.dart';
import 'design_system.dart';
import 'protection_page.dart';
import 'settings_page.dart';

class LinkGuardApp extends StatefulWidget {
  const LinkGuardApp({super.key, this.controller, this.qrReader});
  final LinkGuardController? controller;
  final QrGalleryReader? qrReader;
  @override
  State<LinkGuardApp> createState() => _LinkGuardAppState();
}

class _LinkGuardAppState extends State<LinkGuardApp> {
  late final LinkGuardController controller =
      widget.controller ?? LinkGuardController();
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) => MaterialApp(
      title: 'LinkGuard',
      debugShowCheckedModeBanner: false,
      theme: Lg.theme,
      locale: Locale(controller.language),
      supportedLocales: const [Locale('ms'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: Dashboard(controller: controller, qrReader: widget.qrReader),
    ),
  );
}

class Dashboard extends StatefulWidget {
  const Dashboard({super.key, this.controller, this.qrReader});
  final LinkGuardController? controller;
  final QrGalleryReader? qrReader;
  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  late final LinkGuardController c;
  final _inputFocus = FocusNode();
  final _resultKey = GlobalKey(), _inputKey = GlobalKey();
  ScanResult? _shownResult;
  int _page = 0;
  bool _pasting = false, _qrBusy = false, _recoveringQr = true;
  late final QrGalleryReader qrReader;

  @override
  void initState() {
    super.initState();
    c = (widget.controller ?? LinkGuardController())..addListener(_changed);
    DeviceBridge.channel.setMethodCallHandler((call) async {
      if (call.method == 'shareChanged') await _consumeShare();
    });
    qrReader = widget.qrReader ?? QrGalleryReader(device: c.device);
    unawaited(_recoverQr());
    unawaited(_consumeShare());
  }

  void _changed() {
    if (!mounted) return;
    final result = c.result;
    if (result != null && result != _shownResult && _page == 0) {
      _shownResult = result;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted ||
            c.result != result ||
            _resultKey.currentContext == null) {
          return;
        }
        Scrollable.ensureVisible(
          _resultKey.currentContext!,
          alignment: 0.12,
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 220),
        );
      });
    }
    if (result == null) _shownResult = null;
  }

  @override
  void dispose() {
    DeviceBridge.channel.setMethodCallHandler(null);
    c.removeListener(_changed);
    if (widget.controller == null) c.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  Future<void> _recoverQr() async {
    try {
      final values = await qrReader.recover();
      if (values == null || !mounted || _qrBusy) return;
      setState(() {
        _page = 0;
        _qrBusy = true;
      });
      c.clearResult();
      await _confirmQr(values);
    } on QrReadException catch (error) {
      if (mounted) c.setNotice(error.message);
    } catch (_) {
      // A cold start without a pending picker result needs no interruption.
    } finally {
      if (mounted) {
        setState(() {
          _qrBusy = false;
          _recoveringQr = false;
        });
      }
    }
  }

  Future<void> _readQr({required bool camera}) async {
    if (_qrBusy || _recoveringQr) return;
    FocusScope.of(context).unfocus();
    setState(() => _qrBusy = true);
    c.clearResult();
    try {
      await c.ready;
      if (!mounted) return;
      final values = camera
          ? await Navigator.of(context).push<List<String>>(
              MaterialPageRoute(builder: (_) => const QrCameraPage()),
            )
          : await qrReader.pick();
      if (values != null && mounted) await _confirmQr(values);
    } on QrReadException catch (error) {
      if (mounted) c.setNotice(error.message);
    } catch (_) {
      if (mounted) {
        c.setNotice(
          'QR tidak dapat dibaca. Cuba gambar lain atau scan semula.',
        );
      }
    } finally {
      if (mounted) setState(() => _qrBusy = false);
    }
  }

  Future<void> _confirmQr(List<String> values) async {
    if (values.isEmpty) {
      c.setNotice(
        'Tiada QR ditemui. Pilih gambar yang jelas dan tidak terpotong.',
      );
      return;
    }
    final links = qrWebLinks(values);
    if (links.isEmpty) {
      c.setNotice(
        'QR ini tidak mengandungi link HTTP/HTTPS yang sah. Wi-Fi, pembayaran dan teks biasa tidak diperiksa.',
      );
      return;
    }
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => SheetFrame(
        title: 'Semak link QR',
        children: [
          const AppText(
            'Link QR disemak pada telefon. Gambar tidak dihantar dan link tidak dibuka.',
          ),
          const SizedBox(height: 16),
          if (links.length == 1) ...[
            PaperPanel(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 160),
                child: SingleChildScrollView(
                  child: SelectableText(
                    links.single,
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            MainAction(
              'Semak link ini',
              key: const Key('confirm-qr'),
              onPressed: () => Navigator.pop(context, links.single),
            ),
          ] else ...[
            const AppText('Beberapa QR ditemui. Pilih link untuk disemak.'),
            for (final link in links)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  parseUrl(link).host,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text(
                  link,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: const Icon(Icons.arrow_forward_rounded),
                onTap: () => Navigator.pop(context, link),
              ),
          ],
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const AppText('Batal'),
          ),
        ],
      ),
    );
    if (selected == null || !mounted) return;
    c.useServer(
      false,
    ); // QR checks are always local, including after a server session.
    await c.scan(text: selected);
  }

  Future<void> _consumeShare() async {
    await c.ready;
    if (!mounted) return;
    try {
      final text = await c.device.consumeShare();
      if (text != null && mounted) {
        setState(() => _page = 0);
        final selected = await _chooseLink(text);
        if (selected != null && mounted) await c.scan(text: selected);
      }
    } catch (_) {
      if (mounted) {
        c.setNotice(
          'Link yang dikongsi tidak dapat dibaca. Cuba tampal semula.',
        );
      }
    }
  }

  Future<String?> _chooseLink(String text) async {
    final urls = extractUrls(text);
    if (urls.isEmpty && (text.length > 8192 || text.runes.length > 4096)) {
      c.setNotice(
        'Teks ini terlalu panjang. Tampal satu link sahaja untuk disemak.',
      );
      return null;
    }
    if (urls.length < 2) return urls.firstOrNull ?? text.trim();
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => SheetFrame(
        title: 'Link yang mana?',
        children: [
          const AppText(
            'Beberapa link ditemui. Pilih satu untuk disemak.',
            style: TextStyle(color: Lg.muted),
          ),
          const SizedBox(height: 16),
          ...urls.map(
            (url) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.link_rounded, color: Lg.orange),
              title: Text(
                url,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13),
              ),
              trailing: const Icon(Icons.arrow_forward_rounded, size: 18),
              onTap: () => Navigator.pop(context, url),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _paste({bool scan = false}) async {
    if (_pasting) return;
    setState(() => _pasting = true);
    try {
      final text = (await Clipboard.getData(Clipboard.kTextPlain))?.text;
      if (!mounted) return;
      if (text == null || text.trim().isEmpty) {
        c.setNotice(
          'Papan klip kosong. Salin link yang anda mahu semak dahulu.',
        );
        return;
      }
      setState(() => _pasting = false);
      final selected = await _chooseLink(text);
      if (!mounted || selected == null) return;
      if (scan) {
        FocusScope.of(context).unfocus();
        await c.scan(text: selected);
      } else {
        c.input.text = selected;
      }
    } catch (_) {
      if (mounted) {
        c.setNotice(
          'Link tidak dapat ditampal. Anda masih boleh menaipnya di sini.',
        );
      }
    } finally {
      if (mounted) setState(() => _pasting = false);
    }
  }

  Future<void> _scan() async {
    FocusScope.of(context).unfocus();
    if (c.input.text.trim().isEmpty) {
      await _paste(scan: true);
    } else {
      await c.scan();
    }
  }

  Future<void> _setup() async {
    if (!c.flag('consent')) {
      if (!await showNotificationConsent(context) || !mounted) return;
      await c.acceptConsent();
    }
    if (!mounted) return;
    if (!c.hasSelection) {
      await showAppSelection(context, c);
      return;
    }
    await c.advanceSetup(userInitiated: true);
  }

  void _openSettings() => Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => SettingsPage(controller: c)));
  void _scanAnother() {
    c.input.clear();
    _inputFocus.requestFocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_inputKey.currentContext != null) {
        Scrollable.ensureVisible(_inputKey.currentContext!, alignment: 0.2);
      }
    });
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: c,
    builder: (context, _) => AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Lg.paper,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 12, 14, 8),
                child: Row(
                  children: [
                    Semantics(
                      label: 'LinkGuard',
                      image: true,
                      child: const LinkMark(size: 38),
                    ),
                    const Spacer(),
                    IconButton(
                      key: const Key('open-settings'),
                      tooltip: tr(context, 'Tetapan'),
                      onPressed: _openSettings,
                      icon: const Icon(
                        Icons.tune_rounded,
                        size: 23,
                        color: Lg.ink,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  key: ValueKey(_page),
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
                  children: [
                    if (_page == 0)
                      ..._scanPage()
                    else
                      ProtectionPage(
                        controller: c,
                        onSetup: _setup,
                        onApps: () => showAppSelection(context, c),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: MediaQuery.viewInsetsOf(context).bottom > 0
            ? null
            : _BottomNav(
                page: _page,
                onChanged: (value) {
                  FocusScope.of(context).unfocus();
                  setState(() => _page = value);
                },
              ),
      ),
    ),
  );

  List<Widget> _scanPage() => [
    const Eyebrow('01 / SEMAKAN PAUTAN'),
    const SizedBox(height: 10),
    const AppText(
      'Semak pautan',
      style: TextStyle(
        fontFamily: Lg.serif,
        fontSize: 38,
        height: 1.08,
        color: Lg.ink,
      ),
    ),
    const SizedBox(height: 10),
    const AppText(
      'Kenali link sebelum anda membukanya.',
      style: TextStyle(fontSize: 14, color: Lg.muted),
    ),
    const SizedBox(height: 24),
    Container(
      key: _inputKey,
      decoration: BoxDecoration(
        color: Lg.white,
        border: Border.all(color: Lg.line),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Semantics(
        container: true,
        explicitChildNodes: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 7, 8, 0),
              child: Row(
                children: [
                  const Expanded(child: Eyebrow('LINK UNTUK DISEMAK')),
                  TextButton.icon(
                    key: const Key('paste-link'),
                    onPressed: _pasting ? null : () => _paste(),
                    icon: const Icon(Icons.content_paste_rounded, size: 14),
                    label: const AppText(
                      'Tampal',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 4, 18, 18),
              child: TextField(
                key: const Key('url-input'),
                controller: c.input,
                focusNode: _inputFocus,
                keyboardType: TextInputType.url,
                textInputAction: TextInputAction.go,
                autocorrect: false,
                enableSuggestions: false,
                minLines: 2,
                maxLines: 3,
                inputFormatters: [LengthLimitingTextInputFormatter(4096)],
                onSubmitted: (_) => _scan(),
                style: const TextStyle(
                  fontSize: 19,
                  height: 1.5,
                  color: Lg.ink,
                  fontWeight: FontWeight.w500,
                ),
                decoration: InputDecoration(
                  hintText: tr(context, 'https://contoh.com'),
                  semanticCounterText: '',
                  hintStyle: const TextStyle(
                    color: Color(0xff9B9E95),
                    fontSize: 19,
                  ),
                  filled: false,
                  contentPadding: EdgeInsets.zero,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
    if (c.inputNotice != null)
      Padding(
        padding: const EdgeInsets.only(top: 12),
        child: AppText(
          c.inputNotice!,
          style: const TextStyle(color: Lg.orange, fontSize: 12, height: 1.6),
        ),
      ),
    const SizedBox(height: 14),
    MainAction(
      c.loading && !c.online
          ? 'Menyiapkan semakan…'
          : c.scanning
          ? 'Sedang menyemak…'
          : c.input.text.trim().isEmpty
          ? 'Tampal & semak'
          : 'Semak link',
      key: const Key('scan-action'),
      onPressed: _qrBusy || (c.loading && !c.online) ? null : _scan,
      busy: c.scanning || _pasting,
      icon: c.input.text.trim().isEmpty
          ? Icons.content_paste_rounded
          : Icons.arrow_forward_rounded,
    ),
    const SizedBox(height: 12),
    Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            key: const Key('qr-camera'),
            onPressed: _qrBusy || _recoveringQr
                ? null
                : () => _readQr(camera: true),
            icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
            label: const AppText('Kamera QR', textAlign: TextAlign.center),
            style: OutlinedButton.styleFrom(
              foregroundColor: Lg.ink,
              minimumSize: const Size.fromHeight(48),
              side: const BorderSide(color: Lg.line),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            key: const Key('qr-gallery'),
            onPressed: _qrBusy || _recoveringQr
                ? null
                : () => _readQr(camera: false),
            icon: const Icon(Icons.photo_library_outlined, size: 18),
            label: const AppText('QR galeri', textAlign: TextAlign.center),
            style: OutlinedButton.styleFrom(
              foregroundColor: Lg.ink,
              minimumSize: const Size.fromHeight(48),
              side: const BorderSide(color: Lg.line),
            ),
          ),
        ),
      ],
    ),
    if (_qrBusy)
      const Padding(
        padding: EdgeInsets.only(top: 8),
        child: AppText(
          'Membaca QR…',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: Lg.muted),
        ),
      ),
    const SizedBox(height: 13),
    Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          c.online ? Icons.cloud_outlined : Icons.lock_outline_rounded,
          size: 14,
          color: Lg.muted,
        ),
        const SizedBox(width: 7),
        Flexible(
          child: AppText(
            c.online
                ? 'Melalui pelayan anda · boleh ditukar di Tetapan'
                : 'Disemak pada telefon. Link tidak dibuka.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11, color: Lg.muted, height: 1.5),
          ),
        ),
      ],
    ),
    if (!c.loading && c.engine == null && !c.online)
      Padding(
        padding: const EdgeInsets.only(top: 14),
        child: TextButton.icon(
          onPressed: c.loadModel,
          icon: const Icon(Icons.refresh_rounded),
          label: const AppText('Muatkan semula semakan'),
        ),
      ),
    if (c.result case final result?) ...[
      const SizedBox(height: 24),
      _resultPanel(result),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: _scanAnother,
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const AppText('Semak link lain'),
        ),
      ),
    ],
    const SizedBox(height: 28),
    _protectionTeaser(),
    const SizedBox(height: 24),
    Row(
      children: [
        Container(
          width: 5,
          height: 5,
          decoration: const BoxDecoration(
            color: Lg.orange,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        const Expanded(
          child: AppText(
            'Versi percubaan',
            style: TextStyle(fontSize: 11, color: Lg.muted),
          ),
        ),
        TextButton(
          onPressed: _openSettings,
          child: const AppText(
            'Tentang semakan',
            style: TextStyle(fontSize: 11),
          ),
        ),
      ],
    ),
  ];

  Widget _resultPanel(ScanResult result) {
    final suspicious = result.verdict == Verdict.suspicious;
    final unknown = result.verdict == Verdict.unableToScan;
    final tone = suspicious || unknown ? Lg.orange : Lg.green;
    return PaperPanel(
      key: _resultKey,
      color: suspicious
          ? Lg.blush
          : unknown
          ? Lg.white
          : Lg.sage,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                suspicious
                    ? Icons.priority_high_rounded
                    : unknown
                    ? Icons.help_outline_rounded
                    : Icons.check_rounded,
                size: 20,
                color: tone,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Eyebrow(
                  suspicious
                      ? 'LINK MENCURIGAKAN'
                      : unknown
                      ? 'BELUM DAPAT DIPERIKSA'
                      : 'SEMAKAN SELESAI',
                  color: tone,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          AppText(
            suspicious
                ? 'Jangan buka dahulu.'
                : unknown
                ? 'Cuba semak semula.'
                : 'Tiada tanda bahaya\ndikesan.',
            key: const Key('scan-verdict'),
            style: TextStyle(
              fontFamily: Lg.serif,
              fontSize: 29,
              height: 1.15,
              color: tone,
            ),
          ),
          if (result.domain.isNotEmpty) ...[
            const SizedBox(height: 13),
            SelectableText(
              result.domain,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
          ],
          const SizedBox(height: 12),
          AppText(
            unknown
                ? (c.online
                      ? 'Sambungan ke pelayan tidak berjaya atau link tidak sah. Tiada keputusan keselamatan diberikan.'
                      : 'Pastikan anda memasukkan satu link yang lengkap. Jika semakan belum tersedia, cuba muatkan semula.')
                : suspicious
                ? 'Ada corak yang mencurigakan. Semak pengirim dan ejaan domain sebelum meneruskan.'
                : 'Tiada corak mencurigakan ditemui pada bentuk link ini. Ini bukan jaminan bahawa laman tersebut selamat.',
            style: const TextStyle(fontSize: 13, height: 1.65),
          ),
          if (!unknown) ...[
            const SizedBox(height: 10),
            Theme(
              data: Theme.of(context)
                  .copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: EdgeInsets.zero,
                title: const AppText(
                  'Kenapa keputusan ini?',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                ),
                children: result.reasons
                    .map(
                      (reason) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const AppText(
                              '—  ',
                              style: TextStyle(color: Lg.muted),
                            ),
                            Expanded(
                              child: AppText(
                                _friendlyReason(reason),
                                style: const TextStyle(
                                  fontSize: 12,
                                  height: 1.6,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 12),
          const AppText(
            'Semakan awal sahaja. Kandungan laman dan destinasi link pendek belum diperiksa.',
            style: TextStyle(fontSize: 11, color: Lg.muted, height: 1.6),
          ),
        ],
      ),
    );
  }

  String _friendlyReason(String reason) {
    if (reason.startsWith('Gabungan ciri')) {
      return 'Bentuk link ini menyerupai corak yang digunakan dalam phishing.';
    }
    if (reason.contains('punycode')) {
      return 'Alamat ini menggunakan aksara khas. Semak sama ada ejaannya menyerupai domain lain.';
    }
    if (reason.startsWith('Tiada petunjuk')) {
      return 'Tiada tanda mencurigakan ditemui dalam struktur link.';
    }
    return reason;
  }

  Widget _protectionTeaser() => InkWell(
    key: const Key('protection-teaser'),
    onTap: () => setState(() => _page = 1),
    borderRadius: BorderRadius.circular(12),
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: Lg.line),
          bottom: BorderSide(color: Lg.line),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 42,
            decoration: BoxDecoration(
              color: c.protected ? Lg.sage : Lg.blush,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(
              c.protected
                  ? Icons.notifications_active_outlined
                  : Icons.notifications_none_rounded,
              color: c.protected ? Lg.green : Lg.orange,
              size: 21,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText(
                  c.protected
                      ? 'Semakan automatik aktif'
                      : c.flag('setupPending')
                      ? 'Sambung persediaan anda'
                      : 'Link dalam mesej?',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 5),
                AppText(
                  c.protected
                      ? 'Link dalam notifikasi diperiksa pada telefon.'
                      : 'Sediakan semakan automatik untuk notifikasi baharu.',
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.6,
                    color: Lg.muted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.arrow_forward_rounded, size: 18, color: Lg.orange),
        ],
      ),
    ),
  );
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.page, required this.onChanged});
  final int page;
  final ValueChanged<int> onChanged;
  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      color: Lg.white,
      border: Border(top: BorderSide(color: Lg.line)),
    ),
    child: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Row(
          children: [
            _item(context, 0, 'Semak link', Icons.link_rounded),
            const SizedBox(width: 12),
            _item(context, 1, 'Perlindungan', Icons.notifications_none_rounded),
          ],
        ),
      ),
    ),
  );
  Widget _item(BuildContext context, int index, String text, IconData icon) =>
      Expanded(
        child: Semantics(
          key: Key(index == 0 ? 'nav-scan' : 'nav-protection'),
          label: tr(context, 'Tab $text'),
          button: true,
          selected: page == index,
          onTap: () => onChanged(index),
          child: ExcludeSemantics(
            child: InkWell(
              onTap: () => onChanged(index),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                constraints: const BoxConstraints(minHeight: 52),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                decoration: BoxDecoration(
                  color: page == index ? Lg.paper : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      icon,
                      size: 21,
                      color: page == index ? Lg.orange : Lg.muted,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: AppText(
                        text,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: page == index
                              ? FontWeight.w800
                              : FontWeight.w500,
                          color: page == index ? Lg.ink : Lg.muted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}
