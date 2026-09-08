import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app_installer/flutter_app_installer.dart';
import 'package:image_picker/image_picker.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract final class KitchenColors {
  static const background = Color(0xff160b22);
  static const surface = Color(0xff281438);
  static const surfaceBright = Color(0xff38204d);
  static const pink = Color(0xffff6eb5);
  static const gold = Color(0xffffc44d);
  static const text = Color(0xffffeff8);
  static const muted = Color(0xffc9aecb);
}

class AppUpdate {
  const AppUpdate({
    required this.versionCode,
    required this.versionName,
    required this.title,
    required this.changelog,
    required this.forceUpdate,
    required this.apkUrl,
  });

  final int versionCode;
  final String versionName;
  final String title;
  final String changelog;
  final bool forceUpdate;
  final String apkUrl;

  factory AppUpdate.fromJson(Map<String, dynamic> json) => AppUpdate(
    versionCode: json['versionCode'] as int,
    versionName: json['versionName'] as String,
    title: json['title'] as String? ?? '发现新版本',
    changelog: json['changelog'] as String? ?? '',
    forceUpdate: json['forceUpdate'] as bool? ?? false,
    apkUrl: json['apkUrl'] as String,
  );
}

class UpdateService {
  static const _metadataUrl =
      'https://raw.githubusercontent.com/zezakgong/gg/main/lohouse/update.json';
  final Dio _dio = Dio();

  Future<AppUpdate?> findUpdate() async {
    if (!Platform.isAndroid) return null;
    final response = await _dio
        .get<String>(_metadataUrl)
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != HttpStatus.ok || response.data == null) {
      return null;
    }
    final update = AppUpdate.fromJson(
      jsonDecode(response.data!) as Map<String, dynamic>,
    );
    final local = await PackageInfo.fromPlatform();
    final localCode = int.tryParse(local.buildNumber) ?? 0;
    return update.versionCode > localCode ? update : null;
  }

  Future<void> downloadAndInstall(
    AppUpdate update,
    void Function(int received, int total) onProgress,
  ) async {
    final directory = await getExternalStorageDirectory();
    if (directory == null) throw StateError('无法获取更新文件的存储目录');
    final apk = File(
      '${directory.path}${Platform.pathSeparator}guoguo-kitchen-update.apk',
    );
    if (await apk.exists()) await apk.delete();
    await _dio.download(
      update.apkUrl,
      apk.path,
      onReceiveProgress: onProgress,
      options: Options(receiveTimeout: const Duration(minutes: 5)),
    );
    await FlutterAppInstaller().installApk(filePath: apk.path);
  }
}

void main() => runApp(const GuoguoKitchenApp());

class GuoguoKitchenApp extends StatelessWidget {
  const GuoguoKitchenApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: '果果厨房',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme.dark(
        primary: KitchenColors.pink,
        onPrimary: Color(0xff310d2b),
        secondary: KitchenColors.gold,
        onSecondary: Color(0xff332006),
        surface: KitchenColors.surface,
        onSurface: KitchenColors.text,
        primaryContainer: Color(0xff59315e),
        onPrimaryContainer: Color(0xffffd9ee),
      ),
      scaffoldBackgroundColor: KitchenColors.background,
      appBarTheme: const AppBarTheme(
        backgroundColor: KitchenColors.background,
        foregroundColor: KitchenColors.text,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: KitchenColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: KitchenColors.surface,
        selectedColor: KitchenColors.pink,
        secondarySelectedColor: KitchenColors.pink,
        labelStyle: const TextStyle(color: KitchenColors.muted),
        secondaryLabelStyle: const TextStyle(
          color: Color(0xff300d2a),
          fontWeight: FontWeight.bold,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: KitchenColors.surfaceBright,
        labelStyle: const TextStyle(color: KitchenColors.muted),
        hintStyle: const TextStyle(color: Color(0xffaa8db2)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xff543466)),
        ),
      ),
    ),
    home: const RecipeHomePage(),
  );
}

class Ingredient {
  Ingredient({this.name = '', this.amount = ''});
  String name;
  String amount;
}

class RecipeStep {
  RecipeStep({this.description = '', List<XFile>? images})
    : images = images ?? [];
  String description;
  final List<XFile> images;
}

