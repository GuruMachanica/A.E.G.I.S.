import 'package:go_router/go_router.dart';
import '../screens/splash_screen.dart';
import '../screens/welcome_screen.dart';
import '../screens/login_screen.dart';
import '../screens/create_account_screen.dart';
import '../screens/main_shell.dart';
import '../screens/live_call_monitor_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/splash',
  routes: [
    GoRoute(
      path: '/splash',
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: '/welcome',
      builder: (context, state) => const WelcomeScreen(),
    ),
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/register',
      builder: (context, state) => const CreateAccountScreen(),
    ),
    GoRoute(
      path: '/home',
      builder: (context, state) => const MainShell(),
      routes: [
        GoRoute(
          path: 'monitor',
          builder: (context, state) => const LiveCallMonitorScreen(),
        ),
      ],
    ),
  ],
);
