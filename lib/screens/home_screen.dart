import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import 'package:cbzv/models/cbz_model.dart';
import 'package:cbzv/providers/cbz_providers.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    // Android 14 이상에서는 Photos 권한을 요청합니다.
    // iOS에서는 photos 권한이 적절합니다.
    Map<Permission, PermissionStatus> statuses = await [
      Permission.photos,
    ].request();

    if (statuses[Permission.photos]!.isGranted) {
      // 권한이 부여되면 CBZ 파일을 로드합니다.
      Provider.of<CBZLibraryProvider>(context, listen: false).loadCBZFiles();
    } else {
      // 권한이 거부되면 사용자에게 알립니다.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('CBZ 파일에 접근하기 위해 사진 라이브러리 접근 권한이 필요합니다.')),
      );
    }
  }

  Future<void> _addCBZFile() async {
    // 파일 선택기를 열기 전에 권한을 다시 확인합니다.
    if (await Permission.photos.request().isGranted) {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['cbz'],
      );

      if (result != null) {
        File file = File(result.files.single.path!);
        await Provider.of<CBZLibraryProvider>(context, listen: false)
            .addCBZFile(file);
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('CBZ 파일을 추가하기 위해 사진 라이브러리 접근 권한이 필요합니다.')),
      );
    }
  }

  void _openCBZFile(CBZFile cbzFile) {
    Provider.of<CBZReaderProvider>(context, listen: false).loadCBZFile(cbzFile);
    Navigator.pushNamed(context, '/reader');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CBZ 뷰어'),
      ),
      body: Consumer<CBZLibraryProvider>(
        builder: (context, libraryProvider, child) {
          if (libraryProvider.cbzFiles.isEmpty) {
            return const Center(
              child: Text('CBZ 파일이 없습니다. 추가 버튼을 눌러 CBZ 파일을 추가하세요.'),
            );
          }
          return ListView.builder(
            itemCount: libraryProvider.cbzFiles.length,
            itemBuilder: (context, index) {
              CBZFile cbzFile = libraryProvider.cbzFiles[index];
              return ListTile(
                title: Text(cbzFile.name),
                onTap: () => _openCBZFile(cbzFile),
                trailing: IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () async {
                    await libraryProvider.removeCBZFile(cbzFile);
                  },
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addCBZFile,
        tooltip: 'CBZ 파일 추가',
        child: const Icon(Icons.add),
      ),
    );
  }
}
