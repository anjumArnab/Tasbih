import 'package:flutter/material.dart';
import '../services/db_service.dart';
import '../models/dhikr.dart';

class AddDhikrDialog extends StatefulWidget {
  final VoidCallback? onDhikrAdded;
  final Dhikr? dhikrToEdit; // Optional parameter for editing

  const AddDhikrDialog({
    super.key,
    this.onDhikrAdded,
    this.dhikrToEdit, // Add this parameter
  });

  @override
  State<AddDhikrDialog> createState() => _AddDhikrDialogState();
}

class _AddDhikrDialogState extends State<AddDhikrDialog> {
  final _formKey = GlobalKey<FormState>();
  final _dhikrTitleController = TextEditingController();
  final _dhikrController = TextEditingController();
  final _timesToReciteController = TextEditingController();

  DateTime? _selectedDateTime;
  bool _isLoading = false;
  bool get _isEditMode => widget.dhikrToEdit != null;

  @override
  void initState() {
    super.initState();

    // If editing, populate fields with existing data
    if (_isEditMode) {
      _dhikrTitleController.text = widget.dhikrToEdit!.dhikrTitle;
      _dhikrController.text = widget.dhikrToEdit!.dhikr;
      _timesToReciteController.text = widget.dhikrToEdit!.times.toString();
      _selectedDateTime = widget.dhikrToEdit!.when;
    }
  }

  @override
  void dispose() {
    _dhikrTitleController.dispose();
    _dhikrController.dispose();
    _timesToReciteController.dispose();
    super.dispose();
  }

  Future<void> _selectDateTime() async {
    final initialDate = _selectedDateTime ?? DateTime.now();

    final date = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (date != null) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(initialDate),
      );

      if (time != null) {
        setState(() {
          _selectedDateTime = DateTime(
            date.year,
            date.month,
            date.day,
            time.hour,
            time.minute,
          );
        });
      }
    }
  }

  Future<void> _saveDhikr() async {
    if (_formKey.currentState!.validate() && _selectedDateTime != null) {
      setState(() {
        _isLoading = true;
      });

      try {
        if (_isEditMode) {
          // Update existing dhikr
          final updatedDhikr = Dhikr(
            id: widget.dhikrToEdit!.id,
            dhikrTitle: _dhikrTitleController.text.trim(),
            dhikr: _dhikrController.text.trim(),
            times: int.parse(_timesToReciteController.text),
            when: _selectedDateTime!,
            currentCount:
                widget.dhikrToEdit!.currentCount, // Preserve current count
          );

          await DbService.updateDhikr(updatedDhikr);

          if (mounted) {
            Navigator.of(context).pop();
            widget.onDhikrAdded?.call();

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Dhikr updated successfully!'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } else {
          // Add new dhikr
          final newDhikr = Dhikr(
            dhikrTitle: _dhikrTitleController.text.trim(),
            dhikr: _dhikrController.text.trim(),
            times: int.parse(_timesToReciteController.text),
            when: _selectedDateTime!,
            currentCount: 0,
          );

          await DbService.addDhikr(newDhikr);

          if (mounted) {
            Navigator.of(context).pop();
            widget.onDhikrAdded?.call();

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Dhikr added successfully!'),
                backgroundColor: Colors.green,
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Failed to ${_isEditMode ? 'update' : 'add'} dhikr: $e',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } else if (_selectedDateTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select date and time'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _isEditMode ? 'Edit Dhikr' : 'Add New Dhikr',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),

              // Dhikr Title Field
              TextFormField(
                controller: _dhikrTitleController,
                decoration: const InputDecoration(
                  labelText: 'Dhikr Title',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter dhikr title';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Dhikr Field
              TextFormField(
                controller: _dhikrController,
                decoration: const InputDecoration(
                  labelText: 'Dhikr',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
                maxLines: 3,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter dhikr text';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Times to Recite Field
              TextFormField(
                controller: _timesToReciteController,
                decoration: const InputDecoration(
                  labelText: 'Times to Recite',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter number of times';
                  }
                  if (int.tryParse(value) == null || int.parse(value) <= 0) {
                    return 'Please enter a valid positive number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // When to Recite Field
              InkWell(
                onTap: _isLoading ? null : _selectDateTime,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _selectedDateTime == null
                            ? 'When to Recite'
                            : '${_selectedDateTime!.day}/${_selectedDateTime!.month}/${_selectedDateTime!.year} at ${_selectedDateTime!.hour.toString().padLeft(2, '0')}:${_selectedDateTime!.minute.toString().padLeft(2, '0')}',
                        style: TextStyle(
                          color:
                              _selectedDateTime == null
                                  ? Colors.grey[600]
                                  : Colors.black87,
                          fontSize: 16,
                        ),
                      ),
                      const Icon(Icons.calendar_today, color: Colors.grey),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed:
                          _isLoading ? null : () => Navigator.of(context).pop(),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _saveDhikr,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black87,
                        foregroundColor: Colors.white,
                      ),
                      child:
                          _isLoading
                              ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                              : Text(_isEditMode ? 'Update' : 'Save'),
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
}
