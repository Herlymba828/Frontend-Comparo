import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../core/widgets/app_navigation_bar.dart';
import 'not_found_screen.dart';

import '../features/account/account_screen.dart';
import '../features/account/channels_screen.dart';
import '../features/account/consents_screen.dart';
import '../features/account/complaint_screen.dart';
import '../features/account/contributions_screen.dart';
import '../features/account/support_screen.dart';
import '../features/alerts/alerts_screen.dart';
import '../features/assistant/assistant_screen.dart';
import '../features/budget/budgets_screen.dart';
import '../features/commerce/basket_optimisation_screen.dart';
import '../features/commerce/cart_screen.dart';
import '../features/commerce/checkout_screen.dart';
import '../features/commerce/order_detail_screen.dart';
import '../features/commerce/orders_screen.dart';
import '../features/contributions/price_report_screen.dart';
import '../features/courier/courier_deliveries_screen.dart';
import '../features/courier/courier_delivery_screen.dart';
import '../features/courier/courier_profile_screen.dart';
import '../features/courier/courier_shell.dart';
import '../features/favorites/favorites_screen.dart';
import '../features/home/home_screen.dart';
import '../features/identity/auth_screen.dart';
import '../features/identity/password_reset_screen.dart';
import '../features/merchant/merchant_complaints_screen.dart';
import '../features/merchant/merchant_offers_screen.dart';
import '../features/merchant/merchant_order_screen.dart';
import '../features/merchant/merchant_orders_screen.dart';
import '../features/merchant/merchant_shell.dart';
import '../features/merchant/merchant_shop_screen.dart';
import '../features/merchant/merchant_stats_screen.dart';
import '../features/merchant/merchant_stock_screen.dart';
import '../features/moderation/moderation_review_screens.dart';
import '../features/moderation/moderation_screen.dart';
import '../features/product/product_screen.dart';
import '../features/roles/application_screen.dart';
import '../features/roles/applications_review_screens.dart';
import '../features/roles/my_roles_screen.dart';
import '../features/search/search_screen.dart';
import '../features/stores/stores_screen.dart';
import '../features/support_agent/support_agent_screens.dart';

/// The numeric id of a route; [_rejectInvalidId] has already turned back
/// any address whose id is not a positive number.
int _id(GoRouterState state) =>
    int.tryParse(state.pathParameters['id'] ?? '') ?? 0;

const _notFoundPath = '/introuvable';

String? _rejectInvalidId(BuildContext context, GoRouterState state) {
  final id = state.pathParameters['id'];
  if (id == null) {
    return null;
  }
  return (int.tryParse(id.trim()) ?? 0) < 1 ? _notFoundPath : null;
}

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
    redirect: _rejectInvalidId,
    errorBuilder: (context, state) => const NotFoundScreen(),
    routes: [
      GoRoute(
        path: _notFoundPath,
        builder: (context, state) => const NotFoundScreen(),
      ),
      // ── Shared ────────────────────────────────────────────────────────
      GoRoute(path: '/auth', builder: (context, state) => const AuthScreen()),
      GoRoute(
        path: '/auth/reset',
        builder: (context, state) => PasswordResetScreen(
          initialEmail: state.uri.queryParameters['email'] ?? '',
        ),
      ),
      // ── Customer ──────────────────────────────────────────────────────
      ShellRoute(
        builder: (context, state, child) =>
            CustomerShell(location: state.uri.path, child: child),
        routes: [
          _tab('/', const HomeScreen()),
          GoRoute(
            path: '/search',
            pageBuilder: (context, state) => NoTransitionPage(
              child: SearchScreen(
                initialQuery: state.uri.queryParameters['query'] ?? '',
                initialCategory: state.uri.queryParameters['category'],
              ),
            ),
          ),
          _tab('/cart', const CartScreen()),
          _tab('/account', const AccountScreen()),
        ],
      ),
      GoRoute(
        path: '/assistant',
        builder: (context, state) => const AssistantScreen(),
      ),
      GoRoute(
        path: '/alerts',
        builder: (context, state) => const AlertsScreen(),
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
      GoRoute(
        path: '/cart/optimise',
        builder: (context, state) => const BasketOptimisationScreen(),
      ),
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
        path: '/account/profile',
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/account/budgets',
        builder: (context, state) => const BudgetsScreen(),
      ),
      GoRoute(
        path: '/account/budgets/:id',
        builder: (context, state) => BudgetScreen(budgetId: _id(state)),
      ),
      GoRoute(
        path: '/account/favorites',
        builder: (context, state) => const FavoritesScreen(),
      ),
      GoRoute(
        path: '/account/roles',
        builder: (context, state) => const MyRolesScreen(),
      ),
      GoRoute(
        path: '/account/roles/applications/:id',
        builder: (context, state) =>
            ApplicationScreen(applicationId: _id(state)),
      ),
      GoRoute(
        path: '/account/channels',
        builder: (context, state) => const ChannelsScreen(),
      ),
      GoRoute(
        path: '/account/privacy',
        builder: (context, state) => const ConsentsScreen(),
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
        path: '/support/complaints/:id',
        builder: (context, state) => ComplaintScreen(complaintId: _id(state)),
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
        path: '/merchant/stats',
        builder: (context, state) => const MerchantStatsScreen(),
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
      // ── Support ───────────────────────────────────────────────────────
      GoRoute(
        path: '/agent',
        redirect: (context, state) => '/agent/complaints',
      ),
      ShellRoute(
        builder: (context, state, child) =>
            SupportShell(location: state.uri.path, child: child),
        routes: [
          _tab('/agent/complaints', const AgentComplaintsScreen()),
          _tab('/agent/tickets', const AgentTicketsScreen()),
        ],
      ),
      GoRoute(
        path: '/agent/complaints/:id',
        builder: (context, state) =>
            AgentComplaintScreen(complaintId: _id(state)),
      ),
      GoRoute(
        path: '/agent/tickets/:id',
        builder: (context, state) => AgentTicketScreen(ticketId: _id(state)),
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
          _tab('/moderation/anomalies', const ModerationAnomaliesScreen()),
          _tab('/moderation/applications', const ApplicationsQueueScreen()),
          _tab('/moderation/roles', const RoleGrantsScreen()),
        ],
      ),
      GoRoute(
        path: '/moderation/applications/:id',
        builder: (context, state) =>
            ApplicationReviewScreen(applicationId: _id(state)),
      ),
    ],
  );
}
