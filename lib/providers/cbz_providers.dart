import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:archive/archive.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

    try {
      final prefs = await SharedPreferences.getInstance();
      _currentPageIndex = prefs.getInt('lastPage_${file.path}') ?? 0;

      final bytes = await File(file.path).readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      final tempDir = await getTemporaryDirectory();
      final cbzTempDir = await Directory(
              '${tempDir.path}/cbz_temp/${path.basenameWithoutExtension(file.path)}')
          .create(recursive: true);

      final futures = archive.files
          .where((file) =>
              file.isFile &&
              ['.jpg', '.jpeg', '.png', '.gif']
                  .contains(path.extension(file.name).toLowerCase()))
          .map((file) async {
        final tempFilePath = path.join(cbzTempDir.path, file.name);
        final tempFileDir = Directory(path.dirname(tempFilePath));

        try {
          await tempFileDir.create(recursive: true);
          final tempFile = File(tempFilePath);
          await tempFile.writeAsBytes(file.content as List<int>);
          return CBZPage(
            imagePath: tempFile.path,
            pageNumber: _pages.length + 1,
          );
        } catch (e) {
          print('Error writing file ${file.name}: $e');
          return null;
        }
      });

      final results = await Future.wait(futures);
      _pages = results.whereType<CBZPage>().toList();
      _pages.sort((a, b) => a.imagePath.compareTo(b.imagePath));

      notifyListeners();
    } catch (e) {
      print('Error loading CBZ file: $e');
    }
  }

  Future<void> goToPage(int index) async {
    if (index >= 0 && index < _pages.length) {
      _currentPageIndex = index;
      notifyListeners();

      if (_currentFile != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('lastPage_${_currentFile!.path}', index);
      }
    }
  }

  void nextPage() {
    goToPage(_currentPageIndex + 1);
  }

  void previousPage() {
    goToPage(_currentPageIndex - 1);
  }

  @override
  void dispose() {
    // 임시 파일들 정리
    if (_currentFile != null) {
      final tempDir = Directory(
          '${Directory.systemTemp.path}/cbz_temp/${path.basenameWithoutExtension(_currentFile!.path)}');
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    }
    super.dispose();
  }
}
