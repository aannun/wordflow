/// A book available to read: a real file on disk (mobile/desktop) or a
/// record stored in the browser (web). [id] is stable per book and is used
/// as the key for saved reading progress.
class Book {
  final String id;
  final String title;
  final Future<List<String>> Function() loadWords;

  const Book({required this.id, required this.title, required this.loadWords});
}
