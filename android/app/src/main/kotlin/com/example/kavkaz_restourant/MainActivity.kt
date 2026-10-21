package com.example.kavkaz_restourant

import android.content.ContentValues
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import androidx.annotation.NonNull
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.IOException

class MainActivity : FlutterActivity() {
    private val channelName = "kavkaz_restourant/files"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result ->
            if (call.method != "saveToDownloads") {
                result.notImplemented()
                return@setMethodCallHandler
            }

            val fileName = call.argument<String>("fileName")
            val mimeType = call.argument<String>("mimeType") ?: "application/octet-stream"
            val sourceFilePath = call.argument<String>("sourceFilePath")
            val bytes = call.argument<ByteArray>("bytes")

            if (fileName.isNullOrBlank()) {
                result.error("INVALID_ARGS", "fileName is required", null)
                return@setMethodCallHandler
            }

            val hasPath = !sourceFilePath.isNullOrBlank()
            val hasBytes = bytes != null && bytes.isNotEmpty()
            if (!hasPath && !hasBytes) {
                result.error("INVALID_ARGS", "sourceFilePath or non-empty bytes is required", null)
                return@setMethodCallHandler
            }

            try {
                val resolver = applicationContext.contentResolver
                val values = ContentValues().apply {
                    put(MediaStore.Downloads.DISPLAY_NAME, fileName)
                    put(MediaStore.Downloads.MIME_TYPE, mimeType)
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                        put(MediaStore.Downloads.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS)
                        put(MediaStore.Downloads.IS_PENDING, 1)
                    }
                }

                val uri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
                    ?: throw IOException("Unable to create MediaStore record")

                resolver.openOutputStream(uri)?.use { outStream ->
                    if (hasPath) {
                        val src = File(sourceFilePath!!)
                        if (!src.isFile || !src.canRead()) {
                            throw IOException("sourceFilePath not readable: $sourceFilePath")
                        }
                        src.inputStream().use { ins -> ins.copyTo(outStream) }
                    } else {
                        outStream.write(bytes!!)
                    }
                    outStream.flush()
                } ?: throw IOException("Unable to open output stream")

                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    val publishValues = ContentValues().apply {
                        put(MediaStore.Downloads.IS_PENDING, 0)
                    }
                    resolver.update(uri, publishValues, null, null)
                }

                result.success(uri.toString())
            } catch (e: Exception) {
                result.error("SAVE_FAILED", e.message, null)
            }
        }
    }
}
