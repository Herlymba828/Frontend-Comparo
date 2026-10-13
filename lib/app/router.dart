import 'package:go_router/go_router.dart';

import '../features/home/home_screen.dart';
import '../features/product/product_screen.dart';
import '../features/search/search_screen.dart';

class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/search',
        builder: (context, state) => SearchScreen(
          initialQuery: state.uri.queryParameters['query'] ?? '',
        ),
      ),
      GoRoute(
        path: '/product/:id',
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return ProductScreen(productId: id);
        },
      ),
    ],
  );
}
