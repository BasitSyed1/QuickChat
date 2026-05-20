import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/cache/local_cache.dart';

// Inline Supabase credentials for testing builds. These are the project's
// public anon URL/key — safe to ship as long as RLS is enforced in Postgres.
const _supabaseUrl = 'https://tsnqqrlicrcnfoxmyyyv.supabase.co';
const _supabaseAnonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRzbnFxcmxpY3JjbmZveG15eXl2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTEyMjM2OTIsImV4cCI6MjA2Njc5OTY5Mn0.POsLjZQYz-f7NwBHXVNlkzB1Zp1sd3j0S8BlB5bsbBg';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
    ),
  );
  SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.edgeToEdge,
    overlays: SystemUiOverlay.values,
  );

  if (_supabaseUrl.isEmpty || _supabaseAnonKey.isEmpty) {
    runApp(const _MissingEnvApp());
    return;
  }

  await LocalCache.init();

  try {
    await Supabase.initialize(
      url: _supabaseUrl,
      anonKey: _supabaseAnonKey,
    );
  } catch (e) {
    runApp(_StartupErrorApp(message: e.toString()));
    return;
  }

  runApp(const ProviderScope(child: QuickChatApp()));
}

class _MissingEnvApp extends StatelessWidget {
  const _MissingEnvApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFF0F0F0F),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Icon(Icons.key_off_rounded,
                    color: Color(0xFF7CFC8A), size: 48),
                SizedBox(height: 16),
                Text(
                  'Missing Supabase credentials',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  'Pass SUPABASE_URL and SUPABASE_ANON_KEY when running the app:',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                SizedBox(height: 12),
                SelectableText(
                  'flutter run \\\n  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co \\\n  --dart-define=SUPABASE_ANON_KEY=YOUR_ANON_KEY',
                  style: TextStyle(
                    color: Color(0xFF7CFC8A),
                    fontSize: 12,
                    fontFamily: 'monospace',
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  'In VS Code, edit .vscode/launch.json and replace PASTE_YOUR_SUPABASE_URL_HERE / PASTE_YOUR_SUPABASE_ANON_KEY_HERE with your real values, then press F5.',
                  style: TextStyle(color: Colors.white60, fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StartupErrorApp extends StatelessWidget {
  final String message;
  const _StartupErrorApp({required this.message});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFF0F0F0F),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.error_outline_rounded,
                    color: Color(0xFFE53935), size: 48),
                const SizedBox(height: 16),
                const Text(
                  'Startup failed',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                SelectableText(
                  message,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
