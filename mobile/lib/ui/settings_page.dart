import 'package:flutter/material.dart';

import 'app_copy.dart';

import '../application/linkguard_controller.dart';
import 'design_system.dart';

const commonApps = {
  'WhatsApp': 'com.whatsapp',
  'WhatsApp Business': 'com.whatsapp.w4b',
  'Telegram': 'org.telegram.messenger',
  'Google Messages': 'com.google.android.apps.messaging',
  'Samsung Messages': 'com.samsung.android.messaging',
  'Gmail': 'com.google.android.gm',
  'Outlook': 'com.microsoft.office.outlook',
};

Future<void> showAppSelection(
  BuildContext context,
  LinkGuardController controller,
) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) => SheetFrame(
      title: 'App pilihan anda',
      children: [
        const AppText(
          'Periksa semua app atau pilih yang anda gunakan. Link hanya diperiksa apabila notifikasi boleh dibaca.',
          style: TextStyle(color: Lg.muted),
        ),
        const SizedBox(height: 16),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: const AppText(
            'Semua app',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          value: controller.flag('allApps'),
          onChanged: (value) => controller.configureApps(
            allApps: value,
            selected: controller.selected,
          ),
        ),
        if (!controller.flag('allApps'))
          ...commonApps.entries.map(
            (app) => CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: AppText(app.key, style: const TextStyle(fontSize: 14)),
              value: controller.selected.contains(app.value),
              onChanged: (checked) => controller.configureApps(
                allApps: false,
                selected: {
                  ...controller.selected.where((value) => value != app.value),
                  if (checked == true) app.value,
                },
              ),
            ),
          ),
        if (!controller.hasSelection)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: AppText(
              'Tiada app dipilih. Perlindungan automatik dijeda.',
              style: TextStyle(color: Lg.orange, fontSize: 12),
            ),
          ),
        const SizedBox(height: 16),
        MainAction(
          'Selesai',
          onPressed: () => Navigator.pop(context),
          icon: Icons.check_rounded,
        ),
      ],
    ),
  ),
);

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, required this.controller});
  final LinkGuardController controller;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) => Scaffold(
      appBar: AppBar(
        title: const AppText(
          'Tetapan',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        children: [
          const Eyebrow('Bahasa'),
          const SizedBox(height: 12),
          SegmentedButton<String>(
            key: const Key('language-picker'),
            segments: const [
              ButtonSegment(value: 'ms', label: Text('Bahasa Melayu')),
              ButtonSegment(value: 'en', label: Text('English')),
            ],
            selected: {controller.language},
            onSelectionChanged: (values) =>
                controller.setLanguage(values.single),
          ),
          const SizedBox(height: 8),
          const AppText(
            'Pilihan bahasa disimpan pada telefon ini.',
            style: TextStyle(color: Lg.muted, fontSize: 12),
          ),
          const SizedBox(height: 24),
          const Eyebrow('DATA & PILIHAN ANDA'),
          const SizedBox(height: 12),
          const AppText(
            'Ringkas.\nDalam kawalan anda.',
            style: TextStyle(fontFamily: Lg.serif, fontSize: 33, height: 1.12),
          ),
          const SizedBox(height: 24),
          PaperPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const AppText(
                  'Semakan harian',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                ),
                const SizedBox(height: 10),
                const AppText(
                  'Link diperiksa pada telefon secara lalai. Tiada akaun diperlukan dan tiada sejarah mesej atau link disimpan.',
                  style: TextStyle(color: Lg.muted, fontSize: 13),
                ),
                const SizedBox(height: 12),
                _SettingsRow(
                  Icons.apps_rounded,
                  'App yang diperiksa',
                  onTap: () => showAppSelection(context, controller),
                ),
                _SettingsRow(
                  Icons.notifications_none_rounded,
                  'Urus akses di Android',
                  onTap: controller.device.openAccess,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Eyebrow('TENTANG KEPUTUSAN'),
          const SizedBox(height: 12),
          const AppText(
            'Ini semakan awal, bukan jaminan keselamatan.',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
          ),
          const SizedBox(height: 8),
          const AppText(
            'Versi ini menilai bentuk link sahaja. Kandungan laman, destinasi link pendek, teks dalam gambar dan mesej tanpa link belum diperiksa. Android juga boleh menyembunyikan sebahagian notifikasi.',
            style: TextStyle(color: Lg.muted, fontSize: 13),
          ),
          const SizedBox(height: 22),
          const Divider(),
          ExpansionTile(
            key: const Key('advanced-settings'),
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(bottom: 20),
            title: const AppText(
              'Pilihan lanjutan',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
            ),
            subtitle: const AppText(
              'Tidak diperlukan untuk kegunaan biasa',
              style: TextStyle(fontSize: 12, color: Lg.muted),
            ),
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const AppText(
                  'Semakan melalui pelayan',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
                subtitle: const AppText(
                  'Untuk semakan manual sahaja',
                  style: TextStyle(fontSize: 12),
                ),
                value: controller.online,
                onChanged: (value) async {
                  if (!value) {
                    controller.useServer(false);
                    return;
                  }
                  final allowed = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const AppText('Hantar link ke pelayan anda?'),
                      content: const AppText(
                        'Link penuh, termasuk sebarang token atau maklumat peribadi dalamnya, akan dihantar ke alamat pelayan yang anda tetapkan. Gunakan hanya pelayan yang anda percayai. Notifikasi kekal diperiksa pada telefon.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const AppText('Batal'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const AppText('Benarkan untuk sesi ini'),
                        ),
                      ],
                    ),
                  );
                  if (allowed == true) controller.useServer(true);
                },
              ),
              if (controller.online)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: TextField(
                    key: const Key('backend-endpoint'),
                    controller: controller.endpoint,
                    keyboardType: TextInputType.url,
                    autocorrect: false,
                    decoration: InputDecoration(
                      labelText: tr(context, 'Alamat pelayan anda'),
                      helperText: tr(context, 'HTTPS untuk sambungan luar.'),
                    ),
                  ),
                ),
            ],
          ),
          const Divider(),
          const SizedBox(height: 18),
          TextButton.icon(
            style: TextButton.styleFrom(
              alignment: Alignment.centerLeft,
              padding: EdgeInsets.zero,
            ),
            onPressed: () => showLicensePage(
              context: context,
              applicationName: 'LinkGuard',
              applicationVersion: tr(context, '0.5.0 · Versi percubaan'),
            ),
            icon: const Icon(Icons.info_outline_rounded, size: 18),
            label: const AppText('Tentang & lesen'),
          ),
          const AppText(
            'Sumber latihan: PhiUSIIL, Prasad & Chandra (2024), UCI #967. CC BY 4.0. doi.org/10.1016/j.cose.2023.103545',
            style: TextStyle(color: Lg.muted, fontSize: 11, height: 1.7),
          ),
          const SizedBox(height: 22),
          TextButton.icon(
            style: TextButton.styleFrom(
              alignment: Alignment.centerLeft,
              padding: EdgeInsets.zero,
            ),
            icon: const Icon(Icons.restart_alt_rounded, size: 18),
            label: const AppText('Jeda & set semula tetapan'),
            onPressed: () async {
              final reset = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const AppText('Set semula tetapan?'),
                  content: const AppText(
                    'Perlindungan akan dijeda dan pilihan app dipadam. Akses Android masih boleh ditarik balik melalui tetapan telefon.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const AppText('Batal'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const AppText('Set semula'),
                    ),
                  ],
                ),
              );
              if (reset == true) await controller.reset();
            },
          ),
        ],
      ),
    ),
  );
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow(this.icon, this.text, {required this.onTap});
  final IconData icon;
  final String text;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          Icon(icon, size: 19, color: Lg.muted),
          const SizedBox(width: 12),
          Expanded(
            child: AppText(
              text,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: Lg.muted, size: 20),
        ],
      ),
    ),
  );
}
