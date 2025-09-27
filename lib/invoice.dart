import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';

class Invoice extends StatelessWidget {
  final ReceiptData receiptData;
  final bool forPrint;

  const Invoice({Key? key, required this.receiptData, this.forPrint = false})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Align(alignment: Alignment.center, child: _buildHeader()),
        Align(alignment: Alignment.center, child: _buildStoreInfo()),
        if (_shouldShowWifi()) _buildWifiInfo(),
        Align(alignment: Alignment.center, child: _buildOrderInfo()),
        _buildDateTimeInfo(),
        if (receiptData.order.creator != null) _buildStaffInfo(),
        if (receiptData.order.client != null) _buildCustomerInfo(),
        _buildDivider(),
        _buildProductHeader(),
        _buildProductList(),
        _buildDivider(),
        _buildTotals(),
        _buildPaymentInfo(),
        if (receiptData.order.note != null)
          Align(alignment: Alignment.center, child: _buildOrderNote()),
        if (receiptData.order.qrBank != null)
          Align(alignment: Alignment.center, child: _buildQRCode()),
        Align(alignment: Alignment.center, child: _buildFooter()),
      ],
    );

    return Container(
      width: double.infinity, // Use full available width (576px)
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: forPrint
          ? Container(
              constraints: const BoxConstraints(minHeight: 0),
              child: content,
            )
          : SingleChildScrollView(
              child: Container(
                constraints: const BoxConstraints(minHeight: 0),
                child: content,
              ),
            ),
    );
  }

  Widget _buildHeader() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          receiptData.isProvisional
              ? ' HÓA ĐƠN TẠM TÍNH'
              : 'HÓA ĐƠN THANH TOÁN',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        if (receiptData.isReprint)
          const Text(
            '(In lại)',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
            textAlign: TextAlign.center,
          ),
      ],
    );
  }

  Widget _buildStoreInfo() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Zami Solution FNB',
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),
        if (receiptData.order.branch?.address != null)
          Text(
            receiptData.order.branch!.address!,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w500),
            textAlign: TextAlign.center,
          ),
      ],
    );
  }

  Widget _buildWifiInfo() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildDivider(),
        const Text(
          'WIFI MIỄN PHÍ',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 17,
          ),
          textAlign: TextAlign.center,
        ),
        Text(
          'Tên: ${_removeAccents(receiptData.wifiInfo!['name']!)}',
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w500),
          textAlign: TextAlign.center,
        ),
        Text(
          'Mật khẩu: ${_removeAccents(receiptData.wifiInfo!['password']!)}',
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w500),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildOrderInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Mã đơn: ${receiptData.order.code}',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
        ),
        if (receiptData.order.table != null)
          Text(
            'Bàn: ${receiptData.order.table!.name}',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
          ),
        if (receiptData.order.waitingCard != null)
          Text(
            'Thẻ: ${receiptData.order.waitingCard}',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
          ),
      ],
    );
  }

  Widget _buildDateTimeInfo() {
    final orderTimeGMT7 =
        receiptData.order.createdAt.add(const Duration(hours: 7));
    final currentTimeGMT7 = DateTime.now();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Thời gian tạo: ${DateFormat('dd/MM/yyyy HH:mm').format(orderTimeGMT7)}',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
        ),
        Text(
          'Thời gian in: ${DateFormat('dd/MM/yyyy HH:mm').format(currentTimeGMT7)}',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildStaffInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Nhân viên: ${_removeAccents(receiptData.order.creator!.fullName)}',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
      ],
    );
  }

  Widget _buildCustomerInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Khách hàng: ${_removeAccents(receiptData.order.client!.name!)}',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
        ),
        Text(
          'SDT: ${receiptData.order.client!.phone}',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
        ),
        if (receiptData.order.orderType == 'SHIPPING' &&
            receiptData.order.shipping?.address != null)
          Text(
            'Địa chỉ: ${_removeAccents(receiptData.order.shipping!.address!)}',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
          ),
      ],
    );
  }

  Widget _buildProductHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: const Row(
        children: [
          SizedBox(
            width: 40, // Increased for better readability
            child: Text(
              'SL',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ),
          Expanded(
            flex: 6, // Increased flex for product name
            child: Text(
              'Sản phẩm',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ),
          SizedBox(
            width: 80, // Increased for price display
            child: Text(
              'Đơn giá',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
              textAlign: TextAlign.right,
            ),
          ),
          SizedBox(
            width: 80, // Increased for total display
            child: Text(
              'Thành tiền',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductList() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: receiptData.order.products
            .map((product) => _buildProductRow(product))
            .toList(),
      ),
    );
  }

  Widget _buildProductRow(ProductData product) {
    const maxLineLength = 35; // Increased for wider layout
    final productName = _removeAccents(product.name);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Main product row
        Container(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 40, // Match header width
                child: Text(
                  '${product.quantity}',
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w500),
                ),
              ),
              Expanded(
                flex: 6, // Match header flex
                child: Text(
                  productName.length <= maxLineLength
                      ? productName
                      : productName.substring(0, maxLineLength),
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w500),
                ),
              ),
              SizedBox(
                width: 80, // Match header width
                child: Text(
                  _formatNumber(_calculateProductPrice(product)),
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w500),
                  textAlign: TextAlign.right,
                ),
              ),
              SizedBox(
                width: 80, // Match header width
                child: Text(
                  _formatNumber(_calculateProductTotalPrice(product)),
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w500),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
        ),
        // Additional lines for long product names
        if (productName.length > maxLineLength)
          ..._buildAdditionalProductLines(productName, maxLineLength),
        // Product attributes
        ...product.attributes
            .map((attr) => _buildAttributeRow(attr, product.quantity)),
        // Product note
        if (product.note != null && product.note!.isNotEmpty)
          _buildProductNote(product.note!),
      ],
    );
  }

  List<Widget> _buildAdditionalProductLines(
      String productName, int maxLineLength) {
    List<Widget> lines = [];
    String remainingText = productName.substring(maxLineLength);

    while (remainingText.isNotEmpty) {
      final nextLine = remainingText.length > maxLineLength
          ? remainingText.substring(0, maxLineLength)
          : remainingText;

      lines.add(
        Container(
          padding: const EdgeInsets.symmetric(vertical: 1),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(width: 40), // Match header width
              Expanded(
                flex: 6, // Match header flex
                child: Text(
                  nextLine,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w500),
                ),
              ),
              const SizedBox(width: 80), // Match header width
              const SizedBox(width: 80), // Match header width
            ],
          ),
        ),
      );

      remainingText = remainingText.length > maxLineLength
          ? remainingText.substring(maxLineLength)
          : '';
    }

    return lines;
  }

  Widget _buildAttributeRow(AttributeData attr, int quantity) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 6, // Match header flex
            child: Text(
              '+ ${_removeAccents(attr.name)}',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
            ),
          ),
          SizedBox(
            width: 80, // Match header width
            child: Text(
              _formatNumber(attr.price),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
              textAlign: TextAlign.right,
            ),
          ),
          SizedBox(
            width: 80, // Match header width
            child: Text(
              _formatNumber(attr.price * quantity),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductNote(String note) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 1, horizontal: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(width: 40), // Match product layout
          Expanded(
            child: Text(
              'Ghi chú: ${_removeAccents(note)}',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotals() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildTotalRow('Thành tiền:', receiptData.order.totalMoney),
          _buildDivider(),
          _buildTotalRow(
              'Tổng thanh toán:', receiptData.order.totalMoneyPayment,
              bold: true, large: true),
        ],
      ),
    );
  }

  Widget _buildTotalRow(String label, double amount,
      {bool bold = false, bool large = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: bold ? FontWeight.bold : FontWeight.w500,
              fontSize: large ? 17 : 15,
            ),
          ),
          Text(
            '${_formatNumber(amount)} d',
            style: TextStyle(
              fontWeight: bold ? FontWeight.bold : FontWeight.w500,
              fontSize: large ? 17 : 15,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentInfo() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildInfoRow('Phương thức thanh toán:',
              _getPaymentMethodName(receiptData.order.paymentMethod)),
          _buildInfoRow('Trạng thái thanh toán:',
              _getPaymentStatusName(receiptData.order.paymentStatus)),
          if (receiptData.order.qrBank != null)
            _buildInfoRow('Ghi chú:', 'Mã QR thanh toán'),
        ],
      ),
    );
  }

  Widget _buildOrderNote() {
    return _buildInfoRow('Ghi chú:', _removeAccents(receiptData.order.note!));
  }

  Widget _buildInfoRow(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              label,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
            ),
          ),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQRCode() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 8),
        Container(
            width: 80, // Increased size for better visibility
            height: 80,
            child: QrImageView(
              data: receiptData.order.qrBank ?? "123",
            )),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildFooter() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 8),
        const Text(
          'Tra cứu hóa đơn điện tử tại',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
          textAlign: TextAlign.center,
        ),
        const Text(
          'https://tracuuhddt.zamiapp.vn',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
          textAlign: TextAlign.center,
        ),
        Text(
          'Mã tra cứu: ${receiptData.order.code}',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
          textAlign: TextAlign.center,
        ),
        const Text(
          'Cảm ơn quý khách đã mua hàng!',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
          textAlign: TextAlign.center,
        ),
        if (receiptData.phone != null)
          Text(
            'Hotline: ${receiptData.phone}',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
            textAlign: TextAlign.center,
          ),
        const Text(
          'Powered by Zami Solution',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: List.generate(
          40,
          (index) => Expanded(
            child: Container(
              height: 1,
              color: index % 2 == 0 ? Colors.black : Colors.transparent,
            ),
          ),
        ),
      ),
    );
  }

  // Helper methods
  bool _shouldShowWifi() {
    return receiptData.enableWifi &&
        receiptData.wifiInfo != null &&
        receiptData.wifiInfo!['name'] != null &&
        receiptData.wifiInfo!['password'] != null;
  }

  String _formatNumber(double number) {
    return NumberFormat('#,###', 'vi_VN').format(number);
  }

  double _calculateProductPrice(ProductData product) {
    return product.price +
        product.attributes.fold(0.0, (sum, attr) => sum + attr.price);
  }

  double _calculateProductTotalPrice(ProductData product) {
    return _calculateProductPrice(product) * product.quantity;
  }

  String _getPaymentMethodName(String method) {
    const methods = {
      'CASH': 'Tien mat',
      'CARD': 'The',
      'TRANSFER': 'Chuyen khoan',
      'EWALLET': 'Vi dien tu',
    };
    return methods[method] ?? method;
  }

  String _getPaymentStatusName(String status) {
    const statuses = {
      'PAID': 'Da thanh toan',
      'PENDING': 'Chua thanh toan',
      'PARTIAL': 'Thanh toan mot phan',
    };
    return statuses[status] ?? status;
  }

  String _removeAccents(String str) {
    return str
        .replaceAll(RegExp(r'[àáạảãâầấậẩẫăằắặẳẵ]'), 'a')
        .replaceAll(RegExp(r'[èéẹẻẽêềếệểễ]'), 'e')
        .replaceAll(RegExp(r'[ìíịỉĩ]'), 'i')
        .replaceAll(RegExp(r'[òóọỏõôồốộổỗơờớợởỡ]'), 'o')
        .replaceAll(RegExp(r'[ùúụủũưừứựửữ]'), 'u')
        .replaceAll(RegExp(r'[ỳýỵỷỹ]'), 'y')
        .replaceAll(RegExp(r'[đ]'), 'd')
        .replaceAll(RegExp(r'[ÀÁẠẢÃÂẦẤẬẨẪĂẰẮẶẲẴ]'), 'A')
        .replaceAll(RegExp(r'[ÈÉẸẺẼÊỀẾỆỂỄ]'), 'E')
        .replaceAll(RegExp(r'[ÌÍỊỈĨ]'), 'I')
        .replaceAll(RegExp(r'[ÒÓỌỎÕÔỒỐỘỔỖƠỜỚỢỞỠ]'), 'O')
        .replaceAll(RegExp(r'[ÙÚỤỦŨƯỪỨỰỬỮ]'), 'U')
        .replaceAll(RegExp(r'[ỲÝỴỶỸ]'), 'Y')
        .replaceAll(RegExp(r'[Đ]'), 'D');
  }
}

