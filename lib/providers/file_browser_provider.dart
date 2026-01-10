import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/adapters.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class FileBrowserItem {
  final String path;
  final String name;
  final bool isDirectory;
  final bool isPinned;

  FileBrowserItem({
    required this.path,
    required this.name,
    required this.isDirectory,
    this.isPinned = false,
  });

  FileBrowserItem copyWith({
    String? path,
    String? name,
    bool? isDirectory,
    bool? isPinned,
  }) {
    return FileBrowserItem(
      path: path ?? this.path,
      name: name ?? this.name,
      isDirectory: isDirectory ?? this.isDirectory,
      isPinned: isPinned ?? this.isPinned,
    );
  }
}

class FileBrowserState {
  final String? rootPath;
  final String currentPath;
  final List<FileBrowserItem> items;
  final bool isLoading;
  final String? error;
  final bool isRootScreen;
  final List<FileBrowserItem> storages;
  final Map<String, double> scrollPositions;

  FileBrowserState({
    this.rootPath,
    this.currentPath = "",
    this.items = const [],
    this.isLoading = false,
    this.error,
    this.isRootScreen = true,
    this.storages = const [],
    this.scrollPositions = const {},
  });

  FileBrowserState copyWith({
    String? rootPath,
    String? currentPath,
    List<FileBrowserItem>? items,
    bool? isLoading,
    String? error,
    bool? isRootScreen,
    List<FileBrowserItem>? storages,
    Map<String, double>? scrollPositions,
  }) {
    return FileBrowserState(
      rootPath: rootPath ?? this.rootPath,
      currentPath: currentPath ?? this.currentPath,
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      isRootScreen: isRootScreen ?? this.isRootScreen,
      storages: storages ?? this.storages,
      scrollPositions: scrollPositions ?? this.scrollPositions,
    );
  }
}

class FileBrowserNotifier extends StateNotifier<FileBrowserState> {
  FileBrowserNotifier(this.ref) : super(FileBrowserState()) {
    //print("FileBrowserNotifier created: $hashCode");
  }

  final Ref ref;

  Future<void> init() async {
    state = state.copyWith(isLoading: true);
    final storages = await _getStorageVolumes();

    // Load scroll positions from Hive
    final box = Hive.box<double>('scroll_positions');
    final scrollPositions = <String, double>{};
    for (var key in box.keys) {
      if (key is String) {
        scrollPositions[key] = box.get(key) ?? 0.0;
      }
    }

    state = state.copyWith(
      storages: storages,
      isLoading: false,
      isRootScreen: true,
      items: storages,
      scrollPositions: scrollPositions,
    );
  }

  Future<bool> _ensurePermissions() async {
    if (!Platform.isAndroid) return true;
    var status = await Permission.manageExternalStorage.status;
    if (status.isGranted) return true;
    status = await Permission.manageExternalStorage.request();
    return status.isGranted;
  }

  Future<List<FileBrowserItem>> _getStorageVolumes() async {
    final List<FileBrowserItem> result = [];
    try {
      final dirs = await getExternalStorageDirectories();
      if (dirs != null) {
        for (final dir in dirs) {
          final parts = dir.path.split('/');
          if (parts.length >= 4 && parts[1] == "storage") {
            final root = "/storage/${parts[2]}";
            final isPrimary = root == "/storage/emulated";
            result.add(
              FileBrowserItem(
                path: isPrimary ? "/storage/emulated/0" : root,
                name: isPrimary ? "Internal Storage" : "SD Card",
                isDirectory: true,
              ),
            );
          }
        }
      }
    } catch (_) {}
    if (result.isEmpty) {
      result.add(
        FileBrowserItem(
          path: "/storage/emulated/0",
          name: "Internal Storage",
          isDirectory: true,
        ),
      );
    }
    return result;
  }

  Future<void> navigateTo(String path, {bool setRoot = false}) async {
    final parts = path.split('/');
    if (parts.length >= 4 && parts[1] == "storage") {
      final root = "/storage/${parts[2]}";
      final isPrimary = root == "/storage/emulated";
      state = state.copyWith(
        rootPath: isPrimary ? "/storage/emulated/0" : root,
        isRootScreen: false,
        currentPath: path,
      );
    }

    try {
      state = state.copyWith(isLoading: true, error: null);
      if (state.isRootScreen) {
        if (!await _ensurePermissions()) {
          state = state.copyWith(error: "Storage permission denied");
          return;
        }
      }
      final dir = Directory(path);
      if (!await dir.exists()) {
        state = state.copyWith(
          isLoading: false,
          error: "Directory does not exist",
        );
        return;
      }

      final entities = await dir.list(recursive: false).toList();
      final audioExtensions = {
        '.mp3',
        '.wav',
        '.flac',
        '.m4a',
        '.aac',
        '.ogg',
        '.opus',
      };

      final items = entities
          .where((e) {
            if (e is Directory) return true;
            final ext = p.extension(e.path).toLowerCase();
            return audioExtensions.contains(ext);
          })
          .map((e) {
            final name = p.basename(e.path);
            return FileBrowserItem(
              path: e.path,
              name: name.isEmpty ? "/" : name,
              isDirectory: e is Directory,
            );
          })
          .toList();

      items.sort((a, b) {
        if (a.isDirectory && !b.isDirectory) return -1;
        if (!a.isDirectory && b.isDirectory) return 1;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

      state = state.copyWith(
        rootPath: setRoot ? path : state.rootPath,
        currentPath: path,
        items: items,
        isLoading: false,
        isRootScreen: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> goBack() async {
    if (state.storages.any(
      (item) => p.normalize(item.path) == p.normalize(state.currentPath),
    )) {
      state = state.copyWith(
        isRootScreen: true,
        currentPath: "",
        items: state.storages,
      );
      return;
    }
    await navigateTo(Directory(state.currentPath).parent.path);
  }

  // Future<void> togglePin(FileBrowserItem item) async {
  //   print("togglePin");
  //   print(item.isPinned);
  // }

  void setScrollPosition(String path, double offset) {
    if (path.isEmpty) return;
    final newPositions = Map<String, double>.from(state.scrollPositions);
    newPositions[path] = offset;
    state = state.copyWith(scrollPositions: newPositions);

    // Persist to Hive
    final box = Hive.box<double>('scroll_positions');
    box.put(path, offset);
  }
}

final fileBrowserProvider =
    StateNotifierProvider<FileBrowserNotifier, FileBrowserState>((ref) {
      final notifier = FileBrowserNotifier(ref);
      notifier.init();
      return notifier;
    });
