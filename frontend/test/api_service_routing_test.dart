import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yaounde_trip/config/api_config.dart';
import 'package:yaounde_trip/services/api_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test(
    'destinations and all chat operations use the configured gateway',
    () async {
      SharedPreferences.setMockInitialValues({'jwt_token_prefs': 'test-token'});
      final requests = <http.Request>[];
      final client = MockClient((request) async {
        requests.add(request);
        if (request.method == 'GET') {
          return http.Response('[{"id":"message-1"}]', 200);
        }
        return http.Response(
          '{"id":"message-1"}',
          request.method == 'POST' ? 201 : 200,
        );
      });

      await http.runWithClient(() async {
        final api = ApiService();
        expect(await api.getDestinations(), isNotEmpty);
        expect(await api.getChatMessages(limit: 20), isNotEmpty);
        expect(
          (await api.sendChatMessage('Hello', username: 'alice'))['id'],
          'message-1',
        );
        expect(
          await api.editChatMessage('message-1', 'Updated', username: 'alice'),
          isTrue,
        );
        expect(
          await api.deleteChatMessage('message-1', username: 'alice'),
          isTrue,
        );
      }, () => client);

      expect(
        requests.map((request) => '${request.method} ${request.url}').toList(),
        [
          'GET ${ApiConfig.baseUrl}/destinations',
          'GET ${ApiConfig.baseUrl}/chat/messages?limit=20',
          'POST ${ApiConfig.baseUrl}/chat/messages',
          'PUT ${ApiConfig.baseUrl}/chat/messages/message-1',
          'DELETE ${ApiConfig.baseUrl}/chat/messages/message-1',
        ],
      );
      for (final request in requests.skip(1)) {
        expect(request.headers['Authorization'], 'Bearer test-token');
      }
      expect(jsonDecode(requests[2].body)['message'], 'Hello');
      expect(jsonDecode(requests[3].body)['message'], 'Updated');
      expect(jsonDecode(requests[4].body)['username'], 'alice');
    },
  );

  for (final connectionFailure in [false, true]) {
    test('chat never falls back to local hosts on '
        '${connectionFailure ? 'connection failure' : 'HTTP error'}', () async {
      SharedPreferences.setMockInitialValues({'jwt_token_prefs': 'test-token'});
      final requests = <http.Request>[];
      final client = MockClient((request) async {
        requests.add(request);
        if (connectionFailure) {
          throw http.ClientException('Server unavailable', request.url);
        }
        return http.Response('{"error":"service unavailable"}', 503);
      });

      await http.runWithClient(() async {
        final api = ApiService();
        await expectLater(api.getChatMessages(), throwsA(isA<ApiException>()));
        await expectLater(
          api.sendChatMessage('Hello'),
          throwsA(isA<ApiException>()),
        );
        await expectLater(
          api.editChatMessage('message-1', 'Updated'),
          throwsA(isA<ApiException>()),
        );
        await expectLater(
          api.deleteChatMessage('message-1'),
          throwsA(isA<ApiException>()),
        );
      }, () => client);

      expect(
        requests.map((request) => '${request.method} ${request.url}').toList(),
        [
          'GET ${ApiConfig.baseUrl}/chat/messages?limit=100',
          'POST ${ApiConfig.baseUrl}/chat/messages',
          'PUT ${ApiConfig.baseUrl}/chat/messages/message-1',
          'DELETE ${ApiConfig.baseUrl}/chat/messages/message-1',
        ],
      );
    });
  }
}
