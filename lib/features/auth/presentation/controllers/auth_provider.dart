import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/auth_service.dart';

/// Estado global de autenticación
class AuthState {
  final bool isAuthenticated;
  final String? token;
  final String? username;
  final bool isLoading;
  final String? error;

  const AuthState({
    this.isAuthenticated = false,
    this.token,
    this.username,
    this.isLoading = false,
    this.error,
  });
}

class AuthController extends StateNotifier<AuthState> {
  final AuthService _authService;

  AuthController(this._authService) : super(const AuthState()) {
    _restoreSession();
  }

  /// Al arrancar la app intenta recuperar una sesión guardada
  Future<void> _restoreSession() async {
    final session = await _authService.getSession();
    if (session != null) {
      state = AuthState(
        isAuthenticated: true,
        token: session.token,
        username: session.username,
      );
    }
  }

  /// Inicia sesión con la API y guarda el token
  Future<bool> login(String username, String password) async {
    state = const AuthState(isLoading: true);
    try {
      final response = await _authService.login(username, password);
      await _authService.saveSession(response.accessToken, username);
      state = AuthState(
        isAuthenticated: true,
        token: response.accessToken,
        username: username,
      );
      return true;
    } catch (e) {
      state = AuthState(
        error: e.toString().replaceFirst('Exception: ', ''),
      );
      return false;
    }
  }

  /// Registra un usuario nuevo y, si tiene éxito, hace login automático
  Future<bool> register(String nombre, String password) async {
    state = const AuthState(isLoading: true);
    try {
      await _authService.register(nombre, password);
      return await login(nombre, password);
    } catch (e) {
      state = AuthState(
        error: e.toString().replaceFirst('Exception: ', ''),
      );
      return false;
    }
  }

  /// Cierra la sesión y borra el token guardado
  Future<void> logout() async {
    await _authService.clearSession();
    state = const AuthState();
  }
}

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

final authProvider = StateNotifierProvider<AuthController, AuthState>(
  (ref) => AuthController(ref.watch(authServiceProvider)),
);