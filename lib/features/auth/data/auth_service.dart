import 'dart:convert'; // Proporciona el jsonDecode() y el jsonEncode() para la API.

import 'package:flutter_secure_storage/flutter_secure_storage.dart';   // Libreria que guarda los datos encriptados a nivel de SO.
import 'package:http/http.dart' as http;  // Libreria para realizar las operaciones http.

// Rutas API y mopdelos que se usan para la autenticación.
import '../../../core/constants/api_constants.dart';
import '../domain/auth_models.dart';

// Clase que agrupa todas las operaciones de autenticación.
// No necesitará crear un objeto AuthService se usan directamente los métodos.
class AuthService {
  // Definimos varibales estaticas compartidas por toda la clase (no cmabian).
  // Instancia de FlytterSecureStorage que maneja el almacenamiento seguro encriptado.
  static const _storage = FlutterSecureStorage(); 
  // Claves para guardar/recuperar datos del almacenamiento seguro.
  static const _tokenKey = 'auth_token';
  static const _usernameKey = 'auth_username';

  // Método login de la clase de autenticación.
  // Devuelve un Future (promesa) que contendrá un AuthResponse (es una función asíncorna).
  Future<AuthResponse> login(String username, String password) async {
    // Realiza un post y espera repsuesta.
    final response = await http.post(
      Uri.parse('${ApiConstants.baseUrl}${ApiConstants.loginEndpoint}'),    // Construye la URL con las constantes.
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},       // Especifica el formato del contenido.
      body: {'username': username, 'password': password},                   // Cupero de la petición (http convierte 
                                                                            // lo que hay al formato especificado anteriormente).
    );

    // TRATAMIENTO DE RESPUESTAS:
    // Estatus 200 = OK.
    if (response.statusCode == 200) {
      return AuthResponse.fromJson(                                         // Convierte el mapa a un objeto AuthResponse.
          jsonDecode(response.body) as Map<String, dynamic>);               // Decodifica el JSON y especifica que es un mapa
                                                                            // de claves string con valores cualquiera.
    // Estatus 401 = Unauthorized.
    } else if (response.statusCode == 401) {
      throw Exception('Credenciales incorrectas');
    // Cualquier otro codigo de error.
    } else {
      throw Exception('Error del servidor: ${response.statusCode}');
    }
  }

  // Método register de la clase de autenticación.
  // Devuelve un Future (promesa) que contendrá un void (es una función asíncorna).
  Future<void> register(String nombre, String password) async {
    // Crea un objeto RegisterRequest con los datos.
    final request = RegisterRequest(nombre: nombre, password: password);
    // Realiza un post y esper respuesta.
    final response = await http.post(
      Uri.parse('${ApiConstants.baseUrl}${ApiConstants.registerEndpoint}'), // Construye la URL con las constantes.
      headers: {'Content-Type': 'application/json'},                        // Especifica el formato del contenido.
      body: jsonEncode(request.toJson()),                                   // Codifica el texto a JSON.
    );                                                                      // Request.toJson() devuelve un mapa.

    // TRATAMIENTO DE RESPUESTAS:
    // Estatus 201 = Created.
    if (response.statusCode == 201) {
      return;
    // Estatus 400 = Bad Request.
    } else if (response.statusCode == 400) {
      throw Exception('El nombre de usuario ya existe');
    // Cualquier otro codigo de error.
    } else {
      throw Exception('Error del servidor: ${response.statusCode}');
    }
  }

  // Método saveSession de la clase de autenticación.
  // Devuelve un Future (promesa) que contendrá un void (es una función asíncorna).
  // Guarda el token y el nombre en almacenamiento seguro
  Future<void> saveSession(String token, String username) async {
    // Escribe en el almacenamiento el token y el username.
    await _storage.write(key: _tokenKey, value: token);
    await _storage.write(key: _usernameKey, value: username);
  }

  // Método getSession de la clase de autenticación.
  // Devuelve un Future (promesa) que contendrá un UserSession o null (es una función asíncorna).
  // Recupera la sesión guardada, o null si no existe.
  Future<UserSession?> getSession() async {
    // Lee el token y username del almacenamiento encriptado.
    final token = await _storage.read(key: _tokenKey);
    final username = await _storage.read(key: _usernameKey);
    // Si ambos existen devuelve un objeto UserSession con ellos.
    if (token != null && username != null) {
      return UserSession(token: token, username: username);
    }
    // Si falta alguno devuelve null (no hay sesión guardada).
    return null;
  }

  // Método clearSession de la clase de autenticación.
  // Devuelve un Future (promesa) que contendrá un void (es una función asíncorna).
  // Borra la sesión (logout).
  Future<void> clearSession() async {
    // Elimina el token y username del almacenamiento.
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _usernameKey);
  }
}