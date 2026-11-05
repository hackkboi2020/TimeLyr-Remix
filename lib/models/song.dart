class Song {
  final String path;
  final String title;
  final String artist;
  final String album;
  final int durationSeconds;
  final String genre;
  final int year; // 0 = unknown
  // File stat to detect changes and avoid re-reading metadata when unchanged
  final int? modifiedMs;
  final int? size;

  Song({
    required this.path,
    required this.title,
    required this.artist,
    required this.album,
    required this.durationSeconds,
    this.genre = '',
    this.year = 0,
    this.modifiedMs,
    this.size,
  });

  Map<String, dynamic> toJson() {
    return {
      'path': path,
      'title': title,
      'artist': artist,
      'album': album,
      'durationSeconds': durationSeconds,
      'genre': genre,
      'year': year,
      'modifiedMs': modifiedMs,
      'size': size,
    };
  }

  factory Song.fromJson(Map<String, dynamic> json) {
    return Song(
      path: json['path'],
      title: json['title'],
      artist: json['artist'],
      album: json['album'],
      durationSeconds: json['durationSeconds'] ?? 0,
      genre: (json['genre'] as String?) ?? '',
      year: (json['year'] as num?)?.toInt() ?? 0,
      modifiedMs: json['modifiedMs'] ?? json['modified'],
      size: json['size'],
    );
  }
}
