import 'package:expandable_animation/expandable_animation.dart';
import 'package:flutter/material.dart';

import '../widgets/common.dart';
import '../widgets/generated_art.dart';

class Metric {
  const Metric(this.title, this.value, this.change, this.icon, this.values);

  final String title;
  final String value;
  final String change;
  final IconData icon;
  final List<double> values;
}

const List<Metric> metrics = <Metric>[
  Metric('Revenue', '\$48.2k', '+12.4%', Icons.payments_outlined,
      <double>[12, 18, 15, 22, 26, 24, 31, 35, 33, 41, 44, 48]),
  Metric('Active users', '8,931', '+4.1%', Icons.people_alt_outlined,
      <double>[70, 72, 69, 75, 78, 80, 79, 83, 85, 84, 88, 89]),
  Metric('Conversion', '3.8%', '-0.3%', Icons.trending_up,
      <double>[4.2, 4.0, 4.1, 3.9, 4.0, 3.7, 3.9, 3.8, 3.6, 3.9, 3.7, 3.8]),
  Metric('Avg. session', '6m 12s', '+18s', Icons.timer_outlined,
      <double>[5.1, 5.3, 5.2, 5.6, 5.5, 5.8, 5.7, 6.0, 5.9, 6.1, 6.0, 6.2]),
];

const List<String> _months = <String>[
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// Dashboard tiles that expand into a detailed analytics view.
class DashboardDemo extends StatelessWidget {
  const DashboardDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return DemoScaffold(
      title: 'Dashboard widget expansion',
      description: 'Statistic tiles expand into detailed analytics. On wide '
          'windows the detail opens as a centered panel; on phones it fills '
          'the screen.',
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final bool wide = constraints.maxWidth > 700;
          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: wide ? 4 : 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.05,
            ),
            itemCount: metrics.length,
            itemBuilder: (BuildContext context, int index) {
              final ColorScheme scheme = Theme.of(context).colorScheme;
              return ExpandableAnimation(
                mode: wide
                    ? const ExpandableAnimationMode.dialog(
                        maxSize: Size(760, 560),
                      )
                    : const ExpandableAnimationMode.fullscreen(),
                borderRadius: BorderRadius.circular(18),
                expandedBorderRadius:
                    wide ? BorderRadius.circular(28) : BorderRadius.zero,
                collapsedColor: scheme.surfaceContainerHigh,
                expandedColor: scheme.surfaceContainerLow,
                semanticLabel: 'Open ${metrics[index].title} analytics',
                expandedBuilder: (BuildContext context) =>
                    MetricDetails(metric: metrics[index]),
                child: MetricTile(metric: metrics[index]),
              );
            },
          );
        },
      ),
    );
  }
}

class MetricTile extends StatelessWidget {
  const MetricTile({super.key, required this.metric});

  final Metric metric;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool negative = metric.change.startsWith('-');
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(metric.icon, size: 20, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(metric.title,
                    style: theme.textTheme.labelLarge, maxLines: 1),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(metric.value, style: theme.textTheme.headlineSmall),
          Text(
            metric.change,
            style: theme.textTheme.labelMedium?.copyWith(
              color: negative ? theme.colorScheme.error : Colors.green,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Sparkline(
              values: metric.values,
              color: theme.colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class MetricDetails extends StatelessWidget {
  const MetricDetails({super.key, required this.metric});

  final Metric metric;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Material(
      type: MaterialType.transparency,
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(metric.icon, color: theme.colorScheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(metric.title, style: theme.textTheme.titleLarge),
                ),
                const CollapseButton(),
              ],
            ),
            const SizedBox(height: 16),
            Text(metric.value, style: theme.textTheme.displaySmall),
            Text('${metric.change} vs. last period',
                style: theme.textTheme.bodyLarge),
            const SizedBox(height: 24),
            SizedBox(
              height: 220,
              child: Sparkline(
                values: metric.values,
                color: theme.colorScheme.primary,
                strokeWidth: 3.5,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                for (int i = 0; i < _months.length; i += 3)
                  Text(_months[i], style: theme.textTheme.bodySmall),
              ],
            ),
            const SizedBox(height: 24),
            Text('Monthly breakdown', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            for (int i = metric.values.length - 1; i >= 6; i--)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(_months[i]),
                trailing: Text(metric.values[i].toStringAsFixed(1)),
              ),
          ],
        ),
      ),
    );
  }
}
