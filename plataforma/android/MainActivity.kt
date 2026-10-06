package com.vixago.vixago_player

import android.Manifest
import android.content.ActivityNotFoundException
import android.content.ContentUris
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.media.MediaMetadataRetriever
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import android.provider.Settings
import android.util.Size
import android.view.WindowManager
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File
import java.util.concurrent.Executors

/**
 * Puente entre Flutter y la biblioteca de medios de Android (MediaStore).
 * Hereda de AudioServiceActivity para que la música siga sonando en segundo plano.
 * El código Dart que lo usa está en lib/services/media_store.dart.
 */
class MainActivity : AudioServiceActivity() {
    private val main = Handler(Looper.getMainLooper())
    private val workers = Executors.newFixedThreadPool(3)
    private var pendingPermission: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "vixago/media")
            .setMethodCallHandler(::onMethodCall)
    }

    private fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "hasPermission" -> result.success(hasPermission())
            "requestPermission" -> requestPermission(result)
            "openAppSettings" -> result.success(
                tryStart(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$packageName"))),
            )
            "audio" -> background(result) { queryAudio() }
            "videos" -> background(result) { queryVideos() }
            "thumbnail" -> background(result) {
                thumbnail(
                    call.argument<String>("uri")!!,
                    call.argument<Int>("size") ?: 300,
                    call.argument<Boolean>("video") ?: false,
                )
            }
            "keepScreenOn" -> {
                // Mientras se ve un video la pantalla no se apaga.
                if (call.argument<Boolean>("on") == true) {
                    window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                } else {
                    window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                }
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun background(result: MethodChannel.Result, work: () -> Any?) {
        workers.execute {
            try {
                val value = work()
                main.post { result.success(value) }
            } catch (e: Throwable) {
                main.post { result.error("failed", e.message ?: e.toString(), null) }
            }
        }
    }

    // ---------- Permisos ----------

    private fun permissions(): Array<String> =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            arrayOf(Manifest.permission.READ_MEDIA_AUDIO, Manifest.permission.READ_MEDIA_VIDEO)
        } else {
            arrayOf(Manifest.permission.READ_EXTERNAL_STORAGE)
        }

    private fun hasPermission(): Boolean =
        permissions().all { checkSelfPermission(it) == PackageManager.PERMISSION_GRANTED }

    private fun requestPermission(result: MethodChannel.Result) {
        if (hasPermission()) {
            result.success(true)
            return
        }
        pendingPermission?.success(false)
        pendingPermission = result
        requestPermissions(permissions(), PERMISSION_REQUEST)
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == PERMISSION_REQUEST) {
            pendingPermission?.success(hasPermission())
            pendingPermission = null
        }
    }

    // ---------- Consultas a MediaStore ----------

    /** Carpeta donde está el archivo: la ruta completa (DATA) o, si no hay, la relativa. */
    private fun folderOf(data: String?, relative: String?): String {
        if (!data.isNullOrEmpty()) {
            val parent = File(data).parent
            if (!parent.isNullOrEmpty()) return parent
        }
        return relative?.trimEnd('/') ?: ""
    }

    @Suppress("DEPRECATION")
    private fun queryAudio(): List<Map<String, Any?>> {
        val collection = MediaStore.Audio.Media.EXTERNAL_CONTENT_URI
        val columns = mutableListOf(
            MediaStore.Audio.Media._ID,
            MediaStore.Audio.Media.TITLE,
            MediaStore.Audio.Media.ARTIST,
            MediaStore.Audio.Media.ALBUM,
            MediaStore.Audio.Media.ALBUM_ID,
            MediaStore.Audio.Media.DURATION,
            MediaStore.Audio.Media.DATA,
            MediaStore.Audio.Media.DISPLAY_NAME,
            MediaStore.Audio.Media.SIZE,
            MediaStore.Audio.Media.DATE_ADDED,
            MediaStore.Audio.Media.TRACK,
        )
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) columns.add(MediaStore.Audio.Media.RELATIVE_PATH)

        val items = mutableListOf<Map<String, Any?>>()
        contentResolver.query(collection, columns.toTypedArray(), null, null, null)?.use { c ->
            val id = c.getColumnIndexOrThrow(MediaStore.Audio.Media._ID)
            val title = c.getColumnIndexOrThrow(MediaStore.Audio.Media.TITLE)
            val artist = c.getColumnIndexOrThrow(MediaStore.Audio.Media.ARTIST)
            val album = c.getColumnIndexOrThrow(MediaStore.Audio.Media.ALBUM)
            val albumId = c.getColumnIndexOrThrow(MediaStore.Audio.Media.ALBUM_ID)
            val duration = c.getColumnIndexOrThrow(MediaStore.Audio.Media.DURATION)
            val data = c.getColumnIndexOrThrow(MediaStore.Audio.Media.DATA)
            val name = c.getColumnIndexOrThrow(MediaStore.Audio.Media.DISPLAY_NAME)
            val size = c.getColumnIndexOrThrow(MediaStore.Audio.Media.SIZE)
            val added = c.getColumnIndexOrThrow(MediaStore.Audio.Media.DATE_ADDED)
            val track = c.getColumnIndexOrThrow(MediaStore.Audio.Media.TRACK)
            val relative = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                c.getColumnIndex(MediaStore.Audio.Media.RELATIVE_PATH)
            } else {
                -1
            }
            while (c.moveToNext()) {
                val rowId = c.getLong(id)
                items.add(
                    mapOf(
                        "id" to rowId,
                        "uri" to ContentUris.withAppendedId(collection, rowId).toString(),
                        "title" to c.getString(title),
                        "artist" to c.getString(artist),
                        "album" to c.getString(album),
                        "albumId" to c.getLong(albumId),
                        "duration" to c.getLong(duration),
                        "fileName" to c.getString(name),
                        "size" to c.getLong(size),
                        "dateAdded" to c.getLong(added),
                        "track" to c.getInt(track),
                        "folder" to folderOf(c.getString(data), if (relative >= 0) c.getString(relative) else null),
                    ),
                )
            }
        }
        return items
    }

    @Suppress("DEPRECATION")
    private fun queryVideos(): List<Map<String, Any?>> {
        val collection = MediaStore.Video.Media.EXTERNAL_CONTENT_URI
        val columns = mutableListOf(
            MediaStore.Video.Media._ID,
            MediaStore.Video.Media.TITLE,
            MediaStore.Video.Media.DURATION,
            MediaStore.Video.Media.WIDTH,
            MediaStore.Video.Media.HEIGHT,
            MediaStore.Video.Media.DATA,
            MediaStore.Video.Media.DISPLAY_NAME,
            MediaStore.Video.Media.SIZE,
            MediaStore.Video.Media.DATE_ADDED,
        )
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) columns.add(MediaStore.Video.Media.RELATIVE_PATH)

        val items = mutableListOf<Map<String, Any?>>()
        contentResolver.query(collection, columns.toTypedArray(), null, null, null)?.use { c ->
            val id = c.getColumnIndexOrThrow(MediaStore.Video.Media._ID)
            val title = c.getColumnIndexOrThrow(MediaStore.Video.Media.TITLE)
            val duration = c.getColumnIndexOrThrow(MediaStore.Video.Media.DURATION)
            val width = c.getColumnIndexOrThrow(MediaStore.Video.Media.WIDTH)
            val height = c.getColumnIndexOrThrow(MediaStore.Video.Media.HEIGHT)
            val data = c.getColumnIndexOrThrow(MediaStore.Video.Media.DATA)
            val name = c.getColumnIndexOrThrow(MediaStore.Video.Media.DISPLAY_NAME)
            val size = c.getColumnIndexOrThrow(MediaStore.Video.Media.SIZE)
            val added = c.getColumnIndexOrThrow(MediaStore.Video.Media.DATE_ADDED)
            val relative = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                c.getColumnIndex(MediaStore.Video.Media.RELATIVE_PATH)
            } else {
                -1
            }
            while (c.moveToNext()) {
                val rowId = c.getLong(id)
                items.add(
                    mapOf(
                        "id" to rowId,
                        "uri" to ContentUris.withAppendedId(collection, rowId).toString(),
                        "title" to c.getString(title),
                        "duration" to c.getLong(duration),
                        "width" to c.getInt(width),
                        "height" to c.getInt(height),
                        "fileName" to c.getString(name),
                        "size" to c.getLong(size),
                        "dateAdded" to c.getLong(added),
                        "folder" to folderOf(c.getString(data), if (relative >= 0) c.getString(relative) else null),
                    ),
                )
            }
        }
        return items
    }

    // ---------- Carátulas y miniaturas ----------

    /** JPEG de la carátula (audio) o de un cuadro del video. Null si no tiene. */
    @Suppress("DEPRECATION")
    private fun thumbnail(uriString: String, size: Int, video: Boolean): ByteArray? {
        val uri = Uri.parse(uriString)
        var bitmap: Bitmap? = null
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            bitmap = try {
                contentResolver.loadThumbnail(uri, Size(size, size), null)
            } catch (e: Exception) {
                null
            }
        } else if (video) {
            bitmap = try {
                MediaStore.Video.Thumbnails.getThumbnail(
                    contentResolver,
                    ContentUris.parseId(uri),
                    MediaStore.Video.Thumbnails.MINI_KIND,
                    null,
                )
            } catch (e: Exception) {
                null
            }
        }
        if (bitmap == null && !video) bitmap = embeddedArt(uri, size)
        val image = bitmap ?: return null
        return ByteArrayOutputStream().use { out ->
            image.compress(Bitmap.CompressFormat.JPEG, 85, out)
            out.toByteArray()
        }
    }

    /** Carátula guardada dentro del archivo de audio (Android 9 o anterior). */
    private fun embeddedArt(uri: Uri, size: Int): Bitmap? {
        val retriever = MediaMetadataRetriever()
        return try {
            retriever.setDataSource(this, uri)
            val bytes = retriever.embeddedPicture ?: return null
            val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
            BitmapFactory.decodeByteArray(bytes, 0, bytes.size, bounds)
            var sample = 1
            while (bounds.outWidth / (sample * 2) >= size && bounds.outHeight / (sample * 2) >= size) sample *= 2
            BitmapFactory.decodeByteArray(bytes, 0, bytes.size, BitmapFactory.Options().apply { inSampleSize = sample })
        } catch (e: Exception) {
            null
        } finally {
            try {
                retriever.release()
            } catch (e: Exception) {
            }
        }
    }

    private fun tryStart(intent: Intent): Boolean =
        try {
            startActivity(intent)
            true
        } catch (e: ActivityNotFoundException) {
            false
        }

    companion object {
        private const val PERMISSION_REQUEST = 7301
    }
}
