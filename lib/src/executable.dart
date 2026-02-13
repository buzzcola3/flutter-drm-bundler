// ignore_for_file: avoid_print, implementation_imports

import 'dart:async';
import 'package:args/command_runner.dart';
import 'package:flutter_drm_bundler/src/context.dart';
import 'package:flutter_drm_bundler/src/shutdown_hooks.dart';
import 'package:meta/meta.dart';

import 'package:flutter_drm_bundler/src/cache.dart';
import 'package:flutter_drm_bundler/src/cli/commands/build.dart';
import 'package:flutter_drm_bundler/src/cli/command_runner.dart';
import 'package:flutter_drm_bundler/src/cli/commands/devices.dart';
import 'package:flutter_drm_bundler/src/cli/commands/precache.dart';
import 'package:flutter_drm_bundler/src/cli/commands/run.dart';
import 'package:flutter_drm_bundler/src/cli/commands/test.dart';

import 'package:flutter_drm_bundler/src/fltool/common.dart' as fltool;
import 'package:flutter_drm_bundler/src/fltool/globals.dart' as globals;

@visibleForTesting
FlutterDrmBundlerCommandRunner createFlutterDrmBundlerCommandRunner({
  bool verboseHelp = false,
}) {
  final runner = FlutterDrmBundlerCommandRunner(verboseHelp: verboseHelp);

  runner.addCommand(BuildCommand(verboseHelp: verboseHelp));
  runner.addCommand(PrecacheCommand());
  runner.addCommand(DevicesCommand(verboseHelp: verboseHelp));
  runner.addCommand(RunCommand(verboseHelp: verboseHelp));
  runner.addCommand(TestCommand());

  runner.argParser
    ..addSeparator('Other options')
    ..addFlag('verbose', negatable: false, help: 'Enable verbose logging.');

  return runner;
}

Future<void> main(List<String> args) async {
  final verbose =
      args.contains('-v') || args.contains('--verbose') || args.contains('-vv');
  final powershellHelpIndex = args.indexOf('-?');
  if (powershellHelpIndex != -1) {
    args[powershellHelpIndex] = '-h';
  }

  final help = args.contains('-h') ||
      args.contains('--help') ||
      (args.isNotEmpty && args.first == 'help') ||
      (args.length == 1 && verbose);
  final verboseHelp = help && verbose;

  final runner = createFlutterDrmBundlerCommandRunner(verboseHelp: verboseHelp);

  fltool.Cache.flutterRoot = await getFlutterRoot();

  await runInContext(
    () async {
      try {
        await runner.run(args);

        await exitWithHooks(
          0,
          shutdownHooks: globals.shutdownHooks,
          logger: globals.logger,
        );
      } on fltool.ToolExit catch (e) {
        if (e.message != null) {
          globals.printError(e.message!);
        }

        await exitWithHooks(
          0,
          shutdownHooks: globals.shutdownHooks,
          logger: globals.logger,
        );
      } on UsageException catch (e) {
        globals.printError(e.message);
        globals.printStatus(e.usage);

        await exitWithHooks(
          0,
          shutdownHooks: globals.shutdownHooks,
          logger: globals.logger,
        );
      }
    },
    verbose: verbose,
  );
}
