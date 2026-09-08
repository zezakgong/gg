import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

void main() => runApp(const ShoppingArchiveApp());

class ShoppingArchiveApp extends StatelessWidget {
  const ShoppingArchiveApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: '购物档案',
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff5d54b4)),
      scaffoldBackgroundColor: const Color(0xfff7f7fb),
    ),
    home: const ShoppingHomePage(),
  );
}

enum PurchaseStage { listed, ordered, balancePaid, shipped, received }

extension StageInfo on PurchaseStage {
  String get label => switch (this) {
    PurchaseStage.listed => '已上架',
    PurchaseStage.ordered => '已下定',
    PurchaseStage.balancePaid => '已付尾款',
    PurchaseStage.shipped => '已发货',
    PurchaseStage.received => '已到货',
  };
  IconData get icon => switch (this) {
    PurchaseStage.listed => Icons.storefront_outlined,
    PurchaseStage.ordered => Icons.shopping_bag_outlined,
    PurchaseStage.balancePaid => Icons.account_balance_wallet_outlined,
    PurchaseStage.shipped => Icons.local_shipping_outlined,
    PurchaseStage.received => Icons.inventory_2_outlined,
  };
}

class PurchaseItem {
  PurchaseItem({
    required this.name,
    required this.price,
    required this.images,
    required this.dates,
    required this.note,
  });
  final String name;
  final double price;
  final List<XFile> images;
  final Map<PurchaseStage, DateTime?> dates;
  final String note;
  PurchaseStage get stage => PurchaseStage.values.lastWhere(
    (stage) => dates[stage] != null,
    orElse: () => PurchaseStage.listed,
  );
}

class ShoppingHomePage extends StatefulWidget {
  const ShoppingHomePage({super.key});
  @override
  State<ShoppingHomePage> createState() => _ShoppingHomePageState();
}

class _ShoppingHomePageState extends State<ShoppingHomePage> {
  final List<PurchaseItem> _items = [];
  PurchaseStage? _filter;
  List<PurchaseItem> get _shown => _filter == null
      ? _items
      : _items.where((e) => e.stage == _filter).toList();
  Future<void> _add() async {
    final item = await Navigator.push<PurchaseItem>(
      context,
      MaterialPageRoute(builder: (_) => const PurchaseEditorPage()),
    );
    if (item != null) setState(() => _items.insert(0, item));
  }

  @override
  Widget build(BuildContext context) {
    final sum = _items.fold<double>(0, (value, item) => value + item.price);
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '购物档案',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        icon: const Icon(Icons.add),
        label: const Text('记录商品'),
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: _Summary(count: _items.length, total: sum),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 62,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                children: [
                  _Filter(
                    label: '全部',
                    selected: _filter == null,
                    onTap: () => setState(() => _filter = null),
                  ),
                  ...PurchaseStage.values.map(
                    (s) => _Filter(
                      label: s.label,
                      selected: _filter == s,
                      onTap: () => setState(() => _filter = s),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_shown.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _Empty(onAdd: _add),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 96),
              sliver: SliverList.separated(
                itemCount: _shown.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (_, i) => _PurchaseCard(item: _shown[i]),
              ),
            ),
        ],
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.count, required this.total});
  final int count;
  final double total;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xff554dac), Color(0xff887cda)],
      ),
      borderRadius: BorderRadius.circular(24),
    ),
    child: Row(
      children: [
        const Icon(Icons.auto_awesome, color: Colors.white, size: 30),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('我的购物足迹', style: TextStyle(color: Colors.white70)),
              const SizedBox(height: 4),
              Text(
                '已记录 $count 件商品',
                style: const TextStyle(
                  fontSize: 19,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const Text(
              '累计金额',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
            Text(
              '¥${total.toStringAsFixed(2)}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class _Filter extends StatelessWidget {
  const _Filter({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
    ),
  );
}

class _Empty extends StatelessWidget {
  const _Empty({required this.onAdd});
  final VoidCallback onAdd;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 70,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 16),
          const Text(
            '还没有商品记录',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
          ),
          const SizedBox(height: 8),
          const Text('从上架到收货，完整保存每一次购买', textAlign: TextAlign.center),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text('添加第一件商品'),
          ),
        ],
      ),
    ),
  );
}

class _PurchaseCard extends StatelessWidget {
  const _PurchaseCard({required this.item});
  final PurchaseItem item;
  @override
  Widget build(BuildContext context) => Card(
    elevation: 0,
    color: Colors.white,
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ProductImage(images: item.images),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.name,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Text(
                      '¥${item.price.toStringAsFixed(2)}',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                _StageChip(stage: item.stage),
                const SizedBox(height: 11),
                _Timeline(item: item),
                if (item.note.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      item.note,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.black54),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _ProductImage extends StatelessWidget {
  const _ProductImage({required this.images});
  final List<XFile> images;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 88,
    height: 112,
    child: Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(13),
          child: SizedBox.expand(
            child: images.isEmpty
                ? ColoredBox(
                    color: const Color(0xffeeeef5),
                    child: Icon(
                      Icons.image_outlined,
                      color: Colors.grey.shade500,
                    ),
                  )
                : Image.file(File(images.first.path), fit: BoxFit.cover),
          ),
        ),
        if (images.length > 1)
          Positioned(
            right: 5,
            bottom: 5,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${images.length} 张',
                style: const TextStyle(color: Colors.white, fontSize: 11),
              ),
            ),
          ),
      ],
    ),
  );
}

