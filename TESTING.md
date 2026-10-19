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
