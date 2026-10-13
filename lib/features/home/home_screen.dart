import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Comparateur Prix'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Trouver le meilleur prix',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SearchBar(
              onSubmitted: (value) {
                final query = value.trim();
                if (query.isNotEmpty) {
                  context.push('/search?query=$query');
                } else {
                  context.push('/search');
                }
              },
              hintText: 'Rechercher un produit',
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => context.push('/search'),
              icon: const Icon(Icons.search),
              label: const Text('Explorer les produits'),
            ),
            const SizedBox(height: 24),
            const Text(
              'Le frontend suit désormais le plan métier du comparateur.',
              style: TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}