class _StageChip extends StatelessWidget {
  const _StageChip({required this.stage});
  final PurchaseStage stage;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.primaryContainer,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      stage.label,
      style: TextStyle(
        fontSize: 12,
        color: Theme.of(context).colorScheme.onPrimaryContainer,
      ),
    ),
  );
}

class _Timeline extends StatelessWidget {
  const _Timeline({required this.item});
  final PurchaseItem item;
  @override
  Widget build(BuildContext context) {
    final current = item.stage.index;
    return Row(
      children: PurchaseStage.values.map((stage) {
        final active = stage.index <= current;
        final date = item.dates[stage];
        return Expanded(
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 2,
                      color: stage.index == 0
                          ? Colors.transparent
                          : active
                          ? Theme.of(context).colorScheme.primary
                          : Colors.grey.shade300,
                    ),
                  ),
                  Icon(
                    stage.icon,
                    size: 14,
                    color: active
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey.shade400,
                  ),
                  Expanded(
                    child: Container(
                      height: 2,
                      color: stage.index == 4
                          ? Colors.transparent
                          : stage.index < current
                          ? Theme.of(context).colorScheme.primary
                          : Colors.grey.shade300,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                date == null ? stage.label : _date(date),
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 9,
                  color: active ? Colors.black87 : Colors.grey,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class PurchaseEditorPage extends StatefulWidget {
  const PurchaseEditorPage({super.key});
  @override
  State<PurchaseEditorPage> createState() => _PurchaseEditorPageState();
}

class _PurchaseEditorPageState extends State<PurchaseEditorPage> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _price = TextEditingController();
  final _note = TextEditingController();
  final _picker = ImagePicker();
  final _images = <XFile>[];
  final Map<PurchaseStage, DateTime?> _dates = {
    for (final stage in PurchaseStage.values) stage: null,
  };
  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final picks = await _picker.pickMultiImage(imageQuality: 82);
    if (picks.isNotEmpty && mounted) setState(() => _images.addAll(picks));
  }

  Future<void> _choose(PurchaseStage stage) async {
    final choice = await showDatePicker(
      context: context,
      initialDate: _dates[stage] ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (choice != null) setState(() => _dates[stage] = choice);
  }

  void _save() {
    if (!_form.currentState!.validate()) return;
    Navigator.pop(
      context,
      PurchaseItem(
        name: _name.text.trim(),
        price: double.parse(_price.text.trim()),
        images: _images,
        dates: _dates,
        note: _note.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('记录商品'),
      actions: [TextButton(onPressed: _save, child: const Text('保存'))],
    ),
    body: Form(
      key: _form,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
        children: [
          const Text(
            '商品信息',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _name,
            decoration: const InputDecoration(
              labelText: '商品名称',
              border: OutlineInputBorder(),
            ),
            validator: (v) => v == null || v.trim().isEmpty ? '请填写商品名称' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _price,
            decoration: const InputDecoration(
              labelText: '购买价格',
              prefixText: '¥ ',
              border: OutlineInputBorder(),
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            validator: (v) =>
                double.tryParse(v ?? '') == null ? '请输入正确的金额' : null,
          ),
          const SizedBox(height: 24),
          const Text(
            '商品图片',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          const Text('可一次选择多张图片', style: TextStyle(color: Colors.black54)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              ..._images.asMap().entries.map(
                (e) => _Thumb(
                  image: e.value,
                  onDelete: () => setState(() => _images.removeAt(e.key)),
                ),
              ),
              InkWell(
                onTap: _pick,
                borderRadius: BorderRadius.circular(12),
                child: Ink(
                  width: 86,
                  height: 86,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.add_photo_alternate_outlined),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            '购买进度',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ...PurchaseStage.values.map(
            (s) => Card(
              elevation: 0,
              child: ListTile(
                leading: Icon(s.icon),
                title: Text(s.label),
                subtitle: Text(_dates[s] == null ? '尚未记录' : _date(_dates[s]!)),
                trailing: _dates[s] == null
                    ? const Icon(Icons.calendar_month_outlined)
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => setState(() => _dates[s] = null),
                      ),
                onTap: () => _choose(s),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _note,
            decoration: const InputDecoration(
              labelText: '备注（选填）',
              alignLabelWithHint: true,
              border: OutlineInputBorder(),
            ),
            minLines: 3,
            maxLines: 5,
          ),
        ],
      ),
    ),
  );
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.image, required this.onDelete});
  final XFile image;
  final VoidCallback onDelete;
  @override
  Widget build(BuildContext context) => Stack(
    clipBehavior: Clip.none,
    children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.file(
          File(image.path),
          width: 86,
          height: 86,
          fit: BoxFit.cover,
        ),
      ),
      Positioned(
        right: -7,
        top: -7,
        child: InkWell(
          onTap: onDelete,
          child: const CircleAvatar(
            radius: 11,
            backgroundColor: Colors.black54,
            child: Icon(Icons.close, color: Colors.white, size: 14),
          ),
        ),
      ),
    ],
  );
}

String _date(DateTime date) =>
    '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