class Recipe {
  Recipe({
    required this.name,
    required this.category,
    required this.coverImages,
    required this.ingredients,
    required this.steps,
    required this.tip,
  });
  final String name;
  final String category;
  final List<XFile> coverImages;
  final List<Ingredient> ingredients;
  final List<RecipeStep> steps;
  final String tip;
}

class RecipeCodec {
  static Map<String, dynamic> toJson(
    Recipe recipe, {
    String Function(String path)? pathMapper,
  }) {
    final mapPath = pathMapper ?? (path) => path;
    return {
      'name': recipe.name,
      'category': recipe.category,
      'coverImages': recipe.coverImages
          .map((image) => mapPath(image.path))
          .toList(),
      'ingredients': recipe.ingredients
          .map((item) => {'name': item.name, 'amount': item.amount})
          .toList(),
      'steps': recipe.steps
          .map(
            (step) => {
              'description': step.description,
              'images': step.images
                  .map((image) => mapPath(image.path))
                  .toList(),
            },
          )
          .toList(),
      'tip': recipe.tip,
    };
  }

  static Recipe fromJson(
    Map<String, dynamic> json, {
    String Function(String path)? pathMapper,
  }) {
    final mapPath = pathMapper ?? (path) => path;
    return Recipe(
      name: json['name'] as String? ?? '',
      category: json['category'] as String? ?? '其他',
      coverImages: (json['coverImages'] as List<dynamic>? ?? [])
          .whereType<String>()
          .map((path) => XFile(mapPath(path)))
          .toList(),
      ingredients: (json['ingredients'] as List<dynamic>? ?? [])
          .whereType<Map>()
          .map(
            (item) => Ingredient(
              name: item['name'] as String? ?? '',
              amount: item['amount'] as String? ?? '',
            ),
          )
          .toList(),
      steps: (json['steps'] as List<dynamic>? ?? [])
          .whereType<Map>()
          .map(
            (item) => RecipeStep(
              description: item['description'] as String? ?? '',
              images: (item['images'] as List<dynamic>? ?? [])
                  .whereType<String>()
                  .map((path) => XFile(mapPath(path)))
                  .toList(),
            ),
          )
          .toList(),
      tip: json['tip'] as String? ?? '',
    );
  }
}

class RecipeStore {
  static const _recipesKey = 'recipes_v1';

  static Future<Directory> _mediaDirectory() async {
    final documents = await getApplicationDocumentsDirectory();
    final directory = Directory(
      '${documents.path}${Platform.pathSeparator}recipe_images',
    );
    if (!await directory.exists()) await directory.create(recursive: true);
    return directory;
  }

  static Future<List<XFile>> persistImages(List<XFile> images) async {
    final directory = await _mediaDirectory();
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    final copied = <XFile>[];
    for (var index = 0; index < images.length; index++) {
      final source = File(images[index].path);
      if (!await source.exists()) continue;
      final extension = source.path.contains('.')
          ? source.path.substring(source.path.lastIndexOf('.'))
          : '.jpg';
      final target = File(
        '${directory.path}${Platform.pathSeparator}${timestamp}_$index$extension',
      );
      await source.copy(target.path);
      copied.add(XFile(target.path));
    }
    return copied;
  }

