package com.example.toonframe_studio
// IMPORTANT: change the line above to match YOUR app's actual package
// name - this file replaces the MainActivity.kt that `flutter create`
// generated, so copy the package line FROM your existing file, not
// from here.

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "toonframe_studio/mp4_encoder"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                if (call.method != "encodeMp4") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }

                val framesDir = call.argument<String>("framesDir")
                val frameCount = call.argument<Int>("frameCount")
                val fps = call.argument<Int>("fps")
                val width = call.argument<Int>("width")
                val height = call.argument<Int>("height")
                val outputPath = call.argument<String>("outputPath")

                if (framesDir == null || frameCount == null || fps == null ||
                    width == null || height == null || outputPath == null
                ) {
                    result.error("BAD_ARGS", "Missing one or more required arguments", null)
                    return@setMethodCallHandler
                }

                // Encoding is CPU-bound and takes real time for longer
                // animations - must run off the main/platform thread
                // or the app (and the MethodChannel call itself) will
                // hang.
                Thread {
                    try {
                        Mp4Encoder().encode(framesDir, frameCount, fps, width, height, outputPath)
                        runOnUiThread { result.success(outputPath) }
                    } catch (e: Exception) {
                        runOnUiThread { result.error("ENCODE_FAILED", e.message, null) }
                    }
                }.start()
            }
    }
}
