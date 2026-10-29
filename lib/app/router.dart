import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../features/account/account_screen.dart';
import '../features/account/contributions_screen.dart';
import '../features/account/support_screen.dart';
import '../features/alerts/alerts_screen.dart';
import '../features/commerce/cart_screen.dart';
import '../features/commerce/checkout_screen.dart';
import '../features/commerce/order_detail_screen.dart';
import '../features/commerce/orders_screen.dart';
import '../features/contributions/price_report_screen.dart';
import '../features/courier/courier_deliveries_screen.dart';
import '../features/courier/courier_delivery_screen.dart';
import '../features/courier/courier_profile_screen.dart';
import '../features/courier/courier_shell.dart';
import '../features/home/home_screen.dart';
import '../features/identity/auth_screen.dart';
import '../features/merchant/merchant_complaints_screen.dart';
import '../features/merchant/merchant_offers_screen.dart';
import '../features/merchant/merchant_order_screen.dart';
import '../features/merchant/merchant_orders_screen.dart';
import '../features/merchant/merchant_shell.dart';
import '../features/merchant/merchant_shop_screen.dart';
import '../features/merchant/merchant_stock_screen.dart';
import '../features/moderation/moderation_screen.dart';
import '../features/product/product_screen.dart';
import '../features/search/search_screen.dart';
import '../features/stores/stores_screen.dart';

int _id(GoRouterState state) =>
    int.tryParse(state.pathParameters['id'] ?? '') ?? 0;

/// A tab of a role space: switching tabs does not animate like a push.
GoRoute _tab(String path, Widget child) => GoRoute(
  path: path,
  pageBuilder: (context, state) => NoTransitionPage(child: child),
);

/// Routes per space. Each role space (merchant, courier, moderation) has a
/// shell with its own navigation and role gate; its detail screens are
/// pushed above the shell and check the role themselves.
class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: '/',
    routes: [
      // ── Shared ────────────────────────────────────────────────────────
      GoRoute(path: '/auth', builder: (context, state) => const AuthScreen()),
      // ── Customer ──────────────────────────────────────────────────────
      GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
      GoRoute(
        path: '/alerts',
        builder: (context, state) => const AlertsScreen(),
      ),
      GoRoute(
        path: '/search',
        builder: (context, state) => SearchScreen(
          initialQuery: state.uri.queryParameters['query'] ?? '',
          initialCategory: state.uri.queryParameters['category'],
        ),
      ),
      GoRoute(
        path: '/product/:id',
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return ProductScreen(productId: id);
        },
      ),
      GoRoute(
        path: '/product/:id/stores',
        builder: (context, state) => StoresScreen(
          productId: _id(state),
          productName: state.uri.queryParameters['name'],
        ),
      ),
      GoRoute(path: '/cart', builder: (context, state) => const CartScreen()),
      GoRoute(
        path: '/checkout',
        builder: (context, state) => const CheckoutScreen(),
      ),
      GoRoute(
        path: '/orders',
        builder: (context, state) => const OrdersScreen(),
      ),
      GoRoute(
        path: '/orders/:id',
        builder: (context, state) => OrderDetailScreen(orderId: _id(state)),
      ),
      GoRoute(
        path: '/account',
        builder: (context, state) => const AccountScreen(),
      ),
      GoRoute(
        path: '/account/profile',
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(
        path: '/support',
        builder: (context, state) =>
            SupportScreen(orderNumber: state.uri.queryParameters['order']),
      ),
      GoRoute(
        path: '/support/tickets/:id',
        builder: (context, state) => TicketScreen(ticketId: _id(state)),
      ),
      GoRoute(
        path: '/contributions',
        builder: (context, state) => const ContributionsScreen(),
      ),
      GoRoute(
        path: '/contributions/new',
        builder: (context, state) => const PriceReportScreen(),
      ),
      // ── Merchant ──────────────────────────────────────────────────────
      GoRoute(
        path: '/merchant',
        redirect: (context, state) => '/merchant/orders',
      ),
      ShellRoute(
        builder: (context, state, child) =>
            MerchantShell(location: state.uri.path, child: child),
        routes: [
          _tab(
            '/merchant/orders',
            ShopPage(builder: (shop) => MerchantOrdersScreen(shopId: shop.id)),
          ),
          _tab(
            '/merchant/offers',
            ShopPage(builder: (shop) => MerchantOffersScreen(shopId: shop.id)),
          ),
          _tab(
            '/merchant/stock',
            ShopPage(builder: (shop) => MerchantStockScreen(shopId: shop.id)),
          ),
          _tab('/merchant/complaints', const MerchantComplaintsScreen()),
          _tab(
            '/merchant/shop',
            ShopPage(builder: (shop) => MerchantShopScreen(shop: shop)),
          ),
        ],
      ),
      GoRoute(
        path: '/merchant/orders/:id',
        builder: (context, state) => MerchantOrderScreen(orderId: _id(state)),
      ),
      GoRoute(
        path: '/merchant/complaints/:id',
        builder: (context, state) =>
            MerchantComplaintScreen(complaintId: _id(state)),
      ),
      // ── Courier ───────────────────────────────────────────────────────
      GoRoute(
        path: '/courier',
        redirect: (context, state) => '/courier/deliveries',
      ),
      ShellRoute(
        builder: (context, state, child) =>
            CourierShell(location: state.uri.path, child: child),
        routes: [
          _tab(
            '/courier/deliveries',
            const CourierDeliveriesScreen(available: false),
          ),
          _tab(
            '/courier/available',
            const CourierDeliveriesScreen(available: true),
          ),
          _tab('/courier/profile', const CourierProfileScreen()),
        ],
      ),
      GoRoute(
        path: '/courier/deliveries/:id',
        builder: (context, state) =>
            CourierDeliveryScreen(deliveryId: _id(state)),
      ),
      // ── Moderation ────────────────────────────────────────────────────
      GoRoute(
        path: '/moderation',
        redirect: (context, state) => '/moderation/pending',
      ),
      ShellRoute(
        builder: (context, state, child) =>
            ModerationShell(location: state.uri.path, child: child),
        routes: [
          _tab('/moderation/pending', const ModerationQueueScreen()),
          _tab('/moderation/decided', const ModerationDecisionsScreen()),
        ],
      ),
    ],
  );
}
