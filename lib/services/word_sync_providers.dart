import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:timelyr/services/kpoe_remote_service.dart';
import 'package:timelyr/utils/lyrics_utils.dart';

/// How a word-synced result is stored.
/// - [ttml]: a TTML document (saved as .ttml)
/// - [elrc]: "Enhanced LRC", i.e. LRC with <mm:ss.xx> word tags and optional
///   `[bg:...]` background-vocal lines (saved as .lrc)
enum WordSyncFormat { ttml, elrc }

class WordSyncResult {
  final String source;
  final WordSyncFormat format;
  final String content;

  const WordSyncResult({
    required this.source,
    required this.format,
    required this.content,
  });
}

class WordSyncQuery {
  final String title;
  final String artist;
  final String album;
  final int durationSec;
  final String isrc;

  const WordSyncQuery({
    required this.title,
    required this.artist,
    this.album = '',
    this.durationSec = 0,
    this.isrc = '',
  });
}

/// Lets callers tell "nothing found" from "no network".
class WordSyncStats {
  bool reachedServer = false;
}

/// Looks up word-by-word synced lyrics on several public services (the same
/// kind of sources Mornye uses): LyricsPlus, Musixmatch (through Paxsenix),
/// lrc.red and BetterLyrics. Every provider fails soft: it returns null.
class WordSyncProviders {
  static const Duration _timeout = Duration(seconds: 10);
  static const Map<String, String> _headers = {
    'User-Agent': 'TimeLyr (lyrics downloader)',
    'Accept': 'application/json, text/plain, application/ttml+xml, */*',
  };
  static const Map<String, String> _ttmlHeaders = {
    'User-Agent': 'TimeLyr (lyrics downloader)',
    'Accept': 'application/ttml+xml, application/xml',
  };

  static final RegExp _wordTag = RegExp(r'<\d+:\d{1,2}(?:[.:]\d{1,3})?>');
  static final RegExp _lineTag = RegExp(r'\[\d+:\d{1,2}(?:[.:]\d{1,3})?\]');

  static bool hasWordTags(String text) =>
      _wordTag.hasMatch(text) && _lineTag.hasMatch(text);

  /// Runs every provider at once (manual search) and returns what was found,
  /// best-first.
  static Future<List<WordSyncResult>> search(
    WordSyncQuery q, {
    WordSyncStats? stats,
  }) async {
    final s = stats ?? WordSyncStats();
    final futures = <Future<WordSyncResult?>>[];
    for (final variant in _variants(q)) {
      futures.addAll([
        _lyricsPlus(variant, s),
        _lrcRed(variant, s),
        _musixmatch(variant, s),
        _betterLyrics(variant, s),
      ]);
    }
    final results = await Future.wait<WordSyncResult?>(futures);
    // Same lyrics found through two spellings of the artist count once
    final seen = <String>{};
    final unique = <WordSyncResult>[];
    for (final r in results.whereType<WordSyncResult>()) {
      if (seen.add('${r.source}|${r.content.hashCode}')) unique.add(r);
    }
    return unique;
  }

  /// The tags as given, then the cleaned title with each credited artist on its own.
  /// Songs by several artists (A, B / A & B) are often listed under just one of them.
  static List<WordSyncQuery> _variants(WordSyncQuery q) {
    final out = <WordSyncQuery>[q];
    final title = cleanTrackTitle(q.title);
    void add(String t, String artist) {
      final a = artist.trim();
      if (a.isEmpty) return;
      final candidate = WordSyncQuery(
        title: t,
        artist: a,
        album: q.album,
        durationSec: q.durationSec,
        isrc: q.isrc,
      );
      if (!out.any((o) => o.title == candidate.title && o.artist == candidate.artist)) {
        out.add(candidate);
      }
    }

    add(title, q.artist);
    final artists = q.artist.split(
      RegExp(r'\s*(?:,|;|/|&|\bfeat\.?|\bft\.?|\bfeaturing\b)\s*', caseSensitive: false),
    );
    if (artists.length > 1) {
      for (final a in artists) {
        add(title, a);
      }
    }
    return out.take(4).toList();
  }

  /// Tries providers one after another and stops at the first hit
  /// (automatic downloads, to stay gentle on the servers).
  static Future<WordSyncResult?> fetchBest(
    WordSyncQuery q, {
    WordSyncStats? stats,
  }) async {
    final s = stats ?? WordSyncStats();
    for (final provider in <Future<WordSyncResult?> Function()>[
      () => _lyricsPlus(q, s),
      () => _lrcRed(q, s),
      () => _musixmatch(q, s),
      () => _betterLyrics(q, s),
    ]) {
      final result = await provider();
      if (result != null) return result;
    }
    return null;
  }

