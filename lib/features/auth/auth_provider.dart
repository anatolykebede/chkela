import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_session_store.dart';
import '../../data/auth_api.dart';
import '../../data/leaderboard_store.dart';
import '../../data/referral_api.dart';
import '../referral/referral_purchase_store.dart';

class AuthState {
  const AuthState({
    this.isHydrated = false,
    this.isAuthenticated = false,
    this.otpVerified = false,
    this.isReturningUser = false,
    this.phoneE164,
    this.pendingPhone,
    this.fullName,
    this.grade,
    this.birthdate,
    this.interests = const {},
    this.isBusy = false,
    this.errorMessage,
  });

  /// True after local session has been loaded from disk.
  final bool isHydrated;

  /// Full access to the app (OTP + onboarding done).
  final bool isAuthenticated;

  /// Phone confirmed via OTP; may still need onboarding.
  final bool otpVerified;

  /// Had a completed profile for this phone before (skip onboarding).
  final bool isReturningUser;
  final String? phoneE164;
  final String? pendingPhone;
  final String? fullName;
  final String? grade;
  final DateTime? birthdate;
  final Set<String> interests;
  final bool isBusy;
  final String? errorMessage;

  bool get needsOnboarding => otpVerified && !isAuthenticated;

  /// Next incomplete onboarding route.
  String get onboardingPath {
    if (fullName == null || fullName!.trim().isEmpty) {
      return '/onboarding/name';
    }
    if (grade == null) return '/onboarding/grade';
    if (birthdate == null) return '/onboarding/birthdate';
    return '/onboarding/interests';
  }

