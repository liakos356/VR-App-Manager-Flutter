import 'package:flutter/material.dart';

final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.system);
final ValueNotifier<bool> isGreekNotifier = ValueNotifier(false);

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
