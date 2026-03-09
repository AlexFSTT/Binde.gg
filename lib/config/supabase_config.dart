import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  // ──────────────────────────────────────────────────────
  // Replace with your Supabase project credentialss
  // ──────────────────────────────────────────────────────
  static const String _supabaseUrl = 'https://pszvntnuehqxxhfecdmc.supabase.co';
  static const String _supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBzenZudG51ZWhxeHhoZmVjZG1jIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzI3NDQ2MjEsImV4cCI6MjA4ODMyMDYyMX0.XqA9G1AvS3kNtOBCSPSbpybAE7mzig9QHZwQds7egMQ';

  static Future<void> initialize() async {
    await Supabase.initialize(
      url: _supabaseUrl,
      anonKey: _supabaseAnonKey,
    );
  }

  /// Quick access to the Supabase client
  static SupabaseClient get client => Supabase.instance.client;

  /// Quick access to the auth instance
  static GoTrueClient get auth => client.auth;
}
