import 'package:flutter/material.dart';

class LabelWidget extends StatelessWidget {
  final String title;
  final String content;
  final String? additionalInfo;

  const LabelWidget({
    Key? key,
    required this.title,
    required this.content,
    this.additionalInfo,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final formattedDate =
        "${now.day.toString().padLeft(2, '0')}-${now.month.toString().padLeft(2, '0')}-${now.year} "
        "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(8),
      width: 400, // 50mm ~ 400px @203dpi
      height: 240, // 30mm ~ 240px @203dpi
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 25, // tăng kích cỡ tiêu đề
                  fontWeight: FontWeight.w700)),
          const Divider(thickness: 1),
          Text(content,
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          if (additionalInfo != null) ...[
            const SizedBox(height: 8),
            ...additionalInfo!.split('\n').map(
                  (line) => Text("• $line",
                      style: const TextStyle(
                        fontSize: 16,
                      )),
                ),
          ],
          const Spacer(),
          const Divider(thickness: 1),
          Text(formattedDate, style: const TextStyle(fontSize: 14)),
        ],
      ),
    );
  }
}
