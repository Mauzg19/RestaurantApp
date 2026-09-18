import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/theme/app_theme.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key, required this.onFinished});

  final Widget Function() onFinished;

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  VideoPlayerController? _controller;
  bool _showFallback = false;
  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();
    _startVideo();
  }

  Future<void> _startVideo() async {
    final controller = VideoPlayerController.asset(
      'assets/videos/restaurant_splash.mp4',
    );
    _controller = controller;
    try {
      await controller.initialize();
      await controller.setLooping(false);
      await controller.setVolume(0);
      controller.addListener(_onVideoChanged);
      if (mounted) setState(() {});
      await controller.play();
    } catch (_) {
      if (mounted) setState(() => _showFallback = true);
      _finishAfter(const Duration(milliseconds: 1500));
    }
  }

  void _onVideoChanged() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (controller.value.duration > Duration.zero &&
        controller.value.position >= controller.value.duration) {
      _goToLogin();
    }
  }

  void _finishAfter(Duration duration) {
    Future<void>.delayed(duration, _goToLogin);
  }

  void _goToLogin() {
    if (!mounted || _hasNavigated) return;
    _hasNavigated = true;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, _, _) => widget.onFinished(),
        transitionDuration: const Duration(milliseconds: 550),
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  void dispose() {
    _controller?.removeListener(_onVideoChanged);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final hasVideo = controller?.value.isInitialized ?? false;
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (hasVideo)
            FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: controller!.value.size.width,
                height: controller.value.size.height,
                child: VideoPlayer(controller),
              ),
            )
          else
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF3B1909), AppTheme.background],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
          Container(color: Colors.black.withValues(alpha: 0.32)),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.restaurant_menu,
                  size: 72,
                  color: AppTheme.accent,
                ),
                const SizedBox(height: 18),
                Text(
                  'RESTAURANT FAST',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 3,
                  ),
                ),
                if (_showFallback) ...[
                  const SizedBox(height: 22),
                  const SizedBox(
                    width: 26,
                    height: 26,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.accent,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
