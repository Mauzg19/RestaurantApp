import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../session/session_manager.dart';

class HttpApiException implements Exception {
  final int statusCode;
  final String message;

  const HttpApiException(this.statusCode, this.message);

  @override
  String toString() => 'HttpApiException ($statusCode): $message';
}

class UnauthorizedApiException extends HttpApiException {
  const UnauthorizedApiException([String message = 'Sesión expirada o no autorizada.'])
      : super(401, message);
}

class NetworkUnavailableException implements Exception {
  final String message;
  const NetworkUnavailableException([this.message = 'No se pudo conectar al servidor de backend.']);

  @override
  String toString() => message;
}

/// Cliente HTTP centralizado con soporte para JWT e intercepción de cabeceras.
class HttpClientService {
  final Duration timeoutDuration;
  final SessionManager? sessionManager;

  HttpClientService({
    this.sessionManager,
    this.timeoutDuration = const Duration(seconds: 10),
  });

  Map<String, String> _buildHeaders({bool requiresAuth = true, Map<String, String>? extraHeaders}) {
    final headers = <String, String>{
      'Content-Type': 'application/json; charset=UTF-8',
      'Accept': 'application/json',
    };

    if (requiresAuth && sessionManager != null) {
      final token = sessionManager!.getToken();
      if (token != null && token.isNotEmpty) {
        // El filtro Spring Boot espera "Bearer <token>"
        headers['Authorization'] = token.startsWith('Bearer ') ? token : 'Bearer $token';
      }
    }

    if (extraHeaders != null) {
      headers.addAll(extraHeaders);
    }

    return headers;
  }

  Future<dynamic> get(String url, {bool requiresAuth = true}) async {
    try {
      final response = await http
          .get(Uri.parse(url), headers: _buildHeaders(requiresAuth: requiresAuth))
          .timeout(timeoutDuration);
      return _processResponse(response);
    } on SocketException {
      throw const NetworkUnavailableException('Servidor inaccesible. Verifique que el backend Spring Boot esté activo.');
    } on TimeoutException {
      throw const NetworkUnavailableException('Tiempo de espera agotado al conectar con el servidor.');
    }
  }

  Future<dynamic> post(String url, {required Map<String, dynamic> body, bool requiresAuth = true}) async {
    try {
      final response = await http
          .post(
            Uri.parse(url),
            headers: _buildHeaders(requiresAuth: requiresAuth),
            body: jsonEncode(body),
          )
          .timeout(timeoutDuration);
      return _processResponse(response);
    } on SocketException {
      throw const NetworkUnavailableException('Servidor inaccesible. Verifique que el backend Spring Boot esté activo.');
    } on TimeoutException {
      throw const NetworkUnavailableException('Tiempo de espera agotado al conectar con el servidor.');
    }
  }

  Future<dynamic> postMultipartBytes(
    String url, {
    required Uint8List bytes,
    required String fileName,
    bool requiresAuth = true,
  }) async {
    try {
      final request = http.MultipartRequest('POST', Uri.parse(url));
      final headers = _buildHeaders(requiresAuth: requiresAuth)
        ..remove('Content-Type');
      request.headers.addAll(headers);
      request.files.add(
        http.MultipartFile.fromBytes('image', bytes, filename: fileName),
      );
      final streamedResponse = await request.send().timeout(timeoutDuration);
      final response = await http.Response.fromStream(streamedResponse);
      return _processResponse(response);
    } on SocketException {
      throw const NetworkUnavailableException(
        'Servidor inaccesible. Verifique que el backend Spring Boot esté activo.',
      );
    } on TimeoutException {
      throw const NetworkUnavailableException(
        'Tiempo de espera agotado al subir la imagen.',
      );
    }
  }

  Future<dynamic> patch(String url, {required Map<String, dynamic> body, bool requiresAuth = true}) async {
    try {
      final response = await http
          .patch(
            Uri.parse(url),
            headers: _buildHeaders(requiresAuth: requiresAuth),
            body: jsonEncode(body),
          )
          .timeout(timeoutDuration);
      return _processResponse(response);
    } on SocketException {
      throw const NetworkUnavailableException('Servidor inaccesible. Verifique que el backend Spring Boot esté activo.');
    } on TimeoutException {
      throw const NetworkUnavailableException('Tiempo de espera agotado al conectar con el servidor.');
    }
  }

  Future<dynamic> put(String url, {required Map<String, dynamic> body, bool requiresAuth = true}) async {
    try {
      final response = await http
          .put(
            Uri.parse(url),
            headers: _buildHeaders(requiresAuth: requiresAuth),
            body: jsonEncode(body),
          )
          .timeout(timeoutDuration);
      return _processResponse(response);
    } on SocketException {
      throw const NetworkUnavailableException('Servidor inaccesible. Verifique que el backend Spring Boot esté activo.');
    } on TimeoutException {
      throw const NetworkUnavailableException('Tiempo de espera agotado al conectar con el servidor.');
    }
  }

  Future<dynamic> delete(String url, {bool requiresAuth = true}) async {
    try {
      final response = await http
          .delete(Uri.parse(url), headers: _buildHeaders(requiresAuth: requiresAuth))
          .timeout(timeoutDuration);
      return _processResponse(response);
    } on SocketException {
      throw const NetworkUnavailableException('Servidor inaccesible. Verifique que el backend Spring Boot esté activo.');
    } on TimeoutException {
      throw const NetworkUnavailableException('Tiempo de espera agotado al conectar con el servidor.');
    }
  }

  dynamic _processResponse(http.Response response) {
    if (response.statusCode == 204) return null; // No Content

    dynamic decodedBody;
    if (response.body.isNotEmpty) {
      try {
        decodedBody = jsonDecode(utf8.decode(response.bodyBytes));
      } catch (_) {
        decodedBody = response.body;
      }
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decodedBody;
    }

    if (response.statusCode == 401) {
      throw const UnauthorizedApiException();
    }

    final message = (decodedBody is Map && decodedBody['message'] != null)
        ? decodedBody['message'].toString()
        : 'Error HTTP ${response.statusCode} en el servidor.';

    throw HttpApiException(response.statusCode, message);
  }
}
