class DeviceModel {
  final String id;
  final String name;
  final bool isActive;

  DeviceModel({required this.id, required this.name, this.isActive = true});

  DeviceModel copyWith({String? id, String? name, bool? isActive}) {
    return DeviceModel(
      id: id ?? this.id,
      name: name ?? this.name,
      isActive: isActive ?? this.isActive,
    );
  }
}
