class Inventory {
  final int? id;
  final String janCode;
  final DateTime expirationDate;
  final int quantity;
  final DateTime registrationDate;
  final bool isArchived;

  Inventory({
    this.id,
    required this.janCode,
    required this.expirationDate,
    required this.quantity,
    required this.registrationDate,
    this.isArchived = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'janCode': janCode,
      'expirationDate': expirationDate.toIso8601String(),
      'quantity': quantity,
      'registrationDate': registrationDate.toIso8601String(),
      'isArchived': isArchived ? 1 : 0,
    };
  }

  factory Inventory.fromMap(Map<String, dynamic> map) {
    return Inventory(
      id: map['id'],
      janCode: map['janCode'],
      expirationDate: DateTime.parse(map['expirationDate']),
      quantity: map['quantity'],
      registrationDate: DateTime.parse(map['registrationDate']),
      isArchived: map['isArchived'] == 1,
    );
  }
}