// Data models
class ReceiptData {
  final bool isProvisional;
  final bool isReprint;
  final bool enableWifi;
  final Map<String, String>? wifiInfo;
  final OrderData order;
  final String? taxCode;
  final String? phone;

  ReceiptData({
    required this.isProvisional,
    required this.isReprint,
    required this.enableWifi,
    this.wifiInfo,
    required this.order,
    this.taxCode,
    this.phone,
  });
}

class OrderData {
  final String code;
  final BranchData? branch;
  final TableData? table;
  final String? waitingCard;
  final DateTime createdAt;
  final UserData? creator;
  final ClientData? client;
  final String orderType;
  final ShippingData? shipping;
  final List<ProductData> products;
  final double totalMoney;
  final double totalDiscount;
  final double? totalShipping;
  final double? tax;
  final double totalMoneyPayment;
  final String paymentMethod;
  final String paymentStatus;
  final String? note;
  final String? qrBank;

  OrderData({
    required this.code,
    this.branch,
    this.table,
    this.waitingCard,
    required this.createdAt,
    this.creator,
    this.client,
    required this.orderType,
    this.shipping,
    required this.products,
    required this.totalMoney,
    required this.totalDiscount,
    this.totalShipping,
    this.tax,
    required this.totalMoneyPayment,
    required this.paymentMethod,
    required this.paymentStatus,
    this.note,
    this.qrBank,
  });
}

