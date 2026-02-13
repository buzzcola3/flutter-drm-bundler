// ignore_for_file: avoid_print, implementation_imports

import 'dart:async';

import 'package:args/command_runner.dart';
import 'package:flutter_drm_bundler/src/artifacts.dart';
import 'package:flutter_drm_bundler/src/cache.dart';
import 'package:flutter_drm_bundler/src/cli/command_runner.dart';
import 'package:flutter_drm_bundler/src/fltool/common.dart';
import 'package:flutter_drm_bundler/src/fltool/globals.dart' as globals;

import '../../common.dart';

class BuildCommand extends FlutterDrmBundlerCommand {
  static const archs = ['arm', 'arm64', 'x64', 'riscv64'];

  static const cpus = ['generic', 'pi3', 'pi4'];

  BuildCommand({bool verboseHelp = false}) {
    argParser.addSeparator(
      'Runtime mode options (Defaults to debug. At most one can be specified)',
    );

    usesEngineFlavorOption();

    argParser
      ..addSeparator('Build options')
      ..addFlag(
        'tree-shake-icons',
        help:
            'Tree shake icon fonts so that only glyphs used by the application remain.',
      );

    usesDebugSymbolsOption();

    // add --dart-define, --dart-define-from-file options
    usesDartDefineOption();
    usesTargetOption();
    usesLocalEmbedderExecutableArg(verboseHelp: verboseHelp);
    usesFilesystemLayoutArg(verboseHelp: verboseHelp);

    argParser
      ..addSeparator('Target options')
      ..addOption(
        'arch',
        allowed: archs,
        defaultsTo: 'arm',
        help: 'The target architecture to build for.',
        valueHelp: 'target arch',
        allowedHelp: {
          'arm': 'Build for 32-bit ARM. (armv7-linux-gnueabihf)',
          'arm64': 'Build for 64-bit ARM. (aarch64-linux-gnu)',
          'x64': 'Build for x86-64. (x86_64-linux-gnu)',
          'riscv64': 'Build for 64-bit RISC-V. (riscv64-linux-gnu)',
        },
      )
      ..addOption(
        'cpu',
        allowed: cpus,
        defaultsTo: 'generic',
        help:
            'If specified, uses an engine tuned for the given CPU. An engine tuned for one CPU will likely not work on other CPUs.',
        valueHelp: 'target cpu',
        allowedHelp: {
          'generic':
              'Don\'t use a tuned engine. The generic engine will work on all CPUs of the specified architecture.',
          'pi3':
              'Use a Raspberry Pi 3 tuned engine. Compatible with arm and arm64. (-mcpu=cortex-a53+nocrypto -mtune=cortex-a53)',
          'pi4':
              'Use a Raspberry Pi 4 tuned engine. Compatible with arm and arm64. (-mcpu=cortex-a72+nocrypto -mtune=cortex-a72)',
        },
      );
  }

  @override
  String get name => 'build';

  @override
  String get description => 'Builds a flutter-drm-embedder asset bundle.';

  @override
  String get category => FlutterCommandCategory.project;

  @override
  FlutterDrmBundlerCommandRunner? get runner =>
      super.runner as FlutterDrmBundlerCommandRunner;

  EngineFlavor get defaultFlavor => EngineFlavor.debug;

  int exitWithUsage({int exitCode = 1, String? errorMessage, String? usage}) {
    if (errorMessage != null) {
      print(errorMessage);
    }

    if (usage != null) {
      print(usage);
    } else {
      printUsage();
    }
    return exitCode;
  }

  FlutterDrmTargetPlatform getTargetPlatform() {
    return switch ((stringArg('arch'), stringArg('cpu'))) {
      ('arm', 'generic') => FlutterDrmTargetPlatform.genericArmV7,
      ('arm', 'pi3') => FlutterDrmTargetPlatform.pi3,
      ('arm', 'pi4') => FlutterDrmTargetPlatform.pi4,
      ('arm64', 'generic') => FlutterDrmTargetPlatform.genericAArch64,
      ('arm64', 'pi3') => FlutterDrmTargetPlatform.pi3_64,
      ('arm64', 'pi4') => FlutterDrmTargetPlatform.pi4_64,
      ('x64', 'generic') => FlutterDrmTargetPlatform.genericX64,
      ('riscv64', 'generic') => FlutterDrmTargetPlatform.genericRiscv64,
      (final arch, final cpu) => throw UsageException(
          'Unsupported target arch & cpu combination: architecture "$arch" is not supported for cpu "$cpu"',
          usage,
        ),
    };
  }

  @override
  Future<FlutterCommandResult> runCommand() async {
    final buildMode = getBuildMode();
    final flavor = getEngineFlavor();
    final debugSymbols = getIncludeDebugSymbols();
    final buildInfo = await getBuildInfo();

    final os = globals.moreOs;

    // for windows arm64, darwin arm64, we just use the x64 variant
    final host = switch (os.fpiHostPlatform) {
      FlutterDrmHostPlatform.windowsARM64 => FlutterDrmHostPlatform.windowsX64,
      FlutterDrmHostPlatform.darwinARM64 => FlutterDrmHostPlatform.darwinX64,
      FlutterDrmHostPlatform other => other
    };

    var targetPlatform = getTargetPlatform();

    if (buildMode == BuildMode.debug && !targetPlatform.isGeneric) {
      globals.logger.printTrace(
        'Non-generic target platform ($targetPlatform) is not supported '
        'for debug mode, using generic variant '
        '${targetPlatform.genericVariant}.',
      );
      targetPlatform = targetPlatform.genericVariant;
    }

    // update the cached flutter-drm-embedder artifacts
    await flutterDrmBundlerCache.updateAll(
      const {DevelopmentArtifact.universal},
      host: host,
      offline: false,
      flutterDrmPlatforms: {targetPlatform, targetPlatform.genericVariant},
      runtimeModes: {buildMode},
      engineFlavors: {flavor},
      includeDebugSymbols: debugSymbols,
    );

    FlutterDrmEmbedderArtifacts artifacts = FlutterToFlutterDrmEmbedderArtifactsForwarder(
      inner: globals.flutterDrmEmbedderArtifacts,
      host: host,
      target: targetPlatform,
    );
    var forceBundleEmbedder = false;
    if (getLocalEmbedderExecutable() case File file) {
      artifacts = LocalFlutterDrmEmbedderBinaryOverride(
        inner: artifacts,
        flutterDrmEmbedderBinary: file,
      );
      forceBundleEmbedder = true;
    }

    // actually build the flutter bundle

    await globals.builder.build(
      host: host,
      target: targetPlatform,
      buildInfo: buildInfo,
      mainPath: targetFile,
      artifacts: artifacts,

      // for `--debug-unoptimized` build mode
      unoptimized: flavor.unoptimized,
      includeDebugSymbols: debugSymbols,

      fsLayout: filesystemLayout,
      forceBundleEmbedder: forceBundleEmbedder,
    );

    return FlutterCommandResult.success();
  }
}
