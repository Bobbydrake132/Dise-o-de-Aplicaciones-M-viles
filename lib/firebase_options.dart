import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      default:
        return web;
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyB4cjCQbJZZBKlt2U1wcKC5dGHqxhzqUuY',
    appId: '1:581467070586:web:dc32171d79b9ca58261bc3',
    messagingSenderId: '581467070586',
    projectId: 'peliculas-buenas',
    authDomain: 'peliculas-buenas.firebaseapp.com',
    storageBucket: 'peliculas-buenas.firebasestorage.app',
  );
}