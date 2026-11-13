import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

// Struktur hirarki Firestore:
// users (collection) -> {uid} (document) -> transactions (sub-collection) -> {id} (document)
CollectionReference<Map<String, dynamic>> transaksiRef() {
  final uid = FirebaseAuth.instance.currentUser!.uid;
  return FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('transactions');
}

String formatRupiah(num angka) {
  final s = angka.round().abs().toString();
  final buf = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
    buf.write(s[i]);
  }
  return 'Rp ${angka < 0 ? '-' : ''}$buf';
}

String formatTanggal(Timestamp? ts) {
  if (ts == null) return '-';
  final d = ts.toDate();
  String dua(int n) => n.toString().padLeft(2, '0');
  return '${dua(d.day)}/${dua(d.month)}/${d.year} ${dua(d.hour)}:${dua(d.minute)}';
}

// ======================= FORM TAMBAH / EDIT =======================
class TransactionFormPage extends StatefulWidget {
  /// null = mode tambah, terisi = mode edit
  final DocumentSnapshot<Map<String, dynamic>>? doc;

  const TransactionFormPage({super.key, this.doc});

  @override
  State<TransactionFormPage> createState() => _TransactionFormPageState();
}

class _TransactionFormPageState extends State<TransactionFormPage> {
  final _judul = TextEditingController();
  final _nominal = TextEditingController();
  final _catatan = TextEditingController();
  String _tipe = 'Pemasukan';
  bool _saving = false;

  bool get _isEdit => widget.doc != null;

  @override
  void initState() {
    super.initState();
    final data = widget.doc?.data();
    if (data != null) {
      _judul.text = data['judul'] ?? '';
      _nominal.text = (data['nominal'] ?? 0).toString();
      _catatan.text = data['catatan'] ?? '';
      _tipe = data['tipe'] ?? 'Pemasukan';
    }
  }

  Future<void> _simpan() async {
    final nominal = num.tryParse(_nominal.text.trim());
    if (_judul.text.trim().isEmpty || nominal == null || nominal <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Judul dan nominal (angka > 0) wajib diisi')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      if (_isEdit) {
        // Edit hanya mengubah nominal dan catatan
        await widget.doc!.reference.update({
          'nominal': nominal,
          'catatan': _catatan.text.trim(),
        });
      } else {
        await transaksiRef().add({
          'judul': _judul.text.trim(),
          'nominal': nominal,
          'tipe': _tipe,
          'catatan': _catatan.text.trim(),
          'tanggal': FieldValue.serverTimestamp(),
        });
      }
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Gagal menyimpan: $e')));
      setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _judul.dispose();
    _nominal.dispose();
    _catatan.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Edit Transaksi' : 'Tambah Transaksi')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _judul,
              enabled: !_isEdit,
              decoration: const InputDecoration(
                  labelText: 'Judul Transaksi', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nominal,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                  labelText: 'Nominal (Rp)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                      value: 'Pemasukan',
                      label: Text('Pemasukan'),
                      icon: Icon(Icons.arrow_downward)),
                  ButtonSegment(
                      value: 'Pengeluaran',
                      label: Text('Pengeluaran'),
                      icon: Icon(Icons.arrow_upward)),
                ],
                selected: {_tipe},
                onSelectionChanged: _isEdit
                    ? null
                    : (value) => setState(() => _tipe = value.first),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _catatan,
              maxLines: 3,
              decoration: const InputDecoration(
                  labelText: 'Catatan (opsional)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _saving ? null : _simpan,
                child: Text(_isEdit ? 'Simpan Perubahan' : 'Simpan'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ======================= DETAIL =======================
class TransactionDetailPage extends StatelessWidget {
  final String docId;

  const TransactionDetailPage({super.key, required this.docId});

  Future<void> _hapus(BuildContext context) async {
    final yakin = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Transaksi'),
        content: const Text('Catatan ini akan dihapus permanen. Lanjutkan?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Hapus')),
        ],
      ),
    );
    if (yakin == true) {
      await transaksiRef().doc(docId).delete();
      if (context.mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: transaksiRef().doc(docId).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return Scaffold(
            appBar: AppBar(title: const Text('Detail Transaksi')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        final doc = snapshot.data!;
        final d = doc.data()!;
        final masuk = d['tipe'] == 'Pemasukan';

        return Scaffold(
          appBar: AppBar(
            title: const Text('Detail Transaksi'),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => TransactionFormPage(doc: doc)),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete),
                onPressed: () => _hapus(context),
              ),
            ],
          ),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(d['judul'] ?? '',
                    style: const TextStyle(
                        fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(
                  '${masuk ? '+' : '-'} ${formatRupiah(d['nominal'] ?? 0)}',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: masuk ? Colors.green : Colors.red,
                  ),
                ),
                const SizedBox(height: 16),
                Text('Tipe : ${d['tipe']}'),
                const SizedBox(height: 4),
                Text('Tanggal : ${formatTanggal(d['tanggal'] as Timestamp?)}'),
                const SizedBox(height: 16),
                const Text('Catatan',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text((d['catatan'] ?? '').toString().isEmpty
                    ? '-'
                    : d['catatan']),
              ],
            ),
          ),
        );
      },
    );
  }
}
