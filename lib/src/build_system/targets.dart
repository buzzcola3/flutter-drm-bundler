// ignore_for_file: avoid_print, implementation_imports

import 'dart:async';
import 'dart:convert';

import 'package:flutterpi_tool/src/artifacts.dart';
import 'package:flutterpi_tool/src/build_system/extended_environment.dart';
import 'package:flutterpi_tool/src/cli/flutterpi_command.dart';
import 'package:flutterpi_tool/src/common.dart';
import 'package:flutterpi_tool/src/fltool/common.dart';
import 'package:flutterpi_tool/src/fltool/globals.dart';
import 'package:flutterpi_tool/src/more_os_utils.dart';
import 'package:path/path.dart' as p;

class ReleaseBundleFlutterpiAssets extends CompositeTarget {
  ReleaseBundleFlutterpiAssets({
    required this.target,
    required this.layout,
    bool debugSymbols = false,
    bool forceBundleFlutterpi = false,
  }) : super([
          CopyFlutterAssets(
            layout: layout,
            buildMode: BuildMode.release,
          ),
          FlutterpiPluginBundle(layout: layout),
          CopyIcudtl(layout: layout),
          const DartBuildForNative(),
          const KernelSnapshot(),
          const InstallCodeAssets(),
          CopyFlutterpiEngine(
            target: target,
            flavor: EngineFlavor.release,
            includeDebugSymbols: debugSymbols,
            layout: layout,
          ),
          if (layout == FilesystemLayout.flutterPi || forceBundleFlutterpi)
            CopyFlutterpiBinary(
              target: target,
              buildMode: BuildMode.release,
              layout: layout,
            ),
          FlutterpiAppElf(
            AotElfRelease(TargetPlatform.linux_arm64),
            layout: layout,
          ),
        ]);

  final FlutterpiTargetPlatform target;
  final FilesystemLayout layout;

  @override
  String get name => 'release_bundle_flutterpi_${target.shortName}_assets';
}

class ProfileBundleFlutterpiAssets extends CompositeTarget {
  ProfileBundleFlutterpiAssets({
    required this.target,
    bool debugSymbols = false,
    required FilesystemLayout layout,
    bool forceBundleFlutterpi = false,
  }) : super([
          CopyFlutterAssets(
            layout: layout,
            buildMode: BuildMode.profile,
          ),
          FlutterpiPluginBundle(layout: layout),
          CopyIcudtl(layout: layout),
          const DartBuildForNative(),
          const KernelSnapshot(),
          const InstallCodeAssets(),
          CopyFlutterpiEngine(
            target: target,
            flavor: EngineFlavor.profile,
            includeDebugSymbols: debugSymbols,
            layout: layout,
          ),
          if (layout == FilesystemLayout.flutterPi || forceBundleFlutterpi)
            CopyFlutterpiBinary(
              target: target,
              buildMode: BuildMode.profile,
              layout: layout,
            ),
          FlutterpiAppElf(
            AotElfProfile(TargetPlatform.linux_arm64),
            layout: layout,
          ),
        ]);

  final FlutterpiTargetPlatform target;

  @override
  String get name => 'profile_bundle_flutterpi_${target.shortName}_assets';
}

class DebugBundleFlutterpiAssets extends CompositeTarget {
  DebugBundleFlutterpiAssets({
    required this.target,
    bool unoptimized = false,
    bool debugSymbols = false,
    required FilesystemLayout layout,
    bool forceBundleFlutterpi = false,
  }) : super([
          CopyFlutterAssets(
            layout: layout,
            buildMode: BuildMode.debug,
          ),
          FlutterpiPluginBundle(layout: layout),
          CopyIcudtl(layout: layout),
          const DartBuildForNative(),
          const KernelSnapshot(),
          const InstallCodeAssets(),
          CopyFlutterpiEngine(
            target: target,
            flavor: unoptimized ? EngineFlavor.debugUnopt : EngineFlavor.debug,
            includeDebugSymbols: debugSymbols,
            layout: layout,
          ),
          if (layout == FilesystemLayout.flutterPi || forceBundleFlutterpi)
            CopyFlutterpiBinary(
              target: target,
              buildMode: BuildMode.debug,
              layout: layout,
            ),
        ]);

  final FlutterpiTargetPlatform target;

  @override
  String get name => 'debug_bundle_flutterpi_assets';
}

