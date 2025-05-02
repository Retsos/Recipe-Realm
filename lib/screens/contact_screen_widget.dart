import 'package:flutter/material.dart';

class ContactPage extends StatefulWidget {
  const ContactPage({Key? key}) : super(key: key);

  @override
  State<ContactPage> createState() => _ContactPageState();
}

class _ContactPageState extends State<ContactPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();

  void _sendMessage() {
    if (_formKey.currentState!.validate()) {
      final name = _nameController.text.trim();

      // Εδώ θα μπορούσες να στείλεις το μήνυμα στο backend/email αν χρειάζεται.

      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text("Μήνυμα Εστάλη"),
          content: Text("Ευχαριστούμε $name για το μήνυμά σου!"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("ΟΚ"),
            )
          ],
        ),
      );

      // Καθαρισμός πεδίων
      _nameController.clear();
      _messageController.clear();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Επικοινωνία"),
        backgroundColor: Colors.green[500],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Text(
                "Επικοινώνησε μαζί μας",
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: "Όνομα",
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return "Παρακαλώ εισάγετε το όνομά σας";
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _messageController,
                decoration: const InputDecoration(
                  labelText: "Μήνυμα",
                  border: OutlineInputBorder(),
                ),
                maxLines: 5,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return "Παρακαλώ εισάγετε το μήνυμά σας";
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _sendMessage,
                icon: const Icon(Icons.send),
                label: const Text("Αποστολή"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[600],
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
