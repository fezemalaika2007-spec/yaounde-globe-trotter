import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yaounde_trip/config/api_config.dart';
import 'package:yaounde_trip/services/api_service.dart';

import 'chat_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'jwt_token_prefs': chatToken('alice'),
    });
  });

  test(
    'chat identity survives reload and expired sessions are read-only',
    () async {
      expect(await ApiService().getChatUsername(), 'alice');
      await ApiService().saveToken(chatToken('bob', expiresAt: 1));
      expect(await ApiService().getChatUsername(), isNull);
      await ApiService().saveToken('not-a-token');
      expect(await ApiService().getChatUsername(), isNull);
      await ApiService().deleteToken();
      expect(await ApiService().getChatUsername(), isNull);
    },
  );

  test('guests may read but cannot send, edit, delete, or upload', () async {
    SharedPreferences.setMockInitialValues({});
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      return chatResponse([chatMessage('1', 'bob', 'Welcome')]);
    });
    await http.runWithClient(() async {
      final api = ApiService();
      expect((await api.getChatMessages()).single['username'], 'bob');
      final unauthenticated = throwsA(
        isA<ApiException>().having((e) => e.statusCode, 'status', 401),
      );
      await expectLater(api.sendChatMessage('Hi'), unauthenticated);
      await expectLater(api.editChatMessage('1', 'No'), unauthenticated);
      await expectLater(api.deleteChatMessage('1'), unauthenticated);
      await expectLater(
        api.uploadChatMedia(Uint8List.fromList([1]), filename: 'test.png'),
        unauthenticated,
      );
    }, () => client);
    expect(requests, hasLength(1));
  });

  test(
    'multipart media is uploaded once then referenced by a shared URL',
    () async {
      final requests = <http.Request>[];
      final bytes = Uint8List.fromList([0, 1, 2, 128, 255]);
      final client = MockClient((request) async {
        requests.add(request);
        if (request.url.path.endsWith('/uploads')) {
          expect(
            request.headers['content-type'],
            startsWith('multipart/form-data;'),
          );
          expect(latin1.decode(request.bodyBytes), contains('name="file"'));
          expect(
            latin1.decode(request.bodyBytes),
            contains('filename="photo.png"'),
          );
          expect(
            latin1.decode(request.bodyBytes),
            contains(latin1.decode(bytes)),
          );
          return chatResponse({
            'media_url': '/chat/media/photo.png',
            'media_type': 'image',
          }, status: 201);
        }
        final payload = jsonDecode(request.body) as Map<String, dynamic>;
        expect(payload['media_url'], '/chat/media/photo.png');
        expect(payload['media_type'], 'image');
        expect(request.body.length, lessThan(500));
        return chatResponse(chatMessage('1', 'alice', 'Photo'), status: 201);
      });
      await http.runWithClient(() async {
        final api = ApiService();
        final attachment = await api.uploadChatMedia(
          bytes,
          filename: 'photo.png',
        );
        await api.sendChatMessage(
          'Photo',
          mediaUrl: attachment.url,
          mediaType: attachment.type,
        );
        expect(
          ApiService.chatMediaUri(attachment.url).toString(),
          '${ApiConfig.baseUrl}/chat/media/photo.png',
        );
      }, () => client);
      expect(requests.map((request) => request.url.toString()), [
        '${ApiConfig.baseUrl}/chat/uploads',
        '${ApiConfig.baseUrl}/chat/messages',
      ]);
      for (final request in requests) {
        expect(request.headers['authorization'], startsWith('Bearer '));
      }
    },
  );

  test(
    '20 MB boundary is accepted and larger uploads are rejected locally',
    () async {
      var uploads = 0;
      final client = MockClient((request) async {
        uploads++;
        return chatResponse({
          'media_url': '/chat/media/video.mp4',
          'media_type': 'video',
        }, status: 201);
      });
      await http.runWithClient(() async {
        final api = ApiService();
        final result = await api.uploadChatMedia(
          Uint8List(ApiService.maxChatMediaBytes),
          filename: 'video.mp4',
        );
        expect(result.type, 'video');
        for (final bytes in [
          Uint8List(0),
          Uint8List(ApiService.maxChatMediaBytes + 1),
        ]) {
          await expectLater(
            api.uploadChatMedia(bytes, filename: 'video.mp4'),
            throwsA(
              isA<ApiException>().having((e) => e.statusCode, 'status', 413),
            ),
          );
        }
      }, () => client);
      expect(uploads, 1);
    },
  );

  test('emoji and sticker Unicode round trips without mojibake', () async {
    const text = 'Hello \u{1f60a} \u{1f1e8}\u{1f1f2}';
    final client = MockClient((request) async {
      if (request.method == 'GET') {
        return http.Response.bytes(
          utf8.encode(jsonEncode([chatMessage('1', 'bob', text)])),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body['media_url'], text);
      expect(body['media_type'], 'sticker');
      return chatResponse(
        chatMessage('2', 'alice', '', mediaUrl: text, mediaType: 'sticker'),
        status: 201,
      );
    });
    await http.runWithClient(() async {
      expect((await ApiService().getChatMessages()).single['message'], text);
      final sent = await ApiService().sendChatMessage(
        '',
        mediaUrl: text,
        mediaType: 'sticker',
      );
      expect(sent['media_url'], text);
    }, () => client);
  });

  test('invalid list, HTML errors and upload limits are surfaced', () async {
    for (final response in [
      chatResponse({'not': 'a list'}),
      chatResponse([true]),
      http.Response('<html>Bad gateway</html>', 502),
    ]) {
      await http.runWithClient(() async {
        await expectLater(
          ApiService().getChatMessages(),
          throwsA(isA<ApiException>()),
        );
      }, () => MockClient((_) async => response));
    }
    await http.runWithClient(
      () async {
        await expectLater(
          ApiService().uploadChatMedia(Uint8List(1), filename: 'video.mp4'),
          throwsA(
            isA<ApiException>()
                .having((e) => e.statusCode, 'status', 413)
                .having((e) => e.message, 'message', contains('20 MB')),
          ),
        );
      },
      () =>
          MockClient((_) async => http.Response('<html>Too large</html>', 413)),
    );
  });

  test(
    'network failures do not retry writes or switch away from HTTPS',
    () async {
      final requests = <http.Request>[];
      await http.runWithClient(
        () async {
          final unavailable = throwsA(
            isA<ApiException>()
                .having((e) => e.statusCode, 'status', 0)
                .having(
                  (e) => e.message,
                  'message',
                  contains('internet connection'),
                ),
          );
          await expectLater(
            ApiService().sendChatMessage('Keep my draft'),
            unavailable,
          );
          await expectLater(
            ApiService().uploadChatMedia(Uint8List(1), filename: 'photo.png'),
            unavailable,
          );
        },
        () => MockClient((request) async {
          requests.add(request);
          throw http.ClientException('Failed to fetch', request.url);
        }),
      );
      expect(requests, hasLength(2));
      expect(requests.map((request) => request.url.toString()), [
        '${ApiConfig.baseUrl}/chat/messages',
        '${ApiConfig.baseUrl}/chat/uploads',
      ]);
      expect(
        requests.every((request) => request.url.scheme == 'https'),
        isTrue,
      );
    },
  );

  test(
    'non-network failures are not disguised as an unreachable server',
    () async {
      await http.runWithClient(
        () async {
          await expectLater(
            ApiService().getChatMessages(),
            throwsA(isA<StateError>()),
          );
        },
        () => MockClient((_) async => throw StateError('Invalid client state')),
      );
    },
  );

  test(
    'history cursors are encoded and incomplete cursors are rejected',
    () async {
      var requests = 0;
      const timestamp = '2026-09-01T12:00:00+01:00';
      const id = 'message + / boundary';
      await http.runWithClient(
        () async {
          final history = await ApiService().getChatMessages(
            limit: 50,
            beforeCreatedAt: timestamp,
            beforeId: id,
          );
          expect(history.single['message'], 'Saved conversation');
          await expectLater(
            ApiService().getChatMessages(beforeCreatedAt: timestamp),
            throwsA(
              isA<ApiException>().having((e) => e.statusCode, 'status', 400),
            ),
          );
          await expectLater(
            ApiService().getChatMessages(beforeId: id),
            throwsA(
              isA<ApiException>().having((e) => e.statusCode, 'status', 400),
            ),
          );
        },
        () => MockClient((request) async {
          requests++;
          expect(request.url.queryParameters, {
            'limit': '50',
            'before_created_at': timestamp,
            'before_id': id,
          });
          return chatResponse([
            chatMessage('old', 'bob', 'Saved conversation'),
          ]);
        }),
      );
      expect(requests, 1);
    },
  );
}
