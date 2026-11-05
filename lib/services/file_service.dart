import 'dart:io';
import 'package:timelyr/utils/song_database.dart';
import 'package:timelyr/services/metadata_reader.dart';
import '../models/song.dart';
import 'dart:typed_data';
import 'dart:async';
import 'package:path/path.dart' as p;
import 'package:timelyr/services/kpoe_remote_service.dart';
import 'package:timelyr/utils/ttml_miss_cache.dart';

class FileService {
  static List<Song> librarySongs = [];
  static Set<String> indexedPaths = {}; // For O(1) lookups
  static int _activeScanId = 0;

  static void cancelActiveScan() {
    _activeScanId++;
  }

  static void setLibrarySongs(List<Song> songs) {
    librarySongs = songs;
    indexedPaths = songs.map((s) => s.path).toSet();
  }

  // Stream para notificar cambios en la librería (añadidos/actualizaciones)
  static final StreamController<void> libraryUpdateController =
      StreamController<void>.broadcast();

  static Future<void> scanMusicWithCallback(
    String rootPath, {
    required Function(String path, int scanned, int found) onScan,
  }) async {
    final int scanId = ++_activeScanId;
    final normalizedRoot = p.normalize(rootPath);

    // Usar MediaStore para escanear música rápidamente
    final List<dynamic> musicList = await MetadataReader.scanMusic(
      rootPath: normalizedRoot,
    );

    if (scanId != _activeScanId) {
      return;
    }

    List<Song> songs = [];
    final cached = await SongDatabase.load();
    final Map<String, Song> cachedByPath = {
      for (var s in cached) p.normalize(s.path): s,
    };

    for (int i = 0; i < musicList.length; i++) {
      if (scanId != _activeScanId) {
        return;
      }

      if (i % 50 == 0) {
        await Future<void>.delayed(Duration.zero);
      }

      final item = musicList[i] as Map<dynamic, dynamic>;
      final path = item['path'] as String?;

      if (path == null) continue;

      final normalizedPath = p.normalize(path);
      if (!p.isWithin(normalizedRoot, normalizedPath) &&
          normalizedPath != normalizedRoot) {
        continue;
      }

      final String itemGenre = (item['genre'] as String?)?.trim() ?? '';
      final int itemYear = (item['year'] as num?)?.toInt() ?? 0;

      // Si ya existe en caché, reutilizar la entrada
      if (cachedByPath.containsKey(normalizedPath)) {
        final cachedSong = cachedByPath[normalizedPath]!;
        // Entries cached by older versions have no genre/year: fill them in.
        if ((cachedSong.genre.isEmpty && itemGenre.isNotEmpty) ||
            (cachedSong.year == 0 && itemYear > 0)) {
          songs.add(
            Song(
              path: cachedSong.path,
              title: cachedSong.title,
              artist: cachedSong.artist,
              album: cachedSong.album,
              durationSeconds: cachedSong.durationSeconds,
              genre: cachedSong.genre.isEmpty ? itemGenre : cachedSong.genre,
              year: cachedSong.year == 0 ? itemYear : cachedSong.year,
              modifiedMs: cachedSong.modifiedMs,
              size: cachedSong.size,
            ),
          );
        } else {
          songs.add(cachedSong);
        }
        onScan(path, i + 1, songs.length);
        continue;
      }

      final song = Song(
        path: normalizedPath,
        title: item['title'] as String? ?? normalizedPath.split('/').last,
        artist: item['artist'] as String? ?? '',
        album: item['album'] as String? ?? '',
        durationSeconds: ((item['durationMs'] as num?)?.toInt() ?? 0) ~/ 1000,
        genre: itemGenre,
        year: itemYear,
        modifiedMs: DateTime.now().millisecondsSinceEpoch,
        size: 0,
      );

      songs.add(song);
      onScan(path, i + 1, songs.length);
    }

    if (scanId != _activeScanId) {
      return;
    }

    setLibrarySongs(songs);
    await SongDatabase.save(songs);
    libraryUpdateController.add(null);
  }

  static Future<void> saveLRC(String songPath, String lyrics, Song song) async {
    final file = File(songPath);
    final dir = file.parent.path;
    final filename = p.basenameWithoutExtension(file.path);
    final lrcPath = "$dir/$filename.lrc";

    final lrcFile = File(lrcPath);
    await lrcFile.writeAsString(
      '$lyrics\n[ar:${song.artist.toString()}]\n[al:${song.album.toString()}]\n[ti:${song.title.toString()}]\n\n[by:TimeLyr]\n[source:LRCLib.net]',
    );
  }

  static Future<void> _saveTtmlAsLrcFallback(
    String songPath,
    Song song,
    String ttmlContent,
  ) async {
    final lrcLyrics = KpoeRemoteService.convertTtmlToLrc(ttmlContent);
    if (lrcLyrics.trim().isEmpty) return;

    // No guardar si todos los timestamps son 00:00.00 (fuente sin timing real)
    final tsRe = RegExp(r'^\[(\d{2}:\d{2}\.\d{2})\]');
    final tsLines =
        lrcLyrics.split('\n').where((l) => tsRe.hasMatch(l)).toList();
    if (tsLines.isNotEmpty && tsLines.every((l) => l.startsWith('[00:00.00]'))) {
      return;
    }

    await saveLRC(songPath, lrcLyrics, song);
  }

