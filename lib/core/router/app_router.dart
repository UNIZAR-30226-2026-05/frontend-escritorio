import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/controllers/auth_provider.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/board/presentation/board_screen.dart';

// ChangeNotifier es el patron observer de Flutter.
// Notifica a GoRouter cuando cambia el estado de autenticación.
// El guión bajo denota que la clase es privada (Propiedad de Flutter).
class _RouterNotifier extends ChangeNotifier {
  // Referencia privada a Riverpod que nos permite leer, observar y escuchar
  // providers. Un provider es un objeto que mantiene un estado, lo distribuye 
  // a toda la app y notifica los cambios a los widgets que lo esuchan u observan.
  // Final significa que no puede reasignar la variable.
  final Ref _ref;

  // Constructor:
  _RouterNotifier(this._ref) {
    // Escucha el provider de autenticación que es del tipo AuthState, ignora
    // los parámateros que le llegan cuando cambia de estado, y avisa a 
    // GoRouter para redireccionar a la pantalla que toquen según el estado.
    _ref.listen<AuthState>(authProvider, (_, __) => notifyListeners());
  }

  // Devuelve un string que puede ser null, context es la info de la app actual
  // y state es el estado de GoRouter(qué ruta intentas ir, parámetros, etc.).
  String? redirect(BuildContext context, GoRouterState state) {
    // Asigna a la variable isAuthenticated el valor del estadooo de autenticacion
    // a través de la referencia que establecimos anteriormente.
    final isAuthenticated = _ref.read(authProvider).isAuthenticated;
    // Asigna a la variable isAuthRoute si te encuentras en alguna pantalla de
    // autenticacion.
    final isAuthRoute = state.matchedLocation == '/login' ||
        state.matchedLocation == '/register';

    // Si no estas autenticado y te encuentras en otra pantalla te devuelve
    // la ruta de la pantalla de login.
    if (!isAuthenticated && !isAuthRoute) return '/login';
    // Si estas auenticado y te encuentras enn alguna  apntalla de autenticacion
    // te devuelve la ruta de la pantalla principal del juego.
    if (isAuthenticated && isAuthRoute) return '/game';
    // Sino devuelve null.
    return null;
  }
}

// Define un provider que devuelve un GoRouter.
// Cada vez que la app necesite el router, Riverpod lo proporciona desde aquí.
final routerProvider = Provider<GoRouter>((ref) {
  // Instanciamos el notificador definido anteriormente.
  final notifier = _RouterNotifier(ref);

  // Router devuelto:
  return GoRouter(
    initialLocation: '/login',                      // Cuando se abre la app empieza en login.
    refreshListenable: notifier,                    // Escucha los cambios desde notifier.
                                                    // Cuando notifier.notifyListeners() se ejecuta (porque cambió authProvider), 
                                                    // GoRouter vuelve a ejecutar la función redirect.
    redirect: notifier.redirect,                    // Funcion que se ejecuta para decidir si redireccionar.
    routes: [                                       // Se definen las rutas en funcion del path devuelto por la función.
      GoRoute(
        path: '/login',
        builder: (_, __) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (_, __) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/game',
        builder: (_, __) => const BoardScreen(),
      ),
    ],
  );
});