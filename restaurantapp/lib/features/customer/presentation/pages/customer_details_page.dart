import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../auth/domain/entities/auth_user.dart';
import '../../domain/entities/order.dart';
import '../../domain/repositories/user_settings_repository.dart';

class CustomerDetailsPage extends StatefulWidget {
  const CustomerDetailsPage({
    super.key,
    required this.user,
    required this.settingsRepository,
  });

  final AuthUser user;
  final UserSettingsRepository settingsRepository;

  @override
  State<CustomerDetailsPage> createState() => _CustomerDetailsPageState();
}

class _CustomerDetailsPageState extends State<CustomerDetailsPage> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _streetController;
  late TextEditingController _cityController;
  late TextEditingController _zipController;
  late TextEditingController _notesController;
  late TextEditingController _paymentTypeController;
  late TextEditingController _paymentDetailsController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _streetController = TextEditingController();
    _cityController = TextEditingController();
    _zipController = TextEditingController();
    _notesController = TextEditingController();
    _paymentTypeController = TextEditingController();
    _paymentDetailsController = TextEditingController();
    _loadData();
  }

  Future<void> _loadData() async {
    final address = await widget.settingsRepository.getDeliveryAddress(widget.user.email);
    final payment = await widget.settingsRepository.getPaymentMethod(widget.user.email);

    if (!mounted) return;
    setState(() {
      _streetController.text = address?.street ?? '';
      _cityController.text = address?.city ?? '';
      _zipController.text = address?.postalCode ?? '';
      _notesController.text = address?.notes ?? '';
      _paymentTypeController.text = payment?.type ?? '';
      _paymentDetailsController.text = payment?.details ?? '';
    });
  }

  @override
  void dispose() {
    _streetController.dispose();
    _cityController.dispose();
    _zipController.dispose();
    _notesController.dispose();
    _paymentTypeController.dispose();
    _paymentDetailsController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final address = Address(
      street: _streetController.text.trim(),
      city: _cityController.text.trim(),
      postalCode: _zipController.text.trim(),
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
    );

    final payment = PaymentMethod(
      type: _paymentTypeController.text.trim(),
      details: _paymentDetailsController.text.trim(),
    );

    try {
      await widget.settingsRepository.saveDeliveryAddress(
        widget.user.email,
        address,
      );
      await widget.settingsRepository.savePaymentMethod(
        widget.user.email,
        payment,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudieron guardar los datos: $error'),
          backgroundColor: const Color(0xFFB3261E),
        ),
      );
      return;
    }

    if (!mounted) return;
    setState(() => _isSaving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Datos guardados correctamente.')),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F0),
      appBar: AppBar(
        title: const Text(
          'Datos de Entrega y Pago',
          style: TextStyle(color: Color(0xFF3B2115), fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: const Color(0xFF3B2115),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionTitle(title: 'Dirección de Entrega'),
              const SizedBox(height: 16),
              _buildTextField(_streetController, 'Calle y Número', Icons.map, (v) => v == null || v.isEmpty ? 'Requerido' : null),
              const SizedBox(height: 16),
              _buildTextField(_cityController, 'Ciudad', Icons.location_city, (v) => v == null || v.isEmpty ? 'Requerido' : null),
              const SizedBox(height: 16),
              _buildTextField(_zipController, 'Código Postal', Icons.pin_drop, (v) => v == null || v.isEmpty ? 'Requerido' : null),
              const SizedBox(height: 16),
              _buildTextField(_notesController, 'Notas adicionales', Icons.note_add),
              const SizedBox(height: 32),
              const _SectionTitle(title: 'Método de Pago'),
              const SizedBox(height: 16),
              _buildTextField(_paymentTypeController, 'Tipo (Ej: Tarjeta, Efectivo)', Icons.payment, (v) => v == null || v.isEmpty ? 'Requerido' : null),
              const SizedBox(height: 16),
              _buildTextField(_paymentDetailsController, 'Detalles (Ej: **** 1234)', Icons.credit_card, (v) => v == null || v.isEmpty ? 'Requerido' : null),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _isSaving ? null : _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.accent,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Guardar Información',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, [String? Function(String?)? validator]) {
    return TextFormField(
      controller: controller,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppTheme.accent),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFEBDCCE)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFEBDCCE)),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});
  final String title;
  @override
  Widget build(BuildContext context) => Text(
        title,
        style: const TextStyle(
          color: Color(0xFF563524),
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      );
}