  static Future<bool> _saveTTMLContent(
    String songPath,
    Song song,
    String ttmlContent, {
    bool overwrite = false,
  }) async {
    try {
      final file = File(songPath);
      final dir = file.parent.path;
      final filename = p.basenameWithoutExtension(file.path);
      final ttmlPath = "$dir/$filename.ttml";

      // Si ya existe un .ttml para esta canción, comprobar su integridad.
      // Si parece válido, no reintentar; si parece dañado, proceder a descargar.
      final existing = File(ttmlPath);
      if (!overwrite && existing.existsSync()) {
        try {
          final contents = await existing.readAsString();
          // Considerar válido si contiene etiqueta <tt y tiene tamaño razonable
          if (contents.contains('<tt') || contents.contains('<?xml')) {
            if (contents.trim().length > 100) return true;
          }
          // Si no parece válido, continuar y reintentar la descarga (sobrescribir).
        } catch (_) {
          // Si no se puede leer, intentar descargar de nuevo.
        }
      }

      // No guardar como TTML si algún <p> no tiene <span> ni </span>.
      // En ese caso, hacer fallback a LRC para no perder la letra.
      if (KpoeRemoteService.hasParagraphWithoutAnySpan(ttmlContent)) {
        await _saveTtmlAsLrcFallback(songPath, song, ttmlContent);
        return false;
      }

      final ttmlFile = File(ttmlPath);
      // Añadir espacio a las palabras cuando hay separación entre spans
      final normalized = KpoeRemoteService.agregarEspacioEntreSpans(
        ttmlContent,
      );
      await ttmlFile.writeAsString(normalized);
      return true;
    } catch (e) {
      // Log error for debugging
      print('Error saving TTML: $e');
      return false;
    }
  }

  static bool _hasValidTtml(String songPath) {
    try {
      final file = File(songPath);
      final name = p.basenameWithoutExtension(file.path);
      final ttml = File("${file.parent.path}/$name.ttml");
      if (!ttml.existsSync()) return false;
      final contents = ttml.readAsStringSync();
      return (contents.contains('<tt') || contents.contains('<?xml')) &&
          contents.trim().length > 100;
    } catch (_) {
      return false;
    }
  }

  /// Fetches and saves the TTML for a song (automatic mode). Skips the network
  /// when a valid TTML already exists or when a recent lookup found nothing;
  /// pass [force] to ignore both.
  static Future<bool> saveTTMLForSong(
    String songPath,
    Song song, {
    bool force = false,
  }) async {
    if (!force) {
      if (_hasValidTtml(songPath)) return true;
      if (await TtmlMissCache.isMiss(songPath)) return false;
    }

    final stats = KpoeFetchStats();
    final ttml = await KpoeRemoteService.fetchWithFallbacks(
      song.title,
      song.artist,
      album: song.album,
      duration: song.durationSeconds <= 0
          ? ''
          : song.durationSeconds.toString(),
      stats: stats,
    );

    if (ttml == null || ttml.trim().isEmpty) {
      // Only remember genuine "not found" answers, never network failures.
      if (stats.reachedServer) {
        await TtmlMissCache.recordMiss(songPath);
      }
      return false;
    }

    await TtmlMissCache.clear(songPath);

    final converted = KpoeRemoteService.convertKpoeJsonToTtml(
      ttml,
      title: song.title,
      artist: song.artist,
    );

    return _saveTTMLContent(songPath, song, converted);
  }

  /// Manual TTML lookup with the tags the user typed. Returns the TTML text,
  /// or null if nothing was found. Throws if no server could be reached.
  static Future<String?> searchTtml({
    required String title,
    required String artist,
    String album = '',
    int durationSeconds = 0,
  }) async {
    final stats = KpoeFetchStats();
    final body = await KpoeRemoteService.fetchWithFallbacks(
      title,
      artist,
      album: album,
      duration: durationSeconds <= 0 ? '' : durationSeconds.toString(),
      aggressive: true,
      stats: stats,
    );

    if (body == null || body.trim().isEmpty) {
      if (!stats.reachedServer) {
        throw const SocketException('TTML servers unreachable');
      }
      return null;
    }

    final converted = KpoeRemoteService.convertKpoeJsonToTtml(
      body,
      title: title,
      artist: artist,
    );
    return converted.trim().isEmpty ? null : converted;
  }

  /// Saves a TTML chosen by the user. Returns false when the TTML had no
  /// word-level timing and was saved as an LRC instead.
  static Future<bool> saveTtmlContent(
    String songPath,
    Song song,
    String ttml, {
    bool overwrite = false,
  }) {
    return _saveTTMLContent(songPath, song, ttml, overwrite: overwrite);
  }

  /// Creates an LRC from a TTML only when the song has no LRC yet.
  static Future<void> saveLrcFromTtmlIfMissing(
    String songPath,
    Song song,
    String ttml,
  ) async {
    final file = File(songPath);
    final name = p.basenameWithoutExtension(file.path);
    if (File("${file.parent.path}/$name.lrc").existsSync()) return;
    await _saveTtmlAsLrcFallback(songPath, song, ttml);
  }

  static Future<Uint8List?> loadArtwork(String path) async {
    try {
      final meta = await MetadataReader.getMetadata(path);
      return meta?['artwork'] as Uint8List?;
    } catch (_) {
      return null;
    }
  }
}
