package com.example.bsoftdist

import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
  override fun onCreate(savedInstanceState: Bundle?) {
    super.onCreate(savedInstanceState)
    // Remove this line if ML Kit is already initialized by another plugin:
    // MlKit.initialize(this)
  }
}
