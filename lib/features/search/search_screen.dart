import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class SearchScreen extends StatelessWidget {
  const SearchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final query = GoRouterState.of(context).uri.queryParameters['query'] ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recherche'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: TextEditingController(text: query),
              decoration: const InputDecoration(
                labelText: 'Produit',
                hintText: 'Ex : iPhone, lait, aspirateur',
              ),
            ),
            const SizedBox(height: 16),
            const Text('Résultats à implémenter selon le contrat API public.'),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => context.push('/product/1'),
              child: const Text('Ouvrir une fiche produit'),
            ),
          ],
        ),
      ),
    );
  }
}
