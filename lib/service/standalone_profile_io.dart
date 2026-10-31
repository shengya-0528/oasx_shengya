import 'dart:io';
import 'package:get_storage/get_storage.dart';

/// Optional isolated preferences for a side-by-side local build.
Future<void> initializeStandaloneProfile() async {
  if (!const bool.fromEnvironment('OASX_ISOLATED_PROFILE')) return;
  final profile = Directory(
    '${File(Platform.resolvedExecutable).parent.path}${Platform.pathSeparator}profile',
  );
  await profile.create(recursive: true);
  await GetStorage('GetStorage', profile.path).initStorage;
}