  static Future<List<Recipe>> load() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_recipesKey);
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List<dynamic>)
          .whereType<Map>()
          .map((item) => RecipeCodec.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> save(List<Recipe> recipes) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _recipesKey,
      jsonEncode(recipes.map(RecipeCodec.toJson).toList()),
    );
  }

  static Future<File> exportRecipes(List<Recipe> recipes) async {
    if (!Platform.isAndroid) {
      throw UnsupportedError('目前仅支持 Android 导出备份');
    }
    var permission = await Permission.manageExternalStorage.status;
    if (!permission.isGranted) {
      permission = await Permission.manageExternalStorage.request();
    }
    if (!permission.isGranted) {
      throw StateError('需要“管理所有文件”权限才能导出到手机根目录');
    }

    final archive = Archive();
    final imageNames = <String, String>{};
    var imageIndex = 0;
    Future<String> archivePathFor(String path) async {
      if (imageNames.containsKey(path)) return imageNames[path]!;
      final file = File(path);
      if (!await file.exists()) return '';
      final extension = path.contains('.')
          ? path.substring(path.lastIndexOf('.'))
          : '.jpg';
      final archivePath = 'images/${imageIndex++}$extension';
      archive.addFile(
        ArchiveFile(archivePath, await file.length(), await file.readAsBytes()),
      );
      imageNames[path] = archivePath;
      return archivePath;
    }

    final exported = <Map<String, dynamic>>[];
    for (final recipe in recipes) {
      final paths = <String, String>{};
      final allImages = [
        ...recipe.coverImages,
        ...recipe.steps.expand((step) => step.images),
      ];
      for (final image in allImages) {
        paths[image.path] = await archivePathFor(image.path);
      }
      exported.add(
        RecipeCodec.toJson(recipe, pathMapper: (path) => paths[path] ?? ''),
      );
    }
    final recipeBytes = utf8.encode(jsonEncode(exported));
    archive.addFile(
      ArchiveFile('recipes.json', recipeBytes.length, recipeBytes),
    );
    final bytes = ZipEncoder().encode(archive);
    final rootFolder = Directory('/storage/emulated/0/GuoguoKitchen');
    if (!await rootFolder.exists()) {
      await rootFolder.create(recursive: true);
    }
    final timestamp = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .split('.')
        .first;
    final backup = File(
      '${rootFolder.path}${Platform.pathSeparator}guoguo_kitchen_$timestamp.zip',
    );
    await backup.writeAsBytes(bytes, flush: true);
    return backup;
  }

  static Future<List<Recipe>> importRecipes() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['zip'],
    );
    if (picked == null || picked.files.single.path == null) {
      return [];
    }
    final archive = ZipDecoder().decodeBytes(
      await File(picked.files.single.path!).readAsBytes(),
    );
    ArchiveFile? dataFile;
    for (final file in archive.files) {
      if (file.name == 'recipes.json') {
        dataFile = file;
        break;
      }
    }
    if (dataFile == null || !dataFile.isFile) {
      throw FormatException('备份文件中没有 recipes.json');
    }
    final mediaDirectory = await _mediaDirectory();
    final importDirectory = Directory(
      '${mediaDirectory.path}${Platform.pathSeparator}import_${DateTime.now().microsecondsSinceEpoch}',
    );
    await importDirectory.create(recursive: true);
    for (final file in archive.files) {
      if (!file.isFile ||
          !file.name.startsWith('images/') ||
          file.name.contains('..')) {
        continue;
      }
      final target = File(
        '${importDirectory.path}${Platform.pathSeparator}${file.name.substring('images/'.length)}',
      );
      await target.writeAsBytes(file.content as List<int>);
    }
    final entries =
        jsonDecode(utf8.decode(dataFile.content as List<int>)) as List<dynamic>;
    return entries
        .whereType<Map>()
        .map(
          (item) => RecipeCodec.fromJson(
            Map<String, dynamic>.from(item),
            pathMapper: (path) => path.isEmpty
                ? path
                : '${importDirectory.path}${Platform.pathSeparator}${path.replaceFirst('images/', '')}',
          ),
        )
        .toList();
  }
}

class RecipeHomePage extends StatefulWidget {
  const RecipeHomePage({super.key});
  @override
  State<RecipeHomePage> createState() => _RecipeHomePageState();
}

class _RecipeHomePageState extends State<RecipeHomePage> {
  final List<Recipe> _recipes = [];
  final _updateService = UpdateService();
  final Set<Recipe> _selectedRecipes = {};
  bool _selectionMode = false;
  String _category = '全部';
  final _categories = const ['全部', '家常菜', '烘焙', '甜品', '饮品', '汤羹', '其他'];

