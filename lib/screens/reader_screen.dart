import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:cbzv/providers/cbz_providers.dart';
import 'package:cbzv/models/cbz_model.dart';

class ReaderScreen extends StatefulWidget {
  const ReaderScreen({super.key});

  @override
  _ReaderScreenState createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  static const platform = MethodChannel('cbzv/volume');
  final GlobalKey _photoViewKey = GlobalKey();
  late FocusNode _focusNode;
  late PageController _pageController;
  late CBZReaderProvider _readerProvider;
  bool _isFullScreen = false;
  double _currentScale = 1.0;
  double _baseScale = 1.0;
  final double _minScale = 1.0;
  final double _maxScale = 3.0;
  late Size _screenSize;
  int _pointerCount = 0;
  double _dragStartX = 0.0;
  double _dragStartY = 0.0;
  bool _isDragging = false;
  bool _isZooming = false;
  DateTime? _dragStartTime;
  double _maxDragDistance = 0.0;
  final List<Offset> _dragPath = [];
  static const int _pathSampleRate = 5; // 경로 샘플링 속도
  static const double _dragThreshold = 50.0;
  static const Duration _dragTimeThreshold = Duration(milliseconds: 200);

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
  void didChangeDependencies() {
    super.didChangeDependencies();
    _screenSize = MediaQuery.of(context).size;
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
        _changePage(1); // Changed to next page
      } else if (direction == "down") {
        _changePage(-1); // Changed to previous page
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
    return Listener(
      onPointerDown: _handlePointerDown,
      onPointerMove: _handlePointerMove,
      onPointerUp: _handlePointerUp,
      onPointerCancel: _handlePointerCancel,
      child: GestureDetector(
        onScaleStart: _handleScaleStart,
        onScaleUpdate: (details) => _handleScaleUpdate(details, readerProvider),
        onScaleEnd: _handleScaleEnd,
        child: Stack(
          children: [
            _buildPhotoViewGallery(readerProvider),
            if (!_isFullScreen) _buildPageIndicator(readerProvider),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoViewGallery(CBZReaderProvider readerProvider) {
    return PhotoViewGallery.builder(
      key: _photoViewKey,
      itemCount: readerProvider.pages.length,
      builder: (context, index) {
        return PhotoViewGalleryPageOptions(
          imageProvider: FileImage(File(readerProvider.pages[index].imagePath)),
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

  bool _isShortTap() {
    if (_dragPath.length < 2) return true;

    Offset start = _dragPath.first;
    Offset end = _dragPath.last;
    double distance = (end - start).distance;

    Duration tapDuration = DateTime.now().difference(_dragStartTime!);

    return distance < _dragThreshold && tapDuration < _dragTimeThreshold;
  }

  void _handlePointerDown(PointerDownEvent event) {
    _dragStartX = event.position.dx;
    _dragStartY = event.position.dy;
    _dragStartTime = DateTime.now();
    _isDragging = false;
    _pointerCount++;
    if (_pointerCount > 1) {
      _isZooming = true;
    }
    _maxDragDistance = 0.0;
    _dragPath.clear();
    _dragPath.add(event.position);
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (_pointerCount == 1 && !_isZooming) {
      Offset currentPosition = event.position;
      _dragPath.add(currentPosition);
      if (_dragPath.length > _pathSampleRate) {
        _dragPath.removeAt(0);
      }

      double dragDistanceX = currentPosition.dx - _dragStartX;
      double dragDistanceY = currentPosition.dy - _dragStartY;
      double currentDragDistance =
          sqrt(dragDistanceX * dragDistanceX + dragDistanceY * dragDistanceY);

      _maxDragDistance = max(_maxDragDistance, currentDragDistance);

      Duration dragDuration = DateTime.now().difference(_dragStartTime!);

      if (!_isDragging &&
          dragDuration < _dragTimeThreshold &&
          _maxDragDistance > _dragThreshold) {
        _isDragging = true;
        if (dragDistanceX.abs() > dragDistanceY.abs()) {
          // Horizontal drag - change page
          if (dragDistanceX > 0) {
            _changePage(-1);
          } else {
            _changePage(1);
          }
        } else {
          // Vertical drag - you can implement custom behavior here if needed
        }
      }
    }
  }

  void _handlePointerUp(PointerUpEvent event) {
    _pointerCount--;
    if (_pointerCount == 0) {
      if (!_isDragging && !_isZooming) {
        if (_maxDragDistance < _dragThreshold && _isShortTap()) {
          final tapPosition = event.position;
          final screenWidth = _screenSize.width;

          if (tapPosition.dx < screenWidth * 0.2) {
            _changePage(-1);
          } else if (tapPosition.dx > screenWidth * 0.8) {
            _changePage(1);
          } else {
            _toggleFullScreen();
          }
        }
      }
      _isZooming = false;
      _isDragging = false;
    }
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    _pointerCount = 0;
    _isZooming = false;
    _isDragging = false;
  }

  void _handleScaleStart(ScaleStartDetails details) {
    _baseScale = _currentScale;
  }

  void _handleScaleUpdate(
      ScaleUpdateDetails details, CBZReaderProvider readerProvider) {
    if (_pointerCount == 2) {
      setState(() {
        _currentScale =
            (_baseScale * details.scale).clamp(_minScale, _maxScale);
        readerProvider.setScale(_currentScale);
      });
    }
  }

  void _handleScaleEnd(ScaleEndDetails details) {
    // 핀치 줌이 끝난 후 처리
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
