import QtQuick
import qs.Commons
import qs.Commons as Commons
import qs.Ui

Panel {
  id: root
  moduleName: "konochi.konostat"
  manageIpc: false
  property var hostWidget: null
  property var anchorItem: null
  // Popup colors must not inherit the wallpaper-adaptive bar foreground.
  readonly property color panelForeground: Commons.Color.popups.text
  property int selectedIndex: -1

  onOpenedChanged: if (opened) selectedIndex = -1

  function moveCursor(delta) {
    selectedIndex = Math.max(0, Math.min(hostWidget.metrics.length, selectedIndex + delta))
    var item = selectedIndex === hostWidget.metrics.length ? barSettings : metricRows.itemAt(selectedIndex)
    if (!item) return
    var top = item.mapToItem(column, 0, 0).y
    var bottom = top + item.height
    if (top < content.contentY) content.contentY = top
    else if (bottom > content.contentY + content.height) content.contentY = Math.max(0, bottom - content.height)
  }

  function activateCursor() {
    if (selectedIndex < 0) return
    if (selectedIndex === hostWidget.metrics.length) {
      hostWidget.save("iconOnly", !hostWidget.iconOnly)
    } else {
      var metric = hostWidget.metrics[selectedIndex]
      hostWidget.save(metric.key, hostWidget.setting(metric.key, metric.fallback) !== true)
    }
  }

  KeyboardPanel {
    id: popup
    anchorItem: root.anchorItem
    bar: root.bar
    owner: root.hostWidget
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: fittedContentWidth(Style.space(440))
    contentHeight: fittedContentHeight(column.implicitHeight)
    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onMoveRequested: function(dx, dy) { if (dy !== 0) root.moveCursor(dy) }
      onActivateRequested: root.activateCursor()
      onCloseRequested: root.close()
      onTabRequested: function(direction) {
        if (root.bar && typeof root.bar.switchPanelFrom === "function")
          root.bar.switchPanelFrom(root.hostWidget, direction)
      }

      Flickable {
      id: content
      anchors.fill: parent
      clip: true
      contentWidth: width
      contentHeight: column.implicitHeight
      boundsBehavior: Flickable.StopAtBounds
      Column {
        id: column
        width: content.width
        spacing: Style.space(14)
        PanelHero {
          title: "Konostat"
          meta: root.hostWidget.ready ? "System monitor · Live" : "Waiting for system data"
          foreground: root.panelForeground
          iconComponent: Text {
            textFormat: Text.PlainText
            text: "\u{f056e}"
            color: root.panelForeground
            font.family: Style.font.family
            font.pixelSize: Style.font.display
          }
        }
        PanelSeparator { foreground: root.panelForeground }
        Item {
          width: parent.width
          implicitHeight: overviewHeader.implicitHeight
          PanelSectionHeader { id: overviewHeader; text: "OVERVIEW"; foreground: root.panelForeground }
          PanelSectionHeader { anchors.right: parent.right; text: "IN BAR"; foreground: root.panelForeground }
        }
        Repeater {
          id: metricRows
          model: root.hostWidget.metrics
          Column {
            id: metric
            required property var modelData
            required property int index
            readonly property string reading: root.hostWidget.value(modelData.key)
            readonly property bool hasFraction: /^\d+(?:\.\d+)?%$/.test(reading)
            readonly property real fraction: hasFraction ? Math.max(0, Math.min(1, parseFloat(reading) / 100)) : 0
            width: column.width
            spacing: Style.space(4)
            Item {
              width: parent.width
              implicitHeight: Math.max(metricIcon.height, metricLabel.implicitHeight, readingLabel.implicitHeight, pin.implicitHeight)
              OpticalGlyph {
                id: metricIcon
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: Style.space(24)
                height: Style.space(24)
                text: metric.modelData.icon
                color: root.panelForeground
                fontSize: Style.font.title
              }
              Text {
                id: metricLabel
                anchors.left: metricIcon.right
                anchors.leftMargin: Style.space(10)
                anchors.right: readingLabel.left
                anchors.rightMargin: Style.space(8)
                anchors.verticalCenter: parent.verticalCenter
                textFormat: Text.PlainText
                text: metric.modelData.label
                elide: Text.ElideRight
                color: root.panelForeground
                font.family: Style.font.family
                font.pixelSize: Style.font.body
              }
              Text {
                id: readingLabel
                anchors.right: pin.left
                anchors.rightMargin: Style.space(10)
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, parent.width * 0.46)
                horizontalAlignment: Text.AlignRight
                textFormat: Text.PlainText
                text: metric.reading
                elide: Text.ElideRight
                color: root.panelForeground
                font.family: Style.font.family
                font.pixelSize: Style.font.body
                font.bold: true
              }
              ToggleSwitch {
                id: pin
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                checked: root.hostWidget.setting(metric.modelData.key, metric.modelData.fallback) === true
                foreground: root.panelForeground
                hasCursor: root.selectedIndex === metric.index
                onToggled: root.hostWidget.save(metric.modelData.key, !checked)
                onHovered: function(h) { if (h) root.selectedIndex = metric.index }
              }
            }
            Rectangle {
              visible: metric.hasFraction
              x: Style.space(34)
              width: parent.width - x - Style.space(6)
              height: Style.space(4)
              radius: Style.cornerRadius > 0 ? height / 2 : 0
              color: Qt.rgba(root.panelForeground.r, root.panelForeground.g, root.panelForeground.b, 0.12)
              Rectangle {
                width: parent.width * metric.fraction
                height: parent.height
                radius: parent.radius
                color: root.panelForeground
                opacity: 0.8
                Behavior on width { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
              }
            }
            Text {
              x: Style.space(34)
              width: parent.width - x
              textFormat: Text.PlainText
              text: root.hostWidget.details(metric.modelData.key)
              wrapMode: Text.WordWrap
              color: root.panelForeground
              opacity: 0.6
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
            }
          }
        }
        PanelSeparator { foreground: root.panelForeground }
        Column {
          id: barSettings
          width: parent.width
          spacing: Style.space(4)
          PanelSectionHeader { text: "BAR DISPLAY"; foreground: root.panelForeground }
          Item {
            width: parent.width
            implicitHeight: Math.max(barLabel.implicitHeight, iconSwitch.implicitHeight)
            Text {
              id: barLabel
              anchors.left: parent.left
              anchors.right: iconSwitch.left
              anchors.verticalCenter: parent.verticalCenter
              text: "Icon only"
              color: root.panelForeground
              font.family: Style.font.family
              font.pixelSize: Style.font.body
            }
            ToggleSwitch {
              id: iconSwitch
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              checked: root.hostWidget.iconOnly
              foreground: root.panelForeground
              hasCursor: root.selectedIndex === root.hostWidget.metrics.length
              onToggled: root.hostWidget.save("iconOnly", !checked)
              onHovered: function(h) { if (h) root.selectedIndex = root.hostWidget.metrics.length }
            }
          }
          Text {
            width: parent.width
            text: root.hostWidget.iconOnly ? "Bar metrics are hidden. Your selections are preserved." : "Use the switches above to choose your bar metrics."
            wrapMode: Text.WordWrap
            color: root.panelForeground
            opacity: 0.6
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
          }
        }
        Text {
          width: parent.width
          text: "Live every 2s · Storage every 30s\nFan and temperature readings show peak values."
          wrapMode: Text.WordWrap
          color: root.panelForeground
          opacity: 0.5
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
        }
        Text { visible: text !== ""; width: parent.width; textFormat: Text.PlainText; text: root.hostWidget.feedback; color: root.panelForeground; wrapMode: Text.WordWrap; font.family: Style.font.family; font.pixelSize: Style.font.caption }
      }
    }
  }
  }
}
