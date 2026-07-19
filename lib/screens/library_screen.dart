import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../models/book.dart';
import '../services/book_repository.dart';
import 'reader_screen.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  late Future<List<Book>> _booksFuture;
  String? _booksPath;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _booksFuture = BookRepository.listBooks();
    BookRepository.getBooksFolderPath().then((path) {
      if (mounted) setState(() => _booksPath = path);
    });
  }

  Future<void> _refresh() async {
    setState(_load);
    await _booksFuture;
  }

  Future<void> _pickAndAddBook() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['txt'],
      withData: true,
    );
    final picked = result?.files.firstOrNull;
    final bytes = picked?.bytes;
    if (picked == null || bytes == null) return;

    final title = picked.name.replaceAll(
      RegExp(r'\.txt$', caseSensitive: false),
      '',
    );
    await BookRepository.addBook(title, bytes);
    await _refresh();
  }

  Future<void> _deleteBook(Book book) async {
    await BookRepository.deleteBook(book.id);
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('I tuoi libri'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
            tooltip: 'Aggiorna',
          ),
        ],
      ),
      floatingActionButton: BookRepository.supportsManualUpload
          ? FloatingActionButton(
              onPressed: _pickAndAddBook,
              tooltip: 'Aggiungi libro',
              child: const Icon(Icons.add),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<Book>>(
          future: _booksFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }

            final books = snapshot.data ?? const [];
            if (books.isEmpty) {
              return _EmptyState(path: _booksPath);
            }

            return ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: books.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final book = books[index];
                return ListTile(
                  leading: const Icon(Icons.menu_book_outlined),
                  title: Text(book.title),
                  trailing: book.removable
                      ? IconButton(
                          icon: const Icon(Icons.delete_outline),
                          tooltip: 'Rimuovi',
                          onPressed: () => _deleteBook(book),
                        )
                      : null,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ReaderScreen(book: book),
                      ),
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String? path;

  const _EmptyState({required this.path});

  @override
  Widget build(BuildContext context) {
    final uploadMode = BookRepository.supportsManualUpload;

    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.library_books_outlined, size: 64),
                const SizedBox(height: 16),
                const Text(
                  'Nessun libro trovato',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                if (uploadMode)
                  const Text(
                    "Tocca il pulsante '+' in basso per caricare un file "
                    '.txt dal telefono.',
                    textAlign: TextAlign.center,
                  )
                else ...[
                  const Text(
                    'Copia i tuoi file .txt in questa cartella, poi trascina '
                    'in basso per aggiornare:',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  SelectableText(
                    path ?? '',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 13,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