  List<Recipe> get _shown => _category == '全部'
      ? _recipes
      : _recipes.where((recipe) => recipe.category == _category).toList();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkForUpdate());
    _loadRecipes();
  }

  Future<void> _loadRecipes() async {
    final saved = await RecipeStore.load();
    if (mounted) setState(() => _recipes.addAll(saved));
  }

  Future<void> _saveRecipes() => RecipeStore.save(_recipes);

  Future<void> _checkForUpdate({bool showUpToDate = false}) async {
    try {
      final update = await _updateService.findUpdate();
      if (!mounted) return;
      if (update == null) {
        if (showUpToDate) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('已经是最新版本啦')));
        }
        return;
      }
      await _showUpdateDialog(update);
    } catch (_) {
      if (mounted && showUpToDate) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('暂时无法检查更新，请稍后再试')));
      }
    }
  }

  Future<void> _showUpdateDialog(AppUpdate update) => showDialog<void>(
    context: context,
    barrierDismissible: !update.forceUpdate,
    builder: (dialogContext) => AlertDialog(
      icon: const Icon(Icons.auto_awesome, color: KitchenColors.gold),
      title: Text(update.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '版本 ${update.versionName}',
            style: const TextStyle(color: KitchenColors.pink),
          ),
          const SizedBox(height: 12),
          Text(update.changelog),
        ],
      ),
      actions: [
        if (!update.forceUpdate)
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('暂不更新'),
          ),
        FilledButton.icon(
          onPressed: () {
            Navigator.pop(dialogContext);
            _downloadAndInstall(update);
          },
          icon: const Icon(Icons.download_rounded),
          label: const Text('下载更新'),
        ),
      ],
    ),
  );

  Future<void> _downloadAndInstall(AppUpdate update) async {
    final progress = ValueNotifier<double>(0);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: AlertDialog(
          title: const Text('正在下载更新'),
          content: ValueListenableBuilder<double>(
            valueListenable: progress,
            builder: (_, value, _) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                LinearProgressIndicator(value: value == 0 ? null : value),
                const SizedBox(height: 12),
                Text(
                  value == 0
                      ? '正在连接服务器…'
                      : '已下载 ${(value * 100).toStringAsFixed(0)}%',
                ),
              ],
            ),
          ),
        ),
      ),
    );
    try {
      await _updateService.downloadAndInstall(update, (received, total) {
        if (total > 0) progress.value = received / total;
      });
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    } catch (_) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('更新下载失败，请检查网络后重试')));
      }
    } finally {
      progress.dispose();
    }
  }

  Future<void> _addRecipe() async {
    final recipe = await Navigator.of(
      context,
    ).push<Recipe>(MaterialPageRoute(builder: (_) => const RecipeEditorPage()));
    if (recipe != null) {
      setState(() => _recipes.insert(0, recipe));
      await _saveRecipes();
    }
  }

  Future<void> _deleteSelected() async {
    if (_selectedRecipes.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除菜谱？'),
        content: Text('将删除选中的 ${_selectedRecipes.length} 道菜谱，此操作无法撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() {
      _recipes.removeWhere(_selectedRecipes.contains);
      _selectedRecipes.clear();
      _selectionMode = false;
    });
    await _saveRecipes();
  }

  Future<void> _exportRecipes() async {
    try {
      final file = await RecipeStore.exportRecipes(_recipes);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('备份已导出到 ${file.path}')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('导出失败：$error')));
      }
    }
  }

  Future<void> _importRecipes() async {
    try {
      final imported = await RecipeStore.importRecipes();
      if (imported.isEmpty) return;
      setState(() => _recipes.insertAll(0, imported));
      await _saveRecipes();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('已导入 ${imported.length} 道菜谱')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('导入失败：$error')));
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        _selectionMode ? '已选择 ${_selectedRecipes.length} 道菜谱' : '果果厨房',
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      actions: _selectionMode
          ? [
              IconButton(
                tooltip: '删除已选菜谱',
                onPressed: _selectedRecipes.isEmpty ? null : _deleteSelected,
                icon: const Icon(Icons.delete_outline),
              ),
              IconButton(
                tooltip: '退出选择',
                onPressed: () => setState(() {
                  _selectionMode = false;
                  _selectedRecipes.clear();
                }),
                icon: const Icon(Icons.close),
              ),
            ]
          : [
              PopupMenuButton<String>(
                tooltip: '数据与更新',
                onSelected: (value) {
                  switch (value) {
                    case 'export':
                      _exportRecipes();
                      break;
                    case 'import':
                      _importRecipes();
                      break;
                    case 'update':
                      _checkForUpdate(showUpToDate: true);
                      break;
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'export',
                    child: ListTile(
                      leading: Icon(Icons.upload_file_outlined),
                      title: Text('导出菜谱备份'),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'import',
                    child: ListTile(
                      leading: Icon(Icons.download_outlined),
                      title: Text('导入菜谱备份'),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'update',
                    child: ListTile(
                      leading: Icon(Icons.system_update_alt_rounded),
                      title: Text('检查更新'),
                    ),
                  ),
                ],
              ),
              IconButton(
                tooltip: '选择菜谱删除',
                onPressed: () => setState(() => _selectionMode = true),
                icon: const Icon(Icons.checklist_rounded),
              ),
            ],
    ),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: _selectionMode ? null : _addRecipe,
      icon: const Icon(Icons.add),
      label: const Text('新建菜谱'),
    ),
    body: CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _KitchenHeader(recipeCount: _recipes.length)),
        SliverToBoxAdapter(
          child: SizedBox(
            height: 64,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              scrollDirection: Axis.horizontal,
              children: _categories
                  .map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(item),
                        selected: _category == item,
                        onSelected: (_) => setState(() => _category = item),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
        if (_shown.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: _EmptyKitchen(onAdd: _addRecipe),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
            sliver: SliverList.separated(
              itemCount: _shown.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) => RecipeCard(
                recipe: _shown[index],
                selectionMode: _selectionMode,
                selected: _selectedRecipes.contains(_shown[index]),
                onSelected: (selected) => setState(() {
                  if (selected) {
                    _selectedRecipes.add(_shown[index]);
                  } else {
                    _selectedRecipes.remove(_shown[index]);
                  }
                }),
                onUpdated: (updated) {
                  setState(() {
                    final itemIndex = _recipes.indexOf(_shown[index]);
                    if (itemIndex != -1) _recipes[itemIndex] = updated;
                  });
                  _saveRecipes();
                },
              ),
            ),
          ),
      ],
    ),
  );
}

