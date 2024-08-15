import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:cbzv/providers/cbz_providers.dart';
import 'package:cbzv/models/cbz_model.dart';

class ReaderScreen extends StatelessWidget {
  const ReaderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final readerProvider = Provider.of<CBZReaderProvider>(context);
    final CBZFile? currentFile = readerProvider.currentFile;

    if (currentFile == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('CBZ 리더')),
        body: const Center(child: Text('선택된 CBZ 파일이 없습니다.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(currentFile.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.list),
            onPressed: () => _showPageList(context, readerProvider),
          ),
        ],
      ),
      body: GestureDetector(
        onTapUp: (details) => _handleTap(context, details, readerProvider),
        child: PhotoViewGallery.builder(
          itemCount: readerProvider.pages.length,
          builder: (context, index) {
            return PhotoViewGalleryPageOptions(
              imageProvider:
                  FileImage(File(readerProvider.pages[index].imagePath)),
              minScale: PhotoViewComputedScale.contained,
              maxScale: PhotoViewComputedScale.covered * 2,
            );
          },
          scrollPhysics: const ClampingScrollPhysics(),
          backgroundDecoration: const BoxDecoration(color: Colors.black),
          pageController:
              PageController(initialPage: readerProvider.currentPageIndex),
          onPageChanged: (index) => readerProvider.goToPage(index),
        ),
      ),
    );
  }

  void _handleTap(BuildContext context, TapUpDetails details,
      CBZReaderProvider readerProvider) {
    final double screenWidth = MediaQuery.of(context).size.width;
    if (details.globalPosition.dx < screenWidth / 3) {
      readerProvider.previousPage();
    } else if (details.globalPosition.dx > 2 * screenWidth / 3) {
      readerProvider.nextPage();
    }
  }

  void _showPageList(BuildContext context, CBZReaderProvider readerProvider) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return ListView.builder(
          itemCount: readerProvider.pages.length,
          itemBuilder: (context, index) {
            return ListTile(
              title: Text('Page ${index + 1}'),
              onTap: () {
                readerProvider.goToPage(index);
                Navigator.pop(context);
              },
            );
          },
        );
      },
    );
  }
}
