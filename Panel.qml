import QtQuick
import Quickshell
import Quickshell.Io
import qs.Ui
import qs.Commons
import qs.Commons as Commons
import "Model.js" as Model

// The bar widget: a badge that keeps an eye on Podman, and a keyboard popup
// under it. The data lives in the PodmanState singleton and the popup in PodmanView, which
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

  readonly property color foreground: bar ? bar.foreground : Commons.Color.foreground
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  function pushSettings() {
    PodmanState.settings = {
      refreshIntervalSec: root.refreshIntervalSec,
      showStopped: root.showStopped,
      showStats: root.showStats,
      showVolumeSizes: root.showVolumeSizes
    }
  }

  onRefreshIntervalSecChanged: pushSettings()
  onShowStoppedChanged: pushSettings()
  onShowStatsChanged: pushSettings()
  onShowVolumeSizesChanged: pushSettings()

  // The badge needs counts while the popup is closed.
  Component.onCompleted: {
    pushSettings()
    PodmanState.acquire("bar")
  }
  Component.onDestruction: {
    PodmanState.release("bar")
    root.dropView()
  }

  // One lease per instance, so no path can release it twice.
  property bool holdsView: false
  function takeView() {
    if (root.holdsView) return
    root.holdsView = true
    PodmanState.acquire("view")
  }
  function dropView() {
    if (!root.holdsView) return
    root.holdsView = false
    PodmanState.release("view")
  }

  onOpenedChanged: {
    if (opened) {
      root.takeView()
      view.reset()
    } else {
      root.dropView()
      view.dismiss()
    }
  }

  IpcHandler {
    target: root.ipcTarget

    function open(): void { root.open() }
    function close(): void { root.close() }
    function toggle(): void { root.toggle() }
    function refresh(): void { PodmanState.refreshAll() }
    function stopAll(): void { PodmanState.stopEverything() }
    function tab(name: string): void { view.setTab(name) }
  }

  // ------------------------------------------------------------------- bar

  implicitWidth: button.visible ? button.implicitWidth : 0
  implicitHeight: button.implicitHeight

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: Model.Glyph.podman
    visible: !root.hideWhenEmpty || PodmanState.counts.total > 0
    dimmed: PodmanState.counts.running === 0
    active: PodmanState.counts.alerting > 0 || PodmanState.counts.running > 0
    useActiveColor: true
    activeColor: PodmanState.counts.alerting > 0 ? Commons.Color.urgent : Commons.Color.accent
    tooltipText: "Podman · " + Model.summaryText(PodmanState.containers, PodmanState.daemonReachable)

    onPressed: function(b) {
      if (b === Qt.MiddleButton) PodmanState.refresh()
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
      podman: PodmanState
      defaultTab: root.defaultTab
      foreground: root.foreground
      fontFamily: root.fontFamily
      onCloseRequested: root.close()
      onSwitchPanelRequested: function(direction) { root.switchPanel(direction) }
    }
  }
}
