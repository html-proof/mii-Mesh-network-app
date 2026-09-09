import 'package:flutter/material.dart';

const ink = Color(0xff173c38);
const teal = Color(0xff257363);
const orange = Color(0xffd77743);

ThemeData miiTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final scheme = ColorScheme.fromSeed(seedColor: teal, brightness: brightness);
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: dark
        ? const Color(0xff111313)
        : const Color(0xfff7f8f4),
    fontFamily: 'Roboto',
    appBarTheme: const AppBarTheme(
      centerTitle: false,
      scrolledUnderElevation: 0,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: dark ? const Color(0xff1d2020) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(
          color: dark ? const Color(0xff30433e) : const Color(0xffe4e9e1),
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: dark ? const Color(0xff223530) : const Color(0xffeef2eb),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    textTheme: TextTheme(
      headlineLarge: TextStyle(
        fontSize: 38,
        fontWeight: FontWeight.w700,
        letterSpacing: -1.6,
        color: dark ? const Color(0xffd8ebe3) : ink,
      ),
      headlineMedium: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.8,
        color: dark ? const Color(0xffd8ebe3) : ink,
      ),
      titleLarge: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.4,
      ),
      bodyMedium: const TextStyle(fontSize: 14, height: 1.5),
      bodyLarge: const TextStyle(fontSize: 16, height: 1.5),
    ),
  );
}

class MeshArt extends StatelessWidget {
  const MeshArt({super.key, this.size = 260});
  final double size;
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Illustration of a connected mesh',
    child: SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _MeshPainter()),
    ),
  );
}

class _MeshPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final s = size.width;
    canvas.drawCircle(c, s * .44, Paint()..color = const Color(0xffe6eee0));
    for (final r in [.22, .33, .44]) {
      canvas.drawCircle(
        c,
        s * r,
        Paint()
          ..color = const Color(0xffcbdac8)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }
    final points = [
      Offset(s * .22, s * .30),
      Offset(s * .72, s * .22),
      Offset(s * .83, s * .65),
      Offset(s * .28, s * .79),
    ];
    for (final p in points) {
      canvas.drawLine(
        c,
        p,
        Paint()
          ..color = const Color(0xff9cb8a0)
          ..strokeWidth = 1.5,
      );
      canvas.drawCircle(p, s * .043, Paint()..color = Colors.white);
      canvas.drawCircle(p, s * .024, Paint()..color = teal);
    }
    canvas.drawCircle(c, s * .125, Paint()..color = teal);
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = s * .016
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final path = Path()
      ..moveTo(c.dx - s * .055, c.dy + s * .025)
      ..lineTo(c.dx - s * .055, c.dy - s * .03)
      ..lineTo(c.dx, c.dy + s * .005)
      ..lineTo(c.dx + s * .055, c.dy - s * .03)
      ..lineTo(c.dx + s * .055, c.dy + s * .025);
    canvas.drawPath(path, paint);
    canvas.drawCircle(
      Offset(s * .67, s * .78),
      s * .065,
      Paint()..color = orange,
    );
    final text = TextPainter(
      text: const TextSpan(
        text: '+',
        style: TextStyle(
          color: Colors.white,
          fontSize: 24,
          fontFamily: 'Roboto',
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    text.paint(
      canvas,
      Offset(s * .67 - text.width / 2, s * .78 - text.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class Pill extends StatelessWidget {
  const Pill(this.text, {super.key, this.icon, this.warm = false});
  final String text;
  final IconData? icon;
  final bool warm;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
    decoration: BoxDecoration(
      color: warm ? const Color(0xfffaecd9) : const Color(0xffe8efe3),
      borderRadius: BorderRadius.circular(30),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 14, color: warm ? const Color(0xff895426) : ink),
          const SizedBox(width: 6),
        ],
        Flexible(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: warm ? const Color(0xff895426) : ink,
            ),
          ),
        ),
      ],
    ),
  );
}

Future<void> runAction(
  BuildContext context,
  Future<void> Function() action,
) async {
  try {
    await action();
  } catch (error) {
    if (!context.mounted) return;
    final text = error is ArgumentError
        ? '${error.message}'
        : 'Could not save this change. Please try again.';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }
}
