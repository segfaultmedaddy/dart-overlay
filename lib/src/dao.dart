import 'package:json_annotation/json_annotation.dart' show JsonSerializable;

part 'dao.g.dart';

@JsonSerializable()
class GoogleStorageObjectList {
  GoogleStorageObjectList(this.kind, this.prefixes);
  factory GoogleStorageObjectList.fromJson(Map<String, dynamic> json) =>
      _$GoogleStorageObjectListFromJson(json);

  final String kind;
  final List<String> prefixes;

  Map<String, dynamic> toJson() => _$GoogleStorageObjectListToJson(this);
}

// [Source] represents a single source entry in the source-[channel].json
@JsonSerializable()
class Source {
  Source(this.version, this.url, this.sha256);
  factory Source.fromJson(Map<String, dynamic> json) => _$SourceFromJson(json);

  final String version;
  final String url;
  final String sha256;

  Map<String, dynamic> toJson() => _$SourceToJson(this);
}
