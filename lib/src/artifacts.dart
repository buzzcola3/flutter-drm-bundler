import 'package:flutter_drm_bundler/src/build_system/extended_environment.dart';
import 'package:flutter_drm_bundler/src/cache.dart';
import 'package:flutter_drm_bundler/src/common.dart';
import 'package:flutter_drm_bundler/src/fltool/common.dart';

sealed class FlutterDrmEmbedderArtifact {
  const FlutterDrmEmbedderArtifact();
}

final class FlutterDrmEmbedderBinary extends FlutterDrmEmbedderArtifact {
  const FlutterDrmEmbedderBinary({required this.target, required this.mode});

  final FlutterDrmTargetPlatform target;
  final BuildMode mode;
}

final class Engine extends FlutterDrmEmbedderArtifact {
  const Engine({required this.target, required this.flavor});

  final FlutterDrmTargetPlatform target;
  final EngineFlavor flavor;
}

final class EngineDebugSymbols extends FlutterDrmEmbedderArtifact {
  const EngineDebugSymbols({
    required this.target,
    required this.flavor,
  });

  final FlutterDrmTargetPlatform target;
  final EngineFlavor flavor;
}

final class GenSnapshot extends FlutterDrmEmbedderArtifact {
  const GenSnapshot({
    required this.host,
    required this.target,
    required this.mode,
  }) : assert(mode == BuildMode.release || mode == BuildMode.profile);

  final FlutterDrmHostPlatform host;
  final FlutterDrmTargetPlatform target;
  final BuildMode mode;
}

final class FlutterDrmEmbedderGtkShim extends FlutterDrmEmbedderArtifact {
  const FlutterDrmEmbedderGtkShim({required this.target, required this.mode});

  final FlutterDrmTargetPlatform target;
  final BuildMode mode;
}

abstract class FlutterDrmEmbedderArtifacts implements Artifacts {
  File getFlutterDrmEmbedderArtifact(FlutterDrmEmbedderArtifact artifact);
}

class CachedFlutterDrmEmbedderArtifacts implements FlutterDrmEmbedderArtifacts {
  CachedFlutterDrmEmbedderArtifacts({
    required this.inner,
    required this.cache,
  });

  final Artifacts inner;
  final FlutterDrmBundlerCache cache;

  @override
  String getArtifactPath(
    Artifact artifact, {
    TargetPlatform? platform,
    BuildMode? mode,
    EnvironmentType? environmentType,
  }) {
    return inner.getArtifactPath(
      artifact,
      platform: platform,
      mode: mode,
      environmentType: environmentType,
    );
  }

  @override
  File getFlutterDrmEmbedderArtifact(FlutterDrmEmbedderArtifact artifact) {
    return switch (artifact) {
      FlutterDrmEmbedderBinary(:final target, :final mode) => cache
          .getArtifactDirectory('flutter-drm-embedder')
          .childDirectory(target.triple)
          .childDirectory(
            switch (mode) {
              BuildMode.debug => 'debug',
              BuildMode.profile ||
              BuildMode.release ||
              BuildMode.jitRelease =>
                'release',
            },
          )
          .childFile('flutter-drm-embedder'),
      FlutterDrmEmbedderGtkShim(:final target, :final mode) => cache
          .getArtifactDirectory('flutter-drm-embedder')
          .childDirectory('gtk-shim')
          .childDirectory(target.triple)
          .childDirectory(
            switch (mode) {
              BuildMode.debug => 'debug',
              BuildMode.profile ||
              BuildMode.release ||
              BuildMode.jitRelease =>
                'release',
            },
          )
          .childFile('libflutter_linux_gtk.so'),
      Engine(:final target, :final flavor) => cache
          .getArtifactDirectory('engine')
          .childDirectory('flutter-drm-engine-$target-$flavor')
          .childFile('libflutter_engine.so'),
      EngineDebugSymbols(:final target, :final flavor) => cache
          .getArtifactDirectory('engine')
          .childDirectory('flutter-drm-engine-dbgsyms-$target-$flavor')
          .childFile('libflutter_engine.dbgsyms'),
      GenSnapshot(:final host, :final target, :final mode) => cache
          .getArtifactDirectory('engine')
          .childDirectory('flutter-drm-gen-snapshot-$host-$target-$mode')
          .childFile('gen_snapshot')
    };
  }

  @override
  String getEngineType(TargetPlatform platform, [BuildMode? mode]) {
    return inner.getEngineType(platform, mode);
  }

