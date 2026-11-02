import 'package:flutter/material.dart';

/// Owns its TextEditingController so it is disposed only after the sheet has
/// fully closed. Disposing right after `showModalBottomSheet` returns crashes:
/// the sheet still rebuilds during its closing animation (the keyboard going
/// down changes the insets), and the TextField would use a dead controller.
class ProfileSheet extends StatefulWidget {
  const ProfileSheet({super.key, required this.initialName});

  final String initialName;

  @override
  State<ProfileSheet> createState() => _ProfileSheetState();
}

class _ProfileSheetState extends State<ProfileSheet> {
  late final _controller = TextEditingController(text: widget.initialName);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 0, 24, 24 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Profile', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          const Text('Support will greet you by your first name.'),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            maxLength: 40,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(labelText: 'Full name', border: OutlineInputBorder()),
            onSubmitted: (value) => Navigator.pop(context, value),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: () => Navigator.pop(context, _controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
