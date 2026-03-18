import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  static const String url = 'https://lsmvpbdpwbfsedgzbhty.supabase.co';
  static const String anonKey = 'sb_publishable_GhelLLB5VhjNopshJMZiyw_XwiXAvPP';

  static SupabaseClient get client => Supabase.instance.client;

  static Future<void> initialize() async {
    await Supabase.initialize(url: url, anonKey: anonKey);
  }
}

// Convenient global accessor
SupabaseClient get supabase => SupabaseConfig.client;
