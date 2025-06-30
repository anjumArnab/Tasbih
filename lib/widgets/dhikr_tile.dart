// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/dhikr.dart';
import '../widgets/dhikr_dialog.dart';
import '../services/db_service.dart';

class DhikrTile extends StatelessWidget {
  final Dhikr dhikr;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onUpdate;
  final VoidCallback? onDelete;

  const DhikrTile({
    super.key,
    required this.dhikr,
    this.onTap,
    this.onLongPress,
    this.onUpdate,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key('dhikr_${dhikr.id}'),
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.blue.withOpacity(0.5),
          borderRadius: BorderRadius.circular(5),
        ),
        child: const Icon(Icons.edit, color: Colors.white, size: 24),
      ),
      secondaryBackground: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.5),
          borderRadius: BorderRadius.circular(5),
        ),
        child: const Icon(Icons.delete, color: Colors.white, size: 24),
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          _showUpdateDialog(context);
          return false;
        } else if (direction == DismissDirection.endToStart) {
          return await _showDeleteConfirmationDialog(context);
        }
        return false;
      },
      onDismissed: (direction) {
        if (direction == DismissDirection.endToStart) {
          _deleteDhikr(context);
        }
      },
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(5),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dhikr.dhikrTitle,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      dhikr.dhikr,
                      style: TextStyle(fontSize: 14, color: Colors.grey[700]),
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
                        if (dhikr.when != null) ...[
                          const SizedBox(width: 16),
                          Icon(
                            Icons.schedule,
                            size: 16,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _formatDateTime(dhikr.when!),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                children: [
                  SizedBox(
                    width: 50,
                    height: 50,
                    child: CircularProgressIndicator(
                      value: (dhikr.currentCount ?? 0) / dhikr.times,
                      strokeWidth: 3,
                      backgroundColor: Colors.grey[300],
                      valueColor: AlwaysStoppedAnimation<Color>(
                        (dhikr.currentCount ?? 0) >= dhikr.times
                            ? Colors.green
                            : Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<bool> _showDeleteConfirmationDialog(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text(
                'Delete Dhikr',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              content: Text(
                'Are you sure you want to delete "${dhikr.dhikrTitle}"? This action cannot be undone.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(
                    'Cancel',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  child: const Text(
                    'Delete',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            );
          },
        ) ??
        false;
  }

  void _showUpdateDialog(BuildContext context) {
    showDialog(
      context: context,
      builder:
          (context) =>
              AddDhikrDialog(dhikrToEdit: dhikr, onDhikrAdded: onUpdate),
    );
  }

  Future<void> _deleteDhikr(BuildContext context) async {
    try {
      if (dhikr.id != null) {
        await DbService.deleteDhikr(dhikr.id!);
        onDelete?.call();

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Dhikr deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete dhikr: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatDateTime(DateTime dateTime) {
    // Example output: Jun 25, 2025 – 09:15 PM
    return DateFormat('MMM dd, yyyy - hh:mm a').format(dateTime);
  }
}
