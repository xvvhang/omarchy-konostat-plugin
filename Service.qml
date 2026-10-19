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
        } catch (e) { console.warn("Konopulse:", e) }
      }
    }
    stderr: StdioCollector {
      onStreamFinished: if (text.trim()) console.warn("Konopulse:", text.trim())
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
    target: "konochi.konopulse"
    function status(): string { return JSON.stringify({ready: root.ready, error: root.error, data: root.state}) }
  }
}
