// PLACEHOLDER: ejecuta `flutterfire configure` para regenerar este fichero con
// los valores reales de tu proyecto de Firebase (Android + Web).
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show kIsWeb;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    return android;
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'REPLACE_ME',
    appId: 'REPLACE_ME',
    messagingSenderId: 'REPLACE_ME',
    projectId: 'REPLACE_ME',
    authDomain: 'REPLACE_ME.firebaseapp.com',
    databaseURL: 'https://REPLACE_ME-default-rtdb.europe-west1.firebasedatabase.app',
    storageBucket: 'REPLACE_ME.appspot.com',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'REPLACE_ME',
    appId: 'REPLACE_ME',
    messagingSenderId: 'REPLACE_ME',
    projectId: 'REPLACE_ME',
    databaseURL: 'https://REPLACE_ME-default-rtdb.europe-west1.firebasedatabase.app',
    storageBucket: 'REPLACE_ME.appspot.com',
  );
}
