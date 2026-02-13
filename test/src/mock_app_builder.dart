import 'package:file/src/interface/directory.dart';
import 'package:flutter_drm_bundler/src/artifacts.dart';
import 'package:flutter_drm_bundler/src/build_system/build_app.dart';
import 'package:flutter_drm_bundler/src/cli/flutter_drm_bundler_command.dart';
import 'package:flutter_drm_bundler/src/common.dart';
import 'package:flutter_drm_bundler/src/devices/flutter_drm_ssh/device.dart';
import 'package:flutter_drm_bundler/src/fltool/common.dart' as fl;
import 'package:test/test.dart';

class MockAppBuilder implements AppBuilder {
  Future<void> Function({
    required FlutterDrmHostPlatform host,
    required FlutterDrmTargetPlatform target,
    required fl.BuildInfo buildInfo,
    required FilesystemLayout fsLayout,
    fl.FlutterProject? project,
    FlutterDrmEmbedderArtifacts? artifacts,
    String? mainPath,
    String manifestPath,
    String? applicationKernelFilePath,
    String? depfilePath,
    Directory? outDir,
    bool unoptimized,
    bool includeDebugSymbols,
    bool forceBundleEmbedder,
  })? buildFn;

  @override
  Future<void> build({
    required FlutterDrmHostPlatform host,
    required FlutterDrmTargetPlatform target,
    required fl.BuildInfo buildInfo,
    required FilesystemLayout fsLayout,
    fl.FlutterProject? project,
    FlutterDrmEmbedderArtifacts? artifacts,
    String? mainPath,
    String manifestPath = fl.defaultManifestPath,
    String? applicationKernelFilePath,
    String? depfilePath,
    Directory? outDir,
    bool unoptimized = false,
    bool includeDebugSymbols = false,
    bool forceBundleEmbedder = false,
  }) {
    if (buildFn == null) {
      fail("Expected buildFn to not be called.");
    }

    return buildFn!(
      host: host,
      target: target,
      buildInfo: buildInfo,
      fsLayout: fsLayout,
      project: project,
      artifacts: artifacts,
      mainPath: mainPath,
      manifestPath: manifestPath,
      applicationKernelFilePath: applicationKernelFilePath,
      depfilePath: depfilePath,
      outDir: outDir,
      unoptimized: unoptimized,
      includeDebugSymbols: includeDebugSymbols,
      forceBundleEmbedder: forceBundleEmbedder,
    );
  }

  Future<FlutterDrmBundlerAppBundle> Function({
    required String id,
    required FlutterDrmHostPlatform host,
    required FlutterDrmTargetPlatform target,
    required fl.BuildInfo buildInfo,
    required FilesystemLayout fsLayout,
    fl.FlutterProject? project,
    FlutterDrmEmbedderArtifacts? artifacts,
    String? mainPath,
    String manifestPath,
    String? applicationKernelFilePath,
    String? depfilePath,
    bool unoptimized,
    bool includeDebugSymbols,
    bool forceBundleEmbedder,
  })? buildBundleFn;

  @override
  Future<FlutterDrmBundlerAppBundle> buildBundle({
    required String id,
    required FlutterDrmHostPlatform host,
    required FlutterDrmTargetPlatform target,
    required fl.BuildInfo buildInfo,
    required FilesystemLayout fsLayout,
    fl.FlutterProject? project,
    FlutterDrmEmbedderArtifacts? artifacts,
    String? mainPath,
    String manifestPath = fl.defaultManifestPath,
    String? applicationKernelFilePath,
    String? depfilePath,
    bool unoptimized = false,
    bool includeDebugSymbols = false,
    bool forceBundleEmbedder = false,
  }) {
    if (buildBundleFn == null) {
      fail("Expected buildBundleFn to not be called.");
    }

    return buildBundleFn!(
      id: id,
      host: host,
      target: target,
      buildInfo: buildInfo,
      fsLayout: fsLayout,
      project: project,
      artifacts: artifacts,
      mainPath: mainPath,
      manifestPath: manifestPath,
      applicationKernelFilePath: applicationKernelFilePath,
      depfilePath: depfilePath,
      unoptimized: unoptimized,
      includeDebugSymbols: includeDebugSymbols,
      forceBundleEmbedder: forceBundleEmbedder,
    );
  }
}
