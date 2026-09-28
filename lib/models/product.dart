class Product {
  final int? id;
  final String barcode;
  final String name;
  final double price;

  const Product({this.id, required this.barcode, required this.name, required this.price});

  Product copyWith({int? id, String? barcode, String? name, double? price}) => Product(
        id: id ?? this.id,
        barcode: barcode ?? this.barcode,
        name: name ?? this.name,
        price: price ?? this.price,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'barcode': barcode,
        'name': name,
        'price': price,
      };

  factory Product.fromMap(Map<String, Object?> map) => Product(
        id: map['id'] as int?,
        barcode: map['barcode'] as String,
        name: map['name'] as String,
        price: (map['price'] as num).toDouble(),
      );
}
