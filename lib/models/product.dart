class Product {
  final int? id;
  final String barcode;
  final String name;
  final double price;
  final double quantity;

  const Product({
    this.id,
    required this.barcode,
    required this.name,
    required this.price,
    this.quantity = 0,
  });

  Product copyWith({
    int? id,
    String? barcode,
    String? name,
    double? price,
    double? quantity,
  }) {
    return Product(
      id: id ?? this.id,
      barcode: barcode ?? this.barcode,
      name: name ?? this.name,
      price: price ?? this.price,
      quantity: quantity ?? this.quantity,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'barcode': barcode,
      'name': name,
      'price': price,
      'quantity': quantity,
    };
  }

  factory Product.fromMap(
    Map<String, Object?> map,
  ) {
    return Product(
      id: map['id'] as int?,
      barcode: map['barcode'] as String,
      name: map['name'] as String,
      price: (map['price'] as num).toDouble(),
      quantity:
          (map['quantity'] as num?)?.toDouble() ?? 0,
    );
  }
}
