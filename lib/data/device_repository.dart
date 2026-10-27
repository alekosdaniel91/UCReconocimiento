import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/device_definition.dart';

class DeviceRepository {
  DeviceRepository({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  static const deviceAssets = ['assets/devices/koolnova_rcu_hybrid.json'];

  final AssetBundle _bundle;

  Future<List<DeviceDefinition>> loadAll() async => [
    for (final path in deviceAssets)
      DeviceDefinition.fromJson(
        jsonDecode(await _bundle.loadString(path)) as Map<String, dynamic>,
      ),
  ];
}
