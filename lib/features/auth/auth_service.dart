import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

enum Rol { ciudadano, operador }

class Perfil {
  const Perfil({required this.uid, this.nombre = '', this.telefono = '', this.correo, this.rol = Rol.ciudadano});

  final String uid;
  final String nombre;
  final String telefono;
  final String? correo;
  final Rol rol;

  Map<String, dynamic> toMap() =>
      {'nombre': nombre, 'telefono': telefono, 'correo': correo, 'rol': rol.name};

  factory Perfil.fromMap(String uid, Map<String, dynamic> m) => Perfil(
        uid: uid,
        nombre: m['nombre'] as String? ?? '',
        telefono: m['telefono'] as String? ?? '',
        correo: m['correo'] as String?,
        rol: m['rol'] == 'operador' ? Rol.operador : Rol.ciudadano,
      );
}

/// Traduce los codigos de FirebaseAuth a mensajes que una persona nerviosa
/// entienda. Nunca muestra el codigo tecnico.
String mensajeAuth(Object e) {
  if (e is FirebaseAuthException) {
    switch (e.code) {
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
        return 'El correo o la contraseña no coinciden.';
      case 'invalid-email':
        return 'El correo no tiene un formato válido.';
      case 'email-already-in-use':
      case 'credential-already-in-use':
        return 'Ya existe una cuenta con ese correo. Ingrese con ella.';
      case 'weak-password':
        return 'La contraseña debe tener al menos 6 caracteres.';
      case 'network-request-failed':
        return 'No hay conexión. Revise su internet e intente de nuevo.';
      case 'too-many-requests':
        return 'Demasiados intentos. Espere un momento e intente de nuevo.';
      case 'operation-not-allowed':
        return 'Este tipo de acceso no está habilitado en Firebase.';
    }
  }
  return 'No se pudo completar. Intente de nuevo.';
}

/// Sesion y perfil. Todo el que abre la app tiene una sesion anonima de
/// Firebase para poder reportar sin crear cuenta; si despues se registra, la
/// cuenta se enlaza a la misma identidad y conserva sus reportes.
class AuthService extends ChangeNotifier {
  AuthService(this._auth, this._db);

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;

  User? _usuario;
  Perfil? _perfil;
  bool _listo = false;
  Object? _errorInicio;
  StreamSubscription<User?>? _sub;

  User? get usuario => _usuario;
  Perfil? get perfil => _perfil;
  bool get listo => _listo;
  Object? get errorInicio => _errorInicio;
  bool get esOperador => _perfil?.rol == Rol.operador;
  bool get registrado => _usuario != null && !_usuario!.isAnonymous;
  String? get uid => _usuario?.uid;

  Future<void> iniciar() async {
    _sub = _auth.authStateChanges().listen((u) async {
      _usuario = u;
      if (u == null) {
        _perfil = null;
        _listo = true;
        notifyListeners();
        try {
          await _auth.signInAnonymously();
        } catch (e) {
          _errorInicio = e;
          notifyListeners();
        }
        return;
      }
      await _cargarPerfil(u);
      _listo = true;
      notifyListeners();
    });
  }

  Future<void> _cargarPerfil(User u) async {
    if (u.isAnonymous) {
      _perfil = Perfil(uid: u.uid);
      return;
    }
    try {
      final d = await _db.collection('usuarios').doc(u.uid).get();
      _perfil = d.exists
          ? Perfil.fromMap(u.uid, d.data()!)
          : Perfil(uid: u.uid, nombre: u.displayName ?? '', correo: u.email);
    } catch (_) {
      // Sin red: se conserva el perfil anterior si es de la misma persona.
      _perfil = (_perfil?.uid == u.uid) ? _perfil : Perfil(uid: u.uid, correo: u.email);
    }
  }

  /// Reintenta la sesion anonima si fallo el primer intento (por ejemplo sin red).
  Future<void> reintentarSesion() async {
    _errorInicio = null;
    notifyListeners();
    try {
      await _auth.signInAnonymously();
    } catch (e) {
      _errorInicio = e;
      notifyListeners();
    }
  }

  Future<void> ingresar(String correo, String clave) async {
    await _auth.signInWithEmailAndPassword(email: correo.trim(), password: clave);
  }

  Future<void> registrar({
    required String nombre,
    required String telefono,
    required String correo,
    required String clave,
  }) async {
    final cred = EmailAuthProvider.credential(email: correo.trim(), password: clave);
    final actual = _auth.currentUser;
    UserCredential uc;
    if (actual != null && actual.isAnonymous) {
      uc = await actual.linkWithCredential(cred);
    } else {
      uc = await _auth.createUserWithEmailAndPassword(email: correo.trim(), password: clave);
    }
    final u = uc.user!;
    final p = Perfil(uid: u.uid, nombre: nombre.trim(), telefono: telefono, correo: u.email);
    await _db.collection('usuarios').doc(u.uid).set(p.toMap());
    _usuario = u;
    _perfil = p;
    notifyListeners();
  }

  Future<void> actualizarPerfil({required String nombre, required String telefono}) async {
    final u = _usuario;
    if (u == null || u.isAnonymous) return;
    await _db.collection('usuarios').doc(u.uid).update({'nombre': nombre.trim(), 'telefono': telefono});
    _perfil = Perfil(uid: u.uid, nombre: nombre.trim(), telefono: telefono, correo: _perfil?.correo, rol: _perfil?.rol ?? Rol.ciudadano);
    notifyListeners();
  }

  Future<void> salir() async {
    await _auth.signOut();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
