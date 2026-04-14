void main() {
  String? extractYoutubeId(String url) {
    final RegExp regex = RegExp(
      r'(?:youtube\.com\/(?:[^\/]+\/.+\/|(?:v|e(?:mbed)?)\/|.*[?&]v=)|youtu\.be\/)([^"&?\/\s]{11})',
    );
    final match = regex.firstMatch(url);
    return match?.group(1);
  }
  print(extractYoutubeId("https://www.youtube.com/watch?v=dQw4w9WgXcQ"));
  print(extractYoutubeId("https://youtu.be/dQw4w9WgXcQ"));
}
