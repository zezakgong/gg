import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

abstract final class KitchenColors {
  static const background = Color(0xff160b22);
  static const surface = Color(0xff281438);
  static const surfaceBright = Color(0xff38204d);
  static const pink = Color(0xffff6eb5);
  static const gold = Color(0xffffc44d);
  static const text = Color(0xffffeff8);
  static const muted = Color(0xffc9aecb);
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

class RecipeHomePage extends StatefulWidget {
  const RecipeHomePage({super.key});
  @override
  State<RecipeHomePage> createState() => _RecipeHomePageState();
}

class _RecipeHomePageState extends State<RecipeHomePage> {
  final List<Recipe> _recipes = [];
  String _category = '全部';
  final _categories = const ['全部', '家常菜', '烘焙', '甜品', '饮品', '汤羹', '其他'];

  List<Recipe> get _shown => _category == '全部'
      ? _recipes
      : _recipes.where((recipe) => recipe.category == _category).toList();

  Future<void> _addRecipe() async {
    final recipe = await Navigator.of(
      context,
    ).push<Recipe>(MaterialPageRoute(builder: (_) => const RecipeEditorPage()));
    if (recipe != null) setState(() => _recipes.insert(0, recipe));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('果果厨房', style: TextStyle(fontWeight: FontWeight.bold)),
      actions: const [
        Padding(
          padding: EdgeInsets.only(right: 16),
          child: Icon(Icons.menu_book_outlined),
        ),
      ],
    ),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: _addRecipe,
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
                onUpdated: (updated) => setState(() {
                  final itemIndex = _recipes.indexOf(_shown[index]);
                  if (itemIndex != -1) _recipes[itemIndex] = updated;
                }),
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
  const RecipeCard({super.key, required this.recipe, required this.onUpdated});
  final Recipe recipe;
  final ValueChanged<Recipe> onUpdated;
  @override
  Widget build(BuildContext context) => Card(
    elevation: 0,
    color: KitchenColors.surface,
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              RecipeDetailPage(recipe: recipe, onUpdated: onUpdated),
        ),
      ),
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

  void _save() {
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
    Navigator.pop(
      context,
      Recipe(
        name: _name.text.trim(),
        category: _category,
        coverImages: _coverImages,
        ingredients: ingredients,
        steps: steps,
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
