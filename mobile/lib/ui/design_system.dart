import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'app_copy.dart';

import 'package:flutter/services.dart';

abstract final class Lg {
  static const paper = Color(0xffF5F2EB),
      ink = Color(0xff20302D),
      orange = Color(0xffB64628);
  static const muted = Color(0xff68736D),
      line = Color(0xffDDDAD1),
      white = Color(0xffFFFEFA);
  static const sage = Color(0xffE7EDE3),
      green = Color(0xff3C6549),
      blush = Color(0xffF5E4D8);
  static const serif = 'DMSerifDisplay';
  static ThemeData get theme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    fontFamily: 'Manrope',
    scaffoldBackgroundColor: paper,
    colorScheme: const ColorScheme.light(
      primary: orange,
      onPrimary: Colors.white,
      secondary: orange,
      onSecondary: Colors.white,
      secondaryContainer: blush,
      onSecondaryContainer: ink,
      surface: paper,
      onSurface: ink,
      error: orange,
      outline: line,
    ),
    textTheme: const TextTheme(
      bodyMedium: TextStyle(fontSize: 14, height: 1.6, color: ink),
      bodySmall: TextStyle(fontSize: 12, height: 1.6, color: muted),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: ink,
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: paper,
      surfaceTintColor: Colors.transparent,
      foregroundColor: ink,
      elevation: 0,
      centerTitle: false,
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: paper,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    ),
    dividerTheme: const DividerThemeData(color: line, thickness: 1, space: 1),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: paper,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: paper,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: orange,
        foregroundColor: Colors.white,
        disabledBackgroundColor: line,
        minimumSize: const Size.fromHeight(54),
        textStyle: const TextStyle(
          fontFamily: 'Manrope',
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: orange,
        minimumSize: const Size(48, 48),
        textStyle: const TextStyle(
          fontFamily: 'Manrope',
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: orange, width: 1.5),
      ),
    ),
  );
}

class LinkMark extends StatelessWidget {
  const LinkMark({super.key, this.size = 36, this.color = Lg.orange});
  final double size;
  final Color color;
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: CustomPaint(size: Size.square(size), painter: _LinkPainter(color)),
  );
}

class _LinkPainter extends CustomPainter {
  const _LinkPainter(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 36);
    canvas.rotate(-math.pi / 16);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.3
      ..strokeCap = StrokeCap.square
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(
      Path()
        ..moveTo(9, 21)
        ..lineTo(9, 8)
        ..lineTo(23, 8)
        ..lineTo(23, 14),
      paint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(16, 17)
        ..lineTo(29, 17)
        ..lineTo(29, 30)
        ..lineTo(16, 30)
        ..lineTo(16, 24),
      paint,
    );
    canvas.drawLine(const Offset(13, 25), const Offset(25, 13), paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_LinkPainter oldDelegate) => color != oldDelegate.color;
}

class Eyebrow extends StatelessWidget {
  const Eyebrow(this.text, {super.key, this.color = Lg.muted});
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) => AppText(
    text,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: TextStyle(
      color: color,
      fontSize: 10,
      fontWeight: FontWeight.w800,
      letterSpacing: 1.6,
      height: 1.5,
    ),
  );
}

class PaperPanel extends StatelessWidget {
  const PaperPanel({
    super.key,
    required this.child,
    this.color = Lg.white,
    this.padding = const EdgeInsets.all(20),
  });
  final Widget child;
  final Color color;
  final EdgeInsetsGeometry padding;
  @override
  Widget build(BuildContext context) => Material(
    color: color,
    shape: RoundedRectangleBorder(
      side: const BorderSide(color: Lg.line),
      borderRadius: BorderRadius.circular(14),
    ),
    clipBehavior: Clip.antiAlias,
    child: Padding(
      padding: padding,
      child: Semantics(container: true, explicitChildNodes: true, child: child),
    ),
  );
}

class MainAction extends StatelessWidget {
  const MainAction(
    this.text, {
    super.key,
    required this.onPressed,
    this.busy = false,
    this.icon = Icons.arrow_forward_rounded,
  });
  final String text;
  final VoidCallback? onPressed;
  final bool busy;
  final IconData icon;
  @override
  Widget build(BuildContext context) => FilledButton(
    onPressed: busy ? null : onPressed,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (busy)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: Lg.ink),
            )
          else
            Icon(icon, size: 19),
          const SizedBox(width: 10),
          Flexible(child: AppText(text, textAlign: TextAlign.center)),
        ],
      ),
    ),
  );
}

class SheetFrame extends StatelessWidget {
  const SheetFrame({super.key, required this.title, required this.children});
  final String title;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        12,
        24,
        24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: Lg.line,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            AppText(
              title,
              style: const TextStyle(
                fontFamily: Lg.serif,
                fontSize: 29,
                height: 1.15,
                color: Lg.ink,
              ),
            ),
            const SizedBox(height: 20),
            ...children,
          ],
        ),
      ),
    ),
  );
}
