import QtQuick
import Quickshell
import Quickshell.Io
import qs.Ui
import qs.Commons
import "Model.js" as Model

// The bar widget: a badge that keeps an eye on Podman, and a keyboard popup
// under it. The data lives in PodmanState and the popup in PodmanView, which
// the full-screen menu (Menu.qml) shares.
Panel {
  id: root

  moduleName: "nixarchy.podman"
  ipcTarget: "nixarchy.podman.bar"
  manageIpc: false

  readonly property int refreshIntervalSec: Math.max(5, Number(setting("refreshIntervalSec", 15)))
  readonly property bool showStopped: setting("showStopped", true) === true
  readonly property bool showStats: setting("showStats", true) === true
  readonly property bool showVolumeSizes: setting("showVolumeSizes", true) === true
  readonly property bool hideWhenEmpty: setting("hideWhenEmpty", false) === true
  // The setting reads "Containers"; the tab keys are lowercase.
  readonly property string defaultTab: {
    var key = String(setting("defaultTab", "containers")).toLowerCase()
    return Model.isTabKey(key) ? key : "containers"
  }

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  PodmanState {
    id: podmanState
    // The badge needs counts while the popup is closed.
    background: true
    active: root.opened
    settings: ({
      refreshIntervalSec: root.refreshIntervalSec,
      showStopped: root.showStopped,
      showStats: root.showStats,
      showVolumeSizes: root.showVolumeSizes
    })
  }

  onOpenedChanged: {
    if (opened) view.reset()
    else view.dismiss()
  }

  IpcHandler {
    target: root.ipcTarget

    function open(): void { root.open() }
    function close(): void { root.close() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function toggle(): void { root.toggle() }
    function refresh(): void { podmanState.refreshAll() }
    function stopAll(): void { podmanState.stopEverything() }
    function tab(name: string): void { podmanState.setTab(name) }
  }

  // ------------------------------------------------------------------- bar

  implicitWidth: button.visible ? button.implicitWidth : 0
  implicitHeight: button.implicitHeight

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: Model.Glyph.podman
    visible: !root.hideWhenEmpty || podmanState.counts.total > 0
    dimmed: podmanState.counts.running === 0
    active: podmanState.counts.alerting > 0 || podmanState.counts.running > 0
    useActiveColor: true
    activeColor: podmanState.counts.alerting > 0 ? Color.urgent : Color.accent
    tooltipText: "Podman · " + Model.summaryText(podmanState.containers, podmanState.daemonReachable)

    onPressed: function(b) {
      if (b === Qt.MiddleButton) podmanState.refresh()
      else root.toggle()
    }
  }

  // ----------------------------------------------------------------- panel

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: view.keyTarget
    contentWidth: panel.fittedContentWidth(Style.space(470))
    contentHeight: panel.fittedContentHeight(view.implicitHeight)

    PodmanView {
      id: view
      anchors.fill: parent
      podman: podmanState
      defaultTab: root.defaultTab
      foreground: root.foreground
      fontFamily: root.fontFamily
      onCloseRequested: root.close()
      onSwitchPanelRequested: function(direction) { root.switchPanel(direction) }
    }
  }
}
