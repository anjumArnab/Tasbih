import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/dhikr.dart';

class DhikrTile extends StatelessWidget {
  final Dhikr dhikr;
  final VoidCallback? onTap;

  const DhikrTile({super.key, required this.dhikr, this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(
        dhikr.dhikrTitle,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          Text(
            dhikr.dhikr,
            style: const TextStyle(fontSize: 14),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.repeat, size: 16, color: Colors.grey[600]),
              const SizedBox(width: 4),
              Text(
                '${dhikr.currentCount ?? 0}/${dhikr.times}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 16),
              Icon(Icons.schedule, size: 16, color: Colors.grey[600]),
              const SizedBox(width: 4),
              Text(
                _formatDateTime(dhikr.when),
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
        ],
      ),
      trailing: CircularProgressIndicator(
        value: (dhikr.currentCount ?? 0) / dhikr.times,
        strokeWidth: 3,
        backgroundColor: Colors.grey[300],
        valueColor: AlwaysStoppedAnimation<Color>(
          (dhikr.currentCount ?? 0) >= dhikr.times
              ? Colors.green
              : Theme.of(context).primaryColor,
        ),
      ),
      onTap: onTap,
      contentPadding: const EdgeInsets.all(16),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays == 0) {
      return DateFormat('HH:mm').format(dateTime);
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return DateFormat('EEEE').format(dateTime);
    } else {
      return DateFormat('MMM dd').format(dateTime);
    }
  }
}
