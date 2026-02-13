import 'dart:async';

import 'package:file/memory.dart';
import 'package:flutter_drm_bundler/src/build_system/targets.dart';
import 'package:flutter_drm_bundler/src/cli/flutter_drm_bundler_command.dart';
import 'package:flutter_drm_bundler/src/common.dart';
import 'package:flutter_drm_bundler/src/devices/flutter_drm_ssh/device.dart';
import 'package:flutter_drm_bundler/src/fltool/common.dart' as fl;
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:flutter_drm_bundler/src/build_system/build_app.dart';

import 'src/context.dart';
import 'src/fake_flutter_version.dart';
import 'src/fake_os_utils.dart';
import 'src/fake_process_manager.dart';
import 'src/mock_build_system.dart';
import 'src/mock_flutter_drm_embedder_artifacts.dart';

void main() {
  late MemoryFileSystem fs;
  late fl.BufferLogger logger;
  late fl.Platform platform;
  late MockFlutterDrmEmbedderArtifacts flutterDrmEmbedderArtifacts;
  late MockBuildSystem buildSystem;
  late FakeMoreOperatingSystemUtils moreOs;
  late AppBuilder appBuilder;

  // ignore: no_leading_underscores_for_local_identifiers
  Future<V> _runInTestContext<V>(
    FutureOr<V> Function() fn, {
    Map<Type, fl.Generator> overrides = const {},
  }) async {
    return await runInTestContext(
      fn,
      overrides: {
        fl.Logger: () => logger,
        ProcessManager: () => FakeProcessManager.empty(),
        fl.FileSystem: () => fs,
        fl.FlutterVersion: () => FakeFlutterVersion(),
        fl.Platform: () => platform,
        fl.Artifacts: () => flutterDrmEmbedderArtifacts,
        fl.BuildSystem: () => buildSystem,
        ...overrides,
      },
    );
  }

  setUp(() {
    fs = MemoryFileSystem.test();
    logger = fl.BufferLogger.test();
    platform = fl.FakePlatform();
    flutterDrmEmbedderArtifacts = MockFlutterDrmEmbedderArtifacts();
    buildSystem = MockBuildSystem();
    moreOs = FakeMoreOperatingSystemUtils();
    appBuilder = AppBuilder(
      operatingSystemUtils: moreOs,
      buildSystem: buildSystem,
    );
  });

  test('calls build system', () async {
    var buildWasCalled = false;
    buildSystem.buildFn = (
      fl.Target target,
      fl.Environment environment, {
      fl.BuildSystemConfig buildSystemConfig = const fl.BuildSystemConfig(),
    }) async {
      buildWasCalled = true;
      return fl.BuildResult(success: true);
    };

    await _runInTestContext(
      () async => await appBuilder.build(
        host: FlutterDrmHostPlatform.linuxRV64,
        target: FlutterDrmTargetPlatform.genericArmV7,
        buildInfo: fl.BuildInfo.debug,
        fsLayout: FilesystemLayout.flutterDrm,
      ),
    );

    expect(buildWasCalled, isTrue);
  });

  test('passes flutter-drm target platform correctly', () async {
    var buildWasCalled = false;
    buildSystem.buildFn = (
      fl.Target target,
      fl.Environment environment, {
      fl.BuildSystemConfig buildSystemConfig = const fl.BuildSystemConfig(),
    }) async {
      expect(
        environment.defines['flutter-drm-target'],
        equals('riscv64-generic'),
      );
      expect(
        (target as DebugBundleFlutterDrmAssets).target,
        equals(FlutterDrmTargetPlatform.genericRiscv64),
      );

      buildWasCalled = true;
      return fl.BuildResult(success: true);
    };

    await _runInTestContext(
      () async => await appBuilder.build(
        host: FlutterDrmHostPlatform.linuxRV64,
        target: FlutterDrmTargetPlatform.genericRiscv64,
        buildInfo: fl.BuildInfo.debug,
        fsLayout: FilesystemLayout.flutterDrm,
      ),
    );

    expect(buildWasCalled, isTrue);
  });

  test('passes target path correctly', () async {
    var buildWasCalled = false;
    buildSystem.buildFn = (
      fl.Target target,
      fl.Environment environment, {
      fl.BuildSystemConfig buildSystemConfig = const fl.BuildSystemConfig(),
    }) async {
      expect(
        environment.defines[fl.kTargetFile],
        equals('lib/main_flutter_drm.dart'),
      );

      buildWasCalled = true;
      return fl.BuildResult(success: true);
    };

    await _runInTestContext(
      () async => await appBuilder.build(
        host: FlutterDrmHostPlatform.linuxRV64,
        target: FlutterDrmTargetPlatform.genericRiscv64,
        buildInfo: fl.BuildInfo.debug,
        fsLayout: FilesystemLayout.flutterDrm,
        mainPath: 'lib/main_flutter_drm.dart',
      ),
    );

    expect(buildWasCalled, isTrue);
  });

  group('--fs-layout', () {
    group('meta-flutter', () {
      test('creates targets with meta-flutter layout', () async {
        var buildWasCalled = false;
        buildSystem.buildFn = (
          fl.Target target,
          fl.Environment environment, {
          fl.BuildSystemConfig buildSystemConfig = const fl.BuildSystemConfig(),
        }) async {
          final subTargets = (target as fl.CompositeTarget).dependencies;

          expect(
            subTargets.whereType<CopyFlutterAssets>().single.layout,
            equals(FilesystemLayout.metaFlutter),
          );

          expect(
            subTargets.whereType<CopyIcudtl>().single.layout,
            equals(FilesystemLayout.metaFlutter),
          );

          expect(
            subTargets.whereType<CopyFlutterDrmEngine>().single.layout,
            equals(FilesystemLayout.metaFlutter),
          );

          buildWasCalled = true;
          return fl.BuildResult(success: true);
        };

        await _runInTestContext(
          () async => await appBuilder.build(
            host: FlutterDrmHostPlatform.linuxRV64,
            target: FlutterDrmTargetPlatform.genericRiscv64,
            buildInfo: fl.BuildInfo.debug,
            fsLayout: FilesystemLayout.metaFlutter,
          ),
        );

        expect(buildWasCalled, isTrue);
      });

      test(
          'does not bundle an embedder binary if forceBundleEmbedder is not passed',
          () async {
        var buildWasCalled = false;
        buildSystem.buildFn = (
          fl.Target target,
          fl.Environment environment, {
          fl.BuildSystemConfig buildSystemConfig = const fl.BuildSystemConfig(),
        }) async {
          final subTargets = (target as fl.CompositeTarget).dependencies;

          expect(
            subTargets.whereType<CopyFlutterDrmEmbedderBinary>(),
            isEmpty,
          );

          buildWasCalled = true;
          return fl.BuildResult(success: true);
        };

        final bundle = await _runInTestContext(
          () async => await appBuilder.buildBundle(
            id: 'test-id',
            host: FlutterDrmHostPlatform.linuxRV64,
            target: FlutterDrmTargetPlatform.genericRiscv64,
            buildInfo: fl.BuildInfo.debug,
            fsLayout: FilesystemLayout.metaFlutter,
            forceBundleEmbedder: false,
          ),
        );

        expect(buildWasCalled, isTrue);
        expect(bundle.includesEmbedderBinary, isFalse);
      });

      test('does bundle an embedder binary if forceBundleEmbedder is passed',
          () async {
        var buildWasCalled = false;
        buildSystem.buildFn = (
          fl.Target target,
          fl.Environment environment, {
          fl.BuildSystemConfig buildSystemConfig = const fl.BuildSystemConfig(),
        }) async {
          final subTargets = (target as fl.CompositeTarget).dependencies;

          expect(
            subTargets.whereType<CopyFlutterDrmEmbedderBinary>(),
            hasLength(1),
          );

          expect(
            subTargets.whereType<CopyFlutterDrmEmbedderBinary>().single.layout,
            equals(FilesystemLayout.metaFlutter),
          );

          buildWasCalled = true;
          return fl.BuildResult(success: true);
        };

        final bundle = await _runInTestContext(
          () async => await appBuilder.buildBundle(
            id: 'test-id',
            host: FlutterDrmHostPlatform.linuxRV64,
            target: FlutterDrmTargetPlatform.genericRiscv64,
            buildInfo: fl.BuildInfo.debug,
            fsLayout: FilesystemLayout.metaFlutter,
            forceBundleEmbedder: true,
          ),
        );

        expect(buildWasCalled, isTrue);
        expect(bundle.includesEmbedderBinary, isTrue);
      });

      test('default output directory is build/<target>-meta-flutter', () async {
        var buildWasCalled = false;
        buildSystem.buildFn = (
          fl.Target target,
          fl.Environment environment, {
          fl.BuildSystemConfig buildSystemConfig = const fl.BuildSystemConfig(),
        }) async {
          expect(
            environment.outputDir.path,
            equals('build/flutter-drm/meta-flutter-riscv64-generic'),
          );

          buildWasCalled = true;
          return fl.BuildResult(success: true);
        };

        await _runInTestContext(
          () async => await appBuilder.buildBundle(
            id: 'test-id',
            host: FlutterDrmHostPlatform.linuxRV64,
            target: FlutterDrmTargetPlatform.genericRiscv64,
            buildInfo: fl.BuildInfo.debug,
            fsLayout: FilesystemLayout.metaFlutter,
            forceBundleEmbedder: true,
          ),
        );

        expect(buildWasCalled, isTrue);
      });
    });

    group('flutter-drm', () {
      test('creates targets with flutter-drm layout', () async {
        var buildWasCalled = false;
        buildSystem.buildFn = (
          fl.Target target,
          fl.Environment environment, {
          fl.BuildSystemConfig buildSystemConfig = const fl.BuildSystemConfig(),
        }) async {
          final subTargets = (target as fl.CompositeTarget).dependencies;

          expect(
            subTargets.whereType<CopyFlutterAssets>().single.layout,
            equals(FilesystemLayout.flutterDrm),
          );

          expect(
            subTargets.whereType<CopyIcudtl>().single.layout,
            equals(FilesystemLayout.flutterDrm),
          );

          expect(
            subTargets.whereType<CopyFlutterDrmEngine>().single.layout,
            equals(FilesystemLayout.flutterDrm),
          );

          buildWasCalled = true;
          return fl.BuildResult(success: true);
        };

        await _runInTestContext(
          () async => await appBuilder.build(
            host: FlutterDrmHostPlatform.linuxRV64,
            target: FlutterDrmTargetPlatform.genericRiscv64,
            buildInfo: fl.BuildInfo.debug,
            fsLayout: FilesystemLayout.flutterDrm,
          ),
        );

        expect(buildWasCalled, isTrue);
      });

      test('always bundles an embedder binary', () async {
        var buildWasCalled = false;
        buildSystem.buildFn = (
          fl.Target target,
          fl.Environment environment, {
          fl.BuildSystemConfig buildSystemConfig = const fl.BuildSystemConfig(),
        }) async {
          final subTargets = (target as fl.CompositeTarget).dependencies;

          expect(
            subTargets.whereType<CopyFlutterDrmEmbedderBinary>(),
            hasLength(1),
          );

          expect(
            subTargets.whereType<CopyFlutterDrmEmbedderBinary>().single.layout,
            equals(FilesystemLayout.flutterDrm),
          );

          buildWasCalled = true;
          return fl.BuildResult(success: true);
        };

        await _runInTestContext(
          () async => await appBuilder.build(
            host: FlutterDrmHostPlatform.linuxRV64,
            target: FlutterDrmTargetPlatform.genericRiscv64,
            buildInfo: fl.BuildInfo.debug,
            fsLayout: FilesystemLayout.flutterDrm,
          ),
        );

        expect(buildWasCalled, isTrue);
      });

      test('default output directory is build/<target>', () async {
        var buildWasCalled = false;
        buildSystem.buildFn = (
          fl.Target target,
          fl.Environment environment, {
          fl.BuildSystemConfig buildSystemConfig = const fl.BuildSystemConfig(),
        }) async {
          expect(
            environment.outputDir.path,
            equals('build/flutter-drm/riscv64-generic'),
          );

          buildWasCalled = true;
          return fl.BuildResult(success: true);
        };

        await _runInTestContext(
          () async => await appBuilder.buildBundle(
            id: 'test-id',
            host: FlutterDrmHostPlatform.linuxRV64,
            target: FlutterDrmTargetPlatform.genericRiscv64,
            buildInfo: fl.BuildInfo.debug,
            fsLayout: FilesystemLayout.flutterDrm,
            forceBundleEmbedder: true,
          ),
        );

        expect(buildWasCalled, isTrue);
      });
    });
  });

  group('debug symbols', () {
    test('are included', () async {
      var buildWasCalled = false;
      buildSystem.buildFn = (
        fl.Target target,
        fl.Environment environment, {
        fl.BuildSystemConfig buildSystemConfig = const fl.BuildSystemConfig(),
      }) async {
        final subTargets = (target as fl.CompositeTarget).dependencies;

        expect(
          subTargets
              .whereType<CopyFlutterDrmEngine>()
              .single
              .includeDebugSymbols,
          isTrue,
        );

        buildWasCalled = true;
        return fl.BuildResult(success: true);
      };

      await _runInTestContext(
        () async => await appBuilder.build(
          host: FlutterDrmHostPlatform.linuxRV64,
          target: FlutterDrmTargetPlatform.genericRiscv64,
          buildInfo: fl.BuildInfo.debug,
          fsLayout: FilesystemLayout.flutterDrm,
          includeDebugSymbols: true,
        ),
      );

      expect(buildWasCalled, isTrue);
    });

    test('are not included', () async {
      var buildWasCalled = false;
      buildSystem.buildFn = (
        fl.Target target,
        fl.Environment environment, {
        fl.BuildSystemConfig buildSystemConfig = const fl.BuildSystemConfig(),
      }) async {
        final subTargets = (target as fl.CompositeTarget).dependencies;

        expect(
          subTargets
              .whereType<CopyFlutterDrmEngine>()
              .single
              .includeDebugSymbols,
          isFalse,
        );

        buildWasCalled = true;
        return fl.BuildResult(success: true);
      };

      await _runInTestContext(
        () async => await appBuilder.build(
          host: FlutterDrmHostPlatform.linuxRV64,
          target: FlutterDrmTargetPlatform.genericRiscv64,
          buildInfo: fl.BuildInfo.debug,
          fsLayout: FilesystemLayout.flutterDrm,
          includeDebugSymbols: false,
        ),
      );

      expect(buildWasCalled, isTrue);
    });
  });

  group('bundle binaries', () {
    test('binary paths for --fs-layout=flutter-drm', () async {
      buildSystem.buildFn = (
        fl.Target target,
        fl.Environment environment, {
        fl.BuildSystemConfig buildSystemConfig = const fl.BuildSystemConfig(),
      }) async {
        return fl.BuildResult(success: true);
      };

      final bundle = await _runInTestContext(
        () async => await appBuilder.buildBundle(
          id: 'test-id',
          host: FlutterDrmHostPlatform.linuxRV64,
          target: FlutterDrmTargetPlatform.genericRiscv64,
          buildInfo: fl.BuildInfo.debug,
          fsLayout: FilesystemLayout.flutterDrm,
          forceBundleEmbedder: false,
        ),
      ) as PrebuiltFlutterDrmBundlerAppBundle;

      expect(
        bundle.binaries.map(
          (file) =>
              p.relative(file.path, from: 'build/flutter-drm/riscv64-generic'),
        ),
        unorderedEquals([
          'flutter-drm',
          'libflutter_engine.so',
        ]),
      );
    });

    test('binary paths for --fs-layout=flutter-drm and include debug symbols',
        () async {
      buildSystem.buildFn = (
        fl.Target target,
        fl.Environment environment, {
        fl.BuildSystemConfig buildSystemConfig = const fl.BuildSystemConfig(),
      }) async {
        return fl.BuildResult(success: true);
      };

      final bundle = await _runInTestContext(
        () async => await appBuilder.buildBundle(
          id: 'test-id',
          host: FlutterDrmHostPlatform.linuxRV64,
          target: FlutterDrmTargetPlatform.genericRiscv64,
          buildInfo: fl.BuildInfo.debug,
          fsLayout: FilesystemLayout.flutterDrm,
          includeDebugSymbols: true,
          forceBundleEmbedder: false,
        ),
      ) as PrebuiltFlutterDrmBundlerAppBundle;

      expect(
        bundle.binaries.map(
          (file) =>
              p.relative(file.path, from: 'build/flutter-drm/riscv64-generic'),
        ),
        unorderedEquals([
          'flutter-drm',
          'libflutter_engine.dbgsyms',
          'libflutter_engine.so',
        ]),
      );
    });

    test('binary paths for --fs-layout=meta-flutter', () async {
      buildSystem.buildFn = (
        fl.Target target,
        fl.Environment environment, {
        fl.BuildSystemConfig buildSystemConfig = const fl.BuildSystemConfig(),
      }) async {
        return fl.BuildResult(success: true);
      };

      final bundle = await _runInTestContext(
        () async => await appBuilder.buildBundle(
          id: 'test-id',
          host: FlutterDrmHostPlatform.linuxRV64,
          target: FlutterDrmTargetPlatform.genericRiscv64,
          buildInfo: fl.BuildInfo.debug,
          fsLayout: FilesystemLayout.metaFlutter,
          forceBundleEmbedder: false,
        ),
      ) as PrebuiltFlutterDrmBundlerAppBundle;

      expect(
        bundle.binaries.map(
          (file) => p.relative(
            file.path,
            from: 'build/flutter-drm/meta-flutter-riscv64-generic',
          ),
        ),
        unorderedEquals([
          'lib/libflutter_engine.so',
        ]),
      );
    });

    test(
        'binary paths for --fs-layout=meta-flutter with force bundle embedder',
        () async {
      buildSystem.buildFn = (
        fl.Target target,
        fl.Environment environment, {
        fl.BuildSystemConfig buildSystemConfig = const fl.BuildSystemConfig(),
      }) async {
        return fl.BuildResult(success: true);
      };

      final bundle = await _runInTestContext(
        () async => await appBuilder.buildBundle(
          id: 'test-id',
          host: FlutterDrmHostPlatform.linuxRV64,
          target: FlutterDrmTargetPlatform.genericRiscv64,
          buildInfo: fl.BuildInfo.debug,
          fsLayout: FilesystemLayout.metaFlutter,
          forceBundleEmbedder: true,
        ),
      ) as PrebuiltFlutterDrmBundlerAppBundle;

      expect(
        bundle.binaries.map(
          (file) => p.relative(
            file.path,
            from: 'build/flutter-drm/meta-flutter-riscv64-generic',
          ),
        ),
        unorderedEquals([
          'bin/flutter-drm-embedder',
          'lib/libflutter_engine.so',
        ]),
      );
    });

    test('binary paths for --fs-layout=meta-flutter with include debug symbols',
        () async {
      buildSystem.buildFn = (
        fl.Target target,
        fl.Environment environment, {
        fl.BuildSystemConfig buildSystemConfig = const fl.BuildSystemConfig(),
      }) async {
        return fl.BuildResult(success: true);
      };

      final bundle = await _runInTestContext(
        () async => await appBuilder.buildBundle(
          id: 'test-id',
          host: FlutterDrmHostPlatform.linuxRV64,
          target: FlutterDrmTargetPlatform.genericRiscv64,
          buildInfo: fl.BuildInfo.debug,
          fsLayout: FilesystemLayout.metaFlutter,
          includeDebugSymbols: true,
          forceBundleEmbedder: false,
        ),
      ) as PrebuiltFlutterDrmBundlerAppBundle;

      expect(
        bundle.binaries.map(
          (file) => p.relative(
            file.path,
            from: 'build/flutter-drm/meta-flutter-riscv64-generic',
          ),
        ),
        unorderedEquals([
          'lib/libflutter_engine.dbgsyms',
          'lib/libflutter_engine.so',
        ]),
      );
    });
  });
}
