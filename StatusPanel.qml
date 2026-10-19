import QtQuick
import qs.Commons
import qs.Ui

Panel {
  id: root
  moduleName: "konochi.konostat"
  manageIpc: false
  property var hostWidget: null
  property var anchorItem: null
  KeyboardPanel {
    id: popup
    anchorItem: root.anchorItem
    bar: root.bar
    owner: root.hostWidget
    open: root.opened
    focusTarget: content
    contentWidth: fittedContentWidth(Style.space(440))
    contentHeight: fittedContentHeight(column.implicitHeight)
    Flickable {
      id: content
      anchors.fill: parent
      clip: true
      contentWidth: width
      contentHeight: column.implicitHeight
      boundsBehavior: Flickable.StopAtBounds
      Keys.onEscapePressed: root.close()
      Column {
        id: column
        width: content.width
        spacing: Style.space(14)
        Text { text: "Konostat"; color: root.barForeground; font.family: Style.font.family; font.pixelSize: Style.font.body * 1.3 }
        Row {
          width: parent.width
          spacing: Style.space(10)
          Text { width: parent.width - iconSwitch.width - parent.spacing; anchors.verticalCenter: parent.verticalCenter; text: "Icon-only bar"; color: root.barForeground; font.family: Style.font.family; font.pixelSize: Style.font.body }
          ToggleSwitch { id: iconSwitch; checked: root.hostWidget.iconOnly; foreground: root.barForeground; onToggled: root.hostWidget.save("iconOnly", !checked) }
        }
        Text {
          width: parent.width
          text: root.hostWidget.iconOnly ? "Metrics hidden. Your selections are preserved." : "Toggle metrics to show them in the bar."
          wrapMode: Text.WordWrap
          color: root.barForeground
          opacity: 0.65
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
        }
        Repeater {
          model: root.hostWidget.metrics
          Column {
            id: metric
            required property var modelData
            width: column.width
            spacing: Style.space(5)
            Rectangle { width: parent.width; height: 1; color: root.barForeground; opacity: 0.12 }
            Row {
              width: parent.width
              spacing: Style.space(10)
              Text {
                width: parent.width - pin.width - parent.spacing
                anchors.verticalCenter: parent.verticalCenter
                text: metric.modelData.icon + "  " + metric.modelData.label + "   " + root.hostWidget.value(metric.modelData.key)
                wrapMode: Text.WordWrap
                color: root.barForeground
                font.family: Style.font.family
                font.pixelSize: Style.font.body
              }
              ToggleSwitch {
                id: pin
                checked: root.hostWidget.setting(metric.modelData.key, metric.modelData.fallback) === true
                foreground: root.barForeground
                onToggled: root.hostWidget.save(metric.modelData.key, !checked)
              }
            }
            Text {
              width: parent.width
              text: root.hostWidget.details(metric.modelData.key)
              wrapMode: Text.WordWrap
              color: root.barForeground
              opacity: 0.7
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
            }
          }
        }
        Text {
          width: parent.width
          text: "Live: 2s · Storage: 30s · Bar shows peak fan / temperature."
          wrapMode: Text.WordWrap
          color: root.barForeground
          opacity: 0.5
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
        }
        Text { visible: text !== ""; width: parent.width; text: root.hostWidget.feedback; color: root.barForeground; wrapMode: Text.WordWrap; font.pixelSize: Style.font.caption }
      }
    }
  }
}
