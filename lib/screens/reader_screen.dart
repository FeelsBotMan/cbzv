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
  const ReaderScreen({super.key});

  @override
  _ReaderScreenState createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  static const platform = MethodChannel('cbzv/volume');
  late FocusNode _focusNode;
  PageController? _pageController;
  CBZReaderProvider? _readerProvider;
  bool _isFullScreen = false;
  double _currentScale = 1.0;
  double _baseScale = 1.0;
  final double _minScale = 1.0;
  final double _maxScale = 3.0;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
      _initializeReader();
    });

    platform.setMethodCallHandler(_handleVolumeKey);
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _pageController?.dispose();
    _readerProvider?.removeListener(_onReaderProviderChanged);
    super.dispose();
  }

  Future<void> _handleVolumeKey(MethodCall call) async {
    if (call.method == 'handleVolumeKey') {
      String direction = call.arguments;
      if (direction == "up") {
        _changePage(1);
      } else if (direction == "down") {
        _changePage(-1);
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _readerProvider = Provider.of<CBZReaderProvider>(context, listen: false);
  }

  void _initializeReader() {
    _readerProvider?.addListener(_onReaderProviderChanged);
    if (_readerProvider != null && !_readerProvider!.isLoading) {
      _initPageController();
    }
  }

  void _onReaderProviderChanged() {
    if (_readerProvider != null &&
        !_readerProvider!.isLoading &&
        _pageController == null) {
      _initPageController();
    }
  }

  void _initPageController() {
    if (_readerProvider != null && _readerProvider!.pages.isNotEmpty) {
      setState(() {
        _pageController =
            PageController(initialPage: _readerProvider!.currentPageIndex);
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_pageController != null && _pageController!.hasClients) {
          _pageController!.jumpToPage(_readerProvider!.currentPageIndex);
        }
      });
    }
  }

  void _changePage(int delta) {
    if (!mounted || _pageController == null || _readerProvider == null) return;
    final newIndex = _readerProvider!.currentPageIndex + delta;
    if (newIndex >= 0 && newIndex < _readerProvider!.pages.length) {
      _readerProvider!.goToPage(newIndex).then((_) {
        if (_pageController != null && _pageController!.hasClients) {
          _pageController!.animateToPage(
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

        if (currentFile == null ||
            readerProvider.isLoading ||
            _pageController == null) {
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
          body: Stack(
            children: [
              _buildPhotoViewGallery(readerProvider),
              _buildFullscreenToggleArea(),
              _buildZoomGestureAreas(readerProvider),
              if (!_isFullScreen) _buildPageIndicator(readerProvider),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPhotoViewGallery(CBZReaderProvider readerProvider) {
    return KeyboardListener(
      focusNode: _focusNode,
      onKeyEvent: (KeyEvent event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
            _changePage(1);
          } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
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
        child: PhotoViewGallery.builder(
          itemCount: readerProvider.pages.length,
          builder: (context, index) {
            return PhotoViewGalleryPageOptions(
              imageProvider:
                  FileImage(File(readerProvider.pages[index].imagePath)),
              minScale: PhotoViewComputedScale.contained,
              maxScale: PhotoViewComputedScale.covered * 2,
              initialScale: readerProvider.currentScale,
              heroAttributes: PhotoViewHeroAttributes(tag: "page_$index"),
              onScaleEnd: (context, details, controllerValue) {
                readerProvider.setScale(controllerValue.scale ?? 1.0);
              },
            );
          },
          loadingBuilder: (context, event) => Center(
            child: Container(
              width: 20.0,
              height: 20.0,
              child: CircularProgressIndicator(
                value: event == null
                    ? 0
                    : event.cumulativeBytesLoaded / event.expectedTotalBytes!,
              ),
            ),
          ),
          backgroundDecoration: const BoxDecoration(color: Colors.black),
          pageController: _pageController!,
          onPageChanged: (index) {
            if (index != readerProvider.currentPageIndex) {
              readerProvider.goToPage(index);
            }
          },
        ),
      ),
    );
  }

  Widget _buildFullscreenToggleArea() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final centerWidth = constraints.maxWidth * 0.5;
        final centerHeight = constraints.maxHeight * 0.5;
        final leftPadding = (constraints.maxWidth - centerWidth) / 2;
        final topPadding = (constraints.maxHeight - centerHeight) / 2;

        return Positioned(
          left: leftPadding,
          top: topPadding,
          width: centerWidth,
          height: centerHeight,
          child: GestureDetector(
            onTap: _toggleFullScreen,
            behavior: HitTestBehavior.opaque,
            child: Container(color: Colors.transparent),
          ),
        );
      },
    );
  }

  Widget _buildZoomGestureAreas(CBZReaderProvider readerProvider) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final centerWidth = constraints.maxWidth * 0.5;
        final centerHeight = constraints.maxHeight * 0.5;
        final leftPadding = (constraints.maxWidth - centerWidth) / 2;
        final topPadding = (constraints.maxHeight - centerHeight) / 2;

        return Stack(
          children: [
            Positioned(
              left: 0,
              top: 0,
              right: 0,
              bottom: constraints.maxHeight - topPadding,
              child: _buildGestureDetector(readerProvider),
            ),
            Positioned(
              left: 0,
              top: topPadding + centerHeight,
              right: 0,
              bottom: 0,
              child: _buildGestureDetector(readerProvider),
            ),
            Positioned(
              left: 0,
              top: topPadding,
              width: leftPadding,
              height: centerHeight,
              child: _buildGestureDetector(readerProvider),
            ),
            Positioned(
              right: 0,
              top: topPadding,
              width: leftPadding,
              height: centerHeight,
              child: _buildGestureDetector(readerProvider),
            ),
          ],
        );
      },
    );
  }

  Widget _buildGestureDetector(CBZReaderProvider readerProvider) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onScaleStart: (details) {
        _baseScale = _currentScale;
      },
      onScaleUpdate: (details) {
        if (details.pointerCount == 2) {
          // Only zoom if two fingers are used
          setState(() {
            _currentScale =
                (_baseScale * details.scale).clamp(_minScale, _maxScale);
            readerProvider.setScale(_currentScale);
          });
        }
      },
      onHorizontalDragEnd: (details) {
        if (details.primaryVelocity == null) return;
        if (details.primaryVelocity! > 0) {
          // Swiped from left to right
          _changePage(-1);
        } else if (details.primaryVelocity! < 0) {
          // Swiped from right to left
          _changePage(1);
        }
      },
      child: Container(color: Colors.transparent),
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
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 2,
                  thumbShape:
                      const RoundSliderThumbShape(enabledThumbRadius: 6),
                  overlayShape:
                      const RoundSliderOverlayShape(overlayRadius: 14),
                ),
                child: Slider(
                  value: readerProvider.currentPageIndex.toDouble(),
                  min: 0,
                  max: (readerProvider.pages.length - 1).toDouble(),
                  onChanged: (value) {
                    _pageController?.jumpToPage(value.round());
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
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
                  if (_pageController != null && _pageController!.hasClients) {
                    _pageController!.jumpToPage(index);
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
