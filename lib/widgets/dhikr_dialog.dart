import 'package:flutter/material.dart';
import 'package:tasbih/widgets/app_snack_bar.dart';
import '../widgets/rounded_button.dart';
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

  static const Color backgroundColor = Color(0xFFF8FBFF);

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
                widget.dhikrToEdit!.currentCount,
          );

          await DbService.updateDhikr(updatedDhikr);

          if (mounted) {
            Navigator.of(context).pop();
            widget.onDhikrAdded?.call();

            AppSnackbar.showSuccess(context, 'Dhikr updated successfully!');
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

            AppSnackbar.showSuccess(context, 'Dhikr added successfully!');
          }
        }
      } catch (e) {
        if (mounted) {
          AppSnackbar.showError(context, 'Failed to ${_isEditMode ? 'update' : 'add'} dhikr: $e');
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } else if (_selectedDateTime == null) {
      AppSnackbar.showError(context, 'Please select date and time');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: backgroundColor,
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

              // Times to Recite and When to Recite Row
              Row(
                children: [
                  // Times to Recite Field (smaller width)
                  SizedBox(
                    width: 120,
                    child: TextFormField(
                      controller: _timesToReciteController,
                      decoration: const InputDecoration(
                        labelText: 'Times',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter number';
                        }
                        if (int.tryParse(value) == null ||
                            int.parse(value) <= 0) {
                          return 'Enter valid number';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),

                  // When to Recite Field (takes remaining space)
                  Expanded(
                    child: InkWell(
                      onTap: _isLoading ? null : _selectDateTime,
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'When to Recite',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          suffixIcon: Icon(Icons.calendar_today),
                        ),
                        child: Text(
                          _selectedDateTime == null
                              ? 'Select date and time'
                              : '${_selectedDateTime!.day}/${_selectedDateTime!.month}/${_selectedDateTime!.year} at ${_selectedDateTime!.hour.toString().padLeft(2, '0')}:${_selectedDateTime!.minute.toString().padLeft(2, '0')}',
                          style: TextStyle(
                            color:
                                _selectedDateTime == null
                                    ? Colors.grey[600]
                                    : Colors.black87,
                            fontSize: 16,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    child: RoundedButton(
                      text: 'Cancel',
                      onTap:
                          _isLoading ? null : () => Navigator.of(context).pop(),
                      textColor: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: RoundedButton(
                      text: _isEditMode ? 'Update' : 'Save',
                      onTap: _isLoading ? null : _saveDhikr,
                      textColor: Colors.white,
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
