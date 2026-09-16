import 'dart:convert';

import 'package:http/http.dart' as http;

String chatToken(String username, {int expiresAt = 4102444800}) {
  final claims = base64Url.encode(
    utf8.encode(jsonEncode({'sub': username, 'exp': expiresAt})),
  );
  return 'e30.$claims.test-signature';
}

Map<String, dynamic> chatMessage(
  String id,
  String username,
  String text, {
  String mediaUrl = '',
  String mediaType = '',
}) {
  return {
    'id': id,
    'user_id': username,
    'username': username,
    'message': text,
    'media_url': mediaUrl,
    'media_type': mediaType,
    'created_at': '2026-09-15T12:00:00Z',
    'is_edited': 0,
  };
}

http.Response chatResponse(Object body, {int status = 200}) {
  return http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
}
