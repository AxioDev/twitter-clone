import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../features/auth/providers/auth_provider.dart';
import '../features/auth/screens/sign_in_screen.dart';
import '../features/auth/screens/sign_up_screen.dart';
import '../features/feed/screens/feed_screen.dart';
import '../features/notifications/screens/notifications_screen.dart';
import '../features/post/screens/create_post_screen.dart';
import '../features/post/screens/post_detail_screen.dart';
import '../features/profile/screens/edit_profile_screen.dart';
import '../features/profile/screens/followers_screen.dart';
import '../features/profile/screens/profile_screen.dart';
import '../features/search/screens/search_screen.dart';
import 'widgets/main_shell.dart';

part 'router.g.dart';

@riverpod
GoRouter router(Ref ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/feed',
    redirect: (context, state) {
      final isLoggedIn = authState.value?.session != null;
      final isAuthRoute = state.matchedLocation.startsWith('/auth');

      if (!isLoggedIn && !isAuthRoute) return '/auth/signin';
      if (isLoggedIn && isAuthRoute) return '/feed';
      return null;
    },
    routes: [
      GoRoute(
        path: '/auth/signin',
        builder: (_, _s) => const SignInScreen(),
      ),
      GoRoute(
        path: '/auth/signup',
        builder: (_, _s) => const SignUpScreen(),
      ),
      ShellRoute(
        builder: (_, _s, child) => MainShell(child: child),
        routes: [
          GoRoute(
            path: '/feed',
            builder: (_, _s) => const FeedScreen(),
          ),
          GoRoute(
            path: '/search',
            builder: (_, _s) => const SearchScreen(),
          ),
          GoRoute(
            path: '/notifications',
            builder: (_, _s) => const NotificationsScreen(),
          ),
          GoRoute(
            path: '/profile/:userId',
            builder: (_, state) => ProfileScreen(
              userId: state.pathParameters['userId']!,
            ),
            routes: [
              GoRoute(
                path: 'edit',
                builder: (_, _s) => const EditProfileScreen(),
              ),
              GoRoute(
                path: 'followers',
                builder: (_, state) => FollowersScreen(
                  userId: state.pathParameters['userId']!,
                  showFollowers: true,
                ),
              ),
              GoRoute(
                path: 'following',
                builder: (_, state) => FollowersScreen(
                  userId: state.pathParameters['userId']!,
                  showFollowers: false,
                ),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/post/create',
        builder: (_, state) => CreatePostScreen(
          replyToId: state.uri.queryParameters['replyTo'],
        ),
      ),
      GoRoute(
        path: '/post/:postId',
        builder: (_, state) => PostDetailScreen(
          postId: state.pathParameters['postId']!,
        ),
      ),
    ],
  );
}
