class Ambulance {
  final int id;
  final String hospitalName;
  final String driverName;
  final String contactNumber;
  final String status; // Available, On Trip

  Ambulance({
    required this.id,
    required this.hospitalName,
    required this.driverName,
    required this.contactNumber,
    required this.status,
  });
}