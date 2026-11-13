import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'transaction_pages.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  Future<void> _logout(BuildContext context) async {
    final yakin = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Yakin ingin keluar dari akun?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Keluar')),
        ],
      ),
    );
    if (yakin == true) {
      await FirebaseAuth.instance.signOut();
      if (context.mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    // Nama pemilik akun diambil dari dokumen users/{uid}
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
      builder: (context, userSnap) {
        final nama = userSnap.data?.data()?['nama'] ??
            FirebaseAuth.instance.currentUser?.displayName ??
            'Pengguna';

        return Scaffold(
          appBar: AppBar(
            title: Text('Halo, $nama'),
            actions: [
              IconButton(
                icon: const Icon(Icons.logout),
                tooltip: 'Logout',
                onPressed: () => _logout(context),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const TransactionFormPage()),
            ),
            icon: const Icon(Icons.add),
            label: const Text('Transaksi'),
          ),
          body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            // Real-time, terbaru di atas
            stream: transaksiRef()
                .orderBy('tanggal', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('Terjadi kesalahan: ${snapshot.error}'));
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final docs = snapshot.data!.docs;
              num masuk = 0, keluar = 0;
              for (final d in docs) {
                final nominal = d.data()['nominal'] ?? 0;
                if (d.data()['tipe'] == 'Pemasukan') {
                  masuk += nominal;
                } else {
                  keluar += nominal;
                }
              }

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text('Selamat datang, $nama!',
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _StatCard(
                          label: 'Total Transaksi',
                          nilai: '${docs.length}',
                          warna: Colors.teal),
                      const SizedBox(width: 8),
                      _StatCard(
                          label: 'Saldo',
                          nilai: formatRupiah(masuk - keluar),
                          warna: Colors.blue),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _StatCard(
                          label: 'Pemasukan',
                          nilai: formatRupiah(masuk),
                          warna: Colors.green),
                      const SizedBox(width: 8),
                      _StatCard(
                          label: 'Pengeluaran',
                          nilai: formatRupiah(keluar),
                          warna: Colors.red),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text('Riwayat Transaksi',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  if (docs.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: Text('Belum ada transaksi.')),
                    ),
                  for (final doc in docs)
                    Builder(builder: (context) {
                      final d = doc.data();
                      final isMasuk = d['tipe'] == 'Pemasukan';
                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor:
                                isMasuk ? Colors.green.shade100 : Colors.red.shade100,
                            child: Icon(
                              isMasuk ? Icons.arrow_downward : Icons.arrow_upward,
                              color: isMasuk ? Colors.green : Colors.red,
                            ),
                          ),
                          title: Text(d['judul'] ?? ''),
                          subtitle:
                              Text(formatTanggal(d['tanggal'] as Timestamp?)),
                          trailing: Text(
                            '${isMasuk ? '+' : '-'} ${formatRupiah(d['nominal'] ?? 0)}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isMasuk ? Colors.green : Colors.red,
                            ),
                          ),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  TransactionDetailPage(docId: doc.id),
                            ),
                          ),
                        ),
                      );
                    }),
                  const SizedBox(height: 72),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String nilai;
  final Color warna;

  const _StatCard(
      {required this.label, required this.nilai, required this.warna});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        color: warna.withOpacity(0.1),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(color: warna)),
              const SizedBox(height: 4),
              Text(nilai,
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold, color: warna)),
            ],
          ),
        ),
      ),
    );
  }
}