  @override
  FileSystemEntity getHostArtifact(HostArtifact artifact) {
    return inner.getHostArtifact(artifact);
  }

  @override
  LocalEngineInfo? get localEngineInfo => inner.localEngineInfo;

  @override
  bool get usesLocalArtifacts => inner.usesLocalArtifacts;
}

class FlutterDrmEmbedderArtifactsWrapper implements FlutterDrmEmbedderArtifacts {
  FlutterDrmEmbedderArtifactsWrapper({
    required this.inner,
  });

  final FlutterDrmEmbedderArtifacts inner;

  @override
  String getArtifactPath(
    Artifact artifact, {
    TargetPlatform? platform,
    BuildMode? mode,
    EnvironmentType? environmentType,
  }) {
    return inner.getArtifactPath(
      artifact,
      platform: platform,
      mode: mode,
      environmentType: environmentType,
    );
  }

  @override
  File getFlutterDrmEmbedderArtifact(FlutterDrmEmbedderArtifact artifact) {
    return inner.getFlutterDrmEmbedderArtifact(artifact);
  }

  @override
  String getEngineType(TargetPlatform platform, [BuildMode? mode]) {
    return inner.getEngineType(platform, mode);
  }

  @override
  FileSystemEntity getHostArtifact(HostArtifact artifact) {
    return inner.getHostArtifact(artifact);
  }

  @override
  LocalEngineInfo? get localEngineInfo => inner.localEngineInfo;

  @override
  bool get usesLocalArtifacts => inner.usesLocalArtifacts;
}

class FlutterToFlutterDrmEmbedderArtifactsForwarder extends FlutterDrmEmbedderArtifactsWrapper {
  FlutterToFlutterDrmEmbedderArtifactsForwarder({
    required super.inner,
    required this.host,
    required this.target,
  });

  final FlutterDrmHostPlatform host;
  final FlutterDrmTargetPlatform target;

  @override
  String getArtifactPath(
    Artifact artifact, {
    TargetPlatform? platform,
    BuildMode? mode,
    EnvironmentType? environmentType,
  }) {
    return switch (artifact) {
      Artifact.genSnapshot => inner
          .getFlutterDrmEmbedderArtifact(
            GenSnapshot(host: host, target: target.genericVariant, mode: mode!),
          )
          .path,
      _ => inner.getArtifactPath(
          artifact,
          platform: platform,
          mode: mode,
          environmentType: environmentType,
        ),
    };
  }
}

class LocalFlutterDrmEmbedderBinaryOverride extends FlutterDrmEmbedderArtifactsWrapper {
  LocalFlutterDrmEmbedderBinaryOverride({
    required super.inner,
    required this.flutterDrmEmbedderBinary,
  });

  final File flutterDrmEmbedderBinary;

  @override
  File getFlutterDrmEmbedderArtifact(FlutterDrmEmbedderArtifact artifact) {
    return switch (artifact) {
      FlutterDrmEmbedderBinary _ => flutterDrmEmbedderBinary,
      _ => inner.getFlutterDrmEmbedderArtifact(artifact),
    };
  }

  @override
  bool get usesLocalArtifacts => true;
}

extension _VisitFlutterDrmEmbedderArtifact on SourceVisitor {
  void visitFlutterDrmEmbedderArtifact(FlutterDrmEmbedderArtifact artifact) {
    final environment = this.environment;
    if (environment is! ExtendedEnvironment) {
      throw StateError(
        'Expected environment to be a FlutterDrmEnvironment, '
        'but got ${environment.runtimeType}.',
      );
    }

    final artifactFile = environment.artifacts.getFlutterDrmEmbedderArtifact(artifact);
    assert(artifactFile.fileSystem == environment.fileSystem);

    sources.add(artifactFile);
  }
}

extension SourceFlutterDrmEmbedderArtifactSource on Source {
  static Source flutterDrmEmbedderArtifact(FlutterDrmEmbedderArtifact artifact) {
    return FlutterDrmEmbedderArtifactSource(artifact);
  }
}

class FlutterDrmEmbedderArtifactSource implements Source {
  final FlutterDrmEmbedderArtifact artifact;

  const FlutterDrmEmbedderArtifactSource(
    this.artifact,
  );

  @override
  void accept(SourceVisitor visitor) {
    visitor.visitFlutterDrmEmbedderArtifact(artifact);
  }

  @override
  bool get implicit => false;
}
