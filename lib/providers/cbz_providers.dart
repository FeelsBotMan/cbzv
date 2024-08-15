import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:archive/archive.dart';
import 'package:cbzv/models/cbz_model.dart';

class CBZLibraryProvider with ChangeNotifier {
  final CBZLibrary _library = CBZLibrary();

  List<CBZFile> get cbzFiles => _library.getCBZFiles();

  Future<void> loadCBZFiles() async {
    final directory = await getApplicationDocumentsDirectory();
    final cbzDirectory = Directory('${directory.path}/cbz_files');

    if (await cbzDirectory.exists()) {
      final files = await cbzDirectory
          .list()
          .where((entity) =>
              entity is File &&
              path.extension(entity.path).toLowerCase() == '.cbz')
          .toList();

      for (var file in files) {
        final cbzFile =
            CBZFile(path: file.path, name: path.basename(file.path));
        _library.addCBZFile(cbzFile);
      }

      notifyListeners();
    }
  }

  Future<void> addCBZFile(File file) async {
    final directory = await getApplicationDocumentsDirectory();
    final cbzDirectory = Directory('${directory.path}/cbz_files');
    await cbzDirectory.create(recursive: true);

    final newPath = path.join(cbzDirectory.path, path.basename(file.path));
    await file.copy(newPath);

    final newCBZFile = CBZFile(path: newPath, name: path.basename(newPath));
    _library.addCBZFile(newCBZFile);

    notifyListeners();
  }

  Future<void> removeCBZFile(CBZFile cbzFile) async {
    await File(cbzFile.path).delete();
    _library.removeCBZFile(cbzFile);
    notifyListeners();
  }
}

class CBZReaderProvider with ChangeNotifier {
  CBZFile? _currentFile;
  List<CBZPage> _pages = [];
  int _currentPageIndex = 0;

  CBZFile? get currentFile => _currentFile;
  List<CBZPage> get pages => List.unmodifiable(_pages);
  int get currentPageIndex => _currentPageIndex;
  CBZPage? get currentPage =>
      _currentPageIndex < _pages.length ? _pages[_currentPageIndex] : null;

  Future<void> loadCBZFile(CBZFile file) async {
    _currentFile = file;
    _pages = [];
    _currentPageIndex = 0;

    final bytes = await File(file.path).readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    _pages = archive.files
        .where((file) =>
            file.isFile &&
            ['.jpg', '.jpeg', '.png', '.gif']
                .contains(path.extension(file.name).toLowerCase()))
        .map((file) {
      final tempDir = Directory.systemTemp.createTempSync();
      final tempFile = File('${tempDir.path}/${file.name}');
      tempFile.writeAsBytesSync(file.content as List<int>);
      return CBZPage(
        imagePath: tempFile.path,
        pageNumber: _pages.length + 1,
      );
    }).toList();

    _pages.sort((a, b) => a.imagePath.compareTo(b.imagePath));

    notifyListeners();
  }

  void nextPage() {
    if (_currentPageIndex < _pages.length - 1) {
      _currentPageIndex++;
      notifyListeners();
    }
  }

  void previousPage() {
    if (_currentPageIndex > 0) {
      _currentPageIndex--;
      notifyListeners();
    }
  }

  void goToPage(int pageIndex) {
    if (pageIndex >= 0 && pageIndex < _pages.length) {
      _currentPageIndex = pageIndex;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    // 임시 파일들 정리
    for (var page in _pages) {
      File(page.imagePath).deleteSync();
    }
    super.dispose();
  }
}
