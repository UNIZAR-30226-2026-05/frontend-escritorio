
// Clase que estructura los datos que envías al servidor cuando te registras
// (datos que se envían al endpoint de registro).
class RegisterRequest {
  // Datos necesarios.
  final String nombre;
  final String password;
  // Constructor de la clase (ambos campos requeridos obligatoriamente).
  const RegisterRequest({required this.nombre, required this.password});
  // Convierte el objeto a un mapa (diccionario) que se puede convertir a JSON.
  Map<String, dynamic> toJson() => {
        'nombre': nombre,
        'password': password,
      };
}

// Clase que estructura los datos que recibes del servidor cuando haces login
// (respuesta del endpoint de login).
class AuthResponse {
  // Datos que devuelve el servidor.
  final String accessToken;
  final String tokenType;
  // Constructor de la clase (ambos campos requeridos obligatoriamente).
  const AuthResponse({required this.accessToken, required this.tokenType});
  // Constructor alternativo que crea el objeto desde JSON.
  // Factory es una palabra clave que indica constructor especial.
  // Recibe un mapa y crea el objeto con los datos del mapa.
  factory AuthResponse.fromJson(Map<String, dynamic> json) => AuthResponse( 
        accessToken: json['access_token'] as String,
        tokenType: json['token_type'] as String,
      );
}

// Clase que estructuras los datos de la sesión guardada en el dispositivo
// (token + nombre de usuario).
class UserSession {
  final String token;
  final String username;
  // Constructor de la clase (ambos campos requeridos obligatoriamente).
  const UserSession({required this.token, required this.username});
}
