import 'package:expandable_animation/expandable_animation.dart';
import 'package:flutter/material.dart';

import 'src/demos/app_store_cards_demo.dart';
import 'src/demos/dashboard_demo.dart';
import 'src/demos/music_player_demo.dart';
import 'src/demos/notifications_demo.dart';
import 'src/demos/photo_gallery_demo.dart';
import 'src/demos/playground_demo.dart';
import 'src/demos/product_demo.dart';
import 'src/demos/profile_demo.dart';

void main() => runApp(const ShowcaseApp());

/// A demo shown on the home screen and reachable by its [route].
class Demo {
  const Demo({
    required this.route,
    required this.title,
    required this.description,
    required this.icon,
    required this.builder,
  });

  final String route;
  final String title;
  final String description;
  final IconData icon;
  final WidgetBuilder builder;
}

final List<Demo> demos = <Demo>[
  Demo(
    route: '/product-card',
    title: 'Product card to fullscreen',
    description: 'E-commerce cards that morph into a full product page.',
    icon: Icons.shopping_bag_outlined,
    builder: (_) => const ProductDemo(),
  ),
  Demo(
    route: '/music-player',
    title: 'Expandable music player',
    description: 'A mini player that becomes a fullscreen player.',
    icon: Icons.music_note_outlined,
    builder: (_) => const MusicPlayerDemo(),
  ),
  Demo(
    route: '/photo-gallery',
    title: 'Fullscreen image transition',
    description: 'Gallery thumbnails that open into an image viewer.',
    icon: Icons.photo_library_outlined,
    builder: (_) => const PhotoGalleryDemo(),
  ),
  Demo(
    route: '/app-store-cards',
    title: 'App Store-style cards',
    description: 'Editorial cards that spring open into articles.',
    icon: Icons.auto_stories_outlined,
    builder: (_) => const AppStoreCardsDemo(),
  ),
  Demo(
    route: '/profile-card',
    title: 'Expandable profile card',
    description: 'A compact profile that opens as a centered panel.',
    icon: Icons.account_circle_outlined,
    builder: (_) => const ProfileDemo(),
  ),
  Demo(
    route: '/dashboard',
    title: 'Dashboard widget expansion',
    description: 'Statistic tiles that expand into detailed analytics.',
    icon: Icons.insights_outlined,
    builder: (_) => const DashboardDemo(),
  ),
  Demo(
    route: '/notifications',
    title: 'Expandable notifications',
    description: 'Banners that expand into a partial-height sheet.',
    icon: Icons.notifications_none,
    builder: (_) => const NotificationsDemo(),
  ),
  Demo(
    route: '/playground',
    title: 'Transitions playground',
    description: 'Tune every option and copy the generated code.',
    icon: Icons.tune,
    builder: (_) => const PlaygroundDemo(),
  ),
];

class ShowcaseApp extends StatefulWidget {
  const ShowcaseApp({super.key, this.initialRoute});

  /// Overrides the starting route; used by integration tests.
  final String? initialRoute;

  @override
  State<ShowcaseApp> createState() => _ShowcaseAppState();
}

class _ShowcaseAppState extends State<ShowcaseApp> {
  ThemeMode _themeMode = ThemeMode.system;

  static const Color _seed = Color(0xFF6750A4);

  void _toggleTheme(Brightness current) {
    setState(() {
      _themeMode =
          current == Brightness.dark ? ThemeMode.light : ThemeMode.dark;
    });
  }

  Route<void> _onGenerateRoute(RouteSettings settings) {
    final Demo? demo =
        demos.where((Demo d) => d.route == settings.name).firstOrNull;
    return MaterialPageRoute<void>(
      settings: settings,
      builder: demo?.builder ?? (_) => HomePage(onToggleTheme: _toggleTheme),
    );
  }

  @override
  Widget build(BuildContext context) {
    // App-wide defaults for every ExpandableAnimation in the showcase.
    return ExpandableAnimationTheme(
      data: const ExpandableAnimationThemeData(hoverScale: 1.02),
      child: MaterialApp(
        title: 'Expandable Animation showcase',
        debugShowCheckedModeBanner: false,
        themeMode: _themeMode,
        theme: ThemeData(colorSchemeSeed: _seed, brightness: Brightness.light),
        darkTheme:
            ThemeData(colorSchemeSeed: _seed, brightness: Brightness.dark),
        initialRoute: widget.initialRoute ?? '/',
        onGenerateRoute: _onGenerateRoute,
      ),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key, required this.onToggleTheme});

  final ValueChanged<Brightness> onToggleTheme;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Brightness brightness = theme.brightness;
    return Scaffold(
      body: CustomScrollView(
        slivers: <Widget>[
          SliverAppBar.large(
            title: const Text('Expandable Animation'),
            actions: <Widget>[
              IconButton(
                tooltip: brightness == Brightness.dark
                    ? 'Switch to light mode'
                    : 'Switch to dark mode',
                onPressed: () => onToggleTheme(brightness),
                icon: Icon(brightness == Brightness.dark
                    ? Icons.light_mode_outlined
                    : Icons.dark_mode_outlined),
              ),
            ],
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverToBoxAdapter(
              child: Text(
                'Expand any widget. Animate every transition. Each demo below '
                'uses the expandable_animation package for widget-to-fullscreen '
                'transitions, container morphing and drag-to-dismiss.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverGrid.builder(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 360,
                mainAxisExtent: 150,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
              ),
              itemCount: demos.length,
              itemBuilder: (BuildContext context, int index) =>
                  _DemoTile(demo: demos[index]),
            ),
          ),
        ],
      ),
    );
  }
}

class _DemoTile extends StatelessWidget {
  const _DemoTile({required this.demo});

  final Demo demo;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Card.filled(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: () => Navigator.of(context).pushNamed(demo.route),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(demo.icon, color: theme.colorScheme.primary),
              const Spacer(),
              Text(demo.title, style: theme.textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                demo.description,
                style: theme.textTheme.bodyMedium,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
