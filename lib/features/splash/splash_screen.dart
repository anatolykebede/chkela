import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';

import '../../core/providers/app_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../data/content/content_store.dart';
import '../../data/app_remote_config.dart';
import '../../data/study_progress_store.dart';
import '../../data/map_profile_store.dart';
import '../auth/auth_provider.dart';
import '../notifications/push_notification_service.dart';

/// Full-screen muted video splash. Black until the first video frame is ready.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  static const _asset = 'assets/branding/splash.mp4';

  VideoPlayerController? _controller;
  bool _navigated = false;
  bool _videoReady = false;
  bool _bootDone = false;
  bool _videoDone = false;
  bool _nativeSplashRemoved = false;

  @override
  void initState() {
    super.initState();
    unawaited(_start());
  }

  Future<void> _start() async {
    final boot = _runBootstrap();
    final video = _runVideo();
    await Future.wait([boot, video]);
    await _leaveWhenReady();
  }

  Future<void> _runBootstrap() async {
    // Local catalog (cache / bundle) only. CMS sync continues in background
    // via ContentStore.load → syncFromNetwork so splash is never blocked on
    // the network.
    await Future.wait([
      _waitForHydration(),
      ContentStore.instance.load(),
      StudyProgressStore.instance.load(),
      MapProfileStore.instance.load(),
      ref.read(appRemoteConfigProvider.notifier).refresh(),
    ]);
    if (!mounted) return;
    _bootDone = true;
  }

  void _removeNativeSplash() {
    if (_nativeSplashRemoved) return;
    _nativeSplashRemoved = true;
    FlutterNativeSplash.remove();
  }

  Future<void> _runVideo() async {
    try {
      await rootBundle.load(_asset);

      final controller = VideoPlayerController.asset(
        _asset,
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );
      _controller = controller;
      await controller.initialize();
      if (!mounted) return;
      if (!controller.value.isInitialized ||
          controller.value.size == Size.zero) {
        throw StateError('Video initialized with empty size');
      }

      await controller.setVolume(0);
      await controller.setLooping(false);
      controller.addListener(_onVideoTick);

      // Seek to start so the first painted frame is the video, not a blank
      // player surface that would flash the old logo placeholder.
      await controller.seekTo(Duration.zero);
      if (!mounted) return;

      setState(() => _videoReady = true);
      _removeNativeSplash();
      await controller.play();

      final duration = controller.value.duration;
      final deadline = DateTime.now().add(
        duration > Duration.zero
            ? duration + const Duration(milliseconds: 600)
            : const Duration(seconds: 4),
      );
      while (mounted && !_videoDone && DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 40));
      }
      _markVideoDone();
    } catch (error, stack) {
      developer.log(
        'Splash video failed: $error',
        name: 'SplashScreen',
        error: error,
        stackTrace: stack,
      );
      if (!mounted) return;
      _removeNativeSplash();
      await Future<void>.delayed(const Duration(milliseconds: 700));
      _markVideoDone();
    }
  }

  void _onVideoTick() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    final duration = controller.value.duration;
    final position = controller.value.position;
    if (duration > Duration.zero &&
        position >= duration - const Duration(milliseconds: 80)) {
      _markVideoDone();
    }
  }

  void _markVideoDone() {
    if (_videoDone) return;
    _videoDone = true;
    unawaited(_leaveWhenReady());
  }

  Future<void> _leaveWhenReady() async {
    if (!mounted || _navigated || !_bootDone || !_videoDone) return;
    _navigated = true;

    final auth = ref.read(authProvider);
    if (auth.grade != null) {
      ref.read(selectedGradeProvider.notifier).state = auth.grade!;
    }
    await MapProfileStore.instance.syncFromAuth(
      grade: auth.grade,
      interests: auth.interests,
    );
    if (auth.isAuthenticated) {
      await PushNotificationService.instance.syncTokenForPhone(auth.phoneE164);
    }
    if (!mounted) return;

    _removeNativeSplash();

    if (auth.isAuthenticated) {
      context.go('/home');
    } else if (auth.needsOnboarding) {
      context.go(auth.onboardingPath);
    } else {
      context.go('/login');
    }
  }

  Future<void> _waitForHydration() async {
    if (ref.read(authProvider).isHydrated) return;
    for (var i = 0; i < 40; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      if (!mounted) return;
      if (ref.read(authProvider).isHydrated) return;
    }
  }

  @override
  void dispose() {
    final controller = _controller;
    if (controller != null) {
      controller.removeListener(_onVideoTick);
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final ready = _videoReady &&
        controller != null &&
        controller.value.isInitialized &&
        controller.value.size != Size.zero;

    return Scaffold(
      backgroundColor: AppColors.bgBase,
      body: ColoredBox(
        color: AppColors.bgBase,
        child: SizedBox.expand(
          child: ready
              ? LayoutBuilder(
                  builder: (context, constraints) {
                    final video = controller.value.size;
                    final sx = constraints.maxWidth / video.width;
                    final sy = constraints.maxHeight / video.height;
                    final scale = sx > sy ? sx : sy;
                    final width = video.width * scale;
                    final height = video.height * scale;
                    return ClipRect(
                      child: OverflowBox(
                        minWidth: width,
                        maxWidth: width,
                        minHeight: height,
                        maxHeight: height,
                        alignment: Alignment.center,
                        child: SizedBox(
                          width: width,
                          height: height,
                          child: VideoPlayer(controller),
                        ),
                      ),
                    );
                  },
                )
              : null,
        ),
      ),
    );
  }
}
