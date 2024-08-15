import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cbzv/providers/cbz_providers.dart';
import 'package:cbzv/screens/home_screen.dart';
import 'package:cbzv/screens/reader_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => CBZLibraryProvider()),
        ChangeNotifierProvider(create: (_) => CBZReaderProvider()),
      ],
      child: MaterialApp(
        title: 'CBZ 뷰어',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          visualDensity: VisualDensity.adaptivePlatformDensity,
          brightness: Brightness.light,
        ),
        darkTheme: ThemeData(
          primarySwatch: Colors.blue,
          visualDensity: VisualDensity.adaptivePlatformDensity,
          brightness: Brightness.dark,
        ),
        themeMode: ThemeMode.system, // 시스템 설정에 따라 라이트/다크 모드 자동 전환
        initialRoute: '/',
        routes: {
          '/': (context) => const HomeScreen(),
          '/reader': (context) => const ReaderScreen(),
        },
      ),
    );
  }
}
