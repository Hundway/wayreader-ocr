import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'dart:convert';
import 'ocr.dart';
import 'package:share_plus/share_plus.dart';

/// Main page that displays a search bar and a list of scanned items.
class HomePage extends StatefulWidget {
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<File> images = [];
  List<File> filteredImages = [];

  Set<String> selected = {};
  bool selectionMode = false;
  String searchText = "";

  final TextEditingController _searchController = TextEditingController();

  // ---------------- SELECTION ----------------

  void _enterSelectionMode() {
    setState(() => selectionMode = true);
  }

  void _toggleSelection(String path) {
    setState(() {
      if (selected.contains(path)) {
        selected.remove(path);
        if (selected.isEmpty) selectionMode = false;
      } else {
        selected.add(path);
      }
    });
  }

  void _clearSelection() {
    setState(() {
      selected.clear();
      selectionMode = false;
    });
  }

  // ---------------- DELETE ----------------

  Future<void> _deleteSelected() async {
    setState(() {
      images.clear();
      filteredImages.clear();
    });

    for (final path in selected) {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    }

    _clearSelection();
    await _loadImages();
  }

  Future<void> _shareSelected() async {
    if (selected.isEmpty) return;

    final List<XFile> files = selected.map((path) => XFile(path)).toList();

    try {
      final result = await SharePlus.instance.share(
        ShareParams(
          files: files,
          text: files.length == 1
              ? 'Sharing scan: ${basename(files.first.path)}'
              : 'Sharing ${files.length} scanned images',
        ),
      );

      if (result.status == ShareResultStatus.success) {
        debugPrint('Share successful');
      } else if (result.status == ShareResultStatus.dismissed) {
        debugPrint('Share dismissed by user');
      }
    } catch (e) {
      debugPrint('Error while sharing: $e');
    }
  }

  // ---------------- RENAME ----------------

