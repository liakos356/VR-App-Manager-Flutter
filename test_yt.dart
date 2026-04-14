import 'package:flutter/foundation.dart';
void main() {
  String? extractYoutubeId(String url) {
    final RegExp regex = RegExp(
      r'(?:youtube\.com\/(?:[^\/]+\/.+\/|(?:v|e(?:mbed)?)\/|.*[?&]v=)|youtu\.be\/)([^"&?\/\s]{11})',
    );
    final match = regex.firstMatch(url);
    return match?.group(1);
  }
  debugPrint(extractYoutubeId("https://www.youtube.com/watch?v=dQw4w9WgXcQ"));
  debugPrint(extractYoutubeId("https://youtu.be/dQw4w9WgXcQ"));
}
