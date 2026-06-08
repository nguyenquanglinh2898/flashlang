import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/card_provider.dart';
import 'providers/group_provider.dart';
import 'providers/settings_provider.dart';
import 'screens/card_detail_screen.dart';
import 'screens/home_screen.dart';
import 'services/notification_service.dart';

class FlashLangApp extends StatelessWidget {
  const FlashLangApp({
    super.key,
    required this.notificationService,
  });

  final NotificationService notificationService;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: <ChangeNotifierProvider<dynamic>>[
        ChangeNotifierProvider<CardProvider>(
          create: (_) => CardProvider(),
        ),
        ChangeNotifierProvider<GroupProvider>(
          create: (_) => GroupProvider(),
        ),
        ChangeNotifierProvider<SettingsProvider>(
          create: (_) => SettingsProvider(
            onSettingsChanged: notificationService.scheduleNotifications,
          ),
        ),
      ],
      child: _FlashLangAppView(notificationService: notificationService),
    );
  }
}

class _FlashLangAppView extends StatefulWidget {
  const _FlashLangAppView({
    required this.notificationService,
  });

  final NotificationService notificationService;

  @override
  State<_FlashLangAppView> createState() => _FlashLangAppViewState();
}

class _FlashLangAppViewState extends State<_FlashLangAppView> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  StreamSubscription<NotificationPayload>? _notificationSubscription;

  @override
  void initState() {
    super.initState();
    _notificationSubscription =
        widget.notificationService.notificationTapStream.listen(_openCardFromPayload);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final NotificationPayload? launchPayload =
          await widget.notificationService.getLaunchPayload();
      if (!mounted || launchPayload == null) {
        return;
      }

      _openCardFromPayload(launchPayload);
    });
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme lightColorScheme = ColorScheme.fromSeed(
      seedColor: Colors.blue,
      brightness: Brightness.light,
    );
    final ColorScheme darkColorScheme = ColorScheme.fromSeed(
      seedColor: Colors.blue,
      brightness: Brightness.dark,
    );

    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'FlashLang',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: lightColorScheme,
        scaffoldBackgroundColor: lightColorScheme.surface,
        appBarTheme: AppBarTheme(
          centerTitle: false,
          backgroundColor: lightColorScheme.surface,
          foregroundColor: lightColorScheme.onSurface,
          elevation: 0,
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: lightColorScheme.surfaceContainerLow,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: darkColorScheme,
        scaffoldBackgroundColor: darkColorScheme.surface,
        appBarTheme: AppBarTheme(
          centerTitle: false,
          backgroundColor: darkColorScheme.surface,
          foregroundColor: darkColorScheme.onSurface,
          elevation: 0,
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: darkColorScheme.surfaceContainerLow,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ),
      home: const HomeScreen(),
    );
  }

  void _openCardFromPayload(NotificationPayload payload) {
    final NavigatorState? navigator = _navigatorKey.currentState;
    if (navigator == null || payload.cardId <= 0) {
      return;
    }

    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => CardDetailScreen(cardId: payload.cardId),
      ),
    );
  }
}
