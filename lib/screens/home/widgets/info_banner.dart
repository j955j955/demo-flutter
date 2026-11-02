import 'package:flutter/material.dart';

class InfoBanner extends StatelessWidget {
  const InfoBanner({super.key, required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Card(
    elevation: 0,
    color: Theme.of(context).colorScheme.secondaryContainer,
    margin: const EdgeInsets.only(bottom: 8),
    child: ListTile(leading: Icon(icon), title: Text(text), dense: true),
  );
}
