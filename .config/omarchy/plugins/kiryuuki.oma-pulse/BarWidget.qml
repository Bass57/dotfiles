import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "kiryuuki.oma-pulse"

  readonly property string stateDir: (Quickshell.env("HOME") || "") + "/.local/state/omarchy/pulse"
  readonly property string stateFilePath: stateDir + "/status.json"

  property var pulseState: ({
    version: 1,
    alertLevel: "green",
    alertReason: "System resources optimal",
    cpu: { percent: 0, temperature: 45, coreCount: 8, cores: [] },
    memory: { percentUsed: 0, totalBytes: 0, usedBytes: 0, swapPercentUsed: 0 },
    gpu: { available: false, name: "", utilizationPercent: 0, vramPercent: 0, temperature: 0 },
    io: { diskReadKBs: 0, diskWriteKBs: 0, netRxKBs: 0, netTxKBs: 0 },
    topHog: { name: "None", cpuPercent: 0, icon: "󰒋" },
    processes: []
  })

  property bool isManualRefreshing: false
  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    if ("bar" in target) target.bar = root.bar
    if ("settings" in target) target.settings = root.settings
    if ("anchorItem" in target) target.anchorItem = button
    if ("hostWidget" in target) target.hostWidget = root
    if ("pulseData" in target) target.pulseData = root.pulseState
    if ("isManualRefreshing" in target) target.isManualRefreshing = root.isManualRefreshing
  }

  function togglePanel() {
    if (panelLoader.item && panelLoader.item.toggle) panelLoader.item.toggle()
  }

  function open() {
    if (panelLoader.item && panelLoader.item.open) panelLoader.item.open()
  }

  function close() {
    if (panelLoader.item && panelLoader.item.close) panelLoader.item.close()
  }

  function manualRefresh() {
    root.isManualRefreshing = true
    root.injectPanel()
    poll()
  }

  function poll() {
    if (!pollProcess.running) {
      pollProcess.running = true
    }
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()

  FileView {
    id: stateFile
    path: root.stateFilePath
    watchChanges: true
    printErrors: false
    onLoaded: {
      try {
        var parsed = JSON.parse(text())
        if (parsed && typeof parsed === "object") {
          root.pulseState = parsed
          root.injectPanel()
        }
      } catch (e) {}
    }
    onFileChanged: reload()
  }

  Process {
    id: pollProcess
    command: ["/usr/bin/python3", (Quickshell.env("HOME") || "") + "/.config/omarchy/plugins/kiryuuki.oma-pulse/scripts/pulse_engine.py", "--poll"]
    onExited: function(code) {
      root.isManualRefreshing = false
      stateFile.reload()
      root.injectPanel()
    }
  }

  Timer {
    id: initialPollTimer
    interval: 300
    running: true
    repeat: false
    onTriggered: root.poll()
  }

  Timer {
    id: autoPollTimer
    interval: root.opened ? 2500 : 5000
    running: true
    repeat: true
    onTriggered: root.poll()
  }

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  IpcHandler {
    target: "kiryuuki.oma-pulse"

    function refresh(): void { root.manualRefresh() }
    function open(): void { root.open() }
    function close(): void { root.close() }
    function toggle(): void { root.togglePanel() }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: (root.pulseState && root.pulseState.alertLevel === "red") ? "󰓅" : "󰍛"
    foreground: root.opened
      ? Color.accent
      : (root.pulseState && root.pulseState.alertLevel === "red"
          ? "#ef4444"
          : (root.pulseState && root.pulseState.alertLevel === "amber"
              ? "#f59e0b"
              : (root.bar ? root.bar.barForeground : Color.foreground)))
    slotSize: Style.bar.statusSlot

    tooltipText: "OmaPulse: " + (root.pulseState && root.pulseState.cpu ? Math.round(root.pulseState.cpu.percent) : 0) + "% CPU · " +
                 (root.pulseState && root.pulseState.memory ? Math.round(root.pulseState.memory.percentUsed) : 0) + "% RAM · " +
                 (root.pulseState && root.pulseState.cpu ? Math.round(root.pulseState.cpu.temperature) : 0) + "°C\n" +
                 "Hog: " + (root.pulseState && root.pulseState.topHog ? root.pulseState.topHog.name : "None") +
                 " (" + (root.pulseState && root.pulseState.topHog ? root.pulseState.topHog.cpuPercent : 0) + "% CPU)"

    onPressed: function(b) {
      if (!root.bar) return
      if (b === Qt.MiddleButton) root.manualRefresh()
      else root.togglePanel()
    }
  }
}
