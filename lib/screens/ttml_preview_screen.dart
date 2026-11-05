import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:timelyr/services/file_service.dart';
import 'package:timelyr/services/kpoe_remote_service.dart';
import 'package:timelyr/theme/app_theme.dart';

import '../models/song.dart';

/// Preview of a TTML found through manual search. Pops `true` once saved.
class TtmlPreviewScreen extends StatefulWidget {
  final String ttml;
  final Song song;
  final String title;
  final String artist;

  const TtmlPreviewScreen({
    super.key,
    required this.ttml,
    required this.song,
    required this.title,
    required this.artist,
  });

  @override
  State<TtmlPreviewScreen> createState() => _TtmlPreviewScreenState();
}

class _TtmlPreviewScreenState extends State<TtmlPreviewScreen> {
  bool _saving = false;

  /// True when every line has word-level timing (a real TTML worth keeping).
  bool get _wordSynced => !KpoeRemoteService.hasParagraphWithoutAnySpan(
    widget.ttml,
  );

  String get _previewText {
    final lrc = KpoeRemoteService.convertTtmlToLrc(widget.ttml);
    return lrc
        .split('\n')
        .map((line) => line.replaceFirst(RegExp(r'^\[[^\]]*\]'), ''))
        .join('\n')
        .trim();
  }

  Future<void> _save() async {
    final file = File(widget.song.path);
    final base = p.basenameWithoutExtension(file.path);
    final targetExt = _wordSynced ? 'ttml' : 'lrc';
    final target = File("${file.parent.path}/$base.$targetExt");

    if (target.existsSync()) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: AppTheme.background,
          title: const Text(
            "Replace existing lyrics",
            style: TextStyle(color: Colors.white),
          ),
          content: Text(
            "This song already has a .$targetExt file. Do you want to replace it?",
            style: const TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text(
                "Cancel",
                style: TextStyle(color: Colors.white70),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accent,
              ),
              child: const Text(
                "Replace",
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      );
      if (confirmed != true) {
        return;
      }
    }

    setState(() => _saving = true);
    try {
      await FileService.saveTtmlContent(
        widget.song.path,
        widget.song,
        widget.ttml,
        overwrite: true,
      );
      if (_wordSynced) {
        // The viewer reads the .lrc, so make sure one exists too.
        await FileService.saveLrcFromTtmlIfMissing(
          widget.song.path,
          widget.song,
          widget.ttml,
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _wordSynced
                ? "TTML saved."
                : "No word-level timing in this result, saved as LRC.",
          ),
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error saving lyrics: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final preview = _previewText;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(widget.title, style: const TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.title,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                widget.artist,
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: (_wordSynced ? AppTheme.accent : Colors.orange)
                      .withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _wordSynced
                      ? "Word-synced (TTML)"
                      : "Line-synced only, will be saved as LRC",
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  preview.isEmpty ? "No preview available." : preview,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.check, color: Colors.white),
                  label: Text(
                    _wordSynced ? "Use this TTML" : "Use as LRC",
                    style: const TextStyle(color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accent,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
