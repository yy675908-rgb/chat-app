import 'dart:io';

void main() {
  final file = File('android/app/build.gradle.kts');
  final source = file.readAsStringSync();
  const needle = 'signingConfig = signingConfigs.getByName("debug")';
  const replacement = '''signingConfig = signingConfigs.create("linjian") {
                storeFile = file("/home/runner/.android/debug.keystore")
                storePassword = "android"
                keyAlias = "androiddebugkey"
                keyPassword = "android"
            }''';
  if (!source.contains(needle)) {
    stderr.writeln('Flutter Android template no longer contains debug signing');
    exitCode = 1;
    return;
  }
  file.writeAsStringSync(source.replaceFirst(needle, replacement));
}
