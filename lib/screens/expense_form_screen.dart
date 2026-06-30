
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../models/expense_model.dart';
import '../models/expense_category.dart';
import '../providers/expense_provider.dart';
import '../providers/form_provider.dart';
import '../services/ai_service.dart';
import '../services/image_service.dart';
import '../services/storage_service.dart';
import '../core/errors.dart';

enum ExpenseFormMode { create, edit, scan }

class ExpenseFormScreen extends ConsumerStatefulWidget {
  final ExpenseFormMode initialMode;
  final ExpenseModel? expenseToEdit;

  const ExpenseFormScreen({
    super.key,
    this.initialMode = ExpenseFormMode.create,
    this.expenseToEdit,
  });

  @override
  ConsumerState<ExpenseFormScreen> createState() => _ExpenseFormScreenState();
}

class _ExpenseFormScreenState extends ConsumerState<ExpenseFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _merchantNameController = TextEditingController();
  final _amountController = TextEditingController();
  final _dateController = TextEditingController();
  final _notesController = TextEditingController();
  ExpenseCategory? _selectedCategory;
  File? _receiptImage;
  bool _isScanning = false;

  late ImageService _imageService;
  late AIService _aiService;

  @override
  void initState() {
    super.initState();
    _initializeServices();

    if (widget.initialMode == ExpenseFormMode.edit &&
        widget.expenseToEdit != null) {
      _populateFormFromExpense(widget.expenseToEdit!);
    } else {
      _initializeWithDefaults();
    }
  }

  void _initializeServices() {
    // Initialize services with API key from Hive storage
    final apiKey = StorageService.getGeminiApiKey() ?? '';
    _imageService = ImageService();
    _aiService = AIService(apiKey: apiKey);

    // Initialize image service
    _imageService.initialize();
  }

  void _initializeWithDefaults() {
    // Initialize form with today's date
    final today = DateTime.now();
    _dateController.text =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    // Initialize form provider after widget tree is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(expenseFormNotifierProvider.notifier).initializeWithTodayDate();
    });
  }

  void _populateFormFromExpense(ExpenseModel expense) {
    _merchantNameController.text = expense.merchantName;
    _amountController.text = expense.amount.toStringAsFixed(2);
    _dateController.text = expense.date.toIso8601String().split('T')[0];
    _notesController.text = expense.notes ?? '';
    _selectedCategory = expense.category;

    // Initialize form provider with expense data after widget tree is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(expenseFormNotifierProvider.notifier)
          .fillFromExpense(
            merchantName: expense.merchantName,
            amount: expense.amount,
            date: expense.date,
            category: expense.category,
            notes: expense.notes,
          );
    });
  }

  @override
  void dispose() {
    _merchantNameController.dispose();
    _amountController.dispose();
    _dateController.dispose();
    _notesController.dispose();
    _imageService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final formState = ref.watch(expenseFormNotifierProvider);

    return Scaffold(
      appBar: AppBar(title: Text(_getAppBarTitle()), elevation: 0),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.initialMode == ExpenseFormMode.scan) ...[
                  _buildScanSection(context),
                  const SizedBox(height: 24),
                ],
                _buildMerchantNameField(context, formState),
                const SizedBox(height: 16),
                _buildAmountField(context, formState),
                const SizedBox(height: 16),
                _buildDateField(context, formState),
                const SizedBox(height: 16),
                _buildCategoryPicker(context, formState),
                const SizedBox(height: 16),
                _buildNotesField(context, formState),
                const SizedBox(height: 24),
                _buildSubmitButton(context, formState),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getAppBarTitle() {
    switch (widget.initialMode) {
      case ExpenseFormMode.create:
        return 'Add Expense';
      case ExpenseFormMode.edit:
        return 'Edit Expense';
      case ExpenseFormMode.scan:
        return 'Scan Receipt';
    }
  }

  Widget _buildScanSection(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Receipt Scanning',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (_receiptImage != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  _receiptImage!,
                  height: 200,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isScanning ? null : _scanReceipt,
                      icon: _isScanning
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.document_scanner),
                      label: Text(_isScanning ? 'Scanning...' : 'Scan Receipt'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _receiptImage = null;
                      });
                    },
                    icon: const Icon(Icons.close),
                    label: const Text('Clear'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey,
                    ),
                  ),
                ],
              ),
            ] else ...[
              ElevatedButton.icon(
                onPressed: _pickReceiptImage,
                icon: const Icon(Icons.camera_alt),
                label: const Text('Take Photo'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => _pickReceiptImage(fromGallery: true),
                icon: const Icon(Icons.photo_library),
                label: const Text('Choose from Gallery'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMerchantNameField(BuildContext context, formState) {
    return TextFormField(
      controller: _merchantNameController,
      decoration: InputDecoration(
        labelText: 'Merchant Name',
        hintText: 'e.g., Walmart, Starbucks',
        prefixIcon: const Icon(Icons.store),
        border: const OutlineInputBorder(),
        errorText: formState.merchantName.error,
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Merchant name is required';
        }
        if (value.length > 100) {
          return 'Merchant name cannot exceed 100 characters';
        }
        return null;
      },
      onChanged: (value) {
        ref
            .read(expenseFormNotifierProvider.notifier)
            .updateMerchantName(value);
      },
    );
  }

  Widget _buildAmountField(BuildContext context, formState) {
    return TextFormField(
      controller: _amountController,
      decoration: InputDecoration(
        labelText: 'Amount',
        hintText: '0.00',
        prefixIcon: const Icon(Icons.attach_money),
        border: const OutlineInputBorder(),
        errorText: formState.amount.error,
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Amount is required';
        }
        final amount = double.tryParse(value);
        if (amount == null) {
          return 'Please enter a valid number';
        }
        if (amount <= 0) {
          return 'Amount must be greater than 0';
        }
        if (amount > 1000000) {
          return 'Amount cannot exceed 1,000,000';
        }
        return null;
      },
      onChanged: (value) {
        ref.read(expenseFormNotifierProvider.notifier).updateAmount(value);
      },
    );
  }

  Widget _buildDateField(BuildContext context, formState) {
    return TextFormField(
      controller: _dateController,
      decoration: InputDecoration(
        labelText: 'Date',
        hintText: 'YYYY-MM-DD',
        prefixIcon: const Icon(Icons.calendar_today),
        border: const OutlineInputBorder(),
        errorText: formState.date.error,
      ),
      keyboardType: TextInputType.datetime,
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Date is required';
        }
        try {
          final date = DateTime.parse(value);
          final now = DateTime.now();
          if (date.isAfter(now.add(const Duration(days: 30)))) {
            return 'Date cannot be more than 30 days in the future';
          }
          if (date.isBefore(now.subtract(const Duration(days: 365 * 10)))) {
            return 'Date cannot be more than 10 years in the past';
          }
        } catch (e) {
          return 'Please enter a valid date (YYYY-MM-DD)';
        }
        return null;
      },
      onTap: () async {
        final pickedDate = await showDatePicker(
          context: context,
          initialDate: DateTime.now(),
          firstDate: DateTime.now().subtract(const Duration(days: 365 * 10)),
          lastDate: DateTime.now().add(const Duration(days: 30)),
        );
        if (pickedDate != null) {
          _dateController.text =
              '${pickedDate.year}-${pickedDate.month.toString().padLeft(2, '0')}-${pickedDate.day.toString().padLeft(2, '0')}';
          ref
              .read(expenseFormNotifierProvider.notifier)
              .updateDate(_dateController.text);
        }
      },
      onChanged: (value) {
        ref.read(expenseFormNotifierProvider.notifier).updateDate(value);
      },
    );
  }

  Widget _buildCategoryPicker(BuildContext context, formState) {
    return DropdownButtonFormField<ExpenseCategory>(
      value: _selectedCategory,
      decoration: const InputDecoration(
        labelText: 'Category',
        prefixIcon: Icon(Icons.category),
        border: OutlineInputBorder(),
      ),
      items: ExpenseCategory.values.map((category) {
        return DropdownMenuItem(
          value: category,
          child: Row(
            children: [
              Icon(category.icon, color: category.color, size: 20),
              const SizedBox(width: 12),
              Text(category.displayName),
            ],
          ),
        );
      }).toList(),
      validator: (value) {
        if (value == null) {
          return 'Please select a category';
        }
        return null;
      },
      onChanged: (value) {
        setState(() {
          _selectedCategory = value;
        });
        ref.read(expenseFormNotifierProvider.notifier).updateCategory(value);
      },
    );
  }

  Widget _buildNotesField(BuildContext context, formState) {
    return TextFormField(
      controller: _notesController,
      decoration: InputDecoration(
        labelText: 'Notes (Optional)',
        hintText: 'Add any additional details...',
        prefixIcon: const Icon(Icons.note),
        border: const OutlineInputBorder(),
        errorText: formState.notes.error,
      ),
      maxLines: 3,
      maxLength: 500,
      validator: (value) {
        if (value != null && value.length > 500) {
          return 'Notes cannot exceed 500 characters';
        }
        return null;
      },
      onChanged: (value) {
        ref.read(expenseFormNotifierProvider.notifier).updateNotes(value);
      },
    );
  }

  Widget _buildSubmitButton(BuildContext context, formState) {
    return ElevatedButton(
      onPressed: formState.isSubmitting ? null : _submitForm,
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
      ),
      child: formState.isSubmitting
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Text(
              widget.initialMode == ExpenseFormMode.edit
                  ? 'Update Expense'
                  : 'Save Expense',
              style: const TextStyle(fontSize: 16),
            ),
    );
  }

  Future<void> _pickReceiptImage({bool fromGallery = false}) async {
    try {
      final ImageSource source = fromGallery
          ? ImageSource.gallery
          : ImageSource.camera;
      final result = await _imageService.pickImage(
        source,
        config: ImageCompressionConfig.receiptScanning,
      );

      setState(() {
        _receiptImage = result.imageFile;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Image captured: ${(result.compressedSizeBytes / 1024).toStringAsFixed(1)} KB',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not select image. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _scanReceipt() async {
    if (_receiptImage == null) return;

    // Check if API key is configured
    final apiKey = StorageService.getGeminiApiKey();
    if (apiKey == null || apiKey.trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'API key not found. Please configure your Gemini API key in settings.',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    setState(() {
      _isScanning = true;
    });

    try {
      final scanResult = await _aiService.scanReceipt(_receiptImage!);

      // Fill form with scan results
      _merchantNameController.text = scanResult.merchantName;
      _amountController.text = scanResult.amount.toStringAsFixed(2);
      _dateController.text = scanResult.date.toIso8601String().split('T')[0];
      _notesController.text = scanResult.notes ?? '';
      setState(() {
        _selectedCategory = scanResult.category;
      });

      // Update form provider
      ref
          .read(expenseFormNotifierProvider.notifier)
          .fillFromScan(
            merchantName: scanResult.merchantName,
            amount: scanResult.amount,
            date: scanResult.date,
            category: scanResult.category,
            notes: scanResult.notes,
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Receipt scanned successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } on AIException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Scan failed: ${e.message}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Scan failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isScanning = false;
      });
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Validate form state
    if (!ref.read(expenseFormNotifierProvider.notifier).validateForm()) {
      return;
    }

    ref.read(expenseFormNotifierProvider.notifier).setSubmitting(true);

    try {
      final formData = ref
          .read(expenseFormNotifierProvider.notifier)
          .getFormData();

      if (widget.initialMode == ExpenseFormMode.edit &&
          widget.expenseToEdit != null) {
        // Update existing expense
        final updatedExpense = widget.expenseToEdit!.copyWith(
          merchantName: formData['merchantName'] as String,
          amount: formData['amount'] as double,
          date: formData['date'] as DateTime,
          category: formData['category'] as ExpenseCategory,
          notes: formData['notes'] as String?,
          receiptImagePath: _receiptImage?.path,
        );

        await ref
            .read(expenseNotifierProvider.notifier)
            .updateExpense(updatedExpense);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Expense updated successfully')),
          );
          Navigator.pop(context);
        }
      } else {
        // Create new expense
        final newExpense = ExpenseModel.create(
          merchantName: formData['merchantName'] as String,
          amount: formData['amount'] as double,
          date: formData['date'] as DateTime,
          category: formData['category'] as ExpenseCategory,
          notes: formData['notes'] as String?,
          isAiGenerated: widget.initialMode == ExpenseFormMode.scan,
          receiptImagePath: _receiptImage?.path,
          rawAiResponse: widget.initialMode == ExpenseFormMode.scan ? {} : null,
        );

        await ref.read(expenseNotifierProvider.notifier).addExpense(newExpense);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Expense saved successfully')),
          );
          Navigator.pop(context);
        }
      }
    } on DatabaseException catch (e) {
      ref
          .read(expenseFormNotifierProvider.notifier)
          .setSubmissionError(e.message);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save expense: ${e.message}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ref
          .read(expenseFormNotifierProvider.notifier)
          .setSubmissionError(e.toString());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save expense: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      ref.read(expenseFormNotifierProvider.notifier).setSubmitting(false);
    }
  }
}
