// ignore_for_file: avoid_print
import 'package:path_provider/path_provider.dart'; void main() async { print((await getTemporaryDirectory()).path); }
