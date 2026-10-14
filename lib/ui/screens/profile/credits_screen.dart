import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../config/app_config.dart';
import '../../../core/json.dart';
import '../../theme/tokens.dart';
import '../../widgets/panel.dart';

/// Credits for every third-party asset and library, from
/// assets/credits/asset_manifest.json, plus Flutter's full license list.
class CreditsScreen extends StatelessWidget {
  const CreditsScreen({super.key});

  Future<Map<String, dynamic>> _load() async {
    final text = await rootBundle.loadString(
      'assets/credits/asset_manifest.json',
    );
    return asMap(jsonDecode(text));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Credits & licenses')),
    body: FutureBuilder<Map<String, dynamic>>(
      future: _load(),
      builder: (context, snap) {
        if (snap.hasError) {
          return const Center(child: Text('Could not load credits.'));
        }
        if (!snap.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: Palette.gold),
          );
        }
        final sources = asMapList(snap.data!['sources']);
        final software = asMapList(snap.data!['software']);
        return ListView(
          padding: const EdgeInsets.all(Space.lg),
          children: [
            const Text(
              'Made by Cedrick Miguel P. Kaneko, with free and open data, '
              'art, sound and software from these generous creators. Thank you!',
              style: TextStyle(color: Palette.textDim),
            ),
            const SectionHeader('Data, art & sound'),
            for (final s in sources)
              _CreditCard(
                title: asString(s['title']),
                author: asString(s['author']),
                detail: asString(s['attribution']),
                license: asString(s['license']),
                url: asString(s['url']),
              ),
            const SectionHeader('Open-source software'),
            for (final s in software)
              _CreditCard(
                title: asString(s['name']),
                author: asString(s['author']),
                license: asString(s['license']),
                url: asString(s['url']),
              ),
            const SizedBox(height: Space.sm),
            OutlinedButton.icon(
              onPressed: () => showLicensePage(
                context: context,
                applicationName: AppConfig.appName,
                applicationVersion: AppConfig.appVersion,
                applicationLegalese: '© 2026 Cedrick Miguel P. Kaneko',
              ),
              icon: const Icon(Icons.description_outlined),
              label: const Text('All open-source licenses'),
            ),
          ],
        );
      },
    ),
  );
}

class _CreditCard extends StatelessWidget {
  const _CreditCard({
    required this.title,
    required this.author,
    required this.license,
    required this.url,
    this.detail,
  });

  final String title;
  final String author;
  final String license;
  final String url;
  final String? detail;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: Space.sm),
    child: Panel(
      padding: const EdgeInsets.all(Space.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          Text(
            author,
            style: const TextStyle(color: Palette.textDim, fontSize: 13),
          ),
          if (detail case final d? when d.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(d, style: const TextStyle(fontSize: 13)),
          ],
          const SizedBox(height: 4),
          Text(
            'License: $license',
            style: const TextStyle(color: Palette.gold, fontSize: 12),
          ),
          SelectableText(
            url,
            style: const TextStyle(color: Palette.xp, fontSize: 12),
          ),
        ],
      ),
    ),
  );
}