  Future<void> _renameSelected(BuildContext context) async {
    if (selected.length != 1) return;

    final oldPath = selected.first;
    final oldFile = File(oldPath);

    final controller = TextEditingController(text: basename(oldPath));

    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Rename item"),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: "Enter new filename"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text("Rename"),
          ),
        ],
      ),
    );

    if (newName == null || newName.isEmpty) return;

    final directory = oldFile.parent.path;
    final newPath = join(directory, newName);

    setState(() {
      images.clear();
      filteredImages.clear();
    });

    await oldFile.rename(newPath);

    _clearSelection();
    await _loadImages();
  }

  // ---------------- SEARCH ----------------

  void _applySearch(String query) {
    setState(() {
      searchText = query.toLowerCase();

      filteredImages = images.where((file) {
        return basename(file.path).toLowerCase().contains(searchText);
      }).toList();
    });
  }

  // ---------------- LOAD ----------------

  @override
  void initState() {
    super.initState();
    _loadImages();
    _searchController.addListener(() {
      _applySearch(_searchController.text);
    });
  }

  Future<List<File>> _loadAssetImages() async {
    final manifestContent = await DefaultAssetBundle.of(
      this.context,
    ).loadString('AssetManifest.json');

    final manifestMap = Map<String, dynamic>.from(json.decode(manifestContent));

    final assetPaths = manifestMap.keys.where(
      (p) =>
          p.startsWith('assets/images/') &&
          (p.endsWith('.png') || p.endsWith('.jpg') || p.endsWith('.jpeg')),
    );

    final tempDir = await getTemporaryDirectory();
    final files = <File>[];

    for (final assetPath in assetPaths) {
      final data = await rootBundle.load(assetPath);
      final bytes = data.buffer.asUint8List();

      final file = File('${tempDir.path}/${basename(assetPath)}');
      await file.writeAsBytes(bytes, flush: true);
      files.add(file);
    }

    return files;
  }

  Future<void> _loadImages() async {
    final dir = await getApplicationDocumentsDirectory();
    final folder = Directory('${dir.path}/bookocr');

    List<File> localImages = [];
    if (await folder.exists()) {
      localImages = folder
          .listSync()
          .where(
            (f) =>
                f is File &&
                (f.path.endsWith('.jpg') ||
                    f.path.endsWith('.png') ||
                    f.path.endsWith('.jpeg')),
          )
          .map((f) => f as File)
          .toList();
    }

    final assetImages = await _loadAssetImages();

    setState(() {
      images = [...assetImages, ...localImages];
      filteredImages = images;
    });
  }

  // ---------------- UI ----------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      color: theme.colorScheme.surface,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            children: [
              _searchRow(),
              const SizedBox(height: 8),

              /// TOP ACTION BAR
              if (selectionMode)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('${selected.length} selected'),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.drive_file_rename_outline),
                          onPressed: selected.length == 1
                              ? () => _renameSelected(context)
                              : null,
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: selected.isNotEmpty
                              ? _deleteSelected
                              : null,
                        ),
                        IconButton(
                          icon: const Icon(Icons.share),
                          onPressed: selected.isNotEmpty
                              ? _shareSelected
                              : null,
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: _clearSelection,
                        ),
                      ],
                    ),
                  ],
                ),

              const SizedBox(height: 6),

              /// IMAGE LIST
              Expanded(
                child: ListView(
                  children: filteredImages.map((file) {
                    return Padding(
                      padding: const EdgeInsets.all(4),
                      child: ScanItem(
                        imagePath: file.path,
                        isSelected: selected.contains(file.path),
                        selectionMode: selectionMode,
                        onLongPress: () {
                          _enterSelectionMode();
                          _toggleSelection(file.path);
                        },
                        onTap: () {
                          if (selectionMode) {
                            _toggleSelection(file.path);
                          } else {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => OcrPage(imagePath: file.path),
                              ),
                            );
                          }
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// SEARCH FIELD ONLY (PopupMenu REMOVED)
  Widget _searchRow() {
    return TextField(
      controller: _searchController,
      decoration: const InputDecoration(
        border: OutlineInputBorder(),
        hintText: 'Search items',
        prefixIcon: Icon(Icons.search),
      ),
    );
  }
}

/// Represents a single item in the scan list.
class ScanItem extends StatefulWidget {
  final String imagePath;
  final bool isSelected;
  final bool selectionMode;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const ScanItem({
    super.key,
    required this.imagePath,
    required this.isSelected,
    required this.selectionMode,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  State<ScanItem> createState() => _ScanItemState();
}

class _ScanItemState extends State<ScanItem> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseName = basename(widget.imagePath);

    final file = File(widget.imagePath);
    final lastModified = file.lastModifiedSync();
    final formattedDate = DateFormat('dd/MM/yy HH:mm').format(lastModified);

    return GestureDetector(
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainer,
          border: widget.isSelected
              ? Border.all(color: theme.colorScheme.primaryFixed, width: 3)
              : null,
        ),
        height: 100,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              Image.file(File(widget.imagePath), height: 60, width: 60),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final availableWidth = constraints.maxWidth;
                      final titleStyle = theme.textTheme.titleSmall!;
                      final compressedTitle = _compressToFitMiddle(
                        baseName,
                        availableWidth,
                        titleStyle,
                      );

                      return Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(compressedTitle, style: titleStyle),
                          const SizedBox(height: 4),
                          Text(
                            formattedDate,
                            style: theme.textTheme.labelSmall,
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Measures the rendered width of a string with the given style.
  double _measureTextWidth(String text, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: ui.TextDirection.ltr,
      maxLines: 1,
    );
    painter.layout();
    return painter.width;
  }

  /// Compresses a string by inserting an ellipsis in the middle if it exceeds the available width.
  String _compressToFitMiddle(String input, double maxWidth, TextStyle style) {
    // Return the full string if it already fits.
    if (_measureTextWidth(input, style) <= maxWidth) return input;

    const ellipsis = ' ... ';

    int lo = 0;
    int hi = input.length;
    String best = input;

    // Binary search for the maximum number of characters that fit.
    while (lo <= hi) {
      final mid = (lo + hi) ~/ 2;
      final leftCount = mid ~/ 2;
      final rightCount = mid - leftCount;

      if (leftCount + rightCount >= input.length) {
        return input;
      }

      final candidate =
          '${input.substring(0, leftCount)}$ellipsis${input.substring(input.length - rightCount)}';
      final width = _measureTextWidth(candidate, style);

      if (width <= maxWidth) {
        best = candidate;
        lo = mid + 1;
      } else {
        hi = mid - 1;
      }
    }

    return best;
  }
}
