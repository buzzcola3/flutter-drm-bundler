// ignore_for_file: implementation_imports

import 'package:file/file.dart';
import 'package:meta/meta.dart';

import 'package:flutter_drm_bundler/src/fltool/common.dart' as fltool;
import 'package:flutter_drm_bundler/src/fltool/globals.dart' as globals;

import 'package:flutter_drm_bundler/src/cli/flutter_drm_bundler_command.dart';
import 'package:flutter_drm_bundler/src/artifacts.dart';

class RunCommand extends fltool.RunCommand with FlutterDrmBundlerCommandMixin {
  RunCommand({bool verboseHelp = false}) {
    usesEngineFlavorOption();
    usesDebugSymbolsOption();
    usesLocalEmbedderExecutableArg(verboseHelp: verboseHelp);
  }

  @protected
  @override
  Future<fltool.DebuggingOptions> createDebuggingOptions({
    fltool.WebDevServerConfig? webDevServerConfig,
  }) async {
    final buildInfo = await getBuildInfo();

    if (buildInfo.mode.isRelease) {
      return fltool.DebuggingOptions.disabled(buildInfo);
    } else {
      return fltool.DebuggingOptions.enabled(buildInfo);
    }
  }

  @override
  void addBuildModeFlags({
    required bool verboseHelp,
    bool defaultToRelease = true,
    bool excludeDebug = false,
    bool excludeRelease = false,
  }) {
    // noop
  }

  @override
  Future<fltool.FlutterCommandResult> runCommand() async {
    await populateCache();

    var artifacts = globals.flutterDrmEmbedderArtifacts;
    if (getLocalEmbedderExecutable() case File file) {
      artifacts = LocalFlutterDrmEmbedderBinaryOverride(
        inner: artifacts,
        flutterDrmEmbedderBinary: file,
      );
    }

    return fltool.context.run(
      body: super.runCommand,
      overrides: {
        fltool.Artifacts: () => artifacts,
      },
    );
  }
}