class CopyIcudtl extends Target {
  const CopyIcudtl({required this.layout});

  final FilesystemLayout layout;

  @override
  String get name => 'flutterpi_copy_icudtl';

  @override
  List<Source> get inputs => const <Source>[
        Source.artifact(Artifact.icuData),
      ];

  @override
  List<Source> get outputs => <Source>[
        switch (layout) {
          FilesystemLayout.flutterPi =>
            Source.pattern('{OUTPUT_DIR}/icudtl.dat'),
          FilesystemLayout.metaFlutter =>
            Source.pattern('{OUTPUT_DIR}/data/icudtl.dat'),
        },
      ];

  @override
  List<Target> get dependencies => [];

  @override
  Future<void> build(Environment environment) async {
    final icudtl = environment.fileSystem
        .file(environment.artifacts.getArtifactPath(Artifact.icuData));

    final outputDir = switch (layout) {
      FilesystemLayout.flutterPi => environment.outputDir,
      FilesystemLayout.metaFlutter =>
        environment.outputDir.childDirectory('data'),
    };
    if (!outputDir.existsSync()) {
      outputDir.createSync(recursive: true);
    }

    final outputFile = outputDir.childFile('icudtl.dat');
    icudtl.copySync(outputFile.path);
  }
}

extension _FileExecutableBits on File {
  (bool owner, bool group, bool other) getExecutableBits() {
    // ignore: constant_identifier_names
    const S_IXUSR = 00100, S_IXGRP = 00010, S_IXOTH = 00001;

    final stat = statSync();
    final mode = stat.mode;

    return (
      (mode & S_IXUSR) != 0,
      (mode & S_IXGRP) != 0,
      (mode & S_IXOTH) != 0
    );
  }
}

void fixupExePermissions(
  File input,
  File output, {
  required Platform platform,
  required Logger logger,
  required MoreOperatingSystemUtils os,
}) {
  if (platform.isLinux || platform.isMacOS) {
    final inputExeBits = input.getExecutableBits();
    final outputExeBits = output.getExecutableBits();

    if (outputExeBits != (true, true, true)) {
      if (inputExeBits == outputExeBits) {
        logger.printTrace(
          '${input.basename} in cache was not universally executable. '
          'Changing permissions...',
        );
      } else {
        logger.printTrace(
          'Copying ${input.basename} from cache to output directory did not preserve executable bit. '
          'Changing permissions...',
        );
      }

      os.chmod(output, 'ugo+x');
    }
  }
}

class CopyFlutterpiBinary extends Target {
  CopyFlutterpiBinary({
    required this.target,
    required this.buildMode,
    required this.layout,
  });

  final FlutterpiTargetPlatform target;
  final BuildMode buildMode;
  final FilesystemLayout layout;

  @override
  Future<void> build(Environment environment) async {
    final artifacts = environment.artifacts;
    if (artifacts is! FlutterpiArtifacts) {
      throw StateError(
        'Expected artifacts to be a FlutterpiArtifacts, '
        'but got ${artifacts.runtimeType}.',
      );
    }

    final file = artifacts
        .getFlutterpiArtifact(FlutterpiBinary(target: target, mode: buildMode));

    assert(file.fileSystem == environment.fileSystem);

    final outputDir = switch (layout) {
      FilesystemLayout.flutterPi => environment.outputDir,
      FilesystemLayout.metaFlutter =>
        environment.outputDir.childDirectory('bin'),
    };
    if (!outputDir.existsSync()) {
      outputDir.createSync(recursive: true);
    }

    final outputFile = outputDir.childFile('flutter-pi');
    file.copySync(outputFile.path);

    if (environment.platform.isLinux || environment.platform.isMacOS) {
      final inputExeBits = file.getExecutableBits();
      final outputExeBits = outputFile.getExecutableBits();

      if (outputExeBits != (true, true, true)) {
        if (inputExeBits == outputExeBits) {
          environment.logger.printTrace(
            'flutter-pi binary in cache was not universally executable. '
            'Changing permissions...',
          );
        } else {
          environment.logger.printTrace(
            'Copying flutter-pi binary from cache to output directory did not preserve executable bit. '
            'Changing permissions...',
          );
        }

        os.chmod(outputFile, 'ugo+x');
      }
    }
  }

  @override
  List<Target> get dependencies => [];

