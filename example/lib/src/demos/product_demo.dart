import 'package:expandable_animation/expandable_animation.dart';
import 'package:flutter/material.dart';

import '../widgets/common.dart';
import '../widgets/generated_art.dart';

class Product {
  const Product({
    required this.name,
    required this.category,
    required this.price,
    required this.rating,
    required this.description,
    required this.colors,
    required this.seed,
  });

  final String name;
  final String category;
  final double price;
  final double rating;
  final String description;
  final List<Color> colors;
  final int seed;
}

const List<Product> products = <Product>[
  Product(
    name: 'Aurora Headphones',
    category: 'Audio',
    price: 249,
    rating: 4.8,
    description: 'Wireless over-ear headphones with adaptive noise '
        'cancellation, 40 hours of battery life and memory-foam cushions '
        'designed for long listening sessions.',
    colors: <Color>[Color(0xFF6A5AE0), Color(0xFFB06AB3), Color(0xFFFFC371)],
    seed: 3,
  ),
  Product(
    name: 'Drift Sneakers',
    category: 'Footwear',
    price: 129,
    rating: 4.6,
    description: 'Lightweight knit runners with a responsive foam sole, '
        'recycled laces and a breathable upper for everyday miles.',
    colors: <Color>[Color(0xFF11998E), Color(0xFF38EF7D), Color(0xFFE0F7FA)],
    seed: 11,
  ),
  Product(
    name: 'Ember Mug',
    category: 'Home',
    price: 39,
    rating: 4.4,
    description: 'A double-walled ceramic mug that keeps coffee warm for '
        'an hour, with a matte glaze and a dishwasher-safe finish.',
    colors: <Color>[Color(0xFFF83600), Color(0xFFF9D423), Color(0xFFFFF3E0)],
    seed: 7,
  ),
  Product(
    name: 'Nimbus Lamp',
    category: 'Lighting',
    price: 89,
    rating: 4.7,
    description: 'A dimmable desk lamp with warm-to-cool color temperature, '
        'a weighted aluminium base and a touch-sensitive control ring.',
    colors: <Color>[Color(0xFF2193B0), Color(0xFF6DD5ED), Color(0xFFE3F2FD)],
    seed: 19,
  ),
];

/// E-commerce product cards that expand into a fullscreen product page.
class ProductDemo extends StatelessWidget {
  const ProductDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return DemoScaffold(
      title: 'Product card to fullscreen',
      description: 'Tap a product card to morph it into a fullscreen product '
          'page. Drag the page down or press back to return it to the grid.',
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 280,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 0.72,
        ),
        itemCount: products.length,
        itemBuilder: (BuildContext context, int index) =>
            ProductTile(product: products[index]),
      ),
    );
  }
}

class ProductTile extends StatelessWidget {
  const ProductTile({super.key, required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final BorderRadius radius = BorderRadius.circular(20);
    return ExpandableAnimation(
      borderRadius: radius,
      collapsedColor: scheme.surfaceContainerHigh,
      expandedColor: scheme.surface,
      semanticLabel: 'Open ${product.name}',
      expandedBuilder: (BuildContext context) =>
          ProductDetailsPage(product: product),
      child: ProductCard(product: product),
    );
  }
}

class ProductCard extends StatelessWidget {
  const ProductCard({super.key, required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: ColoredBox(
        color: theme.colorScheme.surfaceContainerHigh,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: GeneratedArt(seed: product.seed, colors: product.colors),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(product.category, style: theme.textTheme.labelMedium),
                  const SizedBox(height: 2),
                  Text(
                    product.name,
                    style: theme.textTheme.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '\$${product.price.toStringAsFixed(0)}',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w700,
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
}

/// Keeps the text column readable on wide windows.
double _sidePadding(BuildContext context) {
  final double width = MediaQuery.sizeOf(context).width;
  return width > 760 ? (width - 712) / 2 : 24;
}

class ProductDetailsPage extends StatefulWidget {
  const ProductDetailsPage({super.key, required this.product});

  final Product product;

  @override
  State<ProductDetailsPage> createState() => _ProductDetailsPageState();
}

class _ProductDetailsPageState extends State<ProductDetailsPage> {
  int _quantity = 1;

  @override
  Widget build(BuildContext context) {
    final Product product = widget.product;
    final ThemeData theme = Theme.of(context);
    final EdgeInsets padding = MediaQuery.paddingOf(context);
    return Material(
      color: theme.colorScheme.surface,
      child: Stack(
        children: <Widget>[
          CustomScrollView(
            slivers: <Widget>[
              SliverToBoxAdapter(
                child: SizedBox(
                  // Square-ish on phones, capped on wide windows.
                  height: (MediaQuery.sizeOf(context).width / 1.1)
                      .clamp(0.0, MediaQuery.sizeOf(context).height * 0.5),
                  child: GeneratedArt(
                    seed: product.seed,
                    colors: product.colors,
                    semanticLabel: '${product.name} product artwork',
                  ),
                ),
              ),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  _sidePadding(context),
                  24,
                  _sidePadding(context),
                  120 + padding.bottom,
                ),
                sliver: SliverList.list(
                  children: <Widget>[
                    Text(product.category.toUpperCase(),
                        style: theme.textTheme.labelLarge),
                    const SizedBox(height: 4),
                    Text(product.name, style: theme.textTheme.headlineMedium),
                    const SizedBox(height: 8),
                    Row(
                      children: <Widget>[
                        Icon(Icons.star_rounded,
                            color: theme.colorScheme.tertiary, size: 20),
                        const SizedBox(width: 4),
                        Text('${product.rating} · 1.2k reviews',
                            style: theme.textTheme.bodyMedium),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text(product.description, style: theme.textTheme.bodyLarge),
                    const SizedBox(height: 24),
                    Text('Quantity', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Row(
                      children: <Widget>[
                        IconButton.outlined(
                          tooltip: 'Decrease quantity',
                          onPressed: _quantity > 1
                              ? () => setState(() => _quantity--)
                              : null,
                          icon: const Icon(Icons.remove),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text('$_quantity',
                              style: theme.textTheme.titleLarge),
                        ),
                        IconButton.outlined(
                          tooltip: 'Increase quantity',
                          onPressed: () => setState(() => _quantity++),
                          icon: const Icon(Icons.add),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Text('Details', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 8),
                    for (final String line in const <String>[
                      'Free delivery and returns',
                      'Two-year warranty',
                      'Ships in recyclable packaging',
                    ])
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.check_circle_outline),
                        title: Text(line),
                      ),
                  ],
                ),
              ),
            ],
          ),
          Positioned(
            top: padding.top + 12,
            right: 16,
            child: const CollapseButton(onDark: true),
          ),
          Positioned(
            left: _sidePadding(context),
            right: _sidePadding(context),
            bottom: padding.bottom + 24,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
              ),
              onPressed: () {
                ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                  SnackBar(content: Text('Added $_quantity × ${product.name}')),
                );
              },
              icon: const Icon(Icons.shopping_bag_outlined),
              label: Text(
                'Add to bag · \$${(product.price * _quantity).toStringAsFixed(0)}',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