class _KitchenHeader extends StatelessWidget {
  const _KitchenHeader({required this.recipeCount});
  final int recipeCount;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.fromLTRB(16, 8, 16, 2),
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xff42194e), Color(0xff210d35), Color(0xffcf4d98)],
      ),
      border: Border.all(color: const Color(0xff9c4d91)),
      borderRadius: BorderRadius.circular(28),
      boxShadow: const [
        BoxShadow(
          color: Color(0x557f2c8c),
          blurRadius: 22,
          offset: Offset(0, 10),
        ),
      ],
    ),
    child: Row(
      children: [
        Container(
          width: 62,
          height: 62,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Color(0x88000000),
                blurRadius: 12,
                offset: Offset(0, 5),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Image.asset(
            'assets/images/guoguo_kitchen_app_icon.png',
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '果果食谱实验室',
                style: TextStyle(color: Color(0xffffcbed), letterSpacing: 1),
              ),
              const SizedBox(height: 4),
              Text(
                '收藏了 $recipeCount 道美味',
                style: const TextStyle(
                  fontSize: 20,
                  color: KitchenColors.text,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _EmptyKitchen extends StatelessWidget {
  const _EmptyKitchen({required this.onAdd});
  final VoidCallback onAdd;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.menu_book_outlined,
            size: 72,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 16),
          const Text(
            '还没有菜谱',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text('记录食材、步骤和每一道菜的美好瞬间', textAlign: TextAlign.center),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text('创建第一份菜谱'),
          ),
        ],
      ),
    ),
  );
}

class RecipeCard extends StatelessWidget {
  const RecipeCard({
    super.key,
    required this.recipe,
    required this.onUpdated,
    required this.selectionMode,
    required this.selected,
    required this.onSelected,
  });
  final Recipe recipe;
  final ValueChanged<Recipe> onUpdated;
  final bool selectionMode;
  final bool selected;
  final ValueChanged<bool> onSelected;
  @override
  Widget build(BuildContext context) => Card(
    elevation: 0,
    color: KitchenColors.surface,
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: () {
        if (selectionMode) {
          onSelected(!selected);
          return;
        }
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) =>
                RecipeDetailPage(recipe: recipe, onUpdated: onUpdated),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            _ImageBox(images: recipe.coverImages, width: 104, height: 104),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    recipe.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 7),
                  _CategoryPill(label: recipe.category),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(
                        Icons.shopping_basket_outlined,
                        size: 16,
                        color: KitchenColors.gold,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${recipe.ingredients.length} 种食材',
                        style: const TextStyle(color: KitchenColors.muted),
                      ),
                      const SizedBox(width: 14),
                      const Icon(
                        Icons.format_list_numbered,
                        size: 16,
                        color: KitchenColors.gold,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${recipe.steps.length} 个步骤',
                        style: const TextStyle(color: KitchenColors.muted),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (selectionMode)
              SizedBox(
                width: 42,
                child: Checkbox(
                  value: selected,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                  fillColor: WidgetStateProperty.resolveWith(
                    (states) => states.contains(WidgetState.selected)
                        ? KitchenColors.pink
                        : KitchenColors.surface,
                  ),
                  onChanged: (value) => onSelected(value ?? false),
                ),
              )
            else
              const Icon(Icons.chevron_right, color: KitchenColors.muted),
          ],
        ),
      ),
    ),
  );
}

