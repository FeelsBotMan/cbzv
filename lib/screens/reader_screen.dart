import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:provider/provider.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:cbzv/providers/cbz_providers.dart';
import 'package:cbzv/models/cbz_model.dart';

class ReaderScreen extends StatefulWidget {
  const ReaderScreen({Key? key}) : super(key: key);

  @override
  _ReaderScreenState createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  late FocusNode _focusNode;
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _pageController = PageController();
    SystemChannels.platform.setMethodCallHandler(_handleSystemKeyEvent);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    SystemChannels.platform.setMethodCallHandler(null);
    _focusNode.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<dynamic> _handleSystemKeyEvent(MethodCall call) async {
    if (call.method == 'SystemChrome.keyEvent') {
      final Map<String, dynamic> args = call.arguments;
      final String type = args['type'];
      final int keyCode = args['keyCode'];

      if (type == 'keydown') {
        if (keyCode == 24) {
          // Volume Up
          print('Volume Up pressed');
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _changePage(1);
          });
          return true;
        } else if (keyCode == 25) {
          // Volume Down
          print('Volume Down pressed');
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _changePage(-1);
          });
          return true;
        }
      }
    }
    return null; // Let other handlers deal with the event
  }

  void _changePage(int delta) {
    if (!mounted) return;
    setState(() {
      final readerProvider =
          Provider.of<CBZReaderProvider>(context, listen: false);
      final newIndex = readerProvider.currentPageIndex + delta;
      if (newIndex >= 0 && newIndex < readerProvider.pages.length) {
        readerProvider.goToPage(newIndex);
        _pageController.animateToPage(
          newIndex,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CBZReaderProvider>(
      builder: (context, readerProvider, child) {
        print(
            'Building ReaderScreen. Current page index: ${readerProvider.currentPageIndex}');

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
          body: KeyboardListener(
            focusNode: _focusNode,
            onKeyEvent: (KeyEvent event) {
              if (event is KeyDownEvent) {
                print('Key pressed: ${event.logicalKey}');
                if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
                  print('Right arrow pressed');
                  _changePage(1);
                } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                  print('Left arrow pressed');
                  _changePage(-1);
                }
              }
            },
            child: Listener(
              onPointerSignal: (pointerSignal) {
                if (pointerSignal is PointerScrollEvent) {
                  if (pointerSignal.scrollDelta.dy > 0) {
                    _changePage(1);
                  } else if (pointerSignal.scrollDelta.dy < 0) {
                    _changePage(-1);
                  }
                }
              },
              child: GestureDetector(
                onTapUp: (details) => _handleTap(context, details),
                child: PhotoViewGallery.builder(
                  itemCount: readerProvider.pages.length,
                  builder: (context, index) {
                    return PhotoViewGalleryPageOptions(
                      imageProvider: FileImage(
                          File(readerProvider.pages[index].imagePath)),
                      minScale: PhotoViewComputedScale.contained,
                      maxScale: PhotoViewComputedScale.covered * 2,
                    );
                  },
                  scrollPhysics: const ClampingScrollPhysics(),
                  backgroundDecoration:
                      const BoxDecoration(color: Colors.black),
                  pageController: _pageController,
                  onPageChanged: (index) {
                    print('Page changed to $index');
                    if (index != readerProvider.currentPageIndex) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        readerProvider.goToPage(index);
                      });
                    }
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _handleTap(BuildContext context, TapUpDetails details) {
    final double screenWidth = MediaQuery.of(context).size.width;
    if (details.globalPosition.dx < screenWidth / 3) {
      _changePage(-1);
    } else if (details.globalPosition.dx > 2 * screenWidth / 3) {
      _changePage(1);
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
                _pageController.jumpToPage(index);
                Navigator.pop(context);
              },
            );
          },
        );
      },
    );
  }
}
