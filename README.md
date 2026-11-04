# 🎵 **TimeLyr — Advanced lyrics finder for your local music**

**TimeLyr** is a mobile app built with **Flutter** that lets you fetch, manage and view lyrics for the songs stored on your device.
It scans your local files, extracts their metadata and downloads synced (LRC) or plain-text lyrics from **LRCLib**, always respecting user privacy.

---

## ✨ **Main features**

* 🔍 **Automatic metadata detection**
  Extracts title, artist, album and duration without needing an internet connection.

* 🎼 **Full LRC file support**
  Custom parser, timestamp support and smooth rendering.

* 📡 **Lyrics retrieval from the LRCLib API**
  Requests optimized based on your local metadata.

* 🚫 **Instrumental song detection**
  If no lyrics are found, TimeLyr marks the song automatically.

* 🖼️ **Smart cache for artwork and data**
  Improved speed for large lists.

---

## 🚀 **Technologies used**

| Component   | Technology                       |
| ----------- | -------------------------------- |
| Framework   | Flutter (Dart 3)                 |
| API         | LRCLib                           |
| Metadata    | metadata_god + custom services   |
| LRC parsing | Custom implementation            |
| UI          | Material 3 with custom themes    |
| Cache       | optimized local storage          |

---

## 📦 **Project structure**

```
lib/
├── main.dart
├── models
│   ├── lyric_result.dart
│   └── song.dart
├── screens
│   ├── home_screen.dart
│   ├── library_screen.dart
│   ├── lyric_preview_screen.dart
│   ├── lyrics_viewer.dart
│   ├── main_screen.dart
│   ├── more_screen.dart
│   ├── scan_screen.dart
│   └── search_screen.dart
├── services
│   ├── download_manager.dart
│   ├── file_service.dart
│   ├── local_notification_service.dart
│   ├── lrclib_service.dart
│   ├── lyrics_service.dart
│   └── notifications_settings.dart
├── theme
│   └── app_theme.dart
├── utils
│   ├── app_storage.dart
│   ├── artwork_cache.dart
│   ├── default_music_path.dart
│   ├── folder_picker.dart
│   ├── lyrics_utils.dart
│   ├── permissions.dart
│   ├── song_cache.dart
│   └── song_database.dart
└── widgets
    ├── gradient_background.dart
    ├── scan_music.dart
    ├── select_directory.dart
    ├── song_tile.dart
    └── toggleNotifications.dart
```

---

## 🧪 **Project status**

TimeLyr currently supports:

✔ folder scanning
✔ reading local metadata
✔ automatic lyrics search
✔ LRC download and storage
✔ advanced viewer
✔ instrumental song detection
✔ artwork and song cache
✔ manual search
✔ notification settings

Suggested future work:

* 🎨 more customizable themes
* 🧠 improvements to the API matching algorithm
* 🔔 better integration with system notifications
* 🔍 filter search (album, genre, year…)
* 🗃️ import/export of lyrics and settings
