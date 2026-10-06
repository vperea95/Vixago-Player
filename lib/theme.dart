import 'package:flutter/material.dart';

/// Colores del logo de Vixago Player: degradado de cian a violeta sobre azul noche.
class AppColors {
  static const cyan = Color(0xFF1FD8FF);
  static const blue = Color(0xFF3D6BFF);
  static const violet = Color(0xFF9B5CFF);
  static const night = Color(0xFF05091C);
  static const gradient = LinearGradient(colors: [cyan, blue, violet]);
}

ThemeData buildTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final scheme = ColorScheme.fromSeed(seedColor: AppColors.blue, brightness: brightness).copyWith(
    primary: dark ? const Color(0xFF7FA0FF) : AppColors.blue,
    secondary: AppColors.violet,
    tertiary: AppColors.cyan,
    surface: dark ? const Color(0xFF0A1028) : null,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: dark ? AppColors.night : null,
    appBarTheme: AppBarTheme(
      centerTitle: false,
      backgroundColor: dark ? AppColors.night : null,
    ),
  );
}

/// Símbolo de la app (assets/icon/logo.png).
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 32});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/icon/logo.png',
      width: size,
      height: size,
      filterQuality: FilterQuality.medium,
      semanticLabel: 'Vixago Player',
    );
  }
}

/// "Vixago" + "Player" con el degradado del logo.
class AppTitle extends StatelessWidget {
  const AppTitle({super.key});

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Vixago ', style: style),
        ShaderMask(
          shaderCallback: (rect) => AppColors.gradient.createShader(rect),
          child: Text('Player', style: style?.copyWith(color: Colors.white)),
        ),
      ],
    );
  }
}
