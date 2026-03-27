class Group {
  final String id;
  final String name;
  final List<String> deviceIds;

  Group({required this.id, required this.name, List<String>? deviceIds})
      : deviceIds = deviceIds ?? [];

  Group copyWith({String? id, String? name, List<String>? deviceIds}) {
    return Group(
      id: id ?? this.id,
      name: name ?? this.name,
      deviceIds: deviceIds ?? this.deviceIds,
    );
  }
}
