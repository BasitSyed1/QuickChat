import 'package:device_preview/device_preview.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';

const String _supabaseUrl = 'https://tsnqqrlicrcnfoxmyyyv.supabase.co';
const String _supabaseAnonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRzbnFxcmxpY3JjbmZveG15eXl2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTEyMjM2OTIsImV4cCI6MjA2Njc5OTY5Mn0.POsLjZQYz-f7NwBHXVNlkzB1Zp1sd3j0S8BlB5bsbBg';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: _supabaseUrl,
    anonKey: _supabaseAnonKey,
  );

  runApp(
    DevicePreview(
      enabled: !kReleaseMode,
      builder: (_) => const ProviderScope(child: QuickChatApp()),
    ),
  );
}
