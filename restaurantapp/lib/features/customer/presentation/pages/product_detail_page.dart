import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/product.dart';

class ProductDetailPage extends StatefulWidget {
  const ProductDetailPage({
    super.key,
    required this.product,
    required this.onAddToCart,
  });

  final Product product;
  final Function(String) onAddToCart;

  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  final TextEditingController _notesController = TextEditingController();

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F0),
      appBar: AppBar(
        title: const Text('Detalle del producto'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF3B2115),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        children: [
          Container(
            height: 210,
            decoration: BoxDecoration(
              color: const Color(0xFFFFE5BF),
              borderRadius: BorderRadius.circular(22),
            ),
            child: product.imagePath != null && product.imagePath!.startsWith('http')
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: Image.network(
                      product.imagePath!,
                      width: double.infinity,
                      height: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          Icon(product.icon, size: 96, color: product.accentColor),
                    ),
                  )
                : Icon(product.icon, size: 96, color: product.accentColor),
          ),
          const SizedBox(height: 20),
          Text(
            product.name,
            style: const TextStyle(
              color: Color(0xFF3B2115),
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            product.description ?? 'Una receta preparada al momento con ingredientes seleccionados.',
            style: const TextStyle(color: Color(0xFF937A6B), height: 1.4),
          ),
          const SizedBox(height: 20),
          _InfoSection(
            title: 'Ingredientes',
            value: (product.ingredients?.isNotEmpty ?? false)
                ? product.ingredients!.join(', ')
                : 'Consulta los ingredientes con nuestro equipo.',
          ),
          const SizedBox(height: 12),
          _InfoSection(
            title: 'Alérgenos',
            value: (product.allergens?.isNotEmpty ?? false)
                ? product.allergens!.join(', ')
                : 'No especificados',
          ),
          const SizedBox(height: 24),
          const Text(
            'Personaliza tu pedido',
            style: TextStyle(
              color: Color(0xFF563524),
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _notesController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Ej: Sin cebolla, extra queso, término medio...',
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
              prefixIcon: const Icon(Icons.edit_note, color: AppTheme.accent),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () {
              widget.onAddToCart(_notesController.text.trim());
              Navigator.pop(context);
            },
            icon: const Icon(Icons.add_shopping_cart),
            label: Text('Añadir por ${product.formattedPrice}'),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.accent,
              padding: const EdgeInsets.symmetric(vertical: 15),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoSection extends StatelessWidget {
  const _InfoSection({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFEBDCCE)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF563524))),
            const SizedBox(height: 5),
            Text(value, style: const TextStyle(color: Color(0xFF937A6B))),
          ],
        ),
      );
}
