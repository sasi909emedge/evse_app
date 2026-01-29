import 'package:flutter/material.dart';

class ConnectivitySettings extends StatefulWidget {
  final bool editMode;
  final bool wifiEnable;
  final bool gsmEnable;
  final bool ethEnable;
  final int wifiPriority;
  final int gsmPriority;
  final int ethPriority;
  final void Function(bool, bool, bool, int, int, int) onChanged;

  const ConnectivitySettings({
    super.key,
    required this.editMode,
    required this.wifiEnable,
    required this.gsmEnable,
    required this.ethEnable,
    required this.wifiPriority,
    required this.gsmPriority,
    required this.ethPriority,
    required this.onChanged,
  });

  @override
  State<ConnectivitySettings> createState() => _ConnectivitySettingsState();
}

class _ConnectivitySettingsState extends State<ConnectivitySettings> {
  late bool wifiEnable;
  late bool gsmEnable;
  late bool ethEnable;
  late int wifiPriority;
  late int gsmPriority;
  late int ethPriority;

  @override
  void initState() {
    super.initState();
    wifiEnable = widget.wifiEnable;
    gsmEnable = widget.gsmEnable;
    ethEnable = widget.ethEnable;
    wifiPriority = widget.wifiPriority;
    gsmPriority = widget.gsmPriority;
    ethPriority = widget.ethPriority;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Column(
        children: [
          const ListTile(title: Text('Connectivity Settings')),
          SwitchListTile(
            title: const Text('Wi‑Fi Enable'),
            value: wifiEnable,
            onChanged: widget.editMode
                ? (v) {
              setState(() => wifiEnable = v);
              widget.onChanged(wifiEnable, gsmEnable, ethEnable, wifiPriority, gsmPriority, ethPriority);
            }
                : null,
          ),
          if (wifiEnable)
            ListTile(
              title: const Text('Wi‑Fi Priority'),
              subtitle: widget.editMode
                  ? DropdownButton<int>(
                value: wifiPriority,
                items: [1, 2, 3].map((e) => DropdownMenuItem(value: e, child: Text('$e'))).toList(),
                onChanged: (v) {
                  if (v == null) return;
                  setState(() => wifiPriority = v);
                  widget.onChanged(wifiEnable, gsmEnable, ethEnable, wifiPriority, gsmPriority, ethPriority);
                },
              )
                  : Text('$wifiPriority'),
            ),
          SwitchListTile(
            title: const Text('GSM Enable'),
            value: gsmEnable,
            onChanged: widget.editMode
                ? (v) {
              setState(() => gsmEnable = v);
              widget.onChanged(wifiEnable, gsmEnable, ethEnable, wifiPriority, gsmPriority, ethPriority);
            }
                : null,
          ),
          if (gsmEnable)
            ListTile(
              title: const Text('GSM Priority'),
              subtitle: widget.editMode
                  ? DropdownButton<int>(
                value: gsmPriority,
                items: [1, 2, 3].map((e) => DropdownMenuItem(value: e, child: Text('$e'))).toList(),
                onChanged: (v) {
                  if (v == null) return;
                  setState(() => gsmPriority = v);
                  widget.onChanged(wifiEnable, gsmEnable, ethEnable, wifiPriority, gsmPriority, ethPriority);
                },
              )
                  : Text('$gsmPriority'),
            ),
          SwitchListTile(
            title: const Text('Ethernet Enable'),
            value: ethEnable,
            onChanged: widget.editMode
                ? (v) {
              setState(() => ethEnable = v);
              widget.onChanged(wifiEnable, gsmEnable, ethEnable, wifiPriority, gsmPriority, ethPriority);
            }
                : null,
          ),
          if (ethEnable)
            ListTile(
              title: const Text('Ethernet Priority'),
              subtitle: widget.editMode
                  ? DropdownButton<int>(
                value: ethPriority,
                items: [1, 2, 3].map((e) => DropdownMenuItem(value: e, child: Text('$e'))).toList(),
                onChanged: (v) {
                  if (v == null) return;
                  setState(() => ethPriority = v);
                  widget.onChanged(wifiEnable, gsmEnable, ethEnable, wifiPriority, gsmPriority, ethPriority);
                },
              )
                  : Text('$ethPriority'),
            ),
        ],
      ),
    );
  }
}