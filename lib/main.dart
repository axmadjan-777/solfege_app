import 'package:flutter/material.dart';

import 'app.dart';
import 'core/supabase/supabase_client_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseClientProvider.initialize();
  runApp(const SolfegeApp());
}
