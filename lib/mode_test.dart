import 'package:flutter/material.dart';

class Order {
  final String code;
  final Branch? branch;
  final Table? table;
  final String? waitingCard;
  final DateTime createdAt;
  final User? creator;
  final Client? client;
  final String orderType; // e.g. "SHIPPING" or "DINE_IN"
  final Shipping? shipping;
  final List<Product> products;
  final double totalMoney;
  final double totalDiscount;
  final double? totalShipping;
  final double? tax;
  final double totalMoneyPayment;
  final String paymentMethod;
  final String paymentStatus;
  final String? note;
  final String? qrBank;

  Order({
    required this.code,
    this.branch,
    this.table,
    this.waitingCard,
    required this.createdAt,
    this.creator,
    this.client,
    this.orderType = 'DINE_IN',
    this.shipping,
    this.products = const [],
    this.totalMoney = 0,
    this.totalDiscount = 0,
    this.totalShipping,
    this.tax,
    this.totalMoneyPayment = 0,
    this.paymentMethod = '',
    this.paymentStatus = '',
    this.note,
    this.qrBank,
  });
}

class Branch {
  final String name;
  final String? address;

  Branch({required this.name, this.address});
}

class Table {
  final String name;

  Table({required this.name});
}

class User {
  final String fullName;

  User({required this.fullName});
}

class Client {
  final String? name;
  final String? phone;

  Client({this.name, this.phone});
}

class Shipping {
  final String? address;

  Shipping({this.address});
}

class Product {
  final String name;
  final int quantity;
  final double price;
  final double total;
  final List<Attribute> attributes;
  final String? note;

  Product({
    required this.name,
    required this.quantity,
    required this.price,
    required this.total,
    this.attributes = const [],
    this.note,
  });
}

class Attribute {
  final String name;
  final double price;

  Attribute({required this.name, required this.price});
}

// ----------- Sample data to test -------------
Order sampleOrder = Order(
  code: 'HD001',
  branch: Branch(name: 'Zami Store', address: '123 Duong ABC, Hanoi'),
  table: Table(name: 'B1'),
  waitingCard: 'WC123',
  createdAt: DateTime.now().subtract(const Duration(hours: 2)),
  creator: User(fullName: 'Nguyen Van A'),
  client: Client(name: 'Tran Thi B', phone: '0987654321'),
  orderType: 'SHIPPING',
  shipping: Shipping(address: '456 Duong XYZ, Hanoi'),
  products: [
    Product(
      name: 'Cafe Sua Da Lon',
      quantity: 2,
      price: 30000,
      total: 60000,
      attributes: [Attribute(name: 'Extra Sugar', price: 0)],
      note: 'Khong da',
    ),
    Product(
      name: 'Banh Mi Thit Nguoi Lon Va Rau Xanh Ngon',
      quantity: 1,
      price: 25000,
      total: 25000,
    ),
  ],
  totalMoney: 85000,
  totalDiscount: 5000,
  totalShipping: 10000,
  tax: 10,
  totalMoneyPayment: 90000,
  paymentMethod: 'Cash',
  paymentStatus: 'Paid',
  note: 'Khach yeu cau giao nhanh',
  qrBank: 'https://example.com/qr/HD001',
);
