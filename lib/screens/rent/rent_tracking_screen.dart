import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../services/firebase_service.dart';
import '../../models/rent_payment.dart';

import '../../widgets/app_drawer.dart';
import '../../widgets/avatar_selector_widget.dart';

class RentTrackingScreen extends StatelessWidget {
  const RentTrackingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final firebaseService = context.watch<FirebaseService>();
    final userId = firebaseService.currentUser?.uid;

    if (userId == null) {
      return const Scaffold(body: Center(child: Text('Not authenticated')));
    }

    final displayName = firebaseService.currentUser?.email?.split('@').first ?? '';
    final formattedName = displayName.isEmpty 
        ? '' 
        : displayName[0].toUpperCase() + displayName.substring(1);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rent Tracking'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => context.go('/rent/add'),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: AvatarBadge(userName: formattedName, size: 36),
          ),
        ],
      ),
      drawer: const AppDrawer(),
      body: StreamBuilder<List<RentPayment>>(
        stream: firebaseService.getRentPayments(userId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            final isIndexError = snapshot.error.toString().contains('failed-precondition');
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(isIndexError ? Icons.hourglass_top : Icons.error_outline,
                      size: 48, color: isIndexError ? Colors.orange : Colors.red),
                  const SizedBox(height: 16),
                  Text(isIndexError
                      ? 'Database index building — please wait a moment and refresh.'
                      : 'Error: ${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[700]),
                  ),
                ],
              ),
            );
          }

          final payments = snapshot.data ?? [];

          if (payments.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.receipt_long, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No rent payments yet',
                    style: TextStyle(color: Colors.grey[600], fontSize: 18),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: () => context.go('/rent/add'),
                    icon: const Icon(Icons.add),
                    label: const Text('Add First Payment'),
                  ),
                ],
              ),
            );
          }

          final paidPayments = payments.where((p) => p.isPaid).toList();
          final unpaidPayments = payments.where((p) => !p.isPaid).toList();

          return DefaultTabController(
            length: 2,
            child: Column(
              children: [
                const TabBar(
                  tabs: [
                    Tab(text: 'Unpaid', icon: Icon(Icons.pending)),
                    Tab(text: 'Paid', icon: Icon(Icons.check_circle)),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _PaymentList(
                        payments: unpaidPayments,
                        firebaseService: firebaseService,
                      ),
                      _PaymentList(
                        payments: paidPayments,
                        firebaseService: firebaseService,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _PaymentList extends StatelessWidget {
  final List<RentPayment> payments;
  final FirebaseService firebaseService;

  const _PaymentList({
    required this.payments,
    required this.firebaseService,
  });

  @override
  Widget build(BuildContext context) {
    if (payments.isEmpty) {
      return Center(
        child: Text(
          'No payments in this category',
          style: TextStyle(color: Colors.grey[600]),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: payments.length,
      itemBuilder: (context, index) {
        final payment = payments[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: payment.isPaid ? Colors.green : Colors.orange,
              child: Icon(
                payment.isPaid ? Icons.check : Icons.pending,
                color: Colors.white,
              ),
            ),
            title: Text(
              '\$${payment.amount.toStringAsFixed(2)}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Due: ${DateFormat('MMM dd, yyyy').format(payment.dueDate)}'),
                if (payment.paidDate != null)
                  Text(
                    'Paid: ${DateFormat('MMM dd, yyyy').format(payment.paidDate!)}',
                    style: TextStyle(color: Colors.green[700]),
                  ),
                if (payment.category != null)
                  Chip(
                    label: Text(payment.category!),
                    labelStyle: const TextStyle(fontSize: 12),
                  ),
              ],
            ),
            trailing: payment.isPaid
                ? null
                : IconButton(
                    icon: const Icon(Icons.check_circle),
                    color: Colors.green,
                    onPressed: () async {
                      await firebaseService.markRentPaymentAsPaid(payment.id!);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Payment marked as paid')),
                        );
                      }
                    },
                  ),
            onTap: () {
              // Show payment details dialog
              showDialog(
                context: context,
                builder: (context) => _PaymentDetailsDialog(payment: payment),
              );
            },
          ),
        );
      },
    );
  }
}

class _PaymentDetailsDialog extends StatelessWidget {
  final RentPayment payment;

  const _PaymentDetailsDialog({required this.payment});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('\$${payment.amount.toStringAsFixed(2)}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DetailRow('Due Date', DateFormat('MMM dd, yyyy').format(payment.dueDate)),
          if (payment.paidDate != null)
            _DetailRow('Paid Date', DateFormat('MMM dd, yyyy').format(payment.paidDate!)),
          if (payment.category != null) _DetailRow('Category', payment.category!),
          if (payment.notes != null && payment.notes!.isNotEmpty)
            _DetailRow('Notes', payment.notes!),
          _DetailRow('Status', payment.isPaid ? 'Paid' : 'Unpaid'),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
