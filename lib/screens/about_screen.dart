import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/gestures.dart';
import 'package:timelyr/theme/app_theme.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: const Text(
            'About',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          backgroundColor: AppTheme.background,
        ),
        backgroundColor: AppTheme.background,
        body: Center(
          child: SingleChildScrollView(
            //mainAxisAlignment: MainAxisAlignment.start,
            child: Column(
              children: [
                SizedBox(height: 20),
                Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'TimeLyr\nYour music, your lyrics.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      fontStyle: FontStyle.normal,
                    ),
                  ),
                ),
                SizedBox(height: 20),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0),
                  child: Text(
                    'TimeLyr is an app designed to get lyrics for the songs stored on your device. The app reads the metadata of your files, searches LRCLib for synced (LRC) or plain-text lyrics, and saves them locally so you can view them offline.',
                    textAlign: TextAlign.left,
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'Main features:\n\n'
                    '• Automatic search for synced and plain-text lyrics.\n'
                    '• Local storage for offline access.\n'
                    '• Simple, easy-to-use interface.\n\n'
                    'TimeLyr is ideal for music lovers who want their favorite lyrics always at hand, whether to sing along to their songs or simply to enjoy the poetry behind the music.',
                    textAlign: TextAlign.left,
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'Thanks for using TimeLyr!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Divider(color: Colors.white24),
                ),
                Padding(
                  padding: EdgeInsets.all(10.0),
                  child: Text(
                    'App version: 1.0.1',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.all(10.0),
                  child: Column(
                    children: [
                      Text(
                        'Developed by Cristian Villalobos Cuadrado.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                      RichText(
                        text: TextSpan(
                          text: 'App GitHub',
                          style: TextStyle(
                            color: AppTheme.accent,
                            decoration: TextDecoration.underline,
                            fontSize: 12,
                          ),
                          recognizer: TapGestureRecognizer()
                            ..onTap = () async {
                              final url = Uri.parse(
                                'http://github.com/cvc953/TimeLyr',
                              );
                              _launchURL(url);
                            },
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.all(10.0),
                  child: Column(
                    children: [
                      Text(
                        'Lyrics provided by the LRCLib library.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      RichText(
                        text: TextSpan(
                          text: 'Visit LRCLib on GitHub',
                          style: TextStyle(
                            color: AppTheme.accent,
                            decoration: TextDecoration.underline,
                            fontSize: 12,
                          ),
                          recognizer: TapGestureRecognizer()
                            ..onTap = () async {
                              final url = Uri.parse(
                                'https://github.com/tranxuanthang/lrclib',
                              );
                              _launchURL(url);
                            },
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.all(10.0),
                  child: Text(
                    '© 2025 TimeLyr. MIT License.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ),
                SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _launchURL(Uri url) async {
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }
}