  @override
  List<Source> get inputs => <Source>[
        FlutterpiArtifactSource(
          FlutterpiBinary(target: target, mode: buildMode),
        ),
      ];

  @override
  String get name => 'copy_flutterpi';

  @override
  List<Source> get outputs => <Source>[
        switch (layout) {
          FilesystemLayout.flutterPi =>
            Source.pattern('{OUTPUT_DIR}/flutter-pi'),
          FilesystemLayout.metaFlutter =>
            Source.pattern('{OUTPUT_DIR}/bin/flutter-pi'),
        },
      ];
}

class CopyFlutterpiEngine extends Target {
  CopyFlutterpiEngine({
    required this.target,
    required this.flavor,
    required this.layout,
    this.includeDebugSymbols = false,
  })  : _engine = Engine(
          target: target,
          flavor: flavor,
        ),
        _debugSymbols = EngineDebugSymbols(
          target: target,
          flavor: flavor,
        );

  final FlutterpiTargetPlatform target;
  final EngineFlavor flavor;
  final bool includeDebugSymbols;
  final FilesystemLayout layout;

  final FlutterpiArtifact _engine;
  final FlutterpiArtifact _debugSymbols;

  @override
  List<Target> get dependencies => [];

  @override
  List<Source> get inputs => [
        FlutterpiArtifactSource(_engine),
        if (includeDebugSymbols) FlutterpiArtifactSource(_debugSymbols),
      ];

  @override
  String get name => 'copy_flutterpi_engine_${target.shortName}_$flavor';

  @override
  List<Source> get outputs => [
        switch (layout) {
          FilesystemLayout.flutterPi =>
            Source.pattern('{OUTPUT_DIR}/libflutter_engine.so'),
          FilesystemLayout.metaFlutter =>
            Source.pattern('{OUTPUT_DIR}/lib/libflutter_engine.so'),
        },
        if (includeDebugSymbols)
          switch (layout) {
            FilesystemLayout.flutterPi =>
              Source.pattern('{OUTPUT_DIR}/libflutter_engine.dbgsyms'),
            FilesystemLayout.metaFlutter =>
              Source.pattern('{OUTPUT_DIR}/lib/libflutter_engine.dbgsyms'),
          },
      ];

  @override
  Future<void> build(covariant ExtendedEnvironment environment) async {
    final outputDir = switch (layout) {
      FilesystemLayout.flutterPi => environment.outputDir,
      FilesystemLayout.metaFlutter =>
        environment.outputDir.childDirectory('lib'),
    };

    if (!outputDir.existsSync()) {
      outputDir.createSync(recursive: true);
    }

    final outputFile = outputDir.childFile('libflutter_engine.so');

    final engine = environment.artifacts.getFlutterpiArtifact(_engine);

    engine.copySync(outputFile.path);

    fixupExePermissions(
      engine,
      outputFile,
      platform: environment.platform,
      logger: environment.logger,
      os: environment.operatingSystemUtils,
    );

    if (includeDebugSymbols) {
      final dbgsymsOutputFile =
          outputDir.childFile('libflutter_engine.dbgsyms');

      final dbgsyms = environment.artifacts.getFlutterpiArtifact(_debugSymbols);

      dbgsyms.copySync(dbgsymsOutputFile.path);

      fixupExePermissions(
        dbgsyms,
        dbgsymsOutputFile,
        platform: environment.platform,
        logger: environment.logger,
        os: environment.operatingSystemUtils,
      );
    }
  }
}

/// A wrapper for AOT compilation that copies app.so into the output directory.
class FlutterpiAppElf extends Target {
  /// Create a [FlutterpiAppElf] wrapper for [aotTarget].
  const FlutterpiAppElf(this.aotTarget, {required this.layout});

  /// The [AotElfBase] subclass that produces the app.so.
  final AotElfBase aotTarget;
  final FilesystemLayout layout;

  @override
  String get name => 'flutterpi_aot_bundle';

  @override
  List<Source> get inputs => const <Source>[
        Source.pattern('{BUILD_DIR}/app.so'),
      ];

  @override
  List<Source> get outputs => <Source>[
        switch (layout) {
          FilesystemLayout.flutterPi => Source.pattern('{OUTPUT_DIR}/app.so'),
          FilesystemLayout.metaFlutter =>
            Source.pattern('{OUTPUT_DIR}/lib/libapp.so'),
        },
      ];

