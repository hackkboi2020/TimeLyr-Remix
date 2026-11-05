import 'package:flutter/material.dart';
import 'package:timelyr/models/lyric_result.dart';
import 'package:timelyr/services/lrclib_service.dart';
import 'package:timelyr/widgets/gradient_background.dart';
import 'lyric_preview_screen.dart';
import 'ttml_preview_screen.dart';
import '../services/file_service.dart';
import '../models/song.dart';
import 'package:timelyr/theme/app_theme.dart';

enum SearchMode { lrc, ttml }

class SearchScreen extends StatefulWidget {
  final String initialTitle;
  final String initialArtist;
  final String initialAlbum;
  final Song song;
  const SearchScreen({
    super.key,
    this.initialTitle = "",
    this.initialArtist = "",
    this.initialAlbum = "",
    required this.song,
  });

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController titleController = TextEditingController();
  final TextEditingController albumController = TextEditingController();
  final TextEditingController artistController = TextEditingController();

  bool isSearching = false;
  //String? _lyric;
  String? _error;
  List<LyricResult> results = [];
  SearchMode _mode = SearchMode.lrc;
  String? _ttmlResult;
  String _ttmlTitle = '';
  String _ttmlArtist = '';

  @override
  void initState() {
    super.initState();
    titleController.text = widget.initialTitle;
    albumController.text = widget.initialAlbum;
    artistController.text = widget.initialArtist;
  }

  @override
  void dispose() {
    titleController.dispose();
    albumController.dispose();
    artistController.dispose();
    super.dispose();
  }

  Future<void> _onSearchTtml(String title, String artist, String album) async {
    if (title.isEmpty || artist.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("TTML search needs at least a title and an artist."),
        ),
      );
      return;
    }

    setState(() {
      isSearching = true;
      results = [];
      _ttmlResult = null;
      _error = null;
    });

    try {
      // Only send the song's duration when the user is still searching for it;
      // a different title/artist would make the duration misleading.
      final sameAsSong =
          title == widget.initialTitle.trim() &&
          artist == widget.initialArtist.trim();

      final ttml = await FileService.searchTtml(
        title: title,
        artist: artist,
        album: album,
        durationSeconds: sameAsSong ? widget.song.durationSeconds : 0,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        if (ttml == null) {
          _error = "No TTML found for the given criteria.";
        } else {
          _ttmlResult = ttml;
          _ttmlTitle = title;
          _ttmlArtist = artist;
        }
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error =
            "An error occurred during the search. Check your connection and try again.";
      });
    } finally {
      if (mounted) {
        setState(() {
          isSearching = false;
        });
      }
    }
  }

  Future<void> _onSearch() async {
    if (isSearching) {
      return;
    }
    final title = titleController.text.trim();
    final artist = artistController.text.trim();
    final album = albumController.text.trim();

    if (_mode == SearchMode.ttml) {
      await _onSearchTtml(title, artist, album);
      return;
    }

    if (title.isEmpty && artist.isEmpty && album.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please fill in at least one field to search."),
        ),
      );
      return;
    }
    setState(() {
      isSearching = true;
      results = [];
      _error = null;
    });

    try {
      final lrcList = await LRCLibService.getManualLyrics(
        artist: artist,
        title: title,
        album: album,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        if (lrcList.isEmpty) {
          _error = "No lyrics found for the given criteria.";
        } else {
          results = lrcList;
        }
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error =
            "An error occurred during the search. Check your connection and try again.";
      });
    } finally {
      if (mounted) {
        setState(() {
          isSearching = false;
        });
      }
    }
  }

  String formatDuration(double seconds) {
    final int total = seconds.floor();
    final int minutes = total ~/ 60;
    final int remaining = total % 60;

    return "$minutes:${remaining.toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
    return GradientBackground(
      child: Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
          title: const Text(
            "Manual Search",
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),

        body: ListView(
          children: [
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              child: SegmentedButton<SearchMode>(
                segments: const [
                  ButtonSegment<SearchMode>(
                    value: SearchMode.lrc,
                    label: Text("LRC"),
                    icon: Icon(Icons.lyrics),
                  ),
                  ButtonSegment<SearchMode>(
                    value: SearchMode.ttml,
                    label: Text("TTML"),
                    icon: Icon(Icons.graphic_eq),
                  ),
                ],
                selected: {_mode},
                onSelectionChanged: (selection) {
                  setState(() {
                    _mode = selection.first;
                    results = [];
                    _ttmlResult = null;
                    _error = null;
                  });
                },
                style: SegmentedButton.styleFrom(
                  foregroundColor: Colors.white70,
                  selectedForegroundColor: Colors.white,
                  selectedBackgroundColor: AppTheme.accent.withValues(
                    alpha: 0.6,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              child: TextField(
                controller: titleController,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _onSearch(),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: "Title",
                  hintStyle: const TextStyle(color: Colors.white54),
                  filled: true,
                  fillColor: Colors.white12,
                  prefixIcon: const Icon(Icons.music_note, color: Colors.white),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              child: TextField(
                controller: artistController,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _onSearch(),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: "Artist",
                  hintStyle: const TextStyle(color: Colors.white54),
                  filled: true,
                  fillColor: Colors.white12,
                  prefixIcon: const Icon(Icons.person, color: Colors.white),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              child: TextField(
                controller: albumController,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _onSearch(),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: "Album",
                  hintStyle: const TextStyle(color: Colors.white54),
                  filled: true,
                  fillColor: Colors.white12,
                  prefixIcon: const Icon(Icons.album, color: Colors.white),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: ElevatedButton(
                onPressed: isSearching ? null : _onSearch,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accent,
                  padding: const EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: 20,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: isSearching
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        "Search",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
            if (!isSearching && results.isNotEmpty)
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: results.length,
                itemBuilder: (context, i) {
                  final item = results[i];

                  return Card(
                    color: Colors.white10,
                    margin: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: ListTile(
                      title: Text(
                        item.title.isNotEmpty ? item.title : "Untitled",
                        style: const TextStyle(color: Colors.white),
                      ),
                      subtitle: Text(
                        "${item.artist} • ${item.album.isNotEmpty ? item.album : 'No album'} • ${formatDuration(item.durationSeconds)}",

                        style: const TextStyle(color: Colors.white70),
                      ),
                      trailing: const Icon(
                        Icons.chevron_right,
                        color: Colors.white,
                      ),
                      onTap: () async {
                        final selected = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => LyricPreviewScreen(
                              result: item,
                              song: widget.song,
                            ),
                          ),
                        );
                        if (selected != null) {
                          Navigator.pop(context, selected);
                        }
                      },
                    ),
                  );
                },
              ),
            if (!isSearching && _ttmlResult != null)
              Card(
                color: Colors.white10,
                margin: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                child: ListTile(
                  title: Text(
                    _ttmlTitle,
                    style: const TextStyle(color: Colors.white),
                  ),
                  subtitle: Text(
                    "$_ttmlArtist • TTML lyrics found",
                    style: const TextStyle(color: Colors.white70),
                  ),
                  trailing: const Icon(
                    Icons.chevron_right,
                    color: Colors.white,
                  ),
                  onTap: () async {
                    final saved = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TtmlPreviewScreen(
                          ttml: _ttmlResult!,
                          song: widget.song,
                          title: _ttmlTitle,
                          artist: _ttmlArtist,
                        ),
                      ),
                    );
                    if (saved == true && context.mounted) {
                      Navigator.pop(context, true);
                    }
                  },
                ),
              ),
            if (!isSearching && results.isEmpty && _error != null)
              Container(
                margin: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 20,
                ),
                child: Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
