import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/card_provider.dart';
import 'providers/group_provider.dart';
import 'providers/settings_provider.dart';
import 'screens/card_detail_screen.dart';
import 'screens/home_screen.dart';
import 'services/device_profile_service.dart';
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
  late final Future<bool> _isWatchDeviceFuture;

  @override
  void initState() {
    super.initState();
    _isWatchDeviceFuture = DeviceProfileService.instance.isWatchDevice();
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
      home: FutureBuilder<bool>(
        future: _isWatchDeviceFuture,
        builder: (BuildContext context, AsyncSnapshot<bool> snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            );
          }

          if (snapshot.data == true) {
            return const _UnsupportedWatchScreen();
          }

          return const HomeScreen();
        },
      ),
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

class _UnsupportedWatchScreen extends StatelessWidget {
  const _UnsupportedWatchScreen();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFF07111F),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final double horizontalPadding = constraints.maxWidth < 220 ? 14 : 20;
            final double verticalPadding = constraints.maxHeight < 220 ? 14 : 20;
            final double iconSize = constraints.maxWidth < 220 ? 30 : 40;

            return SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: verticalPadding,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - (verticalPadding * 2),
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 260),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: const Color(0xFF0E1C31),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: const Color(0xFF1E3A5F),
                        ),
                      ),
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: constraints.maxWidth < 220 ? 16 : 20,
                          vertical: constraints.maxHeight < 220 ? 16 : 20,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Icon(
                              Icons.watch_rounded,
                              size: iconSize,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Phone app only',
                              style: theme.textTheme.titleLarge?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Install and open the Wear OS app on your watch.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: const Color(0xFFD8E6FF),
                                height: 1.35,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'wear-release.apk',
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: const Color(0xFF93C5FD),
                                fontWeight: FontWeight.w700,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
