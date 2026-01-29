import 'package:flutter/material.dart';

class ConnectorSettings extends StatefulWidget {
  final bool editMode;
  final int connectorCount;
  final double initialC1;
  final double initialC2;
  final double initialC3;
  final void Function(double c1, double c2, double c3) onValuesChanged;

  const ConnectorSettings({
    super.key,
    required this.editMode,
    required this.connectorCount,
    required this.onValuesChanged,
    required this.initialC1,
    required this.initialC2,
    required this.initialC3,
  });

  @override
  State<ConnectorSettings> createState() => _ConnectorSettingsState();
}

class _ConnectorSettingsState extends State<ConnectorSettings> {
  late double c1;
  late double c2;
  late double c3;

  @override
  void initState() {
    super.initState();
    c1 = widget.initialC1;
    c2 = widget.initialC2;
    c3 = widget.initialC3;
  }

  Widget _numField(String label, double value, void Function(String) onChanged) {
    return ListTile(
      title: Text(label),
      subtitle: widget.editMode
          ? TextFormField(
        initialValue: value.toString(),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        onChanged: onChanged,
      )
          : Text(value.toString()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Column(
        children: [
          const ListTile(title: Text('Connector Settings')),
          if (widget.connectorCount >= 1)
            _numField('Over Current Limit Connector 1 (A)', c1, (v) {
              setState(() {
                c1 = double.tryParse(v) ?? c1;
                widget.onValuesChanged(c1, c2, c3);
              });
            }),
          if (widget.connectorCount >= 2)
            _numField('Over Current Limit Connector 2 (A)', c2, (v) {
              setState(() {
                c2 = double.tryParse(v) ?? c2;
                widget.onValuesChanged(c1, c2, c3);
              });
            }),
          if (widget.connectorCount >= 3)
            _numField('Over Current Limit Connector 3 (A)', c3, (v) {
              setState(() {
                c3 = double.tryParse(v) ?? c3;
                widget.onValuesChanged(c1, c2, c3);
              });
            }),
        ],
      ),
    );
  }
}