class _CategoryPill extends StatelessWidget {
  const _CategoryPill({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.primaryContainer,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      label,
      style: TextStyle(
        fontSize: 12,
        color: Theme.of(context).colorScheme.onPrimaryContainer,
      ),
    ),
  );
}

class RecipeDetailPage extends StatelessWidget {
  const RecipeDetailPage({
    super.key,
    required this.recipe,
    required this.onUpdated,
  });
  final Recipe recipe;
  final ValueChanged<Recipe> onUpdated;

  Future<void> _editRecipe(BuildContext context) async {
    final updated = await Navigator.of(context).push<Recipe>(
      MaterialPageRoute(builder: (_) => RecipeEditorPage(recipe: recipe)),
    );
    if (updated != null && context.mounted) {
      onUpdated(updated);
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(recipe.name),
      actions: [
        IconButton(
          tooltip: '编辑菜谱',
          onPressed: () => _editRecipe(context),
          icon: const Icon(Icons.edit_outlined),
        ),
      ],
    ),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        _ImageBox(
          images: recipe.coverImages,
          width: double.infinity,
          height: 220,
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: Text(
                recipe.name,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            _CategoryPill(label: recipe.category),
          ],
        ),
        const SizedBox(height: 25),
        const _SectionTitle(
          icon: Icons.shopping_basket_outlined,
          label: '食材清单',
        ),
        const SizedBox(height: 8),
        Card(
          elevation: 0,
          child: Column(
            children: recipe.ingredients
                .map(
                  (item) => ListTile(
                    dense: true,
                    title: Text(item.name),
                    trailing: Text(
                      item.amount,
                      style: const TextStyle(color: KitchenColors.muted),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        const SizedBox(height: 22),
        const _SectionTitle(icon: Icons.format_list_numbered, label: '制作步骤'),
        const SizedBox(height: 10),
        ...recipe.steps.asMap().entries.map(
          (entry) => _StepView(number: entry.key + 1, step: entry.value),
        ),
        if (recipe.tip.isNotEmpty) ...[
          const SizedBox(height: 12),
          const _SectionTitle(icon: Icons.lightbulb_outline, label: '小贴士'),
          const SizedBox(height: 8),
          Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(recipe.tip),
            ),
          ),
        ],
      ],
    ),
  );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.icon, required this.label});
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, color: Theme.of(context).colorScheme.primary),
      const SizedBox(width: 8),
      Text(
        label,
        style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
      ),
    ],
  );
}

