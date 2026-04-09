class Product {
  final String janCode;
  final String name;
  final String imagePath;
  final int deptNumber;
  final int salesPeriod;
  final String description;

  Product({
    required this.janCode,
    required this.name,
    required this.imagePath,
    required this.deptNumber,
    required this.salesPeriod,
    required this.description,
  });

  Map<String, dynamic> toMap() {
    return {
      'janCode': janCode,
      'name': name,
      'imagePath': imagePath,
      'deptNumber': deptNumber,
      'salesPeriod': salesPeriod,
      'description': description,
    };
  }

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      janCode: map['janCode'],
      name: map['name'],
      imagePath: map['imagePath'],
      deptNumber: map['deptNumber'],
      salesPeriod: map['salesPeriod'],
      description: map['description'],
    );
  }
}
