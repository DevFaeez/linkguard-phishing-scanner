import 'package:flutter/material.dart';

/// One catalog for all app-owned UI copy; Malay is the source language.
/// URLs, application names and user input pass through unchanged.
String translate(String text, String language) {
  if (language != 'en') return text;
  final count = RegExp(r'^(\d+) app dipilih$').firstMatch(text);
  if (count != null) {
    return '${count[1]} ${count[1] == '1' ? 'app' : 'apps'} selected';
  }
  if (text.startsWith('Tab ')) {
    return '${translate(text.substring(4), language)} tab';
  }
  if (text == '0.5.0 · Versi percubaan') return '0.5.0 · Research preview';
  return englishCopy[text] ?? text;
}

String tr(BuildContext context, String text) =>
    translate(text, Localizations.localeOf(context).languageCode);

/// Translates at build time, including constant widgets and already-open sheets.
class AppText extends StatelessWidget {
  const AppText(
    this.data, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
  });
  final String data;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;
  @override
  Widget build(BuildContext context) => Text(
    tr(context, data),
    style: style,
    textAlign: textAlign,
    maxLines: maxLines,
    overflow: overflow,
  );
}

const englishCopy = <String, String>{
  "Kamera QR": "QR camera",
  "QR galeri": "QR gallery",
  "Membaca QR…": "Reading QR…",
  "Scan QR kamera": "Scan QR with camera",
  "Lampu suluh": "Flashlight",
  "Kebenaran kamera diperlukan": "Camera permission needed",
  "Kamera belum tersedia": "Camera is not available",
  "Benarkan kamera dalam tetapan telefon, atau kembali dan pilih QR dari galeri.": "Allow camera access in your phone settings, or go back and choose a QR image from your gallery.",
  "Buka tetapan": "Open settings",
  "Cuba lagi": "Try again",
  "QR belum dapat dibaca. Cuba dekatkan kamera.":
      "Could not read the QR code yet. Try moving the camera closer.",
  "Halakan kamera pada QR. Link tidak akan dibuka secara automatik.":
      "Point the camera at a QR code. Links will not open automatically.",
  "Kamera berhenti selepas QR ditemui. Tiada gambar disimpan.":
      "The camera stops after a QR code is found. No photo is saved.",
  "Gambar tidak dapat dibaca. Pilih gambar lain.":
      "Could not read the image. Choose another image.",
  "Gambar terlalu besar. Pilih gambar yang lebih kecil.":
      "The image is too large. Choose a smaller image.",
  "QR tidak dapat dibaca. Cuba gambar lain atau scan semula.":
      "Could not read the QR code. Try another image or scan again.",
  "Tiada QR ditemui. Pilih gambar yang jelas dan tidak terpotong.":
      "No QR code found. Choose a clear image with the whole code visible.",
  "QR ini tidak mengandungi link HTTP/HTTPS yang sah. Wi-Fi, pembayaran dan teks biasa tidak diperiksa.": "This QR code has no valid HTTP/HTTPS link. Wi-Fi, payment commands and plain text are not checked.",
  "Semak link QR": "Check QR link",
  "Link QR disemak pada telefon. Gambar tidak dihantar dan link tidak dibuka.": "QR links are checked on your phone. Images are not sent and links are not opened.",
  "Semak link ini": "Check this link",
  "Beberapa QR ditemui. Pilih link untuk disemak.":
      "Several QR codes found. Choose a link to check.",

  "Tetapan": "Settings",
  "Bahasa": "Language",
  "Pilihan bahasa disimpan pada telefon ini.":
      "Your language choice is saved on this phone.",
  "Tampal": "Paste",
  "Link yang dikongsi tidak dapat dibaca. Cuba tampal semula.":
      "The shared link could not be read. Try pasting it again.",
  "Teks ini terlalu panjang. Tampal satu link sahaja untuk disemak.":
      "This text is too long. Paste one link to check.",
  "Link yang mana?": "Which link?",
  "Beberapa link ditemui. Pilih satu untuk disemak.":
      "Several links found. Choose one to check.",
  "Papan klip kosong. Salin link yang anda mahu semak dahulu.":
      "Your clipboard is empty. Copy a link to check first.",
  "Link tidak dapat ditampal. Anda masih boleh menaipnya di sini.":
      "The link could not be pasted. You can still type it here.",
  "01 / SEMAKAN PAUTAN": "01 / LINK CHECK",
  "Semak pautan": "Check a link",
  "Kenali link sebelum anda membukanya.": "Know the link before you open it.",
  "LINK UNTUK DISEMAK": "LINK TO CHECK",
  "https://contoh.com": "https://example.com",
  "Menyiapkan semakan…": "Getting ready…",
  "Sedang menyemak…": "Checking…",
  "Tampal & semak": "Paste & check",
  "Semak link": "Check link",
  "Melalui pelayan anda · boleh ditukar di Tetapan":
      "Using your server · change in Settings",
  "Disemak pada telefon. Link tidak dibuka.":
      "Checked on your phone. The link is not opened.",
  "Muatkan semula semakan": "Reload checker",
  "Semak link lain": "Check another link",
  "Versi percubaan": "Research preview",
  "Tentang semakan": "About this check",
  "LINK MENCURIGAKAN": "SUSPICIOUS LINK",
  "BELUM DAPAT DIPERIKSA": "COULD NOT CHECK",
  "SEMAKAN SELESAI": "CHECK COMPLETE",
  "Jangan buka dahulu.": "Wait before opening.",
  "Cuba semak semula.": "Try checking again.",
  "Tiada tanda bahaya\ndikesan.": "No warning signs\nfound.",
  "Sambungan ke pelayan tidak berjaya atau link tidak sah. Tiada keputusan keselamatan diberikan.": "The server could not be reached or the link is invalid. No safety verdict was given.",
  "Pastikan anda memasukkan satu link yang lengkap. Jika semakan belum tersedia, cuba muatkan semula.":
      "Enter one complete link. If the checker is not ready, try reloading it.",
  "Ada corak yang mencurigakan. Semak pengirim dan ejaan domain sebelum meneruskan.": "A suspicious pattern was found. Check the sender and domain spelling before continuing.",
  "Tiada corak mencurigakan ditemui pada bentuk link ini. Ini bukan jaminan bahawa laman tersebut selamat.": "No suspicious pattern was found in this link's structure. This does not guarantee the website is safe.",
  "Kenapa keputusan ini?": "Why this result?",
  "Semakan awal sahaja. Kandungan laman dan destinasi link pendek belum diperiksa.": "An initial check only. Page content and shortened-link destinations have not been checked.",
  "Bentuk link ini menyerupai corak yang digunakan dalam phishing.":
      "This link resembles patterns used in phishing.",
  "Alamat ini menggunakan aksara khas. Semak sama ada ejaannya menyerupai domain lain.": "This address uses special characters. Check whether its spelling imitates another domain.",
  "Tiada tanda mencurigakan ditemui dalam struktur link.":
      "No suspicious signs were found in the link's structure.",
  "Alamat menggunakan IP, bukan nama domain.":
      "The address uses an IP instead of a domain name.",
  "URL mengandungi bahagian pengguna sebelum domain (@).":
      "The URL contains user information before the domain (@).",
  "Sambungan HTTP tidak disulitkan.": "The HTTP connection is not encrypted.",
  "Semakan automatik aktif": "Automatic checks are on",
  "Sambung persediaan anda": "Continue your setup",
  "Link dalam mesej?": "Links in your messages?",
  "Link dalam notifikasi diperiksa pada telefon.":
      "Links in notifications are checked on your phone.",
  "Sediakan semakan automatik untuk notifikasi baharu.":
      "Set up automatic checks for new notifications.",
  "Perlindungan": "Protection",
  "Link masuk.\nAnda lebih bersedia.": "New links.\nMore peace of mind.",
  "Berehat seketika.": "Taking a break.",
  "Jaga link\nyang masuk.": "Watch the links\ncoming in.",
  "Semak semula": "Check again",
  "Sambung semula": "Reconnect",
  "Sedang menyambung…": "Connecting…",
  "Jeda perlindungan": "Pause protection",
  "Sambung perlindungan": "Resume protection",
  "Sediakan perlindungan": "Set up protection",
  "Pilih app untuk diperiksa": "Choose apps to check",
  "Benarkan akses notifikasi": "Allow notification access",
  "Benarkan amaran": "Allow warnings",
  "02 / PERLINDUNGAN": "02 / PROTECTION",
  "Link dalam notifikasi diperiksa pada telefon. Kami beri amaran apabila ada tanda mencurigakan.": "Notification links are checked on your phone. You receive a warning when suspicious signs are found.",
  "Semakan automatik sedang dijeda. Anda masih boleh menyemak link sendiri.":
      "Automatic checks are paused. You can still check links manually.",
  "Semak link dalam notifikasi secara automatik. Terima amaran jika mencurigakan.": "Check notification links automatically. Get a warning if they look suspicious.",
  "SEDANG MEMERIKSA": "CHECKING LINKS",
  "MENYAMBUNG": "CONNECTING",
  "PERLU PERHATIAN": "NEEDS ATTENTION",
  "SEDANG DIJEDA": "PAUSED",
  "BELUM DISEDIAKAN": "NOT SET UP",
  "Perlindungan aktif": "Protection is on",
  "Menunggu sambungan": "Waiting for connection",
  "Perlindungan dijeda": "Protection is paused",
  "Dua kebenaran diperlukan": "Two permissions needed",
  "Akses notifikasi": "Notification access",
  "Supaya link yang masuk boleh diperiksa.":
      "So incoming links can be checked.",
  "Amaran daripada LinkGuard": "Warnings from LinkGuard",
  "Supaya anda tahu apabila link mencurigakan ditemui.":
      "So you know when a suspicious link is found.",
  "App yang diperiksa": "Apps to check",
  "Semua app · boleh ditukar": "All apps · you can change this",
  "Belum dipilih": "None selected",
  "Mesej tidak disimpan atau dihantar ke pelayan. Semakan bergantung pada kandungan yang Android benarkan untuk dibaca.": "Messages are not saved or sent to a server. Checks depend on the content Android allows the app to read.",
  "Sudah dibenarkan": "Already allowed",
  "Anda tentukan\napa yang dibaca.": "You decide\nwhat is read.",
  "Untuk mencari link, LinkGuard perlu membaca teks notifikasi semua app. Anda boleh memilih app tertentu kemudian.": "To find links, LinkGuard needs to read notification text from all apps. You can choose specific apps later.",
  "Disemak pada telefon": "Checked on your phone",
  "Teks notifikasi tidak dihantar ke pelayan.":
      "Notification text is not sent to a server.",
  "Tiada sejarah mesej": "No message history",
  "Mesej, link dan pengirim tidak disimpan.":
      "Messages, links and senders are not saved.",
  "Boleh dijeda bila-bila masa": "Pause whenever you want",
  "Akses juga boleh ditarik balik dalam tetapan Android.":
      "You can also revoke access in Android settings.",
  "Versi percubaan: semakan mungkin tersilap atau terlepas link berbahaya.":
      "Research preview: checks can be wrong or miss dangerous links.",
  "Setuju & teruskan": "Agree & continue",
  "Bukan sekarang": "Not now",
  "App pilihan anda": "Your chosen apps",
  "Periksa semua app atau pilih yang anda gunakan. Link hanya diperiksa apabila notifikasi boleh dibaca.": "Check all apps or choose the ones you use. Links can only be checked when notification text is readable.",
  "Semua app": "All apps",
  "Tiada app dipilih. Perlindungan automatik dijeda.":
      "No apps selected. Automatic protection is paused.",
  "Selesai": "Done",
  "DATA & PILIHAN ANDA": "YOUR DATA & CHOICES",
  "Ringkas.\nDalam kawalan anda.": "Simple.\nIn your control.",
  "Semakan harian": "Everyday checks",
  "Link diperiksa pada telefon secara lalai. Tiada akaun diperlukan dan tiada sejarah mesej atau link disimpan.": "Links are checked on your phone by default. No account is needed and no message or link history is saved.",
  "Urus akses di Android": "Manage Android access",
  "TENTANG KEPUTUSAN": "ABOUT THE RESULTS",
  "Ini semakan awal, bukan jaminan keselamatan.":
      "This is an initial check, not a safety guarantee.",
  "Versi ini menilai bentuk link sahaja. Kandungan laman, destinasi link pendek, teks dalam gambar dan mesej tanpa link belum diperiksa. Android juga boleh menyembunyikan sebahagian notifikasi.": "This version only checks link structure. Page content, shortened-link destinations, image text and messages without links are not checked. Android may also hide parts of notifications.",
  "Pilihan lanjutan": "Advanced options",
  "Tidak diperlukan untuk kegunaan biasa": "Not needed for everyday use",
  "Semakan melalui pelayan": "Check using a server",
  "Untuk semakan manual sahaja": "For manual checks only",
  "Hantar link ke pelayan anda?": "Send this link to your server?",
  "Link penuh, termasuk sebarang token atau maklumat peribadi dalamnya, akan dihantar ke alamat pelayan yang anda tetapkan. Gunakan hanya pelayan yang anda percayai. Notifikasi kekal diperiksa pada telefon.": "The complete link, including any tokens or personal information in it, will be sent to your configured server. Only use a server you trust. Notifications will still be checked on your phone.",
  "Batal": "Cancel",
  "Benarkan untuk sesi ini": "Allow for this session",
  "Alamat pelayan anda": "Your server address",
  "HTTPS untuk sambungan luar.": "Use HTTPS for external connections.",
  "Tentang & lesen": "About & licenses",
  "Sumber latihan: PhiUSIIL, Prasad & Chandra (2024), UCI #967. CC BY 4.0. doi.org/10.1016/j.cose.2023.103545": "Training source: PhiUSIIL, Prasad & Chandra (2024), UCI #967. CC BY 4.0. doi.org/10.1016/j.cose.2023.103545",
  "Jeda & set semula tetapan": "Pause & reset settings",
  "Set semula tetapan?": "Reset settings?",
  "Perlindungan akan dijeda dan pilihan app dipadam. Akses Android masih boleh ditarik balik melalui tetapan telefon.": "Protection will be paused and your app selection cleared. Android access can still be revoked through your phone settings.",
  "Set semula": "Reset",
  "Salin satu link dahulu, kemudian tampal di sini.":
      "Copy a link first, then paste it here.",
  "Semakan belum tersedia. Cuba muatkan semula.":
      "The checker is not ready. Try reloading it.",
  "Status perlindungan belum dapat disahkan.":
      "Protection status could not be confirmed.",
  "Perubahan belum dapat disimpan. Cuba lagi.":
      "Your changes could not be saved. Try again.",
  "Pilih sekurang-kurangnya satu app untuk diperiksa.":
      "Choose at least one app to check.",
  "Amaran belum dibenarkan. Anda boleh sambung apabila bersedia.":
      "Warnings are not allowed yet. You can continue when you are ready.",
  "Tetapan Android tidak dapat dibuka. Cuba lagi.":
      "Android settings could not be opened. Try again.",
};