class _StepView extends StatelessWidget {
  const _StepView({required this.number, required this.step});
  final int number;
  final RecipeStep step;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 15,
          backgroundColor: Theme.of(context).colorScheme.primary,
          child: Text(
            '$number',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(step.description),
              if (step.images.isNotEmpty) ...[
                const SizedBox(height: 10),
                SizedBox(
                  height: 130,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: step.images.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (_, index) => ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(
                        File(step.images[index].path),
                        width: 150,
                        height: 130,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    ),
  );
}

class RecipeEditorPage extends StatefulWidget {
  const RecipeEditorPage({super.key, this.recipe});
  final Recipe? recipe;
  @override
  State<RecipeEditorPage> createState() => _RecipeEditorPageState();
}

class _RecipeEditorPageState extends State<RecipeEditorPage> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _tip = TextEditingController();
  final _picker = ImagePicker();
  final _coverImages = <XFile>[];
  final _ingredients = <Ingredient>[];
  final _steps = <RecipeStep>[];
  String _category = '家常菜';
  final _categories = const ['家常菜', '烘焙', '甜品', '饮品', '汤羹', '其他'];

  @override
  void initState() {
    super.initState();
    final recipe = widget.recipe;
    if (recipe == null) {
      _ingredients.add(Ingredient());
      _steps.add(RecipeStep());
      return;
    }
    _name.text = recipe.name;
    _tip.text = recipe.tip;
    _category = recipe.category;
    _coverImages.addAll(recipe.coverImages);
    _ingredients.addAll(
      recipe.ingredients.map(
        (item) => Ingredient(name: item.name, amount: item.amount),
      ),
    );
    _steps.addAll(
      recipe.steps.map(
        (item) => RecipeStep(
          description: item.description,
          images: List<XFile>.from(item.images),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _tip.dispose();
    super.dispose();
  }

  Future<void> _pickImages(List<XFile> destination) async {
    final selected = await _picker.pickMultiImage(imageQuality: 82);
    if (selected.isNotEmpty && mounted) {
      setState(() => destination.addAll(selected));
    }
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final ingredients = _ingredients
        .where((item) => item.name.trim().isNotEmpty)
        .toList();
    final steps = _steps
        .where(
          (item) =>
              item.description.trim().isNotEmpty || item.images.isNotEmpty,
        )
        .toList();
    if (steps.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请至少添加一个制作步骤')));
      return;
    }
    final coverImages = await RecipeStore.persistImages(_coverImages);
    final savedSteps = <RecipeStep>[];
    for (final step in steps) {
      savedSteps.add(
        RecipeStep(
          description: step.description,
          images: await RecipeStore.persistImages(step.images),
        ),
      );
    }
    if (!mounted) return;
    Navigator.pop(
      context,
      Recipe(
        name: _name.text.trim(),
        category: _category,
        coverImages: coverImages,
        ingredients: ingredients,
        steps: savedSteps,
        tip: _tip.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.recipe == null ? '新建菜谱' : '编辑菜谱'),
      actions: [TextButton(onPressed: _save, child: const Text('保存'))],
    ),
    body: Form(
      key: _form,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 36),
        children: [
          const _SectionTitle(icon: Icons.restaurant, label: '菜品信息'),
          const SizedBox(height: 12),
          TextFormField(
            controller: _name,
            decoration: const InputDecoration(
              labelText: '菜品名称',
              hintText: '例如：番茄牛腩',
            ),
            validator: (value) =>
                value == null || value.trim().isEmpty ? '请填写菜品名称' : null,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _category,
            decoration: const InputDecoration(labelText: '菜品分类'),
            items: _categories
                .map((item) => DropdownMenuItem(value: item, child: Text(item)))
                .toList(),
            onChanged: (value) => setState(() => _category = value!),
          ),
          const SizedBox(height: 18),
          const Text(
            '菜品成品图（可多选）',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 9),
          _PhotoPicker(
            images: _coverImages,
            onAdd: () => _pickImages(_coverImages),
            onRemove: (index) => setState(() => _coverImages.removeAt(index)),
          ),
          const SizedBox(height: 26),
          const _SectionTitle(
            icon: Icons.shopping_basket_outlined,
            label: '食材清单',
          ),
          const SizedBox(height: 8),
          ..._ingredients.asMap().entries.map(
            (entry) => _IngredientRow(
              ingredient: entry.value,
              allowRemove: _ingredients.length > 1,
              onChanged: () => setState(() {}),
              onDelete: () => setState(() => _ingredients.removeAt(entry.key)),
            ),
          ),
          TextButton.icon(
            onPressed: () => setState(() => _ingredients.add(Ingredient())),
            icon: const Icon(Icons.add),
            label: const Text('添加食材'),
          ),
          const SizedBox(height: 20),
          const _SectionTitle(icon: Icons.format_list_numbered, label: '制作步骤'),
          const SizedBox(height: 8),
          ..._steps.asMap().entries.map(
            (entry) => _RecipeStepEditor(
              number: entry.key + 1,
              step: entry.value,
              canRemove: _steps.length > 1,
              onDelete: () => setState(() => _steps.removeAt(entry.key)),
              onChanged: () => setState(() {}),
              onPick: () => _pickImages(entry.value.images),
              onRemoveImage: (index) =>
                  setState(() => entry.value.images.removeAt(index)),
            ),
          ),
          OutlinedButton.icon(
            onPressed: () => setState(() => _steps.add(RecipeStep())),
            icon: const Icon(Icons.add),
            label: const Text('添加步骤'),
          ),
          const SizedBox(height: 24),
          const _SectionTitle(icon: Icons.lightbulb_outline, label: '小贴士'),
          const SizedBox(height: 10),
          TextFormField(
            controller: _tip,
            decoration: const InputDecoration(
              labelText: '记录火候、替代食材等（选填）',
              alignLabelWithHint: true,
            ),
            minLines: 3,
            maxLines: 5,
          ),
        ],
      ),
    ),
  );
}

class _IngredientRow extends StatelessWidget {
  const _IngredientRow({
    required this.ingredient,
    required this.allowRemove,
    required this.onChanged,
    required this.onDelete,
  });
  final Ingredient ingredient;
  final bool allowRemove;
  final VoidCallback onChanged;
  final VoidCallback onDelete;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      children: [
        Expanded(
          flex: 3,
          child: TextFormField(
            initialValue: ingredient.name,
            decoration: const InputDecoration(hintText: '食材名称', isDense: true),
            onChanged: (value) {
              ingredient.name = value;
              onChanged();
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 2,
          child: TextFormField(
            initialValue: ingredient.amount,
            decoration: const InputDecoration(hintText: '用量', isDense: true),
            onChanged: (value) {
              ingredient.amount = value;
              onChanged();
            },
          ),
        ),
        if (allowRemove)
          IconButton(
            onPressed: onDelete,
            icon: const Icon(Icons.remove_circle_outline),
          ),
      ],
    ),
  );
}

class _RecipeStepEditor extends StatelessWidget {
  const _RecipeStepEditor({
    required this.number,
    required this.step,
    required this.canRemove,
    required this.onDelete,
    required this.onChanged,
    required this.onPick,
    required this.onRemoveImage,
  });
  final int number;
  final RecipeStep step;
  final bool canRemove;
  final VoidCallback onDelete;
  final VoidCallback onChanged;
  final VoidCallback onPick;
  final ValueChanged<int> onRemoveImage;
  @override
  Widget build(BuildContext context) => Card(
    elevation: 0,
    margin: const EdgeInsets.only(bottom: 12),
    color: KitchenColors.surfaceBright,
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: Theme.of(context).colorScheme.primary,
                child: Text(
                  '$number',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              const SizedBox(width: 8),
              const Text('步骤说明', style: TextStyle(fontWeight: FontWeight.bold)),
              const Spacer(),
              if (canRemove)
                IconButton(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline),
                ),
            ],
          ),
          TextFormField(
            initialValue: step.description,
            decoration: const InputDecoration(
              hintText: '例如：牛腩冷水下锅，加入姜片焯水…',
              alignLabelWithHint: true,
            ),
            minLines: 2,
            maxLines: 4,
            onChanged: (value) {
              step.description = value;
              onChanged();
            },
          ),
          const SizedBox(height: 10),
          const Text(
            '步骤图片（可多选）',
            style: TextStyle(fontSize: 13, color: KitchenColors.muted),
          ),
          const SizedBox(height: 7),
          _PhotoPicker(
            images: step.images,
            onAdd: onPick,
            onRemove: onRemoveImage,
            small: true,
          ),
        ],
      ),
    ),
  );
}

