package com.example.restaurantapp

import io.flutter.embedding.android.FlutterFragmentActivity

// Se usa FlutterFragmentActivity en lugar de FlutterActivity
// para que el plugin local_auth pueda mostrar el diálogo biométrico nativo.
class MainActivity : FlutterFragmentActivity()
