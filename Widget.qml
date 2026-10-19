import QtQuick
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "konochi.konostat"
  readonly property var service: bar?.shell?.serviceFor(moduleName)
  readonly property var state: service ? service.state : ({})
  readonly property bool ready: service?.ready ?? false
  readonly property bool iconOnly: setting("iconOnly", true) === true
  readonly property var metrics: [
    {key: "showCpu", label: "CPU", icon: "󰻠", fallback: true},
    {key: "showGpu", label: "GPU", icon: "󰢮", fallback: false},
    {key: "showMemory", label: "Memory", icon: "󰍛", fallback: true},
    {key: "showStorage", label: "Storage", icon: "󰋊", fallback: false},
    {key: "showNetwork", label: "Network", icon: "󰖩", fallback: false},
    {key: "showFan", label: "Fans", icon: "󰈐", fallback: false},
    {key: "showTemperature", label: "Temperature", icon: "󰔏", fallback: false}
  ]
  readonly property var barMetrics: metrics.filter(function(m) { return !root.iconOnly && root.setting(m.key, m.fallback) === true })
  readonly property bool opened: panel.opened
  readonly property bool popoutSwitchClosing: panel.popoutSwitchClosing
  readonly property real openPanelIndicatorWidth: display.implicitWidth
  readonly property real openPanelIndicatorHeight: display.implicitHeight
  function open() { panel.open() }
  function close() { panel.close() }
  function closeForPopoutSwitch() { panel.closeForPopoutSwitch() }
  property string feedback: ""
  function save(key, value) {
    var entry = Object.assign({}, root.settings, {id: moduleName})
    entry[key] = value
    if (bar?.shell?.updateEntryInline(moduleName, entry)) {
      root.settings = entry
      feedback = ""
    } else feedback = "Could not save settings. Please try again."
  }
  function percent(v) { return v === null || v === undefined ? "N/A" : Math.round(v) + "%" }
  function bytes(v) {
    if (v === null || v === undefined) return "N/A"
    var units = ["B", "KiB", "MiB", "GiB", "TiB"]
    var i = 0
    while (v >= 1024 && i < units.length - 1) { v /= 1024; i++ }
    return (i === 0 ? Math.round(v) : v.toFixed(1)) + " " + units[i]
  }
  function maximum(rows) { return rows.length ? Math.max.apply(null, rows.map(function(r) { return r.value })) : null }
  function value(key) {
    if (!ready) return "—"
    if (key === "showCpu") return percent(state.cpu?.percent)
    if (key === "showGpu") {
      var gpu = (state.gpus || [])[0]
      return !gpu ? "N/A" : gpu.percent != null ? percent(gpu.percent) : gpu.frequencyMHz != null ? gpu.frequencyMHz + " MHz" : "N/A"
    }
    if (key === "showMemory") return percent(state.memory?.percent)
    if (key === "showStorage") return percent((state.storage || [])[0]?.percent)
    if (key === "showNetwork") return "↓" + bytes(state.network?.download) + "/s ↑" + bytes(state.network?.upload) + "/s"
    var n = maximum(key === "showFan" ? state.fans || [] : state.temperatures || [])
    return n === null ? "N/A" : Math.round(n) + (key === "showFan" ? " RPM" : "°C")
  }
  function temperatureSummary(rows) {
    var groups = {}
    rows.forEach(function(s) {
      var chip = s.name.split(" · ")[0]
      var label = /^(coretemp|k10temp|zenpower|cpu.*)$/i.test(chip) ? "CPU"
        : /^nvme/i.test(chip) ? "SSD"
        : /^(spd|dimm)/i.test(chip) ? "Memory"
        : /^(iwl|ath|wifi)/i.test(chip) ? "Wi-Fi"
        : /^(acpi|thinkpad)/i.test(chip) ? "System"
        : /^(amdgpu|i915|xe)$/i.test(chip) ? "GPU" : chip
      var v = Math.round(s.value)
      if (!groups[label]) groups[label] = {min: v, max: v}
      else {
        groups[label].min = Math.min(groups[label].min, v)
        groups[label].max = Math.max(groups[label].max, v)
      }
    })
    return Object.keys(groups).map(function(label) {
      var g = groups[label]
      return label + " " + (g.min === g.max ? g.max : g.min + "–" + g.max) + "°C"
    }).join(" · ") || "No readable temperature sensors"
  }
  function details(key) {
    if (!ready) return service?.error || "Reading system information…"
    if (key === "showCpu") return state.cpu.name + "\n" + state.cpu.threads + " threads · Load " + state.cpu.load.map(function(v) { return v.toFixed(2) }).join(" / ")
    if (key === "showMemory") return bytes(state.memory.used) + " / " + bytes(state.memory.total) + "\nSwap " + bytes(state.memory.swapUsed) + " / " + bytes(state.memory.swapTotal)
    if (key === "showGpu") return (state.gpus || []).map(function(g) {
      return g.name + " · " + (g.percent == null ? "Utilization unavailable" : percent(g.percent))
        + (g.frequencyMHz != null ? " · " + g.frequencyMHz + " MHz" : "")
        + (g.memoryTotal > 0 ? "\nVRAM " + bytes(g.memoryUsed) + " / " + bytes(g.memoryTotal) : "")
        + (g.fanPercent != null ? " · Fan " + percent(g.fanPercent) : "")
    }).join("\n") || "No GPU detected"
    if (key === "showStorage") return (state.storage || []).map(function(d) { return d.mount + " · " + bytes(d.used) + " / " + bytes(d.total) + " · " + bytes(d.free) + " free" }).join("\n") || "No local disks detected"
    if (key === "showNetwork") return (state.network?.interfaces || []).map(function(n) { return n.name + " · ↓" + bytes(n.download) + "/s ↑" + bytes(n.upload) + "/s" }).join("\n") || "No connected physical interfaces"
    if (key === "showTemperature") return temperatureSummary(state.temperatures || [])
    return (state.fans || []).map(function(s) { return s.name + " · " + s.value + " RPM" }).join("\n") || "No readable fan sensors"
  }
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight
  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    useActiveColor: false
    dimmed: !root.ready
    labelVisible: false
    hasVisualContent: true
    fixedWidth: root.vertical ? -1 : display.implicitWidth + Math.max(0, Style.bar.iconSlot - Style.bar.iconCanvas)
    fixedHeight: root.vertical ? display.implicitHeight + Style.space(12) : -1
    tooltipText: "Konostat · Click to open"
    onPressed: function(b) { if (b === Qt.LeftButton) panel.toggle() }
    Grid {
      id: display
      anchors.centerIn: parent
      columns: root.vertical ? 1 : Math.max(1, root.barMetrics.length)
      spacing: Style.space(8)
      verticalItemAlignment: Grid.AlignVCenter
      Item {
        visible: root.barMetrics.length === 0
        width: Style.bar.iconCanvas
        height: width
        // nf-md-view_dashboard (U+F056E).
        OpticalGlyph { anchors.fill: parent; text: "\u{f056e}"; color: button.foreground; fontFamily: button.fontFamily; fontSize: Style.bar.iconFont }
      }
      Repeater {
        model: root.barMetrics
        Row {
          id: metricDisplay
          required property var modelData
          spacing: Style.space(6)
          Item {
            width: Style.bar.iconCanvas
            height: width
            anchors.verticalCenter: parent.verticalCenter
            OpticalGlyph {
              anchors.fill: parent
              text: metricDisplay.modelData.icon
              color: button.foreground
              fontFamily: button.fontFamily
              fontSize: Style.bar.iconFont
            }
          }
          Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.value(metricDisplay.modelData.key)
            color: button.foreground
            font.family: button.fontFamily
            font.pixelSize: Style.font.body
          }
        }
      }
    }
  }
  StatusPanel { id: panel; bar: root.bar; hostWidget: root; anchorItem: button }
}