class _PhotoPicker extends StatelessWidget {
  const _PhotoPicker({
    required this.images,
    required this.onAdd,
    required this.onRemove,
    this.small = false,
  });
  final List<XFile> images;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;
  final bool small;
  @override
  Widget build(BuildContext context) {
    final size = small ? 68.0 : 88.0;
    return Wrap(
      spacing: 9,
      runSpacing: 9,
      children: [
        ...images.asMap().entries.map(
          (entry) => Stack(
            clipBehavior: Clip.none,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(11),
                child: Image.file(
                  File(entry.value.path),
                  width: size,
                  height: size,
                  fit: BoxFit.cover,
                ),
              ),
              Positioned(
                right: -6,
                top: -6,
                child: InkWell(
                  onTap: () => onRemove(entry.key),
                  child: const CircleAvatar(
                    radius: 10,
                    backgroundColor: Colors.black54,
                    child: Icon(Icons.close, color: Colors.white, size: 13),
                  ),
                ),
              ),
            ],
          ),
        ),
        InkWell(
          onTap: onAdd,
          borderRadius: BorderRadius.circular(11),
          child: Ink(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(
              Icons.add_photo_alternate_outlined,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
        ),
      ],
    );
  }
}

class _ImageBox extends StatelessWidget {
  const _ImageBox({
    required this.images,
    required this.width,
    required this.height,
  });
  final List<XFile> images;
  final double width;
  final double height;
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(15),
    child: SizedBox(
      width: width,
      height: height,
      child: images.isEmpty
          ? ColoredBox(
              color: KitchenColors.surfaceBright,
              child: Icon(
                Icons.restaurant,
                size: 38,
                color: Theme.of(context).colorScheme.primary,
              ),
            )
          : Stack(
              fit: StackFit.expand,
              children: [
                Image.file(File(images.first.path), fit: BoxFit.cover),
                if (images.length > 1)
                  Positioned(
                    right: 8,
                    bottom: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${images.length} 张',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    ),
  );
}