  // ---------------------------------------------------------------- LyricsPlus

  static Future<WordSyncResult?> _lyricsPlus(
    WordSyncQuery q,
    WordSyncStats stats,
  ) async {
    for (final host in const [
      'lyricsplus.prjktla.my.id',
      'lyricsplus.binimum.org',
    ]) {
      final uri = Uri.https(host, '/v2/lyrics/get', {
        'title': q.title,
        'artist': q.artist,
        if (q.durationSec > 0) 'duration': q.durationSec.toStringAsFixed(3),
        if (q.isrc.isNotEmpty) 'isrc': q.isrc,
      });
      try {
        final r = await http.get(uri, headers: _headers).timeout(_timeout);
        if (r.statusCode == 200 || r.statusCode == 404) {
          stats.reachedServer = true;
        }
        if (r.statusCode != 200) continue;
        final elrc = kpoeJsonToElrc(jsonDecode(utf8.decode(r.bodyBytes)));
        if (elrc != null) {
          return WordSyncResult(
            source: 'LyricsPlus',
            format: WordSyncFormat.elrc,
            content: elrc,
          );
        }
      } catch (_) {
        // try the next server
      }
    }
    return null;
  }

  /// Converts a LyricsPlus (KPOE) response into Enhanced LRC. Returns null
  /// unless the response really has word-level timing.
  static String? kpoeJsonToElrc(dynamic json) {
    if (json is! Map) return null;
    final type = (json['type'] ?? '').toString().toLowerCase();
    final wordLevel = type == 'word' || type == 'syllable';
    final lyrics = json['lyrics'];
    if (!wordLevel || lyrics is! List || lyrics.isEmpty) return null;

    final out = <String>[];
    var anyWord = false;
    for (final raw in lyrics) {
      if (raw is! Map) continue;
      final start = _asMs(raw['time']);
      final syl = raw['syllabus'];
      final syllabus = syl is List
          ? syl.whereType<Map>().toList()
          : <Map>[];

      if (syllabus.isNotEmpty) {
        var main = syllabus.where((s) => s['isBackground'] != true).toList();
        var background = syllabus.where((s) => s['isBackground'] == true).toList();
        if (main.isEmpty) {
          main = syllabus;
          background = [];
        }
        out.add('[${_stamp(start)}]${_tagged(main)}');
        if (background.isNotEmpty) {
          out.add('[bg:${_tagged(background)}]');
        }
        anyWord = true;
      } else {
        final text = (raw['text'] ?? '').toString().trim();
        if (text.isNotEmpty) out.add('[${_stamp(start)}]$text');
      }
    }
    return anyWord ? out.join('\n') : null;
  }

  static String _tagged(List<Map> syllables) => syllables
      .map((s) => '<${_stamp(_asMs(s['time']))}>${s['text'] ?? ''}')
      .join();

  static int _asMs(dynamic v) => v is num ? v.round() : 0;

  /// mm:ss.cc (centiseconds, the most widely supported precision).
  static String _stamp(int ms) {
    final safe = ms < 0 ? 0 : ms;
    final minutes = (safe ~/ 60000).toString().padLeft(2, '0');
    final seconds = ((safe % 60000) ~/ 1000).toString().padLeft(2, '0');
    final centis = ((safe % 1000) ~/ 10).toString().padLeft(2, '0');
    return '$minutes:$seconds.$centis';
  }

  // ------------------------------------------------------------------- lrc.red

