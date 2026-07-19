/// A book available to read: bundled with the app, a real file on disk
/// (mobile/desktop), or a record stored in the browser (web). [id] is
/// stable per book and is used as the key for saved reading progress.
class Book {
  final String id;
  final String title;
  final Future<List<String>> Function() loadWords;

  /// Whether this book can be deleted from within the app. Books bundled
  /// with the app are shared across every device and are never removable.
  final bool removable;

  const Book({
    required this.id,
    required this.title,
    required this.loadWords,
    this.removable = false,
  });
}
