import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';
import 'package:yaounde_trip/config/api_config.dart';
import 'package:yaounde_trip/widgets/chat_media.dart';

class _VideoPlatform extends VideoPlayerPlatform {
  final sources = <String>[];
  final events = <int, StreamController<VideoEvent>>{};
  final disposed = <int>[];
  final disposal = Completer<void>();
  int plays = 0;
  int pauses = 0;
  bool fail = false;

  @override
  Future<void> init() async {}

  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async {
    sources.add(options.dataSource.uri!);
    final id = sources.length;
    final stream = StreamController<VideoEvent>();
    events[id] = stream;
    if (fail) {
      stream.addError(
        PlatformException(
          code: 'test-video-error',
          message: 'Network unavailable',
        ),
      );
    } else {
      stream.add(
        VideoEvent(
          eventType: VideoEventType.initialized,
          duration: const Duration(seconds: 10),
          size: const Size(640, 360),
        ),
      );
    }
    return id;
  }

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) => events[playerId]!.stream;
  @override
  Future<void> dispose(int playerId) async {
    disposed.add(playerId);
    if (!disposal.isCompleted) disposal.complete();
    await events[playerId]!.close();
  }

  @override
  Future<void> play(int playerId) async {
    plays++;
  }

  @override
  Future<void> pause(int playerId) async {
    pauses++;
  }

  @override
  Future<void> setLooping(int playerId, bool looping) async {}
  @override
  Future<void> setVolume(int playerId, double volume) async {}
  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {}
  @override
  Future<void> seekTo(int playerId, Duration position) async {}
  @override
  Future<Duration> getPosition(int playerId) async => Duration.zero;
  @override
  Widget buildViewWithOptions(VideoViewOptions options) =>
      const SizedBox(key: Key('video-view'));
}

void main() {
  late VideoPlayerPlatform originalPlatform;
  late _VideoPlatform platform;

  setUp(() {
    originalPlatform = VideoPlayerPlatform.instance;
    platform = _VideoPlatform();
    VideoPlayerPlatform.instance = platform;
  });

  tearDown(() {
    VideoPlayerPlatform.instance = originalPlatform;
  });

  testWidgets('video plays from the shared API URL, pauses and disposes', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ChatMedia(url: '/chat/media/clip.mp4', type: 'video'),
        ),
      ),
    );
    expect(platform.sources, isEmpty);
    expect(find.byTooltip('Play video'), findsOneWidget);
    await tester.tap(find.byTooltip('Play video'));
    await tester.pumpAndSettle();
    expect(platform.sources, ['${ApiConfig.baseUrl}/chat/media/clip.mp4']);
    expect(platform.plays, 1);
    expect(find.byKey(const Key('video-view')), findsOneWidget);
    await tester.tap(find.byTooltip('Pause video'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Play video'), findsOneWidget);
    expect(platform.pauses, greaterThan(0));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await tester.runAsync(
      () => platform.disposal.future.timeout(const Duration(seconds: 2)),
    );
    expect(platform.disposed, [1]);
  });

  testWidgets('video failure is visible and can be retried', (tester) async {
    platform.fail = true;
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ChatMedia(url: '/chat/media/clip.webm', type: 'video'),
        ),
      ),
    );
    await tester.tap(find.byTooltip('Play video'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Video could not be played'), findsOneWidget);
    expect(find.byTooltip('Retry video'), findsOneWidget);
    platform.fail = false;
    await tester.tap(find.byTooltip('Retry video'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('video-view')), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets(
    'legacy photos, shared photos, stickers and bad media render safely',
    (tester) async {
      const pixel =
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aK1sAAAAASUVORK5CYII=';
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ChatMedia(url: 'data:image/png;base64,$pixel', type: 'image'),
          ),
        ),
      );
      final memory =
          tester.widget<Image>(find.byType(Image)).image as MemoryImage;
      expect(memory.bytes, base64Decode(pixel));
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ChatMedia(url: '/chat/media/photo.png', type: 'image'),
          ),
        ),
      );
      final network =
          tester.widget<Image>(find.byType(Image)).image as NetworkImage;
      expect(network.url, '${ApiConfig.baseUrl}/chat/media/photo.png');
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ChatMedia(url: 'Sticker \u{1f60a}', type: 'sticker'),
          ),
        ),
      );
      expect(find.text('Sticker \u{1f60a}'), findsOneWidget);
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ChatMedia(url: 'blob:unshared-device-file', type: 'image'),
          ),
        ),
      );
      expect(find.text('This attachment could not be loaded.'), findsOneWidget);
    },
  );
}