  static Future<WordSyncResult?> _lrcRed(
    WordSyncQuery q,
    WordSyncStats stats,
  ) async {
    try {
      final search = await http
          .get(
            Uri.https('lrc.red', '/search.json', {'q': '${q.title} ${q.artist}'}),
            headers: _headers,
          )
          .timeout(_timeout);
      if (search.statusCode == 200 || search.statusCode == 404) {
        stats.reachedServer = true;
      }
      if (search.statusCode != 200) return null;
      final decoded = jsonDecode(utf8.decode(search.bodyBytes));
      final hits = decoded is Map && decoded['hits'] is List
          ? (decoded['hits'] as List).whereType<Map>().toList()
          : <Map>[];

      final wantedTitle = _norm(q.title);
      final wantedArtists = _artistWords(q.artist);
      Map? best;
      var bestDistance = double.infinity;
      for (final hit in hits) {
        final isrc = (hit['isrc'] ?? '').toString().trim().toUpperCase();
        if (!RegExp(r'^[A-Z0-9]{12}$').hasMatch(isrc)) continue;
        if (_norm((hit['title'] ?? '').toString()) != wantedTitle) continue;
        final hitArtists = _artistWords((hit['artist'] ?? '').toString());
        if (wantedArtists.intersection(hitArtists).isEmpty) continue;
        final hitDuration = hit['duration'] is num
            ? (hit['duration'] as num).toDouble()
            : 0.0;
        double distance = 0;
        if (q.durationSec > 0 && hitDuration > 0) {
          distance = (hitDuration - q.durationSec).abs();
          if (distance > 4) continue;
        }
        if (distance < bestDistance) {
          bestDistance = distance;
          best = hit;
        }
      }
      if (best == null) return null;

      final isrc = (best['isrc'] as Object).toString().trim().toUpperCase();
      final doc = await http
          .get(
            Uri.https('lrc.red', '/s/$isrc.ttml'),
            headers: _ttmlHeaders,
          )
          .timeout(_timeout);
      if (doc.statusCode != 200) return null;
      final ttml = utf8.decode(doc.bodyBytes);
      if (!ttml.contains('<tt')) return null;
      return WordSyncResult(
        source: 'lrc.red',
        format: WordSyncFormat.ttml,
        content: ttml,
      );
    } catch (_) {
      return null;
    }
  }

  // -------------------------------------------------------- Musixmatch (Paxsenix)

  static Future<WordSyncResult?> _musixmatch(
    WordSyncQuery q,
    WordSyncStats stats,
  ) async {
    try {
      final r = await http
          .get(
            Uri.https('lyrics.paxsenix.org', '/musixmatch/lyrics', {
              't': q.title,
              'a': q.artist,
              'type': 'word',
              'format': 'lrc',
              if (q.durationSec > 0) 'd': q.durationSec.toString(),
            }),
            headers: _headers,
          )
          .timeout(_timeout);
      if (r.statusCode == 200 || r.statusCode == 404) {
        stats.reachedServer = true;
      }
      if (r.statusCode != 200) return null;

      var text = utf8.decode(r.bodyBytes).trim();
      if (text.startsWith('"')) {
        final decoded = jsonDecode(text);
        if (decoded is String) text = decoded;
      } else if (text.startsWith('{')) {
        final decoded = jsonDecode(text);
        text = '';
        if (decoded is Map) {
          for (final key in const ['lyrics', 'lrc', 'text']) {
            final value = decoded[key];
            if (value is String && value.trim().isNotEmpty) {
              text = value;
              break;
            }
          }
        }
      }
      text = text.trim();
      if (!hasWordTags(text)) return null;
      return WordSyncResult(
        source: 'Musixmatch',
        format: WordSyncFormat.elrc,
        content: text,
      );
    } catch (_) {
      return null;
    }
  }

  // ------------------------------------------------------------- BetterLyrics

  static Future<WordSyncResult?> _betterLyrics(
    WordSyncQuery q,
    WordSyncStats stats,
  ) async {
    try {
      final r = await http
          .get(
            Uri.https('lyrics-api.boidu.dev', '/getLyrics', {
              's': q.title.trim(),
              'a': q.artist.trim(),
              if (q.durationSec > 0) 'd': q.durationSec.toString(),
            }),
            headers: _headers,
          )
          .timeout(_timeout);
      if (r.statusCode == 200 || r.statusCode == 401 || r.statusCode == 404) {
        stats.reachedServer = true;
      }
      // Without an API key this service only answers songs it already has.
      if (r.statusCode != 200) return null;
      final decoded = jsonDecode(utf8.decode(r.bodyBytes));
      final ttml = decoded is Map ? (decoded['ttml'] ?? '').toString() : '';
      if (!ttml.contains('<tt')) return null;
      return WordSyncResult(
        source: 'BetterLyrics',
        format: WordSyncFormat.ttml,
        content: ttml,
      );
    } catch (_) {
      return null;
    }
  }

  // ------------------------------------------------------------------ helpers

  static String _norm(String s) => cleanTrackTitle(s)
      .toLowerCase()
      .replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), ' ')
      .trim();

  static Set<String> _artistWords(String artist) {
    return artist
        .toLowerCase()
        .replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), ' ')
        .split(' ')
        .where(
          (w) =>
              w.isNotEmpty &&
              !const {'feat', 'ft', 'featuring', 'with', 'and', 'the'}
                  .contains(w),
        )
        .toSet();
  }

  /// True when a TTML document has real word-level timing.
  static bool ttmlIsWordLevel(String ttml) =>
      !KpoeRemoteService.hasParagraphWithoutAnySpan(ttml);
}
