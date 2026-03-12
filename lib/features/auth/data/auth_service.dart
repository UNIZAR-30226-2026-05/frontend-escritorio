import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../../../core/constants/api_constants.dart';
import '../domain/auth_models.dart';

class AuthService {
  static const _storage = FlutterSecureStorage();
  static const _tokenKey = 'auth_token';
  static const _usernameKey = 'auth_username';

  /// POST /usuarios/login  — body: application/x-www-form-urlencoded
  Future<AuthResponse> login(String username, String password) async {
    final response = await http.post(
      Uri.parse('${ApiConstants.baseUrl}${ApiConstants.loginEndpoint}'),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {'username': username, 'password': password},
    );

    if (response.statusCode == 200) {
      return AuthResponse.fromJson(
          jsonDecode(response.body) as Map<String, dynamic>);
    } else if (response.statusCode == 401) {
      throw Exception('Credenciales incorrectas');
    } else {
      throw Exception('Error del servidor: ${response.statusCode}');
    }
  }

  /// POST /usuarios/registro/  — body: application/json
  Future<void> register(String nombre, String password) async {
    final request = RegisterRequest(nombre: nombre, password: password);
    final response = await http.post(
      Uri.parse('${ApiConstants.baseUrl}${ApiConstants.registerEndpoint}'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(request.toJson()),
    );

    if (response.statusCode == 201) {
      return;
    } else if (response.statusCode == 400) {
      throw Exception('El nombre de usuario ya existe');
    } else {
      throw Exception('Error del servidor: ${response.statusCode}');
    }
  }

  /// Guarda el token y el nombre en almacenamiento seguro
  Future<void> saveSession(String token, String username) async {
    await _storage.write(key: _tokenKey, value: token);
    await _storage.write(key: _usernameKey, value: username);
  }

  /// Recupera la sesión guardada, o null si no existe
  Future<UserSession?> getSession() async {
    final token = await _storage.read(key: _tokenKey);
    final username = await _storage.read(key: _usernameKey);
    if (token != null && username != null) {
      return UserSession(token: token, username: username);
    }
    return null;
  }

  /// Borra la sesión (logout)
  Future<void> clearSession() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _usernameKey);
  }
}