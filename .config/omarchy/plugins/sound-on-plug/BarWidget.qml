import QtQuick
import Quickshell
import Quickshell.Io
import qs.Ui

BarWidget {
  id: root
  moduleName: "com.omarchy.sound-on-plug"

  readonly property string stateFilePath: (Quickshell.env("HOME") || "") + "/.local/state/omarchy/sound-on-plug-status"

  // Hidden while "0": USB unplugged or unmounted. Shown on "1" (USB plugged).
  property bool usbPresent: true

  visible: root.usbPresent

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  FileView {
    id: stateFile
    path: root.stateFilePath
    watchChanges: true
    printErrors: false
    onLoaded: {
      root.usbPresent = String(text()).trim() === "1"
    }
    onFileChanged: reload()
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "🔌"
    fontFamily: ""
    horizontalMargin: 7.5
    tooltipText: "Left: plug · Right: unplug · Middle: unmount"
    onPressed: function(button) {
      if (!root.bar) return
      if (button === Qt.RightButton) {
        root.bar.run("bash /home/bass/.config/omarchy/hooks/sound-on-plug unplug")
      } else if (button === Qt.MiddleButton) {
        root.bar.run("bash /home/bass/.config/omarchy/hooks/sound-on-plug inject")
      } else {
        root.bar.run("bash /home/bass/.config/omarchy/hooks/sound-on-plug plug")
      }
    }
  }
}
