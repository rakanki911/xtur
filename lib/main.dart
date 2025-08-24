import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'src/torrent_manager.dart';
import 'src/ui/home_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AppRoot());
}

class AppRoot extends StatelessWidget {
  const AppRoot({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(seedColor: const Color(0xFF7B61FF));
    return ChangeNotifierProvider(
      create: (_) => TorrentManager()..init(),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: colorScheme,
          brightness: Brightness.light,
          fontFamily: 'SF Pro', // iOS default; أو اتركه فارغًا
        ),
        darkTheme: ThemeData(
          useMaterial3: true,
          colorScheme: colorScheme.copyWith(brightness: Brightness.dark),
          brightness: Brightness.dark,
        ),
        themeMode: ThemeMode.system,
        home: const HomePage(),
      ),
    );
  }
}
