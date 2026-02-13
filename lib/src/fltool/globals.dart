export 'package:flutter_tools/src/globals.dart';

// ignore: implementation_imports
import 'package:flutter_tools/src/base/context.dart' show context;
import 'package:flutter_drm_bundler/src/artifacts.dart';
import 'package:flutter_drm_bundler/src/build_system/build_app.dart';
import 'package:flutter_drm_bundler/src/cache.dart';
import 'package:flutter_drm_bundler/src/config.dart';
import 'package:flutter_drm_bundler/src/devices/flutter_drm_ssh/ssh_utils.dart';
import 'package:flutter_drm_bundler/src/fltool/common.dart' as fl;
import 'package:flutter_drm_bundler/src/more_os_utils.dart';

FlutterDrmBundlerConfig get flutterDrmBundlerConfig =>
    context.get<FlutterDrmBundlerConfig>()!;
FlutterDrmBundlerCache get flutterDrmBundlerCache => context.get<fl.Cache>()! as FlutterDrmBundlerCache;

FlutterDrmEmbedderArtifacts get flutterDrmEmbedderArtifacts =>
    context.get<fl.Artifacts>()! as FlutterDrmEmbedderArtifacts;
MoreOperatingSystemUtils get moreOs =>
    context.get<fl.OperatingSystemUtils>()! as MoreOperatingSystemUtils;

SshUtils get sshUtils => context.get<SshUtils>()!;

AppBuilder get builder => context.get<AppBuilder>()!;
