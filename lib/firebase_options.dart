// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAJqLKOuXiFbm1yBwEh0JPIRxfAxhNueOE',
    appId: '1:99747883016:web:5dc3675fcee3d5bfae09bd',
    messagingSenderId: '99747883016',
    projectId: 'hatchtech-7fba8',
    authDomain: 'hatchtech-7fba8.firebaseapp.com',
    storageBucket: 'hatchtech-7fba8.firebasestorage.app',
    measurementId: 'G-89EQZ3Y8XP',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCezJCrgRrgKDSW_l5vn-XAh309Rlq4040',
    appId: '1:99747883016:android:cd94dd69c0ae3cbaae09bd',
    messagingSenderId: '99747883016',
    projectId: 'hatchtech-7fba8',
    storageBucket: 'hatchtech-7fba8.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAZOBn7W6iWI2iWsN1oXkBJG1eUm0lR9Hw',
    appId: '1:99747883016:ios:943b9953ca1ae0caae09bd',
    messagingSenderId: '99747883016',
    projectId: 'hatchtech-7fba8',
    storageBucket: 'hatchtech-7fba8.firebasestorage.app',
    iosClientId: '99747883016-l61rmgh8qir1lelkgun6mt82ntmofb0d.apps.googleusercontent.com',
    iosBundleId: 'com.example.hatchtech',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyAZOBn7W6iWI2iWsN1oXkBJG1eUm0lR9Hw',
    appId: '1:99747883016:ios:943b9953ca1ae0caae09bd',
    messagingSenderId: '99747883016',
    projectId: 'hatchtech-7fba8',
    storageBucket: 'hatchtech-7fba8.firebasestorage.app',
    iosClientId: '99747883016-l61rmgh8qir1lelkgun6mt82ntmofb0d.apps.googleusercontent.com',
    iosBundleId: 'com.example.hatchtech',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyAJqLKOuXiFbm1yBwEh0JPIRxfAxhNueOE',
    appId: '1:99747883016:web:97b2decae29943aaae09bd',
    messagingSenderId: '99747883016',
    projectId: 'hatchtech-7fba8',
    authDomain: 'hatchtech-7fba8.firebaseapp.com',
    storageBucket: 'hatchtech-7fba8.firebasestorage.app',
    measurementId: 'G-P31QE7KXW7',
  );
}
