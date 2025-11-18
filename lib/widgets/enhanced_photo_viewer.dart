import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

class EnhancedPhotoViewer extends StatefulWidget {
  final List<String> photoUrls;
  final int initialIndex;
  final List<String>? photoLabels;
  final List<DateTime>? photoTimestamps;
  final bool enableComparison;

  const EnhancedPhotoViewer({
    super.key,
    required this.photoUrls,
    this.initialIndex = 0,
    this.photoLabels,
    this.photoTimestamps,
    this.enableComparison = true,
  });

  @override
  State<EnhancedPhotoViewer> createState() => _EnhancedPhotoViewerState();
}

class _EnhancedPhotoViewerState extends State<EnhancedPhotoViewer> {
  late PageController _pageController;
  late int _currentIndex;
  bool _isComparisonMode = false;
  int? _comparisonIndex;
  final TransformationController _transformationController = TransformationController();

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _transformationController.dispose();
    super.dispose();
  }

  void _toggleComparisonMode() {
    setState(() {
      _isComparisonMode = !_isComparisonMode;
      if (_isComparisonMode && _comparisonIndex == null) {
        // Default to previous photo if available
        _comparisonIndex = _currentIndex > 0 ? _currentIndex - 1 : null;
      }
    });
  }

  void _resetZoom() {
    _transformationController.value = Matrix4.identity();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black.withOpacity(0.7),
        foregroundColor: Colors.white,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          '${_currentIndex + 1} of ${widget.photoUrls.length}',
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          if (widget.enableComparison && widget.photoUrls.length > 1)
            IconButton(
              icon: Icon(_isComparisonMode ? Icons.compare : Icons.compare_outlined),
              onPressed: _toggleComparisonMode,
              tooltip: 'Compare Photos',
            ),
          IconButton(
            icon: const Icon(Icons.zoom_out_map),
            onPressed: _resetZoom,
            tooltip: 'Reset Zoom',
          ),
        ],
      ),
      body: Column(
        children: [
          // Main photo area
          Expanded(
            child: _isComparisonMode && _comparisonIndex != null
                ? _buildComparisonView()
                : _buildSinglePhotoView(),
          ),

          // Photo info bar
          Container(
            color: Colors.black.withOpacity(0.7),
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.photoLabels != null && widget.photoLabels!.length > _currentIndex)
                  Text(
                    widget.photoLabels![_currentIndex],
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                if (widget.photoTimestamps != null && widget.photoTimestamps!.length > _currentIndex) ...[
                  const SizedBox(height: 4),
                  Text(
                    _formatTimestamp(widget.photoTimestamps![_currentIndex]),
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 14,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Thumbnail strip
          if (widget.photoUrls.length > 1) _buildThumbnailStrip(),
        ],
      ),
    );
  }

  Widget _buildSinglePhotoView() {
    return PageView.builder(
      controller: _pageController,
      itemCount: widget.photoUrls.length,
      onPageChanged: (index) {
        setState(() {
          _currentIndex = index;
          _resetZoom();
        });
      },
      itemBuilder: (context, index) {
        return _buildZoomablePhoto(widget.photoUrls[index]);
      },
    );
  }

  Widget _buildComparisonView() {
    return Row(
      children: [
        // Current photo
        Expanded(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                color: AppTheme.primaryColor.withOpacity(0.8),
                child: const Text(
                  'Current',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Expanded(
                child: _buildZoomablePhoto(widget.photoUrls[_currentIndex]),
              ),
            ],
          ),
        ),
        
        // Divider
        Container(
          width: 2,
          color: Colors.white.withOpacity(0.5),
        ),
        
        // Comparison photo
        Expanded(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                color: AppTheme.successColor.withOpacity(0.8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios, size: 16),
                      color: Colors.white,
                      onPressed: _comparisonIndex! > 0
                          ? () {
                              setState(() {
                                _comparisonIndex = _comparisonIndex! - 1;
                              });
                            }
                          : null,
                    ),
                    Text(
                      'Photo ${_comparisonIndex! + 1}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.arrow_forward_ios, size: 16),
                      color: Colors.white,
                      onPressed: _comparisonIndex! < widget.photoUrls.length - 1
                          ? () {
                              setState(() {
                                _comparisonIndex = _comparisonIndex! + 1;
                              });
                            }
                          : null,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _buildZoomablePhoto(widget.photoUrls[_comparisonIndex!]),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildZoomablePhoto(String photoUrl) {
    return InteractiveViewer(
      transformationController: _transformationController,
      minScale: 0.5,
      maxScale: 4.0,
      child: Center(
        child: Image.network(
          photoUrl,
          fit: BoxFit.contain,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return const Center(
              child: CircularProgressIndicator(
                color: AppTheme.primaryColor,
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            debugPrint('❌ Error loading photo in viewer: $error');
            debugPrint('Photo URL: $photoUrl');
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.broken_image_outlined,
                    size: 80,
                    color: Colors.white54,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Failed to load photo',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildThumbnailStrip() {
    return Container(
      height: 100,
      color: Colors.black.withOpacity(0.7),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.all(8),
        itemCount: widget.photoUrls.length,
        itemBuilder: (context, index) {
          final isSelected = index == _currentIndex;
          final isComparison = _isComparisonMode && index == _comparisonIndex;
          
          return GestureDetector(
            onTap: () {
              if (_isComparisonMode) {
                setState(() {
                  _comparisonIndex = index;
                });
              } else {
                _pageController.animateToPage(
                  index,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              }
            },
            child: Container(
              width: 80,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                border: Border.all(
                  color: isSelected
                      ? AppTheme.primaryColor
                      : isComparison
                          ? AppTheme.successColor
                          : Colors.transparent,
                  width: 3,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.network(
                  widget.photoUrls[index],
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      color: Colors.grey[800],
                      child: const Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: Colors.grey[800],
                    child: const Icon(
                      Icons.broken_image,
                      color: Colors.white54,
                      size: 24,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays == 0) {
      return 'Today at ${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    }
  }
}

