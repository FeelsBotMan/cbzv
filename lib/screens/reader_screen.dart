import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  static const platform = MethodChannel('cbzv/volume');
  late FocusNode _focusNode;
  late PageController _pageController;
  late CBZReaderProvider _readerProvider;
  bool _isFullScreen = false;
  double _currentScale = 1.0;
  double _baseScale = 1.0;
  final double _minScale = 1.0;
  final double _maxScale = 3.0;
  double _dragStartX = 0.0;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _readerProvider = Provider.of<CBZReaderProvider>(context, listen: false);
    _pageController =
        PageController(initialPage: _readerProvider.currentPageIndex);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
      _initializeReader();
    });

    platform.setMethodCallHandler(_handleVolumeKey);
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _pageController.dispose();
    _readerProvider.removeListener(_onReaderProviderChanged);
    super.dispose();
  }

  Future<void> _handleVolumeKey(MethodCall call) async {
    if (call.method == 'handleVolumeKey') {
      String direction = call.arguments;
      if (direction == "up") {
        _changePage(-1); // Changed to previous page
      } else if (direction == "down") {
        _changePage(1); // Changed to next page
      }
    }
  }

  void _initializeReader() {
    _readerProvider.addListener(_onReaderProviderChanged);
    if (!_readerProvider.isLoading) {
      _pageController.jumpToPage(_readerProvider.currentPageIndex);
    }
  }

  void _onReaderProviderChanged() {
    if (!_readerProvider.isLoading && _pageController.hasClients) {
      _pageController.jumpToPage(_readerProvider.currentPageIndex);
    }
  }

  void _changePage(int delta) {
    if (!mounted) return;
    final newIndex = _readerProvider.currentPageIndex + delta;
    if (newIndex >= 0 && newIndex < _readerProvider.pages.length) {
      _readerProvider.goToPage(newIndex).then((_) {
        if (_pageController.hasClients) {
          _pageController.animateToPage(
            newIndex,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
      });
    }
  }

  void _toggleFullScreen() {
    setState(() {
      _isFullScreen = !_isFullScreen;
    });
    SystemChrome.setEnabledSystemUIMode(
      _isFullScreen ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CBZReaderProvider>(
      builder: (context, readerProvider, child) {
        final CBZFile? currentFile = readerProvider.currentFile;

        if (currentFile == null || readerProvider.isLoading) {
          return Scaffold(
            appBar: AppBar(title: const Text('CBZ 리더')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        return Scaffold(
          appBar: _isFullScreen
              ? null
              : AppBar(
                  title: Text(currentFile.name),
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.list),
                      onPressed: () => _showPageList(context, readerProvider),
                    ),
                  ],
                ),
          body: _buildBody(readerProvider),
        );
      },
    );
  }

  Widget _buildBody(CBZReaderProvider readerProvider) {
    return GestureDetector(
      onScaleStart: _handleScaleStart,
      onScaleUpdate: (details) => _handleScaleUpdate(details, readerProvider),
      onScaleEnd: _handleScaleEnd,
      child: Stack(
        children: [
          _buildPhotoViewGallery(readerProvider),
          if (!_isFullScreen) _buildPageIndicator(readerProvider),
        ],
      ),
    );
  }

  Widget _buildPhotoViewGallery(CBZReaderProvider readerProvider) {
    return Stack(
      children: [
        PhotoViewGallery.builder(
          itemCount: readerProvider.pages.length,
          builder: (context, index) {
            return PhotoViewGalleryPageOptions(
              imageProvider:
                  FileImage(File(readerProvider.pages[index].imagePath)),
              minScale: _minScale,
              maxScale: _maxScale,
              initialScale: readerProvider.currentScale,
              heroAttributes: PhotoViewHeroAttributes(tag: "page_$index"),
              errorBuilder: (context, error, stackTrace) {
                return Center(child: Text('이미지 로드 실패: $error'));
              },
              onScaleEnd: (context, details, controllerValue) {
                readerProvider.setScale(controllerValue.scale ?? 1.0);
              },
            );
          },
          loadingBuilder: (context, event) => Center(
            child: CircularProgressIndicator(
              value: event == null
                  ? 0
                  : event.cumulativeBytesLoaded / event.expectedTotalBytes!,
            ),
          ),
          backgroundDecoration: const BoxDecoration(color: Colors.black),
          pageController: _pageController,
          onPageChanged: (index) {
            if (index != readerProvider.currentPageIndex) {
              readerProvider.goToPage(index);
            }
          },
        ),
        _buildGestureAreas(readerProvider),
      ],
    );
  }

  Widget _buildGestureAreas(CBZReaderProvider readerProvider) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;

        return Stack(
          children: [
            // Left area for previous page
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: width * 0.2,
              child: GestureDetector(
                onTap: () => _changePage(-1),
                behavior: HitTestBehavior.translucent,
              ),
            ),
            // Right area for next page
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              width: width * 0.2,
              child: GestureDetector(
                onTap: () => _changePage(1),
                behavior: HitTestBehavior.translucent,
              ),
            ),
            // Center area for toggling UI
            Positioned(
              left: width * 0.2,
              right: width * 0.2,
              top: 0,
              bottom: 0,
              child: GestureDetector(
                onTap: _toggleFullScreen,
                onDoubleTap: () {
                  // Reset zoom or implement custom double-tap behavior
                  readerProvider.setScale(_minScale);
                },
                onLongPress: _toggleFullScreen,
                behavior: HitTestBehavior.translucent,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPageIndicator(CBZReaderProvider readerProvider) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        color: Colors.black.withOpacity(0.5),
        child: Row(
          children: [
            Text(
              '${readerProvider.currentPageIndex + 1} / ${readerProvider.pages.length}',
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Slider(
                value: readerProvider.currentPageIndex.toDouble(),
                min: 0,
                max: (readerProvider.pages.length - 1).toDouble(),
                onChanged: (value) {
                  _pageController.jumpToPage(value.round());
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleScaleStart(ScaleStartDetails details) {
    _baseScale = _currentScale;
    if (details.pointerCount == 1) {
      _dragStartX = details.localFocalPoint.dx;
      _isDragging = false;
    }
  }

  void _handleScaleUpdate(
      ScaleUpdateDetails details, CBZReaderProvider readerProvider) {
    if (details.pointerCount == 2) {
      setState(() {
        _currentScale =
            (_baseScale * details.scale).clamp(_minScale, _maxScale);
        readerProvider.setScale(_currentScale);
      });
    } else if (details.pointerCount == 1) {
      double dragDistance = details.localFocalPoint.dx - _dragStartX;
      if (!_isDragging && dragDistance.abs() > 50) {
        _isDragging = true;
        if (dragDistance > 0) {
          _changePage(-1);
        } else {
          _changePage(1);
        }
      }
    }
  }

  void _handleScaleEnd(ScaleEndDetails details) {
    _isDragging = false;
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
                readerProvider.goToPage(index).then((_) {
                  if (_pageController.hasClients) {
                    _pageController.jumpToPage(index);
                  }
                  Navigator.pop(context);
                });
              },
            );
          },
        );
      },
    );
  }
}
