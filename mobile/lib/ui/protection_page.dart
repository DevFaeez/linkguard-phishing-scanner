import 'package:flutter/material.dart';

import 'app_copy.dart';

import '../application/linkguard_controller.dart';
import 'design_system.dart';

class ProtectionPage extends StatelessWidget {
  const ProtectionPage({
    super.key,
    required this.controller,
    required this.onSetup,
    required this.onApps,
  });
  final LinkGuardController controller;
  final VoidCallback onSetup, onApps;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final active = c.protected;
    final ready = !c.needsSetup;
    final interrupted = c.flag('enabled') && !active && !c.connecting;
    final heading = active
        ? 'Link masuk.\nAnda lebih bersedia.'
        : ready && !c.flag('enabled')
        ? 'Berehat seketika.'
        : 'Jaga link\nyang masuk.';
    final next = !c.flag('access')
        ? 1
        : !c.flag('warnings')
        ? 2
        : 3;
    final button = c.statusNotice != null && c.flag('enabled')
        ? 'Semak semula'
        : c.connecting
        ? ((c.status['failures'] as num? ?? 0) > 0
              ? 'Sambung semula'
              : 'Sedang menyambung…')
        : active
        ? 'Jeda perlindungan'
        : ready
        ? 'Sambung perlindungan'
        : !c.flag('consent')
        ? 'Sediakan perlindungan'
        : !c.hasSelection
        ? 'Pilih app untuk diperiksa'
        : next == 1
        ? 'Benarkan akses notifikasi'
        : 'Benarkan amaran';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Eyebrow('02 / PERLINDUNGAN'),
        const SizedBox(height: 10),
        AppText(
          heading,
          style: const TextStyle(
            fontFamily: Lg.serif,
            fontSize: 32,
            height: 1.08,
            color: Lg.ink,
          ),
        ),
        const SizedBox(height: 14),
        AppText(
          active
              ? 'Link dalam notifikasi diperiksa pada telefon. Kami beri amaran apabila ada tanda mencurigakan.'
              : ready && !c.flag('enabled')
              ? 'Semakan automatik sedang dijeda. Anda masih boleh menyemak link sendiri.'
              : 'Semak link dalam notifikasi secara automatik. Terima amaran jika mencurigakan.',
          style: const TextStyle(color: Lg.muted, fontSize: 13, height: 1.5),
        ),
        const SizedBox(height: 16),
        PaperPanel(
          color: active ? Lg.sage : Lg.white,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  LinkMark(size: 46, color: active ? Lg.green : Lg.orange),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Eyebrow(
                          active
                              ? 'SEDANG MEMERIKSA'
                              : c.connecting
                              ? 'MENYAMBUNG'
                              : interrupted
                              ? 'PERLU PERHATIAN'
                              : ready
                              ? 'SEDANG DIJEDA'
                              : 'BELUM DISEDIAKAN',
                          color: active ? Lg.green : Lg.orange,
                        ),
                        const SizedBox(height: 5),
                        AppText(
                          active
                              ? 'Perlindungan aktif'
                              : c.connecting
                              ? 'Menunggu sambungan'
                              : ready
                              ? 'Perlindungan dijeda'
                              : 'Dua kebenaran diperlukan',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (c.statusNotice != null) ...[
                const SizedBox(height: 16),
                AppText(
                  c.statusNotice!,
                  style: const TextStyle(color: Lg.orange),
                ),
              ],
              if (!ready) ...[
                const SizedBox(height: 16),
                const Divider(),
                _Step(
                  number: '01',
                  title: 'Akses notifikasi',
                  detail: 'Supaya link yang masuk boleh diperiksa.',
                  complete: c.flag('access'),
                  current: next == 1,
                ),
                const Divider(),
                _Step(
                  number: '02',
                  title: 'Amaran daripada LinkGuard',
                  detail: 'Supaya anda tahu apabila link mencurigakan ditemui.',
                  complete: c.flag('warnings'),
                  current: next == 2,
                ),
              ],
              const SizedBox(height: 20),
              if (active)
                OutlinedButton.icon(
                  key: const Key('pause-protection'),
                  onPressed: c.pause,
                  icon: const Icon(Icons.pause_rounded, size: 19),
                  label: const AppText('Jeda perlindungan'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                    foregroundColor: Lg.ink,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    side: const BorderSide(color: Lg.green),
                  ),
                )
              else
                MainAction(
                  button,
                  key: const Key('setup-action'),
                  busy: c.setupBusy,
                  icon: c.connecting
                      ? Icons.sync_rounded
                      : Icons.arrow_forward_rounded,
                  onPressed:
                      c.connecting && (c.status['failures'] as num? ?? 0) == 0
                      ? null
                      : onSetup,
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        InkWell(
          key: const Key('choose-apps'),
          onTap: onApps,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
            child: Row(
              children: [
                const Icon(Icons.apps_rounded, size: 21, color: Lg.muted),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const AppText(
                        'App yang diperiksa',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      AppText(
                        c.flag('allApps')
                            ? 'Semua app · boleh ditukar'
                            : c.selected.isEmpty
                            ? 'Belum dipilih'
                            : '${c.selected.length} app dipilih',
                        style: const TextStyle(fontSize: 12, color: Lg.muted),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: Lg.muted),
              ],
            ),
          ),
        ),
        const Divider(),
        const SizedBox(height: 22),
        const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.lock_outline_rounded, size: 17, color: Lg.muted),
            SizedBox(width: 10),
            Expanded(
              child: AppText(
                'Mesej tidak disimpan atau dihantar ke pelayan. Semakan bergantung pada kandungan yang Android benarkan untuk dibaca.',
                style: TextStyle(color: Lg.muted, fontSize: 12, height: 1.65),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({
    required this.number,
    required this.title,
    required this.detail,
    required this.complete,
    required this.current,
  });
  final String number, title, detail;
  final bool complete, current;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: complete
                ? Lg.green
                : current
                ? Lg.blush
                : Lg.paper,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: complete
                ? const Icon(Icons.check_rounded, color: Colors.white, size: 18)
                : AppText(
                    number,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: current ? Lg.orange : Lg.muted,
                    ),
                  ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppText(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              AppText(
                complete ? 'Sudah dibenarkan' : detail,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.55,
                  color: complete ? Lg.green : Lg.muted,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

Future<bool> showNotificationConsent(BuildContext context) async =>
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => SheetFrame(
        title: 'Anda tentukan\napa yang dibaca.',
        children: [
          const AppText(
            'Untuk mencari link, LinkGuard perlu membaca teks notifikasi semua app. Anda boleh memilih app tertentu kemudian.',
            style: TextStyle(fontSize: 15, height: 1.65),
          ),
          const SizedBox(height: 20),
          const _ConsentLine(
            Icons.phone_android_rounded,
            'Disemak pada telefon',
            'Teks notifikasi tidak dihantar ke pelayan.',
          ),
          const _ConsentLine(
            Icons.visibility_off_outlined,
            'Tiada sejarah mesej',
            'Mesej, link dan pengirim tidak disimpan.',
          ),
          const _ConsentLine(
            Icons.pause_circle_outline_rounded,
            'Boleh dijeda bila-bila masa',
            'Akses juga boleh ditarik balik dalam tetapan Android.',
          ),
          const SizedBox(height: 8),
          const AppText(
            'Versi percubaan: semakan mungkin tersilap atau terlepas link berbahaya.',
            style: TextStyle(fontSize: 12, color: Lg.muted, height: 1.6),
          ),
          const SizedBox(height: 20),
          MainAction(
            'Setuju & teruskan',
            onPressed: () => Navigator.pop(context, true),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const AppText('Bukan sekarang'),
          ),
        ],
      ),
    ) ??
    false;

class _ConsentLine extends StatelessWidget {
  const _ConsentLine(this.icon, this.title, this.detail);
  final IconData icon;
  final String title, detail;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Lg.orange, size: 21),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppText(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 3),
              AppText(
                detail,
                style: const TextStyle(
                  fontSize: 12,
                  color: Lg.muted,
                  height: 1.6,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
