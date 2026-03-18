import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../supabase/supabase_config.dart';
import '../models/user_profile.dart';

// ── Current Supabase user ────────────────────────────────────
final authStateProvider = StreamProvider<AuthState>((ref) {
  return supabase.auth.onAuthStateChange;
});

// ── Current user profile — CACHED (keepAlive prevents refetch on every navigation) ──
final userProfileProvider = FutureProvider<UserProfile?>((ref) async {
  // keepAlive: profile won't be re-fetched every time screen is visited
  ref.keepAlive();

  final user = supabase.auth.currentUser;
  if (user == null) return null;

  final data = await supabase
      .from('profiles')
      .select()
      .eq('id', user.id)
      .single();

  return UserProfile.fromMap(data);
});

// ── Student extra data (uuid, roll, class, dob) — CACHED ─────
// Separate provider so profile screen needs ZERO extra Supabase calls.
final studentDataProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  ref.keepAlive();

  final user = supabase.auth.currentUser;
  if (user == null) return null;

  final data = await supabase
      .from('students')
      .select('uuid, roll_number, dob, classes(name)')
      .eq('profile_id', user.id)
      .maybeSingle();

  return data as Map<String, dynamic>?;
});

// ── Teacher data (id + assigned classes) — CACHED ────────────
// Used by scanner screen to show only teacher's own classes,
// and by the drawer to show assigned class names.
final teacherDataProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  ref.keepAlive();

  final user = supabase.auth.currentUser;
  if (user == null) return null;

  final data = await supabase
      .from('teachers')
      .select('''
        id,
        can_add_videos,
        can_add_marks,
        can_add_reports,
        teacher_classes (
          subject,
          classes ( id, name )
        )
      ''')
      .eq('profile_id', user.id)
      .maybeSingle();

  return data as Map<String, dynamic>?;
});

// ── Auth actions ─────────────────────────────────────────────
final authProvider = Provider<AuthService>((ref) => AuthService(ref));

class AuthService {
  final Ref _ref;
  AuthService(this._ref);

  Future<AuthResponse> signIn(String email, String password) async {
    return await supabase.auth.signInWithPassword(
      email: email, password: password,
    );
  }

  Future<void> signOut() async {
    // Invalidate cached providers on logout so next login gets fresh data
    _ref.invalidate(userProfileProvider);
    _ref.invalidate(studentDataProvider);
    _ref.invalidate(teacherDataProvider);
    await supabase.auth.signOut();
  }

  User? get currentUser => supabase.auth.currentUser;
  bool get isLoggedIn   => currentUser != null;
}