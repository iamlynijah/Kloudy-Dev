import 'package:flutter/material.dart';

class TabGateScreen extends StatelessWidget {
  final String tabName;
  final IconData icon;
  final String tagline;
  final List<(IconData, String)> features;
  final String ctaLabel;
  final VoidCallback onSetUp;

  const TabGateScreen({
    super.key,
    required this.tabName,
    required this.icon,
    required this.tagline,
    required this.features,
    required this.onSetUp,
    this.ctaLabel = '',
  });

  @override
  Widget build(BuildContext context) {
    final label = ctaLabel.isNotEmpty ? ctaLabel : 'Set up $tabName';
    return Scaffold(
      backgroundColor: null, // inherits from theme
      appBar: AppBar(
        leading: Navigator.of(context).canPop()
            ? BackButton(color: Theme.of(context).colorScheme.onSurface)
            : null,
        title: Text(tabName),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 40, 28, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(icon, color: Colors.white, size: 30),
              ),
              const SizedBox(height: 28),
              // Tab name + tagline
              Text(
                tabName,
                style: const TextStyle(
                    fontSize: 30, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                tagline,
                style: TextStyle(
                    fontSize: 16,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                    height: 1.4),
              ),
              const SizedBox(height: 36),
              // Feature list
              ...features.map((f) => Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Row(children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(f.$1, size: 20),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          f.$2,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ]),
                  )),
              const Spacer(),
              // CTA
              SizedBox(
                width: double.infinity,
                height: 58,
                child: ElevatedButton(
                  onPressed: onSetUp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(29)),
                  ),
                  child: Text(
                    label,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600),
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
