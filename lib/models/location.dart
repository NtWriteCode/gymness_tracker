class SavedLocation {
  final String id;
  final String name;
  final double? latitude;
  final double? longitude;

  SavedLocation({
    required this.id,
    required this.name,
    this.latitude,
    this.longitude,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'latitude': latitude,
        'longitude': longitude,
      };

  factory SavedLocation.fromJson(Map<String, dynamic> json) => SavedLocation(
        id: json['id'],
        name: json['name'],
        latitude: json['latitude'],
        longitude: json['longitude'],
      );
}
