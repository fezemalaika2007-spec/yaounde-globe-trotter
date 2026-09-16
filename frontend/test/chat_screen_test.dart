import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yaounde_trip/screens/chat_screen.dart';
import 'package:yaounde_trip/main.dart';
import 'package:yaounde_trip/services/api_service.dart';
import 'package:yaounde_trip/widgets/chat_media.dart';

import 'chat_test_helpers.dart';

class _PhotoPicker extends ImagePicker {
  final XFile file;
  _PhotoPicker(this.file);

  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async => file;
}

Future<void> _openChat(WidgetTester tester, {ImagePicker? picker}) async {
  await tester.pumpWidget(MaterialApp(home: ChatScreen(imagePicker: picker)));
  await tester.pumpAndSettle();
}

Future<void> _closeChat(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'jwt_token_prefs': chatToken('alice'),
    });
  });

  for (final width in [320.0, 390.0]) {
    testWidgets('chat and composer fit a mobile screen of width $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await http.runWithClient(
        () async {
          await _openChat(tester);
          expect(find.byType(NavigationBar), findsNothing);
          expect(find.byType(TextField), findsOneWidget);
          expect(find.byTooltip('Play video'), findsOneWidget);
          await tester.tap(find.byTooltip('Emojis and stickers'));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await _closeChat(tester);
        },
        () => MockClient(
          (_) async => chatResponse([
            chatMessage(
              'video',
              'alice',
              'Mobile video',
              mediaUrl: '/chat/media/clip.mp4',
              mediaType: 'video',
            ),
          ]),
        ),
      );
    });
  }

  testWidgets('all users see the shared feed and only own their own messages', (
    tester,
  ) async {
    var feed = [
      chatMessage('1', 'alice', 'My message'),
      chatMessage('2', 'bob', 'Hello from Bob'),
      chatMessage('3', 'Traveler', 'Another traveler'),
    ];
    await http.runWithClient(() async {
      await _openChat(tester);
      expect(find.text('Hello from Bob'), findsOneWidget);
      expect(find.text('Another traveler'), findsOneWidget);
      expect(find.byTooltip('Delete message'), findsOneWidget);
      expect(find.byTooltip('Edit message'), findsOneWidget);
      feed = [
        ...feed,
        chatMessage(
          '4',
          'bob',
          'New message \u{1f60a}',
          mediaType: 'sticker',
          mediaUrl: 'Shared sticker',
        ),
      ];
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(find.text('New message \u{1f60a}'), findsOneWidget);
      expect(find.text('Shared sticker'), findsOneWidget);
      await _closeChat(tester);
    }, () => MockClient((_) async => chatResponse(feed)));
  });

  testWidgets('guests can read but the composer and attachments are disabled', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await http.runWithClient(
      () async {
        await _openChat(tester);
        expect(find.text('Public conversation'), findsOneWidget);
        expect(
          tester.widget<TextField>(find.byType(TextField)).enabled,
          isFalse,
        );
        expect(
          tester
              .widget<IconButton>(
                find.byWidgetPredicate(
                  (widget) =>
                      widget is IconButton && widget.tooltip == 'Send message',
                ),
              )
              .onPressed,
          isNull,
        );
        expect(
          tester
              .widget<IconButton>(
                find.byWidgetPredicate(
                  (widget) =>
                      widget is IconButton &&
                      widget.tooltip == 'Attach photo or video',
                ),
              )
              .onPressed,
          isNull,
        );
        expect(find.byTooltip('Delete message'), findsNothing);
        await _closeChat(tester);
      },
      () => MockClient(
        (_) async =>
            chatResponse([chatMessage('1', 'bob', 'Public conversation')]),
      ),
    );
  });

  testWidgets(
    'signed-out visitors can open community chat from the login screen',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await http.runWithClient(
        () async {
          await tester.pumpWidget(const YaoundeTripApp());
          await tester.pumpAndSettle();
          await tester.ensureVisible(find.text('Read community chat'));
          await tester.tap(find.text('Read community chat'));
          await tester.pumpAndSettle();
          expect(find.byType(ChatScreen), findsOneWidget);
          expect(find.text('Welcome, visitors'), findsOneWidget);
          expect(
            tester.widget<TextField>(find.byType(TextField)).enabled,
            isFalse,
          );
          await _closeChat(tester);
        },
        () => MockClient(
          (_) async =>
              chatResponse([chatMessage('public', 'bob', 'Welcome, visitors')]),
        ),
      );
    },
  );

  testWidgets('failed refresh retains messages and displays the error', (
    tester,
  ) async {
    var fail = false;
    await http.runWithClient(
      () async {
        await _openChat(tester);
        fail = true;
        await tester.tap(find.byTooltip('Refresh messages'));
        await tester.pumpAndSettle();
        expect(find.text('Previously loaded'), findsOneWidget);
        expect(find.text('service unavailable'), findsOneWidget);
        expect(find.text('No messages yet'), findsNothing);
        await _closeChat(tester);
      },
      () => MockClient(
        (_) async => fail
            ? chatResponse({'error': 'service unavailable'}, status: 503)
            : chatResponse([chatMessage('1', 'bob', 'Previously loaded')]),
      ),
    );
  });

  testWidgets(
    'failed send retains the draft and retry sends once successfully',
    (tester) async {
      var posts = 0;
      final client = MockClient((request) async {
        if (request.method == 'GET') return chatResponse([]);
        posts++;
        if (posts == 1) {
          return chatResponse({'error': 'Please retry'}, status: 503);
        }
        return chatResponse(
          chatMessage('new', 'alice', jsonDecode(request.body)['message']),
          status: 201,
        );
      });
      await http.runWithClient(() async {
        await _openChat(tester);
        await tester.enterText(find.byType(TextField), 'Keep this draft');
        await tester.tap(find.byTooltip('Send message'));
        await tester.pumpAndSettle();
        expect(
          tester.widget<TextField>(find.byType(TextField)).controller!.text,
          'Keep this draft',
        );
        expect(find.text('Please retry'), findsOneWidget);
        await tester.tap(find.text('Dismiss'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Send message'));
        await tester.pumpAndSettle();
        expect(
          tester.widget<TextField>(find.byType(TextField)).controller!.text,
          isEmpty,
        );
        expect(find.text('Keep this draft'), findsOneWidget);
        expect(posts, 2);
        await _closeChat(tester);
      }, () => client);
    },
  );

  testWidgets(
    'polling does not overlap or erase a confirmed send with a stale response',
    (tester) async {
      var gets = 0;
      final pending = Completer<http.Response>();
      final sent = chatMessage('sent', 'alice', 'Confirmed');
      final client = MockClient((request) async {
        if (request.method == 'POST') return chatResponse(sent, status: 201);
        gets++;
        if (gets == 2) return pending.future;
        return chatResponse(gets == 1 ? [] : [sent]);
      });
      await http.runWithClient(() async {
        await _openChat(tester);
        await tester.pump(const Duration(seconds: 3));
        await tester.pump();
        await tester.pump(const Duration(seconds: 6));
        expect(gets, 2);
        await tester.enterText(find.byType(TextField), 'Confirmed');
        await tester.tap(find.byTooltip('Send message'));
        await tester.pumpAndSettle();
        pending.complete(chatResponse([]));
        await tester.pumpAndSettle();
        expect(find.text('Confirmed'), findsOneWidget);
        await _closeChat(tester);
      }, () => client);
    },
  );

  testWidgets('emoji insertion and sticker failures preserve a typed draft', (
    tester,
  ) async {
    Map<String, dynamic>? payload;
    await http.runWithClient(
      () async {
        await _openChat(tester);
        await tester.enterText(find.byType(TextField), 'Hi ');
        await tester.tap(find.byTooltip('Emojis and stickers'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('\u{1f60a}'));
        expect(
          tester.widget<TextField>(find.byType(TextField)).controller!.text,
          'Hi \u{1f60a}',
        );
        await tester.tap(find.textContaining('Stickers'));
        await tester.pumpAndSettle();
        await tester.tap(find.textContaining('Yaound'));
        await tester.pumpAndSettle();
        expect(payload?['media_type'], 'sticker');
        expect(payload?['media_url'], contains('Yaound'));
        expect(find.text('Sticker failed'), findsOneWidget);
        expect(
          tester.widget<TextField>(find.byType(TextField)).controller!.text,
          'Hi \u{1f60a}',
        );
        await _closeChat(tester);
      },
      () => MockClient((request) async {
        if (request.method == 'GET') return chatResponse([]);
        payload = jsonDecode(request.body) as Map<String, dynamic>;
        return chatResponse({'error': 'Sticker failed'}, status: 503);
      }),
    );
  });

  testWidgets('uploaded photo survives a failed post and is reused on retry', (
    tester,
  ) async {
    var uploads = 0;
    var posts = 0;
    final picker = _PhotoPicker(
      XFile.fromData(
        Uint8List.fromList([1, 2, 3]),
        name: 'photo.png',
        path: 'photo.png',
      ),
    );
    await http.runWithClient(
      () async {
        await _openChat(tester, picker: picker);
        await tester.tap(find.byTooltip('Attach photo or video'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Choose Photo from Gallery'));
        await tester.pumpAndSettle();
        expect(find.textContaining('photo.png'), findsOneWidget);
        await tester.tap(find.byTooltip('Send message'));
        await tester.pumpAndSettle();
        expect(find.textContaining('photo.png'), findsOneWidget);
        await tester.tap(find.text('Dismiss'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Send message'));
        await tester.pumpAndSettle();
        expect(uploads, 1);
        expect(posts, 2);
        expect(
          tester.widget<ChatMedia>(find.byType(ChatMedia)).url,
          '/chat/media/photo.png',
        );
        expect(find.textContaining('attached:'), findsNothing);
        await _closeChat(tester);
      },
      () => MockClient((request) async {
        if (request.method == 'GET') return chatResponse([]);
        if (request.url.path.endsWith('/uploads')) {
          uploads++;
          return chatResponse({
            'media_url': '/chat/media/photo.png',
            'media_type': 'image',
          }, status: 201);
        }
        posts++;
        expect(jsonDecode(request.body)['media_url'], '/chat/media/photo.png');
        return posts == 1
            ? chatResponse({'error': 'Retry message'}, status: 503)
            : chatResponse(
                chatMessage(
                  'photo',
                  'alice',
                  '',
                  mediaUrl: '/chat/media/photo.png',
                  mediaType: 'image',
                ),
                status: 201,
              );
      }),
    );
  });

  testWidgets(
    'oversized picked files are rejected before reading or uploading',
    (tester) async {
      var requests = 0;
      await http.runWithClient(
        () async {
          await _openChat(
            tester,
            picker: _PhotoPicker(
              XFile.fromData(
                Uint8List(ApiService.maxChatMediaBytes + 1),
                name: 'too-large.png',
                path: 'too-large.png',
              ),
            ),
          );
          await tester.tap(find.byTooltip('Attach photo or video'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Choose Photo from Gallery'));
          await tester.pumpAndSettle();
          expect(
            find.text('Choose a non-empty photo or video of 20 MB or smaller.'),
            findsOneWidget,
          );
          expect(find.textContaining('attached:'), findsNothing);
          expect(requests, 1);
          await _closeChat(tester);
        },
        () => MockClient((_) async {
          requests++;
          return chatResponse([]);
        }),
      );
    },
  );

  testWidgets(
    'failed edit and delete do not pretend to change the shared feed',
    (tester) async {
      await http.runWithClient(
        () async {
          await _openChat(tester);
          await tester.tap(find.byTooltip('Edit message'));
          await tester.pump();
          await tester.enterText(find.byType(TextField), 'Changed draft');
          await tester.tap(find.byTooltip('Send message'));
          await tester.pumpAndSettle();
          expect(find.text('Original'), findsOneWidget);
          expect(
            tester.widget<TextField>(find.byType(TextField)).controller!.text,
            'Changed draft',
          );
          await tester.tap(find.byTooltip('Delete message'));
          await tester.pumpAndSettle();
          await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
          await tester.pumpAndSettle();
          expect(find.text('Original'), findsOneWidget);
          await _closeChat(tester);
        },
        () => MockClient(
          (request) async => request.method == 'GET'
              ? chatResponse([chatMessage('mine', 'alice', 'Original')])
              : chatResponse({'error': 'Action failed'}, status: 403),
        ),
      );
    },
  );
}
