# Validation record

Checked 2026-10-19 on Omarchy 4.0.5-1, Qt 6.12.0.

- Manifest validation and Qt 6 qmllint: passed for all QML files.
- Seven Python telemetry tests: passed, including a real local snapshot.
- Running shell: enabled; IPC status reported ready with no error and
  CPU/memory/storage/network/sensor data; shell summon/hide succeeded.
- GPU frequency was available; unsupported utilization remained unavailable.

Full manual settings/click/Escape, multi-monitor behavior, restart, and
destructive uninstall testing remain to be performed before requesting
marketplace approval. NVIDIA-specific collection was not tested on this machine.

## Transparency regression (#1)

The popup must use `Color.popups.text`, paired with KeyboardPanel's
`Color.popups.background`, rather than the wallpaper-adaptive bar foreground.
`test_panel.py` guards these bindings at source level; it is not a rendering test.

Automated checks on 2026-10-23:

- `python3 -B -m unittest discover -v`: all nine tests passed.
- `omarchy plugin validate .` and `git diff --check`: passed.
- Qt 6 qmllint completed with warnings (QtObject member inference,
  unqualified delegate access, and the existing Service `state` override).
  For import resolution, use an import directory containing a `qs` symlink to
  `/usr/share/omarchy/shell`.

Manual checks (not yet performed for this fix):

- With a dark popup theme and a bright wallpaper, enable bar transparency so
  the bar uses dark icons. Open Konostat and check that its title, metric values,
  details, separators, and switches still use the light popup text color.
- Repeat with bar transparency disabled and with a light popup theme.
- Change themes while the popup is open; its colors should update immediately.
- Toggle icon-only mode and a metric, then close with Escape; behavior and saved
  settings should be unchanged.