  @override
  List<Target> get dependencies => <Target>[
        aotTarget,
      ];

  @override
  Future<void> build(covariant ExtendedEnvironment environment) async {
    final appElf = environment.buildDir.childFile('app.so');
    final outputDir = switch (layout) {
      FilesystemLayout.flutterPi => environment.outputDir,
      FilesystemLayout.metaFlutter =>
        environment.outputDir.childDirectory('lib'),
    };
    if (!outputDir.existsSync()) {
      outputDir.createSync(recursive: true);
    }

    final outputFile = switch (layout) {
      FilesystemLayout.flutterPi => outputDir.childFile('app.so'),
      FilesystemLayout.metaFlutter => outputDir.childFile('libapp.so'),
    };

    appElf.copySync(outputFile.path);

    fixupExePermissions(
      appElf,
      outputFile,
      platform: environment.platform,
      logger: logger,
      os: environment.operatingSystemUtils,
    );
  }
}

/// Copies the kernel_blob.bin to the output directory.
class CopyFlutterAssetsOld extends CopyFlutterBundle {
  const CopyFlutterAssetsOld();

  @override
  String get name => 'bundle_flutterpi_assets';
}

class CopyFlutterAssets extends Target {
  const CopyFlutterAssets({
    required this.layout,
    required this.buildMode,
  });

  final FilesystemLayout layout;
  final BuildMode buildMode;

  @override
  String get name => 'copy_flutterpi_assets_${layout}_$buildMode';

  @override
  List<Target> get dependencies => <Target>[
        const KernelSnapshot(),
      ];

  @override
  List<Source> get inputs => const <Source>[
        Source.pattern('{PROJECT_DIR}/pubspec.yaml'),
        ...IconTreeShaker.inputs,
      ];

  @override
  List<Source> get outputs => <Source>[
        if (buildMode.isJit)
          switch (layout) {
            FilesystemLayout.flutterPi =>
              Source.pattern('{OUTPUT_DIR}/kernel_blob.bin'),
            FilesystemLayout.metaFlutter => Source.pattern(
                '{OUTPUT_DIR}/data/flutter_assets/kernel_blob.bin',
              ),
          },
      ];

  @override
  List<String> get depfiles => const <String>['flutter_assets.d'];

  String getVersionInfo(Map<String, String> defines) {
    return FlutterProject.current().getVersionInfo();
  }

  @override
  Future<void> build(Environment environment) async {
    final buildMode = switch (environment.defines[kBuildMode]) {
      null => throw MissingDefineException(kBuildMode, name),
      String value => BuildMode.fromCliName(value),
    };

    final outputDir = switch (layout) {
      FilesystemLayout.flutterPi => environment.outputDir,
      FilesystemLayout.metaFlutter => environment.outputDir
          .childDirectory('data')
          .childDirectory('flutter_assets'),
    };
    if (!outputDir.existsSync()) {
      outputDir.createSync(recursive: true);
    }

    if (buildMode.isJit) {
      environment.buildDir
          .childFile('app.dill')
          .copySync(outputDir.childFile('kernel_blob.bin').path);
    }

    final versionInfo = getVersionInfo(environment.defines);

    final dartHookResult = await DartBuild.loadHookResult(environment);

    final depfile = await copyAssets(
      environment, outputDir,

      // this is not really used internally,
      // copyAssets will just do something special if a web platform is
      // passed.
      //
      // So we don't need this to match the platform we're actually building
      // for.
      targetPlatform: TargetPlatform.linux_arm64,
      buildMode: buildMode,
      additionalContent: <String, DevFSContent>{
        'version.json': DevFSStringContent(versionInfo),
        'NativeAssetsManifest.json': DevFSFileContent(
          environment.buildDir.childFile('native_assets.json'),
        ),
      },
      dartHookResult: dartHookResult,
    );

    environment.depFileService.writeToFile(
      depfile,
      environment.buildDir.childFile('flutter_assets.d'),
    );
  }
}

class _FlutterpiPluginInfo {
  _FlutterpiPluginInfo({required this.name, required this.path});

  final String name;
  final String path;
}

String _normalizePluginName(String name) => name.replaceAll('-', '_');

String _pluginLibraryName(String name) =>
    'lib${_normalizePluginName(name)}_plugin.so';