  AuthState copyWith({
    bool? isHydrated,
    bool? isAuthenticated,
    bool? otpVerified,
    bool? isReturningUser,
    String? phoneE164,
    String? pendingPhone,
    String? fullName,
    String? grade,
    DateTime? birthdate,
    Set<String>? interests,
    bool? isBusy,
    String? errorMessage,
    bool clearError = false,
    bool clearPending = false,
  }) {
    return AuthState(
      isHydrated: isHydrated ?? this.isHydrated,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      otpVerified: otpVerified ?? this.otpVerified,
      isReturningUser: isReturningUser ?? this.isReturningUser,
      phoneE164: phoneE164 ?? this.phoneE164,
      pendingPhone: clearPending ? null : (pendingPhone ?? this.pendingPhone),
      fullName: fullName ?? this.fullName,
      grade: grade ?? this.grade,
      birthdate: birthdate ?? this.birthdate,
      interests: interests ?? this.interests,
      isBusy: isBusy ?? this.isBusy,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier({AuthApi? authApi})
      : _authApi = authApi ?? AuthApi(),
        super(const AuthState()) {
    hydrate();
  }

  final AuthApi _authApi;

  /// Normalize Ethiopian mobile input to E.164 (+2519XXXXXXXX).
  static String? normalizeEthiopianPhone(String raw) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    String local;
    if (digits.startsWith('251') && digits.length >= 12) {
      local = digits.substring(3);
    } else if (digits.startsWith('0') && digits.length >= 10) {
      local = digits.substring(1);
    } else {
      local = digits;
    }
    if (local.length != 9 || !local.startsWith('9')) return null;
    return '+251$local';
  }

  static String displayPhone(String e164) {
    final d = e164.replaceAll(RegExp(r'\D'), '');
    if (d.length < 12) return e164;
    final local = d.substring(3);
    return '+251 ${local.substring(0, 3)} ${local.substring(3, 6)} ${local.substring(6)}';
  }

  /// Restore last session so returning users skip login/onboarding.
  Future<void> hydrate() async {
    try {
      final phone = await AuthSessionStore.loadSessionPhone();
      if (phone == null) {
        state = state.copyWith(isHydrated: true);
        return;
      }

      final profile = await AuthSessionStore.profileFor(phone);
      if (profile == null) {
        await AuthSessionStore.clearSession();
        state = state.copyWith(isHydrated: true);
        return;
      }

      if (profile.onboardingComplete) {
        // Server is source of truth. Stale local "complete" must not skip
        // onboarding after an admin wipe / new registration.
        AuthRemoteUser? remote;
        try {
          remote = await _authApi.fetchMe(profile.phoneE164);
        } catch (e) {
          debugPrint('Auth me fetch failed: $e');
        }

        if (remote == null || !remote.onboardingComplete) {
          await AuthSessionStore.deleteProfile(profile.phoneE164);
          await AuthSessionStore.clearSession();
          state = const AuthState(isHydrated: true);
          return;
        }

        state = AuthState(
          isHydrated: true,
          isAuthenticated: true,
          otpVerified: true,
          isReturningUser: true,
          phoneE164: profile.phoneE164,
          fullName: remote.displayName.isNotEmpty
              ? remote.displayName
              : profile.fullName,
          grade: remote.grade.isNotEmpty ? remote.grade : profile.grade,
          birthdate: remote.birthdate != null
              ? DateTime.tryParse(remote.birthdate!)
              : profile.birthdate,
          interests: remote.interests.isNotEmpty
              ? remote.interests.toSet()
              : profile.interests,
        );
      } else {
        // Mid-onboarding: resume where they left off.
        state = AuthState(
          isHydrated: true,
          otpVerified: true,
          isReturningUser: false,
          phoneE164: profile.phoneE164,
          pendingPhone: profile.phoneE164,
          fullName: profile.fullName,
          grade: profile.grade,
          birthdate: profile.birthdate,
          interests: profile.interests,
        );
      }
    } catch (e, st) {
      debugPrint('Auth hydrate failed: $e\n$st');
      state = state.copyWith(isHydrated: true);
    }
  }

  Future<void> _persistProfile({required bool onboardingComplete}) async {
    final phone = state.phoneE164 ?? state.pendingPhone;
    if (phone == null) return;

    await AuthSessionStore.saveProfile(
      StoredUserProfile(
        phoneE164: phone,
        onboardingComplete: onboardingComplete,
        fullName: state.fullName,
        grade: state.grade,
        birthdate: state.birthdate,
        interests: state.interests,
      ),
    );
    if (onboardingComplete) {
      await AuthSessionStore.saveSessionPhone(phone);
    }

    // Best-effort server sync for the admin Users dashboard.
    try {
      await _authApi.syncProfile(
        phoneE164: phone,
        displayName: state.fullName,
        grade: state.grade,
        birthdate: state.birthdate,
        interests: state.interests,
        onboardingComplete: onboardingComplete,
      );
    } catch (e) {
      debugPrint('Auth profile sync failed: $e');
    }
  }

  Future<bool> sendOtp(String rawPhone) async {
    final normalized = normalizeEthiopianPhone(rawPhone);
    if (normalized == null) {
      state = state.copyWith(
        isBusy: false,
        errorMessage: 'Enter a valid Ethiopian mobile number',
      );
      return false;
    }

    state = state.copyWith(
      isBusy: true,
      clearError: true,
      pendingPhone: normalized,
    );

    try {
      await _authApi.sendOtp(normalized);
      if (!mounted) return false;
      state = state.copyWith(isBusy: false, pendingPhone: normalized);
      return true;
    } on AuthOtpException catch (e) {
      if (!mounted) return false;
      state = state.copyWith(isBusy: false, errorMessage: e.message);
      return false;
    } catch (_) {
      if (!mounted) return false;
      state = state.copyWith(
        isBusy: false,
        errorMessage: 'Could not send SMS. Check your connection and try again.',
      );
      return false;
    }
  }

  Future<bool> verifyOtp(String code) async {
    final phone = state.pendingPhone;
    if (phone == null) {
      state = state.copyWith(errorMessage: 'Request a code first');
      return false;
    }

    final trimmed = code.trim();
    if (trimmed.length != 4 || int.tryParse(trimmed) == null) {
      state = state.copyWith(errorMessage: 'Enter the 4-digit code');
      return false;
    }

    state = state.copyWith(isBusy: true, clearError: true);

    late final AuthVerifyResult verified;
    try {
      verified = await _authApi.verifyOtp(phoneE164: phone, code: trimmed);
    } on AuthOtpException catch (e) {
      if (!mounted) return false;
      state = state.copyWith(isBusy: false, errorMessage: e.message);
      return false;
    } catch (_) {
      if (!mounted) return false;
      state = state.copyWith(
        isBusy: false,
        errorMessage: 'Could not verify code. Check your connection.',
      );
      return false;
    }

    if (!mounted) return false;

    final token = verified.token?.trim();
    if (token != null && token.isNotEmpty) {
      await AuthSessionStore.saveSessionToken(token);
    }

    final remote = verified.user;
    final local = await AuthSessionStore.profileFor(phone);

    // Only skip onboarding when the SERVER says this account is complete.
    if (verified.onboardingComplete) {
      final remoteName = remote?.displayName.trim() ?? '';
      final remoteGrade = remote?.grade.trim() ?? '';
      state = AuthState(
        isHydrated: true,
        isAuthenticated: true,
        otpVerified: true,
        isReturningUser: true,
        phoneE164: phone,
        pendingPhone: phone,
        fullName: remoteName.isNotEmpty ? remoteName : local?.fullName,
        grade: remoteGrade.isNotEmpty ? remoteGrade : local?.grade,
        birthdate: remote?.birthdate != null
            ? DateTime.tryParse(remote!.birthdate!)
            : local?.birthdate,
        interests: (remote?.interests.isNotEmpty ?? false)
            ? remote!.interests.toSet()
            : (local?.interests ?? {}),
      );
      await AuthSessionStore.saveSessionPhone(phone);
      await _persistProfile(onboardingComplete: true);
      return true;
    }

    // New / incomplete server account: drop stale local "complete" profile.
    await AuthSessionStore.deleteProfile(phone);
    state = AuthState(
      isHydrated: true,
      otpVerified: true,
      isReturningUser: false,
      phoneE164: phone,
      pendingPhone: phone,
    );
    await _persistProfile(onboardingComplete: false);
    return true;
  }

  Future<bool> resendOtp() async {
    final phone = state.pendingPhone;
    if (phone == null) return false;
    return sendOtp(phone);
  }

  Future<void> setFullName(String name) async {
    state = state.copyWith(fullName: name.trim());
    await _persistProfile(onboardingComplete: false);
  }

  Future<void> setGrade(String grade) async {
    state = state.copyWith(grade: grade);
    await _persistProfile(onboardingComplete: false);
  }

  Future<void> setBirthdate(DateTime date) async {
    state = state.copyWith(birthdate: date);
    await _persistProfile(onboardingComplete: false);
  }

  Future<int> completeOnboarding(Set<String> interests) async {
    state = state.copyWith(
      interests: interests,
      isAuthenticated: true,
      otpVerified: true,
      isReturningUser: false,
    );
    await _persistProfile(onboardingComplete: true);
    LeaderboardStore.instance.configure(
      phoneE164: state.phoneE164 ?? state.pendingPhone,
      fullName: state.fullName,
      grade: state.grade,
    );
    // ignore: unawaited_futures
    LeaderboardStore.instance.refresh(forceUpsert: true);
    return _redeemPendingReferral();
  }

  /// Redeems a stored invite code after onboarding finishes.
  /// Returns invitee CP granted (0 if none / failed).
  Future<int> _redeemPendingReferral() async {
    final phone = state.phoneE164 ?? state.pendingPhone;
    if (phone == null) return 0;

    final code = await AuthSessionStore.loadPendingReferralCode();
    if (code == null || code.isEmpty) return 0;

    final result = await ReferralApi().redeem(
      code: code,
      inviteePhone: phone,
    );
    await AuthSessionStore.clearPendingReferralCode();

    if (result.ok) {
      final discount = result.purchaseDiscountPercent > 0
          ? result.purchaseDiscountPercent
          : kInviteePurchaseDiscountPercent;
      await ReferralPurchaseStore.markEligible(percent: discount);
      debugPrint(
        'Referral redeemed: $code → ${result.inviteePoints} CP, '
        '$discount% purchase discount',
      );
      return result.inviteePoints > 0 ? result.inviteePoints : 1;
    }
    debugPrint('Referral redeem skipped/failed: ${result.error}');
    return 0;
  }

  void clearError() {
    if (state.errorMessage == null) return;
    state = state.copyWith(clearError: true);
  }

  Future<void> signOut() async {
    await AuthSessionStore.clearSession();
    state = const AuthState(isHydrated: true);
  }

  /// Deletes the account on the server (archived for admin), then signs out.
  Future<void> deleteAccount() async {
    final phone = state.phoneE164 ?? state.pendingPhone;
    if (phone != null) {
      await _authApi.deleteAccount(phone);
      await AuthSessionStore.deleteProfile(phone);
    }
    await AuthSessionStore.clearPendingReferralCode();
    await AuthSessionStore.clearSession();
    // Same logged-out state as signOut so the router sends them to /login.
    state = const AuthState(isHydrated: true);
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});
