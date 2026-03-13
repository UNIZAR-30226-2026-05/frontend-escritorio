import 'package:flutter_riverpod/flutter_riverpod.dart'; // Proporciona los Provider.

// Servicios de autenticacion (llamadas a la API.)
import '../../data/auth_service.dart';

// Define la clase que representa el estado de autenticación.
class AuthState {
  // Variable que representa si la sesión está activa.
  final bool isAuthenticated;         // True = Si.
  // JWT devuelto al hacer login o null.
  final String? token;
  // Nombre del usuario logeado o null.                
  final String? username;
  // Variable que representa el estado de respuesta de la API.
  final bool isLoading;               // True = esperando respuesta.
  // Mensjae de error a mostrar si falla el login o registro.
  final String? error;                
  // Constructor con valores por defecto.
  const AuthState({
    this.isAuthenticated = false,
    this.token,
    this.username,
    this.isLoading = false,
    this.error,
  });
}

// El controlador que gestiona el estado. 
// tiene un state de tipo AuthState y cada vez que se asigna un nuevo valor a state, 
// Riverpod notifica a todos los widgets que lo escuchan.
class AuthController extends StateNotifier<AuthState> {
  // Referencia al servicio de autenticación.
  final AuthService _authService;

  // Constructor, inicializa el estado con un AuthState vacío (no autenticado).
  AuthController(this._authService) : super(const AuthState()) {
    // intenta recuperar la sesión guardada del arranque anterior.
    _restoreSession();
  }

  // Promete devolver valor de tipo void (función asíncrona).
  // Método privado para que al arrancar la app intente recuperar una sesión guardada.
  Future<void> _restoreSession() async {
    // Llama a la función del servicio para comprobar la sesión.
    final session = await _authService.getSession();
    // Si existe, cambia el estado de la autenticación.
    if (session != null) {
      state = AuthState(
        isAuthenticated: true,
        token: session.token,
        username: session.username,
      );
    }
  }

  // Promete devolver valor de tipo bool (función asíncrona).
  // Método público para iniciar sesión con la API y guarda el token.
  Future<bool> login(String username, String password) async {
    // Activa el flag de espera de la API.
    state = const AuthState(isLoading: true);
    try {
      // Llama a la función del servicio para hacer login con la API.
      final response = await _authService.login(username, password);
      // Guarda el JWT y el username en el Windows Credential Manager para persistir la sesión.
      await _authService.saveSession(response.accessToken, username);
      // Actualiza el estado con la sesión activa.
      state = AuthState(
        isAuthenticated: true,
        token: response.accessToken,
        username: username,
      );
      return true;
    } catch (e) {
      // Si el login falló guarda el error en el estado.
      state = AuthState(
        error: e.toString().replaceFirst('Exception: ', ''),
      );
      return false;
    }
  }

  // Promete devolver valor de tipo bool (función asíncrona).
  // Método público para registrar un usuario nuevo.
  Future<bool> register(String nombre, String password) async {
    // Activa el flag de espera de la API.
    state = const AuthState(isLoading: true);
    try {
      // Llama a la función del servicio para registrarse con la API.
      await _authService.register(nombre, password);
      // Si el registro fue bien hace login automáticamente.
      return await login(nombre, password);
    } catch (e) {
      // Si el registro falló guarda el error en el estado.
      state = AuthState(
        error: e.toString().replaceFirst('Exception: ', ''),
      );
      return false;
    }
  }

  // Promete devolver valor de tipo void (función asíncrona).
  // Método público para cerrar sesión.
  Future<void> logout() async {
    // Borra el token y username del Windows Credential Manager.
    await _authService.clearSession();
    // Resetea el estado a vacío. 
    state = const AuthState();
  }
}

// Crea y registra una única instancia de AuthService en el árbol de Riverpod.
final authServiceProvider = Provider<AuthService>((ref) => AuthService());

// Crea y registra el AuthController. El ref.watch(authServiceProvider) le inyecta el AuthService del provider anterior.
final authProvider = StateNotifierProvider<AuthController, AuthState>(
  (ref) => AuthController(ref.watch(authServiceProvider)),
);