const String _flutterLinuxGtkShimInputName = 'libflutter_linux_gtk.so';
const String _flutterLinuxGtkShimOutputName = 'libflutter_linux_gtk.so';
const String _runBundleScriptName = 'run_bundle.sh';
const String _runBundleScriptContent = r'''#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 /path/to/bundle [flutter-pi args...]" >&2
  exit 1
fi

bundle="$1"
shift

bundle_dir="$(cd "$bundle" && pwd)"
flutterpi="$bundle_dir/flutter-pi"

if [[ ! -x "$flutterpi" ]]; then
  echo "Error: bundled flutter-pi not found or not executable at $flutterpi" >&2
  exit 1
fi

plugins_dir="$bundle_dir/plugins"
export LD_LIBRARY_PATH="$bundle_dir:$plugins_dir${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
exec "$flutterpi" "$@" "$bundle_dir"
''';

String _pluginSymbolName(String name) =>
    '${_normalizePluginName(name)}_plugin_register_with_registrar';

List<_FlutterpiPluginInfo> _readLinuxPlugins(ExtendedEnvironment environment) {
  final pluginsFile = environment.projectDir
      .childFile('.flutter-plugins-dependencies');
  if (!pluginsFile.existsSync()) {
    environment.logger.printTrace(
      'No .flutter-plugins-dependencies file found. Skipping plugin bundling.',
    );
    return const [];
  }

  final content = pluginsFile.readAsStringSync();
  final Map<String, Object?> parsed =
      (jsonDecode(content) as Map<String, Object?>);
  final plugins = parsed['plugins'];
  if (plugins is! Map<String, Object?>) {
    return const [];
  }

  final linuxPlugins = plugins['linux'];
  if (linuxPlugins is! List<Object?>) {
    return const [];
  }

  return linuxPlugins
      .whereType<Map<String, Object?>>()
      .map((entry) {
        final name = entry['name'];
        final path = entry['path'];
        if (name is String && path is String) {
          return _FlutterpiPluginInfo(name: name, path: path);
        }
        return null;
      })
      .whereType<_FlutterpiPluginInfo>()
      .toList(growable: false);
}

File? _findFirstFileNamed(
  Directory root,
  String fileName, {
  List<String> preferredPathTokens = const <String>[],
}) {
  if (!root.existsSync()) {
    return null;
  }

  final matches = root
      .listSync(recursive: true, followLinks: false)
      .whereType<File>()
      .where((file) => file.basename == fileName)
      .toList(growable: false);

  if (matches.isEmpty) {
    return null;
  }

  bool segmentMatchesToken(String segment, String token) {
    if (segment == token) {
      return true;
    }
    return segment.startsWith('$token-') ||
      segment.startsWith('${token}_') ||
      segment.endsWith('-$token') ||
      segment.endsWith('_$token') ||
      segment.contains('-$token-') ||
      segment.contains('_${token}_') ||
      segment.contains('-${token}_') ||
      segment.contains('_${token}-');
  }

  bool pathContainsToken(String normalized, String token) {
    final segments = p.split(normalized);
    return segments.any((segment) => segmentMatchesToken(segment, token));
  }

  File pickBestMatch() {
    final filteredMatches = preferredPathTokens.isEmpty
        ? matches
        : matches
            .where((file) {
              final normalized = p.normalize(file.path);
              return preferredPathTokens
                  .any((token) => pathContainsToken(normalized, token));
            })
            .toList(growable: false);

    final bestMatches =
        filteredMatches.isNotEmpty ? filteredMatches : matches;

    for (final file in bestMatches) {
      final normalized = p.normalize(file.path);
      if (normalized.contains('${p.separator}bundle${p.separator}lib') ||
          normalized.contains('${p.separator}plugins${p.separator}')) {
        return file;
      }
    }
    return bestMatches.first;
  }

  return pickBestMatch();
}

List<String> _targetPathTokens(String? targetShortName) {
  if (targetShortName == 'aarch64-generic' ||
      targetShortName == 'pi3-64' ||
      targetShortName == 'pi4-64') {
    return const <String>['aarch64', 'arm64'];
  }

  if (targetShortName == 'armv7-generic' ||
      targetShortName == 'pi3' ||
      targetShortName == 'pi4') {
    return const <String>['armv7', 'arm'];
  }

  if (targetShortName == 'x64-generic') {
    return const <String>['x64', 'x86_64'];
  }

  if (targetShortName == 'riscv64-generic') {
    return const <String>['riscv64'];
  }

  return const <String>[];
}

