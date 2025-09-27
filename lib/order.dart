import 'package:equatable/equatable.dart';

class Order extends Equatable {
  final String id;
  final String code;
  final String source;
  final String orderType;
  final String status;
  final String paymentStatus;
  final String paymentMethod;
  final double totalMoney;
  final double? totalShipping;
  final double? tax;
  final double totalDiscount;
  final double totalMoneyPayment;
  final List<OrderProduct> products;
  final String? note;
  final DateTime createdAt;
  final DateTime? pickupTime;
  final Creator? creator;
  final Branch? branch;
  final Client? client;
  final Receiver? receiver;
  final Shipping? shipping;
  final BankTransferInfo? bankTransferInfo;
  final String? qrBank;
  final String? shippingType;
  final String? shippingStatus;
  final int? waitingCard;
  final dynamic table;
  final double? directDiscountNumber;
  final String? directDiscountType;
  final String? discountCode;
  final List<AhamoveShippingHistory>? ahamoveShippingHistories;

  const Order({
    required this.id,
    required this.code,
    required this.source,
    required this.orderType,
    required this.status,
    required this.paymentStatus,
    required this.paymentMethod,
    required this.totalMoney,
    this.totalShipping,
    this.tax,
    required this.totalDiscount,
    required this.totalMoneyPayment,
    required this.products,
    this.note,
    required this.createdAt,
    this.pickupTime,
    this.creator,
    this.branch,
    this.client,
    this.receiver,
    this.shipping,
    this.bankTransferInfo,
    this.qrBank,
    this.shippingType,
    this.shippingStatus,
    this.waitingCard,
    this.table,
    this.directDiscountNumber,
    this.directDiscountType,
    this.discountCode,
    this.ahamoveShippingHistories,
  });

  @override
  List<Object?> get props => [
        id,
        code,
        source,
        orderType,
        status,
        paymentStatus,
        paymentMethod,
        totalMoney,
        totalShipping,
        tax,
        totalDiscount,
        totalMoneyPayment,
        products,
        note,
        createdAt,
        pickupTime,
        creator,
        branch,
        client,
        receiver,
        shipping,
        bankTransferInfo,
        qrBank,
        shippingType,
        shippingStatus,
        waitingCard,
        table,
        directDiscountNumber,
        directDiscountType,
        discountCode,
        ahamoveShippingHistories,
      ];
}

class OrderProduct extends Equatable {
  final String? uuidv4;
  final String id;
  final String name;
  final String? thumbnail;
  final double price;
  final bool enablePriceSale;
  final double priceSale;
  final int quantity;
  final List<OrderProductAttribute> attributes;
  final String? note;
  final String? liveId;
  final String? sku;
  final String? unit;
  final bool? processed;
  final List<dynamic>? processedArea;
  final bool? labelPrint;

  const OrderProduct({
    this.uuidv4,
    required this.id,
    required this.name,
    this.thumbnail,
    required this.price,
    required this.enablePriceSale,
    required this.priceSale,
    required this.quantity,
    required this.attributes,
    this.note,
    this.liveId,
    this.sku,
    this.unit,
    this.processed,
    this.processedArea,
    this.labelPrint,
  });

  @override
  List<Object?> get props => [
        uuidv4,
        id,
        name,
        thumbnail,
        price,
        enablePriceSale,
        priceSale,
        quantity,
        attributes,
        note,
        liveId,
        sku,
        unit,
        processed,
        processedArea,
        labelPrint,
      ];
}

class OrderProductAttribute extends Equatable {
  final String id;
  final String name;
  final double price;

  const OrderProductAttribute({
    required this.id,
    required this.name,
    required this.price,
  });

  @override
  List<Object?> get props => [id, name, price];
}

class Creator extends Equatable {
  final String id;
  final String fullName;
  final String email;

  const Creator({
    required this.id,
    required this.fullName,
    required this.email,
  });

  @override
  List<Object?> get props => [id, fullName, email];
}

class Branch extends Equatable {
  final String id;
  final String name;
  final String code;
  final String phone;
  final String email;
  final String? address;

  const Branch({
    required this.id,
    required this.name,
    required this.code,
    required this.phone,
    required this.email,
    this.address,
  });

  @override
  List<Object?> get props => [id, name, code, phone, email, address];
}

class Client {
  final String id;
  final String? name;
  final String phone;
  final String? email;
  final String? code;
  final String? avatar;

  Client({
    required this.id,
    this.name,
    required this.phone,
    this.email,
    this.code,
    this.avatar,
  });
}

class Receiver {
  final String name;
  final String phone;
  final String? address;

  Receiver({
    required this.name,
    required this.phone,
    this.address,
  });
}

class Shipping {
  final String? address;
  final String? ward;
  final String? province;
  final double? lat;
  final double? long;

  Shipping({
    this.address,
    this.ward,
    this.province,
    this.lat,
    this.long,
  });
}

class BankTransferInfo {
  final String? bankName;
  final String? accountNumber;
  final String? accountName;
  final String? transactionId;

  BankTransferInfo({
    this.bankName,
    this.accountNumber,
    this.accountName,
    this.transactionId,
  });
}

class AhamoveShippingHistory {
  final String? id;
  final String? sharedLink;
  final String? serviceId;
  final String? status;
  final String? paymentMethod;
  final double? totalPrice;
  final DateTime? createdAt;
  final String? supplierId;
  final String? supplierName;

  AhamoveShippingHistory({
    this.id,
    this.sharedLink,
    this.serviceId,
    this.status,
    this.paymentMethod,
    this.totalPrice,
    this.createdAt,
    this.supplierId,
    this.supplierName,
  });
}
