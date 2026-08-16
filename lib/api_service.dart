import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();

  factory ApiService() {
    return _instance;
  }

  ApiService._internal();

  late String _baseUrl;
  late int _timeout;

  void initialize() {
    _baseUrl = dotenv.env['API_BASE_URL'] ?? 'http://10.0.2.2:5000/api';
    _timeout = int.tryParse(dotenv.env['API_TIMEOUT'] ?? '30') ?? 30;
  }

  Future<Map<String, dynamic>> testConnection() async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/notes'))
          .timeout(Duration(seconds: _timeout));

      if (response.statusCode == 200 || response.statusCode == 401) {
        return {
          'success': true,
          'message': 'Conexión a la API exitosa',
          'status': response.statusCode,
        };
      } else {
        return {
          'success': false,
          'message': 'Error: ${response.statusCode}',
          'status': response.statusCode,
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error de conexión: $e',
      };
    }
  }

  Future<Map<String, dynamic>> registerUser(
      String email, String password) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/auth/register'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'email': email,
              'password': password,
            }),
          )
          .timeout(Duration(seconds: _timeout));

      if (response.statusCode == 201 || response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {
          'success': false,
          'error': {
            'code': 'API_ERROR',
            'message': 'Error: ${response.statusCode}',
          }
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': {'code': 'CONNECTION_ERROR', 'message': e.toString()}
      };
    }
  }

  Future<Map<String, dynamic>> loginUser(String email, String password) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/auth/login'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'email': email,
              'password': password,
            }),
          )
          .timeout(Duration(seconds: _timeout));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {
          'success': false,
          'error': {
            'code': 'API_ERROR',
            'message': 'Error: ${response.statusCode}',
          }
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': {'code': 'CONNECTION_ERROR', 'message': e.toString()}
      };
    }
  }

  Future<List<dynamic>> getNotes(String accessToken) async {
    try {
      final response = await http
          .get(
            Uri.parse('$_baseUrl/notes'),
            headers: {
              'Authorization': 'Bearer $accessToken',
            },
          )
          .timeout(Duration(seconds: _timeout));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['data'] ?? [];
      } else {
        return [];
      }
    } catch (e) {
      return [];
    }
  }
}
