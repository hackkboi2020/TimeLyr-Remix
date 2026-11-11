String getPrimaryArtist(String artist) {
  final separators = ['/ ', ', ', '; '];
  for (final sep in separators) {
    final index = artist.indexOf(sep);
    if (index != -1) {
      return artist.substring(0, index).trim();
    }
  }
  return artist;
}

bool isSynced(String lyrics) {
  final regex = RegExp(r'\[\d{2}:\d{2}(?:\.\d{2,3})?\]');
  return regex.hasMatch(lyrics);
}

String pickBestLyrics(String synced, String plain) {
  synced = synced.trim();
  plain = plain.trim();

  final regex = RegExp(r'\[\d{2}:\d{2}(?:\.\d{2,3})?\]');

  if (synced.isNotEmpty && regex.hasMatch(synced)) {
    return synced; //  Preferir la sincronizada
  }

  return plain;
}

/// Cleans a track title for lookups on lyrics servers: removes
/// "(feat. X)", "[ft. X]", "- Remastered 2011", "(Remastered)", etc.
/// Returns the original (trimmed) title if cleaning would leave it empty.
String cleanTrackTitle(String title) {
  var t = title.trim();
  t = t.replaceAll(
    RegExp(
      r'\s*[\(\[]\s*(?:feat\.?|ft\.?|featuring|with)\b[^\)\]]*[\)\]]',
      caseSensitive: false,
    ),
    '',
  );
  t = t.replaceAll(
    RegExp(
      r'\s*[\(\[]\s*(?:\d{4}\s+)?(?:remaster(?:ed)?|single version|radio edit)[^\)\]]*[\)\]]',
      caseSensitive: false,
    ),
    '',
  );
  t = t.replaceAll(
    RegExp(
      r'\s*[-–]\s*(?:\d{4}\s+)?(?:remaster(?:ed)?|single version|radio edit)\b.*$',
      caseSensitive: false,
    ),
    '',
  );
  t = t.replaceAll(
    RegExp(r'\s+(?:feat\.?|ft\.?|featuring)\s+.*$', caseSensitive: false),
    '',
  );
  t = t.trim();
  return t.isEmpty ? title.trim() : t;
}

/// First credited artist, without "feat." parts. Does not split on "&" so
/// names like "Simon & Garfunkel" stay intact.
String searchArtist(String artist) {
  var a = getPrimaryArtist(artist);
  a = a.split(
    RegExp(r'\s+(?:feat\.?|ft\.?|featuring)\s+', caseSensitive: false),
  ).first;
  return a.trim();
}

/// Lyrics as readable text: drops [mm:ss.xx] and <mm:ss.xx> timing, skips [ar:]-style
/// tags, and shows [bg:...] background vocals as (indented lines in brackets).
String cleanLyricsForDisplay(String raw) {
  final out = <String>[];
  final bgLine = RegExp(r'^\[bg:(.*)\]$', caseSensitive: false);
  final metaTag = RegExp(r'^\[[A-Za-z]+:.*\]$');
  final lineTime = RegExp(r'\[\d+:\d{1,2}(?:[.:]\d{1,3})?\]');
  final wordTime = RegExp(r'<\d+:\d{1,2}(?:[.:]\d{1,3})?>');
  for (final line in raw.split('\n')) {
    final t = line.trim();
    final bg = bgLine.firstMatch(t);
    if (bg == null && metaTag.hasMatch(t)) continue;
    final text = (bg != null ? bg.group(1)! : t)
        .replaceAll(lineTime, '')
        .replaceAll(wordTime, '')
        .trim();
    if (text.isEmpty) {
      if (out.isNotEmpty && out.last.isNotEmpty) out.add('');
      continue;
    }
    out.add(bg != null ? '   ($text)' : text);
  }
  return out.join('\n').trim();
}
