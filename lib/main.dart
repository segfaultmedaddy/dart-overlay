import 'dart:io' show HttpClient, File, stdin;
import 'dart:convert' show utf8, json, JsonEncoder;
import 'dart:math' show min;
import 'package:pub_semver/pub_semver.dart' show Version;
import 'package:jetlog/jetlog.dart' as log;
import 'package:jetlog/handlers.dart' show ConsoleHandler;
import 'package:jetlog/formatters.dart' show TextFormatter;

import 'src/dao.dart';
import 'src/svn_versions.dart';

// Supported channels.
enum Channel {
  dev,
  beta,
  stable;

  // Converts string to Channel, otherwise throws an error
  static Channel fromString(String str) {
    return switch (str) {
      "dev" => Channel.dev,
      "beta" => Channel.beta,
      "stable" => Channel.stable,
      _ => throw Exception('Unsupported channel')
    };
  }
}

// Supported platforms.
enum Platform {
  linux,
  macos;

  String toNix() =>
      switch (this) { Platform.linux => 'linux', Platform.macos => 'darwin' };
}

// Supported architectures.
enum Arch {
  x64,
  arm64;

  String toNix() =>
      switch (this) { Arch.arm64 => 'aarch64', Arch.x64 => 'x86_64' };
}

final _platformToArch = {
  Platform.macos: [Arch.arm64, Arch.x64],
  Platform.linux: [Arch.arm64, Arch.x64],
};

final _domain = 'storage.googleapis.com';
final _alt = 'json';
final _delimiter = '/';
final _chunkSize = 4;

final _logger = log.Logger.detached("dart-overlay.main");

Future<Stream<String>> getTextBase(HttpClient client, Uri url) async {
  final timer = _logger.bind({log.Str.lazy("url", () => url.toString())}).trace(
      'sending request');

  final req = await client.getUrl(url);
  final res = await req.close();
  final stream = await res.transform(utf8.decoder);

  timer.stop('finished request');

  return stream;
}

// [getText] makes GET request to the given [url] and parses returned bytes
// as UTF-8 string.
Future<String> getText(HttpClient client, Uri url) async =>
    (await getTextBase(client, url)).first;

// [getJson] makes GET request to the given [url] and parses returned bytes
// as JSON data.
Future<Object?> getJson(HttpClient client, Uri url) async =>
    (await getTextBase(client, url)).transform(json.decoder).first;

// [getVersions] returns a list of available versions for the channel.
// The returned list is sorted based on semver comparison in desc order.
Future<List<Version>> fetchVersions(
    HttpClient client, final Channel channel) async {
  final commonPrefix = 'channels/${channel.name}/release/';
  final url = Uri.https(_domain, '/storage/v1/b/dart-archive/o',
      {'delimiter': _delimiter, 'alt': _alt, 'prefix': commonPrefix});
  final logctx = _logger.bind({
    log.Str('common_prefix', commonPrefix),
    log.Str('channel', channel.name)
  });

  logctx.info('getting a list of sources');

  final resp = await getJson(client, url);
  final result = GoogleStorageObjectList.fromJson(resp as Map<String, dynamic>);

  return result.prefixes.fold(
    <Version>[],
    (versions, e) {
      var versionStr = e.replaceFirst(commonPrefix, '').replaceAll('/', '');
      if (revisionToVersion.containsKey(versionStr)) {
        versionStr = revisionToVersion[versionStr]!;
      } else if (versionStr == "latest") {
        return versions;
      }
      final version = Version.parse(versionStr);
      if (_skipVersion(version)) {
        return versions;
      }

      return versions..add(version);
    },
  ).toList()
    ..sort((a, b) => b.compareTo(a));
}

String _dartArchivePath(
    Channel channel, Platform platform, Arch arch, String version) {
  final ver = versionToRevision.containsKey(version)
      ? versionToRevision[version]
      : version;

  return 'dart-archive/channels/${channel.name}/release/${ver}/sdk/dartsdk-${platform.name}-${arch.name}-release.zip';
}

// [fetchSha256] returns a SHA-256 fetched from the storage.
Future<String> fetchSha256(HttpClient client, Channel channel,
    Platform platform, Arch arch, String version) async {
  final text = await getText(
      client,
      Uri.https(_domain,
          _dartArchivePath(channel, platform, arch, version) + '.sha256sum'));

  return text.split(' ').first;
}

Future<MapEntry<String, Source>> fetchSource(HttpClient client, Channel channel,
    Platform platform, Arch arch, String version) async {
  final sha256 = await fetchSha256(client, channel, platform, arch, version);
  final url =
      Uri.https(_domain, _dartArchivePath(channel, platform, arch, version))
          .toString();

  return MapEntry(
      "${arch.toNix()}-${platform.toNix()}", Source(version, url, sha256));
}

Future<void> main() async {
  _logger.handler = ConsoleHandler(formatter: TextFormatter.withDefaults());
  _logger.level = log.Level.info;

  final jsonEncoder = JsonEncoder.withIndent(' ' * 2);
  final client = HttpClient();
  final channel = Channel.fromString((stdin.readLineSync()?..trim()) ?? "");

  var timer =
      _logger.trace('fetching a list of sources', level: log.Level.info);
  final versions = (await fetchVersions(client, channel));

  timer.stop('finished fetching a list of sources', fields: [
    log.Str('channel', channel.name),
    log.Int('total_fetched', versions.length)
  ]);

  timer = _logger.trace('fetching source entities', level: log.Level.info);

  final Map<
      String, // version
      Map<
          String, // $arch-$platform
          Source>> result = {};

  for (int i = 0; i < versions.length; i += _chunkSize) {
    final versionsChunk =
        versions.getRange(i, min(i + _chunkSize, versions.length));

    final sources = await Future.wait(versionsChunk.map((version) async {
      final versionStr = version.toString();
      final sourceMap = Map.fromEntries(
          await Future.wait([Platform.linux, Platform.macos].expand((platform) {
        final archs = _platformToArch[platform];
        if (archs == null) {
          throw Exception('Cannot find arch for platform $platform');
        }

        // entry(nix-system-str, Source)
        return archs.where((arch) => _filterArch(platform, arch, version)).map(
            (arch) => fetchSource(client, channel, platform, arch, versionStr));
      })));

      return MapEntry(versionStr, sourceMap);
    }));

    result.addEntries(sources);
  }

  timer.stop('finished fetching source entities',
      fields: [log.Int('total_fetched', result.length)]);

  // Write the source
  timer = _logger.trace('writing file to disk', level: log.Level.info);
  await File('./sources-${channel.name}.json')
    ..writeAsString(jsonEncoder.convert(result));
  timer.stop('finished writing file to disk');

  client.close();
}

bool _skipVersion(Version version) {
  // No SHA-256 for builds before 1.6.0-dev.9.3
  return version < Version(1, 6, 0, pre: "dev.9.3");
}

bool _filterArch(Platform platform, Arch arch, Version version) {
  return switch (platform) {
    // No macOS ARM64 builds before 2.14.1
    Platform.macos => !(arch == Arch.arm64 && version < Version(2, 14, 1)),
    Platform.linux =>
      // No linux ARM64 builds before 1.23.0-dev.5.0
      !(arch == Arch.arm64 && version < Version(1, 23, 0, pre: 'dev.5.0')) &&
          // SHA-256 sum is broken for 2.0.0-dev.49.0
          !(arch == Arch.arm64 && version == Version(2, 0, 0, pre: 'dev.49.0')),
  };
}
