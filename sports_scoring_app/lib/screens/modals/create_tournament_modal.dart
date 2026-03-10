import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/api_services.dart';

class CreateTournamentModal extends StatefulWidget {
  const CreateTournamentModal({super.key});

  @override
  State<CreateTournamentModal> createState() => _CreateTournamentModalState();
}

class _CreateTournamentModalState extends State<CreateTournamentModal> {
  final ApiService api = ApiService();

  final _nameCtrl = TextEditingController();
  final _contactCtrl = TextEditingController();
  final _entryFeeCtrl = TextEditingController();
  final _prizeCtrl = TextEditingController();
  final _venueCtrl = TextEditingController();

  bool _loading = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _contactCtrl.dispose();
    _entryFeeCtrl.dispose();
    _prizeCtrl.dispose();
    _venueCtrl.dispose();
    super.dispose();
  }

Future<void> _submit() async {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return;

  final name = _nameCtrl.text.trim();
  final contact = _contactCtrl.text.trim();
  final entryFeeText = _entryFeeCtrl.text.trim();
  final prizeText = _prizeCtrl.text.trim();
  final venue = _venueCtrl.text.trim();

  if (name.isEmpty || contact.isEmpty || entryFeeText.isEmpty || prizeText.isEmpty || venue.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Please fill all fields.")),
    );
    return;
  }

  final entryFee = double.tryParse(entryFeeText);
  final prize = double.tryParse(prizeText);

  if (entryFee == null || prize == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Entry fee and prize must be numbers.")),
    );
    return;
  }

  setState(() => _loading = true);
  try {
    await api.createTournamentDetails(
      firebaseUid: uid,
      organizerName: name,
      contactNo: contact,
      entryFee: entryFee,
      winningPrize: prize,
      venue: venue,
    );

    if (mounted) Navigator.pop(context, true); // ✅ refresh list
  } catch (e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
  } finally {
    if (mounted) setState(() => _loading = false);
  }
}

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          /// HEADER
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const SizedBox(width: 24),
              const Text(
                'Enter Details',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: _loading ? null : () => Navigator.pop(context),
              ),
            ],
          ),

          const SizedBox(height: 16),

          _inputField('Enter Name', controller: _nameCtrl),
          _inputField('Contact No.', controller: _contactCtrl, keyboardType: TextInputType.phone),
          _inputField('Entry Fees', controller: _entryFeeCtrl, keyboardType: TextInputType.number),
          _inputField('Winning Prize', controller: _prizeCtrl, keyboardType: TextInputType.number),
          _inputField('Venue', controller: _venueCtrl),

          const SizedBox(height: 16),

          /// SUBMIT BUTTON
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE5E5E5),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text(
                      'Submit',
                      style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  /// INPUT FIELD
  Widget _inputField(
    String hint, {
    required TextEditingController controller,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          hintText: hint,
          filled: true,
          fillColor: const Color(0xFFE5E5E5),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}