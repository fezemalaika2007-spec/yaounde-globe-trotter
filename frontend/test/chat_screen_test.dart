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

Future<void> _openChat(
  WidgetTester tester, {
  ImagePicker? picker,
  double textScale = 1,
  Brightness brightness = Brightness.light,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(colorSchemeSeed: Colors.teal, brightness: brightness),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: ChatScreen(imagePicker: picker),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _closeChat(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

ScrollPosition _conversationPosition(WidgetTester tester) {
  return tester
      .state<ScrollableState>(
        find
            .descendant(
              of: find.byKey(const ValueKey('chat-timeline')),
              matching: find.byType(Scrollable),
            )
            .first,
      )
      .position;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'jwt_token_prefs': chatToken('alice'),
    });
  });

  testWidgets(
    'saved conversation is still visible after reopening as another user',
    (tester) async {
      final saved = [
        chatMessage('old-alice', 'alice', 'Our earlier conversation'),
        chatMessage('old-bob', 'bob', 'Saved reply from Bob'),
      ];
      await http.runWithClient(() async {
        for (final username in ['alice', 'bob', null]) {
          SharedPreferences.setMockInitialValues({
            if (username != null) 'jwt_token_prefs': chatToken(username),
          });
          await _openChat(tester);
          expect(find.text('Our earlier conversation'), findsOneWidget);
          expect(find.text('Saved reply from Bob'), findsOneWidget);
          await _closeChat(tester);
        }
      }, () => MockClient((_) async => chatResponse(saved)));
    },
  );

  testWidgets(
    'scrolling upward loads all history and polling does not reset it',
    (tester) async {
      final saved = [
        for (var i = 0; i < 205; i++)
          chatMessage(
            'message-${i.toString().padLeft(3, '0')}',
            'bob',
            'Saved conversation $i',
          ),
      ];
      final cursors = <String>[];
      final cursorTimestamps = <String?>[];
      var recent = saved.sublist(105);
      await http.runWithClient(
        () async {
          await _openChat(tester);
          expect(find.text('Saved conversation 204'), findsOneWidget);
          expect(cursors, isEmpty);
          final firstTop = _conversationPosition(tester).minScrollExtent;
          _conversationPosition(tester).jumpTo(firstTop);
          await tester.pumpAndSettle();
          expect(cursors, ['message-105']);
          expect(_conversationPosition(tester).pixels, closeTo(firstTop, 1));
          recent = [
            ...recent.skip(1),
            chatMessage('message-205', 'alice', 'New while reading history'),
          ];
          await tester.pump(const Duration(seconds: 3));
          await tester.pumpAndSettle();
          _conversationPosition(
            tester,
          ).jumpTo(_conversationPosition(tester).minScrollExtent);
          await tester.pumpAndSettle();
          expect(cursors, ['message-105', 'message-005']);
          expect(cursorTimestamps, [
            saved[105]['created_at'],
            saved[5]['created_at'],
          ]);
          _conversationPosition(
            tester,
          ).jumpTo(_conversationPosition(tester).minScrollExtent);
          await tester.pumpAndSettle();
          expect(find.text('Saved conversation 0'), findsOneWidget);
          await tester.pump(const Duration(seconds: 3));
          await tester.pumpAndSettle();
          expect(find.text('Saved conversation 0'), findsOneWidget);
          expect(cursors, hasLength(2));
          final position = _conversationPosition(tester);
          position.jumpTo(position.maxScrollExtent);
          await tester.pumpAndSettle();
          expect(find.text('New while reading history'), findsOneWidget);
          await _closeChat(tester);
        },
        () => MockClient((request) async {
          final before = request.url.queryParameters['before_id'];
          if (before == null) return chatResponse(recent);
          cursors.add(before);
          cursorTimestamps.add(
            request.url.queryParameters['before_created_at'],
          );
          final boundary = saved.indexWhere(
            (message) => message['id'] == before,
          );
          return chatResponse(
            saved.sublist(boundary > 100 ? boundary - 100 : 0, boundary),
          );
        }),
      );
    },
  );

  testWidgets(
    'older-message failures retain the conversation and can be retried',
    (tester) async {
      final recent = [
        for (var i = 100; i < 200; i++)
          chatMessage('message-$i', 'bob', 'Saved message $i'),
      ];
      var online = false;
      var historyRequests = 0;
      await http.runWithClient(
        () async {
          await _openChat(tester);
          _conversationPosition(
            tester,
          ).jumpTo(_conversationPosition(tester).minScrollExtent);
          await tester.pumpAndSettle();
          expect(find.textContaining('internet connection'), findsOneWidget);
          await tester.pump(const Duration(seconds: 3));
          await tester.pumpAndSettle();
          expect(historyRequests, 1);
          expect(find.text('Saved message 100'), findsOneWidget);
          online = true;
          await tester.ensureVisible(find.text('Retry older messages'));
          await tester.tap(find.text('Retry older messages'));
          await tester.pumpAndSettle();
          _conversationPosition(
            tester,
          ).jumpTo(_conversationPosition(tester).minScrollExtent);
          await tester.pumpAndSettle();
          expect(historyRequests, 2);
          expect(find.text('An older saved message'), findsOneWidget);
          expect(find.text('Retry older messages'), findsNothing);
          await _closeChat(tester);
        },
        () => MockClient((request) async {
          if (!request.url.queryParameters.containsKey('before_id')) {
            return chatResponse(recent);
          }
          historyRequests++;
          if (!online) throw http.ClientException('Offline', request.url);
          return chatResponse([
            chatMessage('message-099', 'alice', 'An older saved message'),
          ]);
        }),
      );
    },
  );

  testWidgets('repeated upward scrolling cannot overlap history requests', (
    tester,
  ) async {
    final recent = [
      for (var i = 100; i < 200; i++)
        chatMessage('message-$i', 'bob', 'Recent $i'),
    ];
    final pending = Completer<http.Response>();
    var historyRequests = 0;
    await http.runWithClient(
      () async {
        await _openChat(tester);
        _conversationPosition(
          tester,
        ).jumpTo(_conversationPosition(tester).minScrollExtent);
        await tester.pump();
        expect(historyRequests, 1);
        _conversationPosition(
          tester,
        ).jumpTo(_conversationPosition(tester).minScrollExtent + 10);
        _conversationPosition(
          tester,
        ).jumpTo(_conversationPosition(tester).minScrollExtent);
        await tester.pump(const Duration(seconds: 3));
        expect(historyRequests, 1);
        pending.complete(
          chatResponse([
            chatMessage('message-099', 'alice', 'Older saved message'),
          ]),
        );
        await tester.pumpAndSettle();
        _conversationPosition(
          tester,
        ).jumpTo(_conversationPosition(tester).minScrollExtent);
        await tester.pumpAndSettle();
        expect(find.text('Older saved message'), findsOneWidget);
        expect(historyRequests, 1);
        await _closeChat(tester);
      },
      () => MockClient((request) async {
        if (request.url.queryParameters.containsKey('before_id')) {
          historyRequests++;
          return pending.future;
        }
        return chatResponse(recent);
      }),
    );
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

  for (final layout in [
    (width: 320.0, height: 640.0, keyboard: 260.0, scale: 1.4),
    (width: 390.0, height: 844.0, keyboard: 330.0, scale: 1.4),
    (width: 640.0, height: 360.0, keyboard: 120.0, scale: 1.0),
    (width: 1440.0, height: 900.0, keyboard: 0.0, scale: 1.4),
  ]) {
    testWidgets(
      'composer remains usable with keyboard and scaling at $layout',
      (tester) async {
        tester.view.physicalSize = Size(layout.width, layout.height);
        tester.view.devicePixelRatio = 1;
        tester.view.viewInsets = FakeViewPadding(bottom: layout.keyboard);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetViewInsets);
        await http.runWithClient(
          () async {
            await _openChat(
              tester,
              textScale: layout.scale,
              brightness: Brightness.dark,
            );
            await tester.enterText(
              find.byType(TextField),
              'A message with the keyboard open',
            );
            final sendButton = find.byTooltip('Send message');
            expect(
              tester.getRect(sendButton).bottom,
              lessThanOrEqualTo(layout.height - layout.keyboard),
            );
            await tester.tap(find.byTooltip('Emojis and stickers'));
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            expect(find.byType(NavigationBar), findsNothing);
            expect(find.byType(BottomNavigationBar), findsNothing);
            await _closeChat(tester);
          },
          () => MockClient(
            (_) async => chatResponse([
              chatMessage('1', 'bob', 'Welcome to the community!'),
            ]),
          ),
        );
      },
    );
  }

  testWidgets(
    'offline loading can recover without hiding the connection failure',
    (tester) async {
      var online = false;
      await http.runWithClient(
        () async {
          await _openChat(tester);
          expect(find.textContaining('internet connection'), findsWidgets);
          expect(find.text('No messages yet'), findsNothing);
          online = true;
          await tester.tap(find.byTooltip('Refresh messages'));
          await tester.pumpAndSettle();
          expect(find.text('Back online with Bob'), findsOneWidget);
          expect(find.textContaining('internet connection'), findsNothing);
          await _closeChat(tester);
        },
        () => MockClient((request) async {
          if (!online) {
            throw http.ClientException('Failed to fetch', request.url);
          }
          return chatResponse([
            chatMessage('bob', 'bob', 'Back online with Bob'),
          ]);
        }),
      );
    },
  );

  testWidgets(
    'connection failure keeps the draft until one explicit retry succeeds',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      tester.view.viewInsets = const FakeViewPadding(bottom: 260);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      var posts = 0;
      final feed = <Map<String, dynamic>>[];
      await http.runWithClient(
        () async {
          await _openChat(tester, textScale: 1.4);
          await tester.enterText(
            find.byType(TextField),
            'Message after reconnect',
          );
          await tester.tap(find.byTooltip('Send message'));
          await tester.pumpAndSettle();
          expect(find.textContaining('internet connection'), findsWidgets);
          expect(
            tester.widget<TextField>(find.byType(TextField)).controller!.text,
            'Message after reconnect',
          );
          await tester.pump(const Duration(seconds: 6));
          await tester.pumpAndSettle();
          expect(posts, 1);
          expect(tester.takeException(), isNull);
          await tester.tap(find.text('Dismiss'));
          await tester.pumpAndSettle();
          await tester.tap(find.byTooltip('Retry send'));
          await tester.pumpAndSettle();
          expect(posts, 2);
          expect(
            tester.widget<TextField>(find.byType(TextField)).controller!.text,
            isEmpty,
          );
          expect(find.text('Message after reconnect'), findsOneWidget);
          expect(find.byTooltip('Retry send'), findsNothing);
          await tester.pump(const Duration(seconds: 3));
          await tester.pumpAndSettle();
          expect(find.text('Message after reconnect'), findsOneWidget);
          await _closeChat(tester);
        },
        () => MockClient((request) async {
          if (request.method == 'GET') return chatResponse(feed);
          posts++;
          if (posts == 1) {
            throw http.ClientException('Failed to fetch', request.url);
          }
          final message = chatMessage(
            'sent',
            'alice',
            jsonDecode(request.body)['message'],
          );
          feed.add(message);
          return chatResponse(message, status: 201);
        }),
      );
    },
  );

  testWidgets(
    'timed-out sends retain the draft and are not silently replayed',
    (tester) async {
      var posts = 0;
      final pending = Completer<http.Response>();
      await http.runWithClient(
        () async {
          await _openChat(tester);
          await tester.enterText(
            find.byType(TextField),
            'Do not lose this draft',
          );
          await tester.tap(find.byTooltip('Send message'));
          await tester.pump();
          await tester.pump(const Duration(seconds: 26));
          await tester.pumpAndSettle();
          expect(find.textContaining('took too long'), findsWidgets);
          expect(
            tester.widget<TextField>(find.byType(TextField)).controller!.text,
            'Do not lose this draft',
          );
          expect(posts, 1);
          pending.complete(
            chatResponse(
              chatMessage('late', 'alice', 'Do not lose this draft'),
              status: 201,
            ),
          );
          await tester.pumpAndSettle();
          expect(
            tester.widget<TextField>(find.byType(TextField)).controller!.text,
            'Do not lose this draft',
          );
          await _closeChat(tester);
        },
        () => MockClient((request) async {
          if (request.method == 'GET') return chatResponse([]);
          posts++;
          return pending.future;
        }),
      );
    },
  );

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
