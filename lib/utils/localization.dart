import 'package:flutter/material.dart';

final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.system);
final ValueNotifier<bool> isGreekNotifier = ValueNotifier(false);
final ValueNotifier<int> accentIndexNotifier = ValueNotifier(0);
final ValueNotifier<double> uiScaleNotifier = ValueNotifier(1.0);

class AccentColorOption {
  final String name;
  final Color lightColor;
  final Color darkColor;
  const AccentColorOption({
    required this.name,
    required this.lightColor,
    required this.darkColor,
  });
}

const List<AccentColorOption> accentColorOptions = [
  AccentColorOption(
    name: 'Purple',
    lightColor: Colors.purple,
    darkColor: Colors.purpleAccent,
  ),
  AccentColorOption(
    name: 'Blue',
    lightColor: Colors.blue,
    darkColor: Colors.blueAccent,
  ),
  AccentColorOption(
    name: 'Teal',
    lightColor: Colors.teal,
    darkColor: Colors.tealAccent,
  ),
  AccentColorOption(
    name: 'Green',
    lightColor: Colors.green,
    darkColor: Colors.greenAccent,
  ),
  AccentColorOption(
    name: 'Orange',
    lightColor: Colors.deepOrange,
    darkColor: Colors.orangeAccent,
  ),
  AccentColorOption(
    name: 'Red',
    lightColor: Colors.red,
    darkColor: Colors.redAccent,
  ),
  AccentColorOption(
    name: 'Pink',
    lightColor: Colors.pink,
    darkColor: Colors.pinkAccent,
  ),
  AccentColorOption(
    name: 'Indigo',
    lightColor: Colors.indigo,
    darkColor: Colors.indigoAccent,
  ),
];

String tr(String key) {
  if (!isGreekNotifier.value) return key;
  final Map<String, String> translations = {
    'VR App Manager': 'Διαχειριστής Εφαρμογών VR',
    'Liako\'s Store': 'Κατάστημα του Λιάκου',
    'Search apps...': 'Αναζήτηση εφαρμογών...',
    'Clear history': 'Καθαρισμός ιστορικού',
    'Clear filters': 'Καθαρισμός φίλτρων',
    'All Categories': 'Όλες οι Κατηγορίες',
    'Ovrport Only': 'Μόνο Ovrport',
    'Name (A-Z)': 'Όνομα (Α-Ω)',
    'Name (Z-A)': 'Όνομα (Ω-Α)',
    'Rating (High to Low)': 'Βαθμολογία (Φθίνουσα)',
    'Rating (Low to High)': 'Βαθμολογία (Αύξουσα)',
    'Size (Large to Small)': 'Μέγεθος (Φθίνον)',
    'Size (Small to Large)': 'Μέγεθος (Αύξον)',
    'Fetching database...': 'Λήψη βάσης δεδομένων...',
    'Unknown App': 'Άγνωστη Εφαρμογή',
    'Category': 'Κατηγορία',
    'Screenshots': 'Στιγμιότυπα Οθόνης',
    'Install to Headset': 'Εγκατάσταση στο Headset',
    'Watch Trailer': 'Προβολή Trailer',
    'Toggle Theme': 'Εναλλαγή Θέματος',
    'Refresh Apps': 'Ανανέωση Εφαρμογών',
    'Cancel': 'Ακύρωση',
    'Install': 'Εγκατάσταση',
    'Could not launch trailer': 'Αδυναμία εκκίνησης trailer',
    'Do you want to send this app to your headset for installation?':
        'Θέλετε να στείλετε αυτήν την εφαρμογή στο headset για εγκατάσταση;',
    'Deployment instruction sent to PC via ADB! Check headset for USB Debugging prompt.':
        'Η εντολή εγκατάστασης εστάλη στο PC μέσω ADB! Ελέγξτε το headset για το μήνυμα USB Debugging.',
    'Unknown Size': 'Άγνωστο Μέγεθος',
    'Toggle Language': 'Αλλαγή Γλώσσας',
    'Install App?': 'Εγκατάσταση Εφαρμογής;',
    'Done': 'Ολοκλήρωση',
    'Ovrport': 'Ovrport',
    'Installation Completed!': 'Η Εγκατάσταση Ολοκληρώθηκε!',
    'Invalid Object: App ID is empty':
        'Μη έγκυρο αντικείμενο: Το αναγνωριστικό εφαρμογής είναι κενό',
  };
  return translations[key] ?? key;
}