File? _findPluginLibrary(
  ExtendedEnvironment environment,
  _FlutterpiPluginInfo plugin,
) {
  final fs = environment.fileSystem;
  final libName = _pluginLibraryName(plugin.name);
  final targetTokens =
      _targetPathTokens(environment.defines['flutterpi-target']);

  final pluginDir = p.isAbsolute(plugin.path)
      ? fs.directory(plugin.path)
      : environment.projectDir.childDirectory(plugin.path);

  final buildDir = environment.projectDir.childDirectory('build');

  final candidates = <Directory>[
    buildDir.childDirectory('flutter-pi').childDirectory('plugins'),
    buildDir.childDirectory('linux'),
    pluginDir.childDirectory('build'),
  ];

  for (final dir in candidates) {
    final match = _findFirstFileNamed(
      dir,
      libName,
      preferredPathTokens: targetTokens,
    );
    if (match != null) {
      return match;
    }
  }

  final fallback = _findFirstFileNamed(
    buildDir,
    libName,
    preferredPathTokens: targetTokens,
  );
  if (fallback != null) {
    return fallback;
  }

  return null;
}

File? _findFlutterLinuxGtkLibrary(ExtendedEnvironment environment) {
  final artifacts = environment.artifacts;
  if (artifacts is! FlutterpiArtifacts) {
    return null;
  }

  final targetShortName = environment.defines['flutterpi-target'];
  if (targetShortName == null) {
    return null;
  }

  final target = FlutterpiTargetPlatform.values
      .firstWhere((platform) => platform.shortName == targetShortName);

  final buildModeName = environment.defines[kBuildMode];
  if (buildModeName == null) {
    return null;
  }

  final buildMode = BuildMode.fromCliName(buildModeName);

  return artifacts.getFlutterpiArtifact(
    FlutterpiGtkShim(target: target, mode: buildMode),
  );
}

class FlutterpiPluginBundle extends Target {
  const FlutterpiPluginBundle({required this.layout});

  final FilesystemLayout layout;

  @override
  String get name => 'flutterpi_plugin_bundle';

  @override
  List<Target> get dependencies => const [];

  @override
  List<Source> get inputs => const <Source>[
        Source.pattern('{PROJECT_DIR}/.flutter-plugins-dependencies'),
      ];

  @override
  List<Source> get outputs => const <Source>[
        Source.pattern('{OUTPUT_DIR}/plugins/*'),
      Source.pattern('{OUTPUT_DIR}/run_bundle.sh'),
      ];

  @override
  Future<void> build(covariant ExtendedEnvironment environment) async {
    final outputDir = environment.outputDir;
    if (!outputDir.existsSync()) {
      outputDir.createSync(recursive: true);
    }

    final pluginOutputDir = outputDir.childDirectory('plugins');
    if (!pluginOutputDir.existsSync()) {
      pluginOutputDir.createSync(recursive: true);
    }

    final plugins = _readLinuxPlugins(environment);

    for (final plugin in plugins) {
      final libName = _pluginLibraryName(plugin.name);
      final libFile = _findPluginLibrary(environment, plugin);
      if (libFile == null) {
        environment.logger.printWarning(
          'Could not find built plugin library for ${plugin.name}. '
          'Expected $libName somewhere in build outputs.',
        );
        continue;
      }

      final outputFile = pluginOutputDir.childFile(libName);
      libFile.copySync(outputFile.path);

    }

    final runScriptOutput = outputDir.childFile(_runBundleScriptName);
    runScriptOutput.writeAsStringSync(_runBundleScriptContent);
    fixupExePermissions(
      runScriptOutput,
      runScriptOutput,
      platform: environment.platform,
      logger: environment.logger,
      os: environment.operatingSystemUtils,
    );

    final flutterGtkLib = _findFlutterLinuxGtkLibrary(environment);
    if (flutterGtkLib == null) {
      environment.logger.printTrace(
        'Could not find $_flutterLinuxGtkShimInputName in flutter-pi cache. '
        'Skipping bundling GTK shim library.',
      );
    } else {
      final gtkOutputFile =
          outputDir.childFile(_flutterLinuxGtkShimOutputName);
      flutterGtkLib.copySync(gtkOutputFile.path);
    }

    // flutter_plugins.json is intentionally not generated.
  }
}
