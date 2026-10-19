import QtQuick
import Quickshell.Io

Item {
  id: root
  property var state: ({})
  property bool ready: false
  property string error: ""
  Process {
    id: backend
    command: ["/usr/bin/python3", "-B", Qt.resolvedUrl("collect.py").toString().replace(/^file:\/\//, "")]
    running: true
    stdout: SplitParser {
      onRead: function(line) {
        try {
          root.state = JSON.parse(line)
          root.ready = true
          root.error = ""
          stale.restart()
        } catch (e) { console.warn("System Status:", e) }
      }
    }
    stderr: StdioCollector {
      onStreamFinished: if (text.trim()) console.warn("System Status:", text.trim())
    }
    onExited: {
      root.ready = false
      root.error = "Collector stopped. Retrying…"
      retry.restart()
    }
  }
  Timer { id: retry; interval: 5000; onTriggered: backend.running = true }
  Timer { id: stale; interval: 10000; onTriggered: { root.ready = false; root.error = "Data update timed out" } }
  IpcHandler {
    target: "alec.system-status"
    function status(): string { return JSON.stringify({ready: root.ready, error: root.error, data: root.state}) }
  }
}
