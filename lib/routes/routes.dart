import 'package:go_router/go_router.dart';
import 'package:widget_ui/component_detail_page/component_detail_page.dart';
import 'package:widget_ui/component_detail_page/detail_pages/card_carousel_details/view/card_carousel.dart';
import 'package:widget_ui/home/screens/home.dart';

final router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (context, state) => const MyHomePage()),
    GoRoute(
      path: '/components/details',
      builder: (context, state) {
        return ComponentDetailPage();
      },
    ),
    GoRoute(
      path: '/components/card_carousel_details',
      builder: (context, state) {
        return CardCarouselDetails();
      },
    ),
  ],
);
