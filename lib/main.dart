import 'package:flutter/material.dart';

import 'app/app.dart';
import 'core/storage/hive_store.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initHive();
  runApp(const App());
}
