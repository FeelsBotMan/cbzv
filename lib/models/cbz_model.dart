
class CBZFile {
  final String path;
  final String name;
  List<CBZPage> pages;

  CBZFile({required this.path, required this.name, this.pages = const []});
}

class CBZPage {
  final String imagePath;
  final int pageNumber;

  CBZPage({required this.imagePath, required this.pageNumber});
}

class CBZLibrary {
  final List<CBZFile> _cbzFiles; // 프라이빗 변수로 변경

  CBZLibrary() : _cbzFiles = []; // 생성자에서 빈 리스트로 초기화

  void addCBZFile(CBZFile file) {
    _cbzFiles.add(file);
  }

  void removeCBZFile(CBZFile file) {
    _cbzFiles.remove(file);
  }

  List<CBZFile> getCBZFiles() {
    return List.unmodifiable(_cbzFiles); // 수정 불가능한 리스트 뷰를 반환
  }
}
