import 'package:flutter_drm_bundler/src/devices/flutter_drm_ssh/device_discovery.dart';
import 'package:flutter_drm_bundler/src/fltool/common.dart';
import 'package:flutter_drm_bundler/src/config.dart';
import 'package:flutter_drm_bundler/src/more_os_utils.dart';
import 'package:flutter_drm_bundler/src/devices/flutter_drm_ssh/ssh_utils.dart';

class FlutterDrmBundlerDeviceManager extends DeviceManager {
  FlutterDrmBundlerDeviceManager({
    required super.logger,
    required Platform platform,
    required MoreOperatingSystemUtils operatingSystemUtils,
    required SshUtils sshUtils,
    required FlutterDrmBundlerConfig flutterDrmBundlerConfig,
    this.specifiedDeviceId,
  }) : deviceDiscoverers = <DeviceDiscovery>[
          FlutterDrmBundlerSshDeviceDiscovery(
            sshUtils: sshUtils,
            logger: logger,
            config: flutterDrmBundlerConfig,
            os: operatingSystemUtils,
          ),
        ];
  @override
  final List<DeviceDiscovery> deviceDiscoverers;

  @override
  String? specifiedDeviceId;
}
