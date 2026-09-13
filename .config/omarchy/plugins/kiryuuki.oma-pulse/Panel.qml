import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

Panel {
  id: root
  moduleName: "kiryuuki.oma-pulse"
  ipcTarget: "kiryuuki.oma-pulse"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root

  readonly property color contentForeground: bar ? bar.foreground : Color.foreground
  readonly property string contentFontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property color contentSubtle: Qt.rgba(contentForeground.r, contentForeground.g, contentForeground.b, 0.65)

  property bool isManualRefreshing: hostWidget ? hostWidget.isManualRefreshing : false
  property var pulseData: hostWidget && hostWidget.pulseState ? hostWidget.pulseState : ({
    version: 1,
    alertLevel: "green",
    alertReason: "System resources optimal",
    cpu: { percent: 0, temperature: 45, coreCount: 8, cores: [] },
    memory: { percentUsed: 0, totalBytes: 0, usedBytes: 0, swapPercentUsed: 0, swapTotalBytes: 0, swapUsedBytes: 0, buffersBytes: 0, cachedBytes: 0 },
    gpu: { available: false, name: "", utilizationPercent: 0, vramPercent: 0, temperature: 0, vramUsedBytes: 0, vramTotalBytes: 0 },
    io: { diskReadKBs: 0, diskWriteKBs: 0, netRxKBs: 0, netTxKBs: 0 },
    topHog: { name: "None", cpuPercent: 0, icon: "󰒋" },
    processes: []
  })

  property int activeTab: 0 // 0: Overview, 1: CPU & Cores, 2: Memory, 3: GPU & IO
  property int selectedIndex: 0
  property string actionNotice: ""

  readonly property var visibleProcesses: {
    var procs = (root.pulseData && root.pulseData.processes) ? root.pulseData.processes.slice() : []
    if (root.activeTab === 1) {
      procs.sort(function(a, b) { return b.cpuPercent - a.cpuPercent })
    } else if (root.activeTab === 2) {
      procs.sort(function(a, b) { return b.rssBytes - a.rssBytes })
    }
    return procs
  }

  function open() { root.controller.show() }
  function close() { root.controller.hide() }
  function toggle() { if (root.opened) close(); else open(); }
  function refresh() {
    if (hostWidget && hostWidget.manualRefresh) hostWidget.manualRefresh()
  }

  onOpenedChanged: {
    if (root.opened) {
      keyCatcher.forceActiveFocus()
      root.selectedIndex = 0
    }
  }

  function killProcess(pid, force) {
    if (!pid) return
    root.actionNotice = (force ? "Force killing PID " : "Terminating PID ") + pid + "..."
    noticeTimer.restart()
    actionProcess.command = [
      "/usr/bin/python3",
      (Quickshell.env("HOME") || "") + "/.config/omarchy/plugins/kiryuuki.oma-pulse/scripts/pulse_engine.py",
      force ? "--kill" : "--term",
      String(pid)
    ]
    actionProcess.running = true
  }

  function formatBytes(bytes) {
    if (!bytes || bytes <= 0) return "0 B"
    var k = 1024
    var sizes = ["B", "KB", "MB", "GB", "TB"]
    var i = Math.floor(Math.log(bytes) / Math.log(k))
    return parseFloat((bytes / Math.pow(k, i)).toFixed(1)) + " " + sizes[i]
  }

  function formatKBs(kb) {
    if (!kb || kb <= 0) return "0 KB/s"
    if (kb >= 1024) return (kb / 1024).toFixed(1) + " MB/s"
    return kb.toFixed(1) + " KB/s"
  }

  Process {
    id: actionProcess
    onExited: function(code) {
      root.refresh()
    }
  }

  Timer {
    id: noticeTimer
    interval: 2500
    repeat: false
    onTriggered: root.actionNotice = ""
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(640))
    contentHeight: panel.fittedContentHeight(mainColumn.implicitHeight + Style.space(32), Style.space(760))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onMoveRequested: function(dx, dy) {
        if (dy !== 0) {
          var procs = root.visibleProcesses || []
          if (procs.length > 0) {
            root.selectedIndex = Math.max(0, Math.min(procs.length - 1, root.selectedIndex + dy))
          }
        }
      }
      onActivateRequested: {
        var procs = root.visibleProcesses || []
        if (procs[root.selectedIndex]) {
          root.killProcess(procs[root.selectedIndex].pid, false)
        }
      }
      onReturnRequested: {
        var procs = root.visibleProcesses || []
        if (procs[root.selectedIndex]) {
          root.killProcess(procs[root.selectedIndex].pid, false)
        }
      }
      onTextKey: function(t) {
        if (t === "r" || t === "R") root.refresh()
        else if (t === "1") { root.activeTab = 0; root.selectedIndex = 0 }
        else if (t === "2") { root.activeTab = 1; root.selectedIndex = 0 }
        else if (t === "3") { root.activeTab = 2; root.selectedIndex = 0 }
        else if (t === "4") { root.activeTab = 3; root.selectedIndex = 0 }
        else if (t === "k" || t === "K") {
          var procs = root.visibleProcesses || []
          if (procs[root.selectedIndex]) {
            root.killProcess(procs[root.selectedIndex].pid, true)
          }
        }
        else if (t === "x" || t === "X") {
          var procs2 = root.visibleProcesses || []
          if (procs2[root.selectedIndex]) {
            root.killProcess(procs2[root.selectedIndex].pid, false)
          }
        }
      }

      Flickable {
        id: scrollArea
        anchors.fill: parent
        contentWidth: mainColumn.width
        contentHeight: mainColumn.implicitHeight + Style.space(24)
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
          id: mainColumn
          width: scrollArea.width
          spacing: Style.space(12)
          topPadding: Style.space(12)
          bottomPadding: Style.space(12)
          leftPadding: Style.space(14)
          rightPadding: Style.space(14)

          readonly property real innerWidth: width - (leftPadding + rightPadding)

          // --- 1. TOP HEADER ---
          RowLayout {
            width: mainColumn.innerWidth

            Row {
              spacing: Style.space(10)
              Layout.alignment: Qt.AlignVCenter

              Text {
                textFormat: Text.PlainText
                text: "󰍛"
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.title + 2
                color: Color.accent
                anchors.verticalCenter: parent.verticalCenter
              }

              Column {
                spacing: 2
                anchors.verticalCenter: parent.verticalCenter

                Text {
                  textFormat: Text.PlainText
                  text: "SYSTEM VITALS & RESOURCE MONITOR"
                  font.family: root.contentFontFamily
                  font.pixelSize: Style.font.body
                  font.bold: true
                  color: root.contentForeground
                }

                Text {
                  textFormat: Text.PlainText
                  text: (root.pulseData.cpu ? root.pulseData.cpu.coreCount + " Threads · " : "") +
                        (root.pulseData.memory ? root.formatBytes(root.pulseData.memory.totalBytes) + " RAM · " : "") +
                        (root.pulseData.cpu ? Math.round(root.pulseData.cpu.temperature) + "°C" : "")
                  font.family: root.contentFontFamily
                  font.pixelSize: Style.font.caption
                  color: root.contentSubtle
                }
              }
            }

            Item { Layout.fillWidth: true }

            Row {
              spacing: Style.space(10)
              Layout.alignment: Qt.AlignVCenter

              Text {
                textFormat: Text.PlainText
                text: root.actionNotice ? root.actionNotice : "Live Telemetry"
                font.family: root.contentFontFamily
                font.pixelSize: 11
                color: root.actionNotice ? Color.accent : root.contentSubtle
                anchors.verticalCenter: parent.verticalCenter
              }

              BorderSurface {
                implicitWidth: Style.space(105)
                implicitHeight: Style.space(30)
                radius: Style.cornerRadius
                color: refreshMouse.pressed
                  ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.35)
                  : (refreshMouse.containsMouse || root.isManualRefreshing
                      ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.2)
                      : Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.1))
                borderSpec: Border.controlSpec("normal", Color.accent, Color.accent)

                Row {
                  anchors.centerIn: parent
                  spacing: Style.space(6)

                  Text {
                    textFormat: Text.PlainText
                    text: "󰑐"
                    font.family: root.contentFontFamily
                    font.pixelSize: Style.font.caption
                    color: Color.accent
                    rotation: root.isManualRefreshing ? spinAnim.angle : 0

                    NumberAnimation on rotation {
                      id: spinAnim
                      property real angle: 0
                      running: root.isManualRefreshing
                      loops: Animation.Infinite
                      from: 0
                      to: 360
                      duration: 800
                    }
                  }

                  Text {
                    textFormat: Text.PlainText
                    text: root.isManualRefreshing ? "Refreshing..." : "Refresh (r)"
                    font.family: root.contentFontFamily
                    font.pixelSize: Style.font.caption
                    font.bold: true
                    color: Color.accent
                  }
                }

                MouseArea {
                  id: refreshMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    root.actionNotice = "Refreshing..."
                    noticeTimer.restart()
                    root.refresh()
                  }
                }
              }
            }
          }

          // --- 2. ALERT & RESOURCE HOG BANNER ---
          BorderSurface {
            width: mainColumn.innerWidth
            implicitHeight: bannerCol.implicitHeight + Style.space(16)
            radius: Style.cornerRadius
            color: root.pulseData.alertLevel === "red"
              ? Qt.rgba(1.0, 0.4, 0.5, 0.14)
              : (root.pulseData.alertLevel === "amber" ? Qt.rgba(0.98, 0.7, 0.53, 0.14) : Qt.rgba(0.65, 0.89, 0.63, 0.12))
            borderSpec: Border.controlSpec(
              "normal",
              root.pulseData.alertLevel === "red" ? "#ef4444" : (root.pulseData.alertLevel === "amber" ? "#f59e0b" : Color.accent),
              root.pulseData.alertLevel === "red" ? "#ef4444" : (root.pulseData.alertLevel === "amber" ? "#f59e0b" : Color.accent)
            )

            Column {
              id: bannerCol
              width: parent.width - Style.space(24)
              anchors.centerIn: parent
              spacing: Style.space(4)

              Row {
                spacing: Style.space(8)
                width: parent.width

                Text {
                  textFormat: Text.PlainText
                  text: root.pulseData.alertLevel === "red" ? "󰓅" : (root.pulseData.alertLevel === "amber" ? "󱐋" : "󰄬")
                  font.family: root.contentFontFamily
                  font.pixelSize: Style.font.caption + 1
                  color: root.pulseData.alertLevel === "red" ? "#ef4444" : (root.pulseData.alertLevel === "amber" ? "#f59e0b" : Color.accent)
                  anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                  textFormat: Text.PlainText
                  text: root.pulseData.alertLevel === "red"
                    ? "CRITICAL RESOURCE PRESSURE"
                    : (root.pulseData.alertLevel === "amber" ? "ELEVATED SYSTEM LOAD" : "SYSTEM OPERATING OPTIMALLY")
                  font.family: root.contentFontFamily
                  font.pixelSize: Style.font.caption
                  font.bold: true
                  color: root.pulseData.alertLevel === "red" ? "#ef4444" : (root.pulseData.alertLevel === "amber" ? "#f59e0b" : Color.accent)
                  anchors.verticalCenter: parent.verticalCenter
                }
              }

              Text {
                width: parent.width
                wrapMode: Text.WordWrap
                textFormat: Text.PlainText
                text: root.pulseData.alertReason
                font.family: root.contentFontFamily
                font.pixelSize: 11
                color: root.contentForeground
              }
            }
          }

          // --- 3. TAB CONTROLS (Overview, CPU & Cores, Memory, GPU & IO) ---
          Row {
            width: mainColumn.innerWidth
            spacing: Style.space(8)

            Repeater {
              model: [
                { id: 0, name: "Overview (1)", icon: "󰍛" },
                { id: 1, name: "CPU Cores (2)", icon: "󰘚" },
                { id: 2, name: "Memory (3)", icon: "󰘞" },
                { id: 3, name: "GPU & IO (4)", icon: "󰢹" }
              ]

              delegate: BorderSurface {
                required property var modelData
                readonly property bool isCurrent: root.activeTab === modelData.id

                implicitWidth: (mainColumn.innerWidth - (Style.space(8) * 3)) / 4
                implicitHeight: Style.space(32)
                radius: Style.cornerRadius
                color: isCurrent ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.22) : Style.hoverFillFor(root.contentForeground, root.contentForeground)
                borderSpec: Border.controlSpec(isCurrent ? "selected" : "normal", isCurrent ? Color.accent : Qt.darker(root.contentForeground, 2.5), Color.accent)

                Row {
                  anchors.centerIn: parent
                  spacing: Style.space(6)

                  Text {
                    textFormat: Text.PlainText
                    text: modelData.icon
                    font.family: root.contentFontFamily
                    font.pixelSize: Style.font.caption
                    color: isCurrent ? Color.accent : root.contentSubtle
                  }

                  Text {
                    textFormat: Text.PlainText
                    text: modelData.name
                    font.family: root.contentFontFamily
                    font.pixelSize: Style.font.caption
                    font.bold: isCurrent
                    color: isCurrent ? Color.accent : root.contentForeground
                  }
                }

                MouseArea {
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    root.activeTab = modelData.id
                    root.selectedIndex = 0
                  }
                }
              }
            }
          }

          // --- 4. GAUGES & METRICS GRID ---
          GridLayout {
            width: mainColumn.innerWidth
            columns: 2
            rowSpacing: Style.space(8)
            columnSpacing: Style.space(8)

            // CPU Gauge Box
            BorderSurface {
              Layout.fillWidth: true
              implicitHeight: Style.space(76)
              radius: Style.cornerRadius
              color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.04)
              borderSpec: Border.controlSpec("normal", Qt.darker(root.contentForeground, 2.5), Color.accent)

              Column {
                anchors.fill: parent
                anchors.margins: Style.space(8)
                spacing: Style.space(4)

                RowLayout {
                  width: parent.width
                  Text {
                    textFormat: Text.PlainText
                    text: "󰍛 CPU TOTAL"
                    font.family: root.contentFontFamily
                    font.pixelSize: 11
                    font.bold: true
                    color: root.contentSubtle
                  }
                  Item { Layout.fillWidth: true }
                  Text {
                    textFormat: Text.PlainText
                    text: (root.pulseData.cpu ? Math.round(root.pulseData.cpu.percent) : 0) + "% · " +
                          (root.pulseData.cpu ? Math.round(root.pulseData.cpu.temperature) : 0) + "°C"
                    font.family: "Monospace"
                    font.pixelSize: 11
                    font.bold: true
                    color: (root.pulseData.cpu && root.pulseData.cpu.percent > 90) ? "#ef4444" : ((root.pulseData.cpu && root.pulseData.cpu.percent > 75) ? "#f59e0b" : Color.accent)
                  }
                }

                Rectangle {
                  width: parent.width
                  height: Style.space(8)
                  radius: 4
                  color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.1)

                  Rectangle {
                    width: Math.max(4, parent.width * ((root.pulseData.cpu ? root.pulseData.cpu.percent : 0) / 100))
                    height: parent.height
                    radius: 4
                    color: (root.pulseData.cpu && root.pulseData.cpu.percent > 90)
                      ? "#ef4444"
                      : ((root.pulseData.cpu && root.pulseData.cpu.percent > 75) ? "#f59e0b" : Color.accent)
                  }
                }
              }
            }

            // RAM Gauge Box
            BorderSurface {
              Layout.fillWidth: true
              implicitHeight: Style.space(76)
              radius: Style.cornerRadius
              color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.04)
              borderSpec: Border.controlSpec("normal", Qt.darker(root.contentForeground, 2.5), Color.accent)

              Column {
                anchors.fill: parent
                anchors.margins: Style.space(8)
                spacing: Style.space(4)

                RowLayout {
                  width: parent.width
                  Text {
                    textFormat: Text.PlainText
                    text: "󰘞 RAM MEMORY"
                    font.family: root.contentFontFamily
                    font.pixelSize: 11
                    font.bold: true
                    color: root.contentSubtle
                  }
                  Item { Layout.fillWidth: true }
                  Text {
                    textFormat: Text.PlainText
                    text: (root.pulseData.memory ? root.formatBytes(root.pulseData.memory.usedBytes) : "0") + " / " +
                          (root.pulseData.memory ? root.formatBytes(root.pulseData.memory.totalBytes) : "0") +
                          " (" + (root.pulseData.memory ? Math.round(root.pulseData.memory.percentUsed) : 0) + "%)"
                    font.family: "Monospace"
                    font.pixelSize: 11
                    font.bold: true
                    color: (root.pulseData.memory && root.pulseData.memory.percentUsed > 90) ? "#ef4444" : ((root.pulseData.memory && root.pulseData.memory.percentUsed > 80) ? "#f59e0b" : Color.accent)
                  }
                }

                Rectangle {
                  width: parent.width
                  height: Style.space(8)
                  radius: 4
                  color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.1)

                  Rectangle {
                    width: Math.max(4, parent.width * ((root.pulseData.memory ? root.pulseData.memory.percentUsed : 0) / 100))
                    height: parent.height
                    radius: 4
                    color: (root.pulseData.memory && root.pulseData.memory.percentUsed > 90)
                      ? "#ef4444"
                      : ((root.pulseData.memory && root.pulseData.memory.percentUsed > 80) ? "#f59e0b" : Color.accent)
                  }
                }
              }
            }

            // GPU Box
            BorderSurface {
              Layout.fillWidth: true
              implicitHeight: Style.space(76)
              radius: Style.cornerRadius
              color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.04)
              borderSpec: Border.controlSpec("normal", Qt.darker(root.contentForeground, 2.5), Color.accent)

              Column {
                anchors.fill: parent
                anchors.margins: Style.space(8)
                spacing: Style.space(4)

                RowLayout {
                  width: parent.width
                  Text {
                    textFormat: Text.PlainText
                    text: "󰢹 GPU (" + (root.pulseData.gpu && root.pulseData.gpu.vendor ? root.pulseData.gpu.vendor : "Integrated") + ")"
                    font.family: root.contentFontFamily
                    font.pixelSize: 11
                    font.bold: true
                    color: root.contentSubtle
                  }
                  Item { Layout.fillWidth: true }
                  Text {
                    textFormat: Text.PlainText
                    text: (root.pulseData.gpu ? Math.round(root.pulseData.gpu.utilizationPercent) : 0) + "% · " +
                          (root.pulseData.gpu && root.pulseData.gpu.vramUsedBytes ? root.formatBytes(root.pulseData.gpu.vramUsedBytes) : "0 B")
                    font.family: "Monospace"
                    font.pixelSize: 11
                    font.bold: true
                    color: Color.accent
                  }
                }

                Rectangle {
                  width: parent.width
                  height: Style.space(8)
                  radius: 4
                  color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.1)

                  Rectangle {
                    width: Math.max(4, parent.width * ((root.pulseData.gpu ? root.pulseData.gpu.utilizationPercent : 0) / 100))
                    height: parent.height
                    radius: 4
                    color: Color.accent
                  }
                }
              }
            }

            // Disk & Network I/O Box (Contained, Zero Overflow)
            BorderSurface {
              Layout.fillWidth: true
              implicitHeight: Style.space(76)
              radius: Style.cornerRadius
              color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.04)
              borderSpec: Border.controlSpec("normal", Qt.darker(root.contentForeground, 2.5), Color.accent)

              Column {
                anchors.fill: parent
                anchors.margins: Style.space(8)
                spacing: Style.space(3)

                RowLayout {
                  width: parent.width
                  Text {
                    textFormat: Text.PlainText
                    text: "󰋊 DISK & NET I/O"
                    font.family: root.contentFontFamily
                    font.pixelSize: 11
                    font.bold: true
                    color: root.contentSubtle
                  }
                  Item { Layout.fillWidth: true }
                  Text {
                    textFormat: Text.PlainText
                    text: "Active"
                    font.family: "Monospace"
                    font.pixelSize: 10
                    color: Color.accent
                  }
                }

                Text {
                  width: parent.width
                  textFormat: Text.PlainText
                  text: "Disk: ▲ " + (root.pulseData.io ? root.formatKBs(root.pulseData.io.diskWriteKBs) : "0 B/s") +
                        "  ▼ " + (root.pulseData.io ? root.formatKBs(root.pulseData.io.diskReadKBs) : "0 B/s")
                  font.family: "Monospace"
                  font.pixelSize: 10
                  color: root.contentForeground
                  elide: Text.ElideRight
                }

                Text {
                  width: parent.width
                  textFormat: Text.PlainText
                  text: "Net:  ▲ " + (root.pulseData.io ? root.formatKBs(root.pulseData.io.netTxKBs) : "0 B/s") +
                        "  ▼ " + (root.pulseData.io ? root.formatKBs(root.pulseData.io.netRxKBs) : "0 B/s")
                  font.family: "Monospace"
                  font.pixelSize: 10
                  color: root.contentForeground
                  elide: Text.ElideRight
                }
              }
            }
          }

          // --- 5. PER-CORE CPU HEATMAP (Visible on Tab 1 or Overview) ---
          Column {
            width: mainColumn.innerWidth
            spacing: Style.space(6)
            visible: root.activeTab === 0 || root.activeTab === 1

            Text {
              textFormat: Text.PlainText
              text: "LOGICAL CORE UTILIZATION (" + (root.pulseData.cpu ? root.pulseData.cpu.coreCount : 0) + " THREADS)"
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
              color: root.contentSubtle
            }

            GridLayout {
              width: mainColumn.innerWidth
              columns: 4
              rowSpacing: Style.space(6)
              columnSpacing: Style.space(6)

              Repeater {
                model: root.pulseData.cpu && root.pulseData.cpu.cores ? root.pulseData.cpu.cores : []

                delegate: BorderSurface {
                  required property var modelData
                  Layout.fillWidth: true
                  implicitHeight: Style.space(32)
                  radius: Style.cornerRadius
                  color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.03)
                  borderSpec: Border.controlSpec("normal", Qt.darker(root.contentForeground, 2.8), Color.accent)

                  Column {
                    anchors.fill: parent
                    anchors.margins: Style.space(4)
                    spacing: 2

                    RowLayout {
                      width: parent.width
                      Text {
                        textFormat: Text.PlainText
                        text: modelData.core.toUpperCase()
                        font.family: "Monospace"
                        font.pixelSize: 9
                        font.bold: true
                        color: root.contentSubtle
                      }
                      Item { Layout.fillWidth: true }
                      Text {
                        textFormat: Text.PlainText
                        text: Math.round(modelData.percent) + "%"
                        font.family: "Monospace"
                        font.pixelSize: 9
                        font.bold: true
                        color: modelData.percent > 90 ? "#ef4444" : (modelData.percent > 75 ? "#f59e0b" : root.contentForeground)
                      }
                    }

                    Rectangle {
                      width: parent.width
                      height: 3
                      radius: 2
                      color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.1)

                      Rectangle {
                        width: Math.max(2, parent.width * (modelData.percent / 100))
                        height: parent.height
                        radius: 2
                        color: modelData.percent > 90 ? "#ef4444" : (modelData.percent > 75 ? "#f59e0b" : Color.accent)
                      }
                    }
                  }
                }
              }
            }
          }

          // --- 6. TOP RESOURCE CONSUMERS / PROCESS TRIAGE LIST ---
          Column {
            width: mainColumn.innerWidth
            spacing: Style.space(6)

            RowLayout {
              width: mainColumn.innerWidth
              Text {
                textFormat: Text.PlainText
                text: "TOP RESOURCE CONSUMING PROCESSES (" + (root.visibleProcesses ? root.visibleProcesses.length : 0) + ")"
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
                color: root.contentSubtle
              }
              Item { Layout.fillWidth: true }
              Text {
                textFormat: Text.PlainText
                text: "Press [k] to force kill · [x] to terminate"
                font.family: root.contentFontFamily
                font.pixelSize: 10
                color: root.contentSubtle
              }
            }

            Repeater {
              model: root.visibleProcesses ? root.visibleProcesses : []

              delegate: BorderSurface {
                id: procCard
                required property var modelData
                required property int index
                readonly property bool isSelected: root.selectedIndex === index

                width: mainColumn.innerWidth
                implicitHeight: Style.space(48)
                radius: Style.cornerRadius
                color: isSelected
                  ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.18)
                  : (procMouse.containsMouse
                      ? Style.hoverFillFor(root.contentForeground, root.contentForeground)
                      : Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.03))
                borderSpec: Border.controlSpec(
                  isSelected ? "selected" : "normal",
                  isSelected ? Color.accent : Qt.darker(root.contentForeground, 2.6),
                  Color.accent
                )

                RowLayout {
                  anchors.fill: parent
                  anchors.leftMargin: Style.space(12)
                  anchors.rightMargin: Style.space(12)
                  spacing: Style.space(10)

                  Text {
                    textFormat: Text.PlainText
                    text: modelData.icon || "󰒋"
                    font.family: root.contentFontFamily
                    font.pixelSize: Style.font.body
                    color: isSelected ? Color.accent : root.contentForeground
                    Layout.alignment: Qt.AlignVCenter
                  }

                  Column {
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 2

                    Row {
                      spacing: Style.space(6)
                      Text {
                        textFormat: Text.PlainText
                        text: modelData.name
                        font.family: root.contentFontFamily
                        font.pixelSize: Style.font.caption + 1
                        font.bold: true
                        color: root.contentForeground
                      }
                      Text {
                        textFormat: Text.PlainText
                        text: "PID " + modelData.pid
                        font.family: "Monospace"
                        font.pixelSize: 10
                        color: root.contentSubtle
                        anchors.verticalCenter: parent.verticalCenter
                      }
                    }

                    Text {
                      textFormat: Text.PlainText
                      text: "State: " + modelData.state + " · " + (modelData.isMine ? "User Process" : "System Process")
                      font.family: root.contentFontFamily
                      font.pixelSize: 10
                      color: root.contentSubtle
                    }
                  }

                  Item { Layout.fillWidth: true }

                  // Metrics Badges
                  Row {
                    spacing: Style.space(12)
                    Layout.alignment: Qt.AlignVCenter

                    // CPU Badge
                    Column {
                      spacing: 1
                      anchors.verticalCenter: parent.verticalCenter
                      Text {
                        textFormat: Text.PlainText
                        text: modelData.cpuPercent.toFixed(1) + "% CPU"
                        font.family: "Monospace"
                        font.pixelSize: 11
                        font.bold: true
                        color: modelData.cpuPercent > 75 ? "#ef4444" : (modelData.cpuPercent > 30 ? "#f59e0b" : Color.accent)
                        horizontalAlignment: Text.AlignRight
                      }
                    }

                    // RAM Badge
                    Column {
                      spacing: 1
                      anchors.verticalCenter: parent.verticalCenter
                      Text {
                        textFormat: Text.PlainText
                        text: root.formatBytes(modelData.rssBytes) + " (" + modelData.memPercent.toFixed(1) + "%)"
                        font.family: "Monospace"
                        font.pixelSize: 11
                        font.bold: true
                        color: root.contentForeground
                        horizontalAlignment: Text.AlignRight
                      }
                    }

                    // Terminate Button (SIGTERM)
                    BorderSurface {
                      implicitWidth: Style.space(56)
                      implicitHeight: Style.space(26)
                      radius: Style.cornerRadius
                      color: termMouse.containsMouse ? Qt.rgba(0.96, 0.62, 0.04, 0.25) : "transparent"
                      borderSpec: Border.controlSpec("normal", "#f59e0b", "#f59e0b")

                      Text {
                        anchors.centerIn: parent
                        textFormat: Text.PlainText
                        text: "Term"
                        font.family: root.contentFontFamily
                        font.pixelSize: 10
                        font.bold: true
                        color: "#f59e0b"
                      }

                      MouseArea {
                        id: termMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.killProcess(modelData.pid, false)
                      }
                    }

                    // Force Kill Button (SIGKILL)
                    BorderSurface {
                      implicitWidth: Style.space(52)
                      implicitHeight: Style.space(26)
                      radius: Style.cornerRadius
                      color: killMouse.containsMouse ? Qt.rgba(0.94, 0.27, 0.27, 0.25) : "transparent"
                      borderSpec: Border.controlSpec("normal", "#ef4444", "#ef4444")

                      Text {
                        anchors.centerIn: parent
                        textFormat: Text.PlainText
                        text: "Kill"
                        font.family: root.contentFontFamily
                        font.pixelSize: 10
                        font.bold: true
                        color: "#ef4444"
                      }

                      MouseArea {
                        id: killMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.killProcess(modelData.pid, true)
                      }
                    }
                  }
                }

                MouseArea {
                  id: procMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.selectedIndex = index
                }
              }
            }
          }
        }
      }
    }
  }
}
