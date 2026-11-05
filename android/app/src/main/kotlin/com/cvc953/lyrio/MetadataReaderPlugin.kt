package com.cvc953.lyrio

import android.content.Context
import android.database.Cursor
import android.media.MediaMetadataRetriever
import android.os.Build
import android.net.Uri
import android.provider.MediaStore
import android.util.Log
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

class MetadataReaderPlugin :
    FlutterPlugin,
    MethodCallHandler {
    private lateinit var channel: MethodChannel
    private lateinit var context: Context

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, "metadata_reader")
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onMethodCall(
        call: MethodCall,
        result: Result,
    ) {
        when (call.method) {
            "getMetadata" -> {
                val path = call.argument<String>("path")
                if (path == null) {
                    result.error("INVALID_ARGUMENT", "Path is null", null)
                    return
                }
                try {
                    val metadata = getMetadata(path)
                    if (metadata != null) {
                        result.success(metadata)
                    } else {
                        result.error("METADATA_ERROR", "Could not read metadata", null)
                    }
                } catch (e: Exception) {
                    result.error("EXCEPTION", e.message, null)
                }
            }

            "scanMusic" -> {
                try {
                    val rootPath = call.argument<String>("rootPath")
                    val musicList = scanMusic(rootPath)
                    result.success(musicList)
                } catch (e: Exception) {
                    result.error("EXCEPTION", e.message, null)
                }
            }

            else -> {
                result.notImplemented()
            }
        }
    }

    private fun getMetadata(path: String): Map<String, Any>? {
        val retriever = MediaMetadataRetriever()
        return try {
            // Intentar con la ruta directa primero
            try {
                retriever.setDataSource(path)
            } catch (e: Exception) {
                // Si falla, intentar con la Uri del content resolver
                val uri = Uri.parse(path)
                context.contentResolver.openFileDescriptor(uri, "r")?.use { fd ->
                    retriever.setDataSource(fd.fileDescriptor)
                }
            }

            val metadata = mutableMapOf<String, Any>()

            val title = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_TITLE)
            val artist = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_ARTIST)
            val album = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_ALBUM)
            val duration = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)

            if (title != null) metadata["title"] = title
            if (artist != null) metadata["artist"] = artist
            if (album != null) metadata["album"] = album
            if (duration != null) metadata["durationMs"] = duration.toLong()

            val artworkBytes = retriever.embeddedPicture
            if (artworkBytes != null) {
                metadata["artwork"] = artworkBytes
            }

            metadata
        } catch (e: Exception) {
            Log.e("MetadataReader", "Error reading metadata for $path", e)
            null
        } finally {
            try {
                retriever.release()
            } catch (_: Exception) {
            }
        }
    }

    private fun scanMusic(rootPath: String?): List<Map<String, Any>> {
        val musicList = mutableListOf<Map<String, Any>>()
        val projection =
            arrayOf(
                MediaStore.Audio.Media._ID,
                MediaStore.Audio.Media.TITLE,
                MediaStore.Audio.Media.ARTIST,
                MediaStore.Audio.Media.ALBUM,
                MediaStore.Audio.Media.DURATION,
                MediaStore.Audio.Media.DATA,
                MediaStore.Audio.Media.YEAR,
            ).let { base ->
                // The GENRE column exists on API 30+; older versions use the Genres table below.
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) base + "genre" else base
            }
        val genreById: Map<Long, String> =
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) loadGenreMap() else emptyMap()

        val hasRootFilter = !rootPath.isNullOrBlank()
        val selection =
            if (hasRootFilter) {
                "${MediaStore.Audio.Media.IS_MUSIC} != 0 AND ${MediaStore.Audio.Media.DATA} LIKE ?"
            } else {
                "${MediaStore.Audio.Media.IS_MUSIC} != 0"
            }
        val selectionArgs =
            if (hasRootFilter) {
                arrayOf("${rootPath}%")
            } else {
                null
            }

        context.contentResolver
            .query(
                MediaStore.Audio.Media.EXTERNAL_CONTENT_URI,
                projection,
                selection,
                selectionArgs,
                "${MediaStore.Audio.Media.TITLE} ASC",
            )?.use { cursor ->
                val idIndex = cursor.getColumnIndex(MediaStore.Audio.Media._ID)
                val titleIndex = cursor.getColumnIndex(MediaStore.Audio.Media.TITLE)
                val artistIndex = cursor.getColumnIndex(MediaStore.Audio.Media.ARTIST)
                val albumIndex = cursor.getColumnIndex(MediaStore.Audio.Media.ALBUM)
                val durationIndex = cursor.getColumnIndex(MediaStore.Audio.Media.DURATION)
                val dataIndex = cursor.getColumnIndex(MediaStore.Audio.Media.DATA)
                val yearIndex = cursor.getColumnIndex(MediaStore.Audio.Media.YEAR)
                val genreIndex = cursor.getColumnIndex("genre")

                while (cursor.moveToNext()) {
                    val item = mutableMapOf<String, Any>()

                    if (idIndex >= 0) item["id"] = cursor.getLong(idIndex)
                    if (titleIndex >= 0) cursor.getString(titleIndex)?.let { item["title"] = it }
                    if (artistIndex >= 0) cursor.getString(artistIndex)?.let { item["artist"] = it }
                    if (albumIndex >= 0) cursor.getString(albumIndex)?.let { item["album"] = it }
                    if (durationIndex >= 0) item["durationMs"] = cursor.getLong(durationIndex)
                    if (dataIndex >= 0) cursor.getString(dataIndex)?.let { item["path"] = it }
                    if (yearIndex >= 0) item["year"] = cursor.getInt(yearIndex)
                    if (genreIndex >= 0) {
                        cursor.getString(genreIndex)?.let { item["genre"] = it }
                    } else if (idIndex >= 0) {
                        genreById[cursor.getLong(idIndex)]?.let { item["genre"] = it }
                    }

                    musicList.add(item)
                }
            }

        return musicList
    }

    /** API < 30: builds a map of audio id -> genre name from the MediaStore Genres tables. */
    private fun loadGenreMap(): Map<Long, String> {
        val map = mutableMapOf<Long, String>()
        try {
            context.contentResolver
                .query(
                    MediaStore.Audio.Genres.EXTERNAL_CONTENT_URI,
                    arrayOf(MediaStore.Audio.Genres._ID, MediaStore.Audio.Genres.NAME),
                    null,
                    null,
                    null,
                )?.use { genres ->
                    val gIdIdx = genres.getColumnIndex(MediaStore.Audio.Genres._ID)
                    val gNameIdx = genres.getColumnIndex(MediaStore.Audio.Genres.NAME)
                    while (genres.moveToNext()) {
                        val genreId = genres.getLong(gIdIdx)
                        val name = genres.getString(gNameIdx) ?: continue
                        context.contentResolver
                            .query(
                                MediaStore.Audio.Genres.Members.getContentUri("external", genreId),
                                arrayOf(MediaStore.Audio.Media._ID),
                                null,
                                null,
                                null,
                            )?.use { members ->
                                val mIdIdx = members.getColumnIndex(MediaStore.Audio.Media._ID)
                                while (members.moveToNext()) {
                                    map[members.getLong(mIdIdx)] = name
                                }
                            }
                    }
                }
        } catch (e: Exception) {
            Log.e("MetadataReader", "Error reading genres", e)
        }
        return map
    }
}
