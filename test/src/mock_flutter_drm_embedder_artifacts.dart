import 'package:file/src/interface/file.dart';
import 'package:file/src/interface/file_system_entity.dart';
import 'package:flutter_tools/src/artifacts.dart';
import 'package:flutter_tools/src/build_info.dart';
import 'package:flutter_drm_bundler/src/artifacts.dart';
import 'package:test/test.dart';

class MockFlutterDrmEmbedderArtifacts implements FlutterDrmEmbedderArtifacts {
  String Function(
    Artifact, {
    TargetPlatform? platform,
    BuildMode? mode,
    EnvironmentType? environmentType,
  })? artifactPathFn;

  @override
  String getArtifactPath(
    Artifact artifact, {
    TargetPlatform? platform,
    BuildMode? mode,
    EnvironmentType? environmentType,
  }) {
    if (artifactPathFn == null) {
      fail("Expected getArtifactPath to not be called.");
    }
    return artifactPathFn!(
      artifact,
      platform: platform,
      mode: mode,
      environmentType: environmentType,
    );
  }

  String Function(TargetPlatform platform, [BuildMode? mode])? getEngineTypeFn;

  @override
  String getEngineType(TargetPlatform platform, [BuildMode? mode]) {
    if (getEngineTypeFn == null) {
      fail("Expected getEngineType to not be called.");
    }
    return getEngineTypeFn!(platform, mode);
  }

  File Function(FlutterDrmEmbedderArtifact artifact)? getFlutterDrmEmbedderArtifactFn;

  @override
  File getFlutterDrmEmbedderArtifact(FlutterDrmEmbedderArtifact artifact) {
    if (getFlutterDrmEmbedderArtifactFn == null) {
      fail("Expected getFlutterDrmEmbedderArtifact to not be called.");
    }
    return getFlutterDrmEmbedderArtifactFn!(artifact);
  }

  FileSystemEntity Function(HostArtifact artifact)? getHostArtifactFn;

  @override
  FileSystemEntity getHostArtifact(HostArtifact artifact) {
    if (getHostArtifactFn == null) {
      fail("Expected getHostArtifact to not be called.");
    }
    return getHostArtifactFn!(artifact);
  }

  @override
  LocalEngineInfo? localEngineInfo;

  @override
  bool usesLocalArtifacts = false;
}
