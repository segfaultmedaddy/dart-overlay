// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dao.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

GoogleStorageObjectList _$GoogleStorageObjectListFromJson(
        Map<String, dynamic> json) =>
    GoogleStorageObjectList(
      json['kind'] as String,
      (json['prefixes'] as List<dynamic>).map((e) => e as String).toList(),
    );

Map<String, dynamic> _$GoogleStorageObjectListToJson(
        GoogleStorageObjectList instance) =>
    <String, dynamic>{
      'kind': instance.kind,
      'prefixes': instance.prefixes,
    };

Source _$SourceFromJson(Map<String, dynamic> json) => Source(
      json['version'] as String,
      json['url'] as String,
      json['sha256'] as String,
    );

Map<String, dynamic> _$SourceToJson(Source instance) => <String, dynamic>{
      'version': instance.version,
      'url': instance.url,
      'sha256': instance.sha256,
    };
