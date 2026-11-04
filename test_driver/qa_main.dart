import 'package:flutter/widgets.dart';
import 'package:flutter/semantics.dart';

import 'package:solfege_app/main.dart' as production;

// Keep the handle alive for the whole app. Playwright drives Flutter's real
// accessibility DOM rather than injecting routes or replacing app services.
SemanticsHandle? _semantics;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _semantics ??= WidgetsBinding.instance.ensureSemantics();
  await production.main();
}
