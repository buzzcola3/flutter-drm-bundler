import 'package:flutter_drm_bundler/src/cache.dart';
import 'package:flutter_drm_bundler/src/cli/command_runner.dart';
import 'package:flutter_drm_bundler/src/common.dart';
import 'package:flutter_drm_bundler/src/fltool/common.dart';

import 'package:flutter_drm_bundler/src/fltool/globals.dart' as globals;
import 'package:flutter_drm_bundler/src/more_os_utils.dart';

class PrecacheCommand extends FlutterDrmBundlerCommand {
  @override
  String get name => 'precache';

  @override
  String get description =>
      'Populate the flutter_drm_bundler\'s cache of binary artifacts.';

  @override
  final String category = 'Flutter DRM Bundler';

  @override
  Future<FlutterCommandResult> runCommand() async {
    final os = switch (globals.os) {
      MoreOperatingSystemUtils os => os,
      _ => throw StateError(
          'Operating system utils is not an FPiOperatingSystemUtils',
        ),
    };

    final host = switch (os.fpiHostPlatform) {
      FlutterDrmHostPlatform.windowsARM64 => FlutterDrmHostPlatform.windowsX64,
      FlutterDrmHostPlatform.darwinARM64 => FlutterDrmHostPlatform.darwinX64,
      FlutterDrmHostPlatform other => other
    };

    // update the cached flutter-drm-embedder artifacts
    await flutterDrmBundlerCache.updateAll(
      const {DevelopmentArtifact.universal},
      offline: false,
      host: host,
      flutterDrmPlatforms: FlutterDrmTargetPlatform.values.toSet(),
      engineFlavors: EngineFlavor.values.toSet(),
      includeDebugSymbols: true,
    );

    return FlutterCommandResult.success();
  }
}
