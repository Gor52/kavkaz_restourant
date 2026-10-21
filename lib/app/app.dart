import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';

import 'router.dart';
import 'theme/app_colors.dart';
import 'theme/app_theme.dart';

class CaucasianRestaurantApp extends StatelessWidget {
  const CaucasianRestaurantApp({super.key});

  static TextTheme _textTheme() {
    final base = GoogleFonts.plusJakartaSansTextTheme();
    TextStyle display(TextStyle? s) => GoogleFonts.fraunces(
          textStyle: s,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        );

    return base.copyWith(
      displaySmall: display(base.displaySmall),
      headlineMedium: display(base.headlineMedium),
      headlineSmall: display(base.headlineSmall),
      titleLarge: display(base.titleLarge),
      titleMedium: base.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
      ),
      bodyLarge: base.bodyLarge?.copyWith(height: 1.45),
      bodyMedium: base.bodyMedium?.copyWith(height: 1.45),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Ресторан кавказской кухни',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme(_textTheme()),
      routerConfig: appRouter,
      locale: const Locale('ru', 'RU'),
      supportedLocales: const [
        Locale('ru', 'RU'),
        Locale('en', 'US'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        if (child == null) {
          return const Material(
            child: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }
        return child;
      },
    );
  }
}