class BranchData {
  final String name;
  final String? address;

  BranchData({required this.name, this.address});
}

class TableData {
  final String name;

  TableData({required this.name});
}

class UserData {
  final String fullName;

  UserData({required this.fullName});
}

class ClientData {
  final String? name;
  final String phone;

  ClientData({this.name, required this.phone});
}

class ShippingData {
  final String? address;

  ShippingData({this.address});
}

class ProductData {
  final String name;
  final int quantity;
  final double price;
  final List<AttributeData> attributes;
  final String? note;

  ProductData({
    required this.name,
    required this.quantity,
    required this.price,
    required this.attributes,
    this.note,
  });
}

class AttributeData {
  final String name;
  final double price;

  AttributeData({required this.name, required this.price});
}

// Example usage widget
class ReceiptExample extends StatelessWidget {
  final bool forPrint;

  const ReceiptExample({Key? key, this.forPrint = false}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    final sampleData = ReceiptData(
      isProvisional: false,
      isReprint: false,
      enableWifi: false,
      wifiInfo: null,
      taxCode: null,
      phone: '0937155085',
      order: OrderData(
        code: 'DH-AOYX-4423',
        branch: BranchData(
          name: 'Zami Solution FNB',
          address: null,
        ),
        table: null,
        waitingCard: null,
        createdAt: DateTime.parse('2025-09-20 08:55:00'),
        creator: UserData(fullName: 'Zami FnB'),
        client: null,
        orderType: 'DINE_IN',
        shipping: null,
        products: [
          ProductData(
            name:
                'Ten san pham dai th iet dai dai dai dai dai dai dai dai da i dai dai dai dai',
            quantity: 1,
            price: 20000,
            attributes: [],
            note: null,
          ),
          ProductData(
            name:
                'Ten san pham dai th iet dai dai dai dai dai dai dai dai da i dai dai dai dai',
            quantity: 1,
            price: 20000,
            attributes: [],
            note: null,
          ),
          ProductData(
            name:
                'Ten san pham dai th iet dai dai dai dai dai dai dai dai da i dai dai dai dai',
            quantity: 1,
            price: 20000,
            attributes: [],
            note: null,
          ),
          ProductData(
            name:
                'Ten san pham dai th iet dai dai dai dai dai dai dai dai da i dai dai dai dai',
            quantity: 1,
            price: 20000,
            attributes: [],
            note: null,
          ),
        ],
        totalMoney: 20000,
        totalDiscount: 0,
        totalShipping: null,
        tax: null,
        totalMoneyPayment: 20000,
        paymentMethod: 'CASH',
        paymentStatus: 'PAID',
        note: null,
        qrBank: 'DH-AOYX-4423',
      ),
    );

    return Scaffold(
      body: SingleChildScrollView(
        child: Center(
          child: Invoice(receiptData: sampleData, forPrint: forPrint),
        ),
      ),
    );
  }
}
