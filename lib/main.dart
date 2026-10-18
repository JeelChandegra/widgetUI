import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:widget_ui/routes/routes.dart';

import 'app_common/export.dart';

void main() {
  usePathUrlStrategy(); // /components/card-carousel, no #
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'widget_ui',
      routerConfig: router,

      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple)),
    );
  }
}
