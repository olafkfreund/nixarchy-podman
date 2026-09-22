import QtQuick
import QtQuick.Controls
import Quickshell
import qs.Ui
import qs.Commons
import "Model.js" as Model

// The four tabs, the cursor, the filter, the questions — everything you can
// press. It draws whatever PodmanState it is handed, so the bar popup and the
// full-screen menu share every key and every row.
FocusScope {
  id: root

  required property var podman
  property string defaultTab: "containers"
  property color foreground: Color.foreground
  property string fontFamily: Style.font.family
  readonly property color dim: Qt.darker(foreground, 1.5)

  // KeyboardPanel focuses this directly: handing it the FocusScope instead
  // would restore whichever child held focus last, stale filter field included.
  readonly property alias keyTarget: keyCatcher

  // How tall the list may grow before it scrolls. The full-screen menu lowers
  // it so the footer still fits on the card (#10); the popup keeps the default.
  property int listMaxHeight: Style.space(560)
  // Everything but the list: what the menu subtracts from the room it has.
  // Summed from the other children rather than taken as column minus list,
  // which would read the list's height and loop back into it (#10). The
  // Column spaces the six always-visible children plus the optional two.
  readonly property int chromeHeight: hero.implicitHeight + tabStrip.implicitHeight +
    filterField.implicitHeight + separator.implicitHeight + footer.implicitHeight +
    (emptyState.visible ? emptyState.implicitHeight : 0) +
    (errorLine.visible ? errorLine.implicitHeight : 0) +
    Style.spacing.panelGap * (5 + (emptyState.visible ? 1 : 0) + (errorLine.visible ? 1 : 0))

  implicitHeight: column.implicitHeight

  signal closeRequested()
  signal switchPanelRequested(int direction)

  // ------------------------------------------------------------------ state

  property string filterText: ""

  property var pendingCommand: null
  property string confirmMessage: ""
  property string confirmLabel: "Remove"
  property bool confirmOpen: false
  property bool helpOpen: false

  property int cursorIndex: 0
  property bool cursorActive: false
  property bool cursorFromKeyboard: false

  // ------------------------------------------------------------- derivation

  readonly property var visibleItems: root.podman.tab === "containers"
    ? Model.filterContainers(root.podman.containers, filterText)
    : Model.filterResources(root.podman.items, filterText)
  readonly property var sections: root.podman.tab === "containers"
    ? Model.sectionsFor(visibleItems)
    : Model.usageSectionsFor(visibleItems)
  readonly property var rows: Model.rowsForSections(sections, root.podman.tab)

  readonly property var cursorRow: cursorIndex >= 0 && cursorIndex < rows.length ? rows[cursorIndex] : null
  readonly property var cursorItem: cursorRow ? Model.itemById(root.podman.items, cursorRow.id) : null

  onRowsChanged: root.cursorIndex = Model.clampCursor(root.cursorIndex, rows.length)

  Connections {
    target: root.podman
    function onTabReset() {
      list.clear()
      root.filterText = ""
      root.cursorIndex = 0
      root.cursorActive = false
      filterField.text = ""
    }
    function onCloseRequested() { root.closeRequested() }
  }

  // ------------------------------------------------------------ lifecycle

  // Called every time the surface opens: fresh cursor, empty filter, the
  // configured tab, and the keyboard on the key catcher rather than wherever
  // it was left.
  function reset() {
    cursorActive = false
    cursorIndex = 0
    filterText = ""
    filterField.text = ""
    filterField.focus = false
    root.podman.lastError = ""
    helpOpen = false
    closeConfirm()
    root.podman.setTab(defaultTab)
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  // Called when the surface closes.
  function dismiss() {
    helpOpen = false
    closeConfirm()
  }

  // --------------------------------------------------------------- actions

  function toggleSection(sectionKey) {
    var action = Model.sectionAction(Model.sectionByKey(sections, sectionKey))
    if (action) root.podman.runAction(action.ids, action.verb)
  }

  // Every row's buttons come from Model.actionsFor, so this is the one place
  // a verb turns into something that happens.
  function dispatch(kind, id, verb) {
    var item = Model.itemById(root.podman.items, id)
    if (verb === "copy") { root.podman.copyText(Model.copyValue(kind, item)); return }
    if (verb === "logs") { root.podman.viewLogs(id); return }
    if (verb === "shell") { root.podman.openShell(id); return }
    if (verb === "remove") { askRemove(kind, id); return }
    if (verb === "start" || verb === "stop" || verb === "restart") root.podman.runAction([id], verb)
  }

  function activateRow() {
    if (!cursorActive || !cursorRow) return
    if (root.podman.tab === "containers") root.podman.toggleContainer(cursorItem)
    else dispatch(root.podman.tab, cursorRow.id, "copy")
  }

  // ---------------------------------------------------------- confirmation

  function ask(command, message, label) {
    if (!command) return
    root.pendingCommand = command
    root.confirmMessage = message
    root.confirmLabel = label
    // Cancel is the default answer to every question asked here.
    confirmDialog.selectedIndex = 0
    root.confirmOpen = true
  }

  function askRemove(kind, id) {
    var item = Model.itemById(root.podman.items, id)
    var command = Model.removeCommand(kind, id)
    if (!item || !command) return
    ask(command, Model.removeMessage(kind, item), "Remove")
  }

  function askPrune() {
    var spec = Model.pruneSpec(root.podman.tab)
    if (!spec || !root.podman.prunable) return
    // Named from the unfiltered list: a prune ignores the filter (#14).
    var list = root.podman.tab === "containers" ? root.podman.containers : root.podman.items
    ask(spec.args, Model.pruneMessage(root.podman.tab, list, {
      usage: root.podman.usage,
      showStopped: root.podman.showStopped,
      filter: root.filterText
    }), spec.label)
  }

  function closeConfirm() {
    root.confirmOpen = false
    root.pendingCommand = null
  }

  function confirmAccepted() {
    var command = root.pendingCommand
    closeConfirm()
    root.podman.runCommand(command)
  }

  // -------------------------------------------------------------- keyboard

  function moveCursor(delta) {
    // Up from the first row lands in the filter, the mirror of the Down key
    // that walks out of it. Between the two, the whole panel is reachable
    // without ever touching the mouse.
    if (delta < 0 && cursorActive && cursorIndex === 0) {
      filterField.forceActiveFocus()
      cursorActive = false
      return
    }
    if (rows.length === 0) {
      filterField.forceActiveFocus()
      return
    }
    cursorIndex = Model.nextCursor(cursorActive, cursorIndex, delta, rows.length).index
    cursorActive = true
    cursorFromKeyboard = true
  }

  function setCursor(index) {
    cursorActive = true
    cursorFromKeyboard = false
    cursorIndex = Model.clampCursor(index, rows.length)
  }

  function handleTextKey(key) {
    if (key === "?") { root.helpOpen = !root.helpOpen; return }
    if (root.helpOpen) { root.helpOpen = false; return }
    if (key === "/") { filterField.forceActiveFocus(); return }

    var digit = "1234".indexOf(key)
    if (digit !== -1) { root.podman.setTab(Model.tabKeyAt(digit)); return }

    if (key === "u") { root.podman.refreshAll(); return }
    if (key === "d") { root.podman.launchTui(); return }
    if (key === "p") { askPrune(); return }

    if (!cursorActive || !cursorRow) return
    if (key === "c") { dispatch(root.podman.tab, cursorRow.id, "copy"); return }

    if (root.podman.tab !== "containers" || !cursorItem) return
    if (key === "o") root.podman.viewLogs(cursorItem.id)
    else if (key === "s") { if (cursorItem.up) root.podman.openShell(cursorItem.id) }
    else if (key === "r") root.podman.restartContainer(cursorItem)
    else if (key === "n") root.podman.copyText(cursorItem.name)
  }

  function removeAtCursor() {
    if (!cursorActive || !cursorRow) return
    if (!Model.allowsVerb(cursorRow, "remove")) return
    askRemove(root.podman.tab, cursorRow.id)
  }

  // ----------------------------------------------------------------- view

  // The confirmation lives outside PanelKeyCatcher on purpose: the catcher
  // goes `blocked` while a question is open, so the unhandled key bubbles
  // out to here and the dialog answers it.
  Item {
    id: keyRoot
    anchors.fill: parent

    Keys.onPressed: function(event) {
      if (!root.confirmOpen) return
      if (confirmDialog.handleKey(event)) event.accepted = true
    }

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      blocked: filterField.activeFocus || root.confirmOpen

      onMoveRequested: function(dx, dy) {
        if (root.helpOpen) return
        if (dy !== 0) root.moveCursor(dy)
        else if (dx !== 0) root.podman.setTab(Model.shiftTab(root.podman.tab, dx))
      }
      onActivateRequested: if (root.helpOpen) root.helpOpen = false; else root.activateRow()
      onDeleteRequested: if (!root.helpOpen) root.removeAtCursor()
      onCloseRequested: {
        if (root.helpOpen) root.helpOpen = false
        else root.closeRequested()
      }
      onTabRequested: function(direction) { root.switchPanelRequested(direction) }
      onTextKey: function(text) { root.handleTextKey(text) }

      Column {
        id: column
        anchors.fill: parent
        spacing: Style.spacing.panelGap

        PanelHero {
          id: hero
          title: "Podman"
          meta: Model.summaryText(root.podman.containers, root.podman.daemonReachable)
          foreground: root.foreground
          fontFamily: root.fontFamily
          iconOpacity: root.podman.counts.running > 0 ? 1.0 : 0.5

          iconComponent: Text {
            text: Model.Glyph.podman
            color: root.podman.counts.alerting > 0 ? Color.urgent : root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.display
          }

          trailingControl: Row {
            spacing: Style.spacing.sm

            PanelActionButton {
              iconText: Model.Glyph.keyboard
              tooltipText: "Keyboard shortcuts  (?)"
              foreground: root.foreground
              fontFamily: root.fontFamily
              onClicked: root.helpOpen = !root.helpOpen
            }

            PanelActionButton {
              iconText: Model.Glyph.refresh
              tooltipText: "Refresh  (u)"
              foreground: root.foreground
              fontFamily: root.fontFamily
              onClicked: root.podman.refreshAll()

              RotationAnimation on rotation {
                running: root.podman.loading
                from: 0
                to: 360
                duration: 900
                loops: Animation.Infinite
                onRunningChanged: if (!running) rotation = 0
              }
            }

            PanelActionButton {
              visible: root.podman.tab === "containers" && root.podman.counts.running > 0
              iconText: Model.Glyph.stop
              tooltipText: "Stop every running container"
              foreground: root.foreground
              hoverColor: Color.urgent
              fontFamily: root.fontFamily
              onClicked: root.podman.stopEverything()
            }
          }
        }

        TabStrip {
          id: tabStrip
          width: parent.width
          current: root.podman.tab
          counts: root.podman.tabCounts
          alerting: root.podman.counts.alerting > 0
          foreground: root.foreground
          fontFamily: root.fontFamily
          onSelected: function(key) { root.podman.setTab(key) }
        }

        TextField {
          id: filterField
          width: parent.width
          foreground: root.foreground
          // The operator stays on the first line: a line that ends on a
          // complete expression gets a semicolon inserted for it, and the
          // rest of the binding is quietly dropped.
          placeholderText: Model.Glyph.search + "  Filter " + Model.tabNoun(root.podman.tab) + "s" +
            (activeFocus ? "" : "   /")
          onTextChanged: {
            root.filterText = text
            root.cursorIndex = 0
          }
          Keys.onEscapePressed: {
            if (text.length > 0) text = ""
            else keyCatcher.forceActiveFocus()
          }
          Keys.onDownPressed: {
            keyCatcher.forceActiveFocus()
            root.moveCursor(0)
          }
        }

        ResourceList {
          id: list
          width: parent.width
          maxHeight: root.listMaxHeight
          rows: root.rows
          kind: root.podman.tab
          stats: root.podman.stats
          showStats: root.podman.showStats
          busy: root.podman.busy
          pendingId: root.podman.pendingId
          cursorIndex: root.cursorIndex
          cursorActive: root.cursorActive
          cursorFromKeyboard: root.cursorFromKeyboard
          foreground: root.foreground
          fontFamily: root.fontFamily

          onActionRequested: function(kind, id, verb) { root.dispatch(kind, id, verb) }
          onRowClicked: function(id) { root.dispatch(root.podman.tab, id, "copy") }
          onSectionToggled: function(key) { root.toggleSection(key) }
          onCursorRequested: function(index) { root.setCursor(index) }
        }

        Column {
          id: emptyState
          visible: list.count === 0
          width: parent.width
          spacing: Style.spacing.sm
          topPadding: Style.spacing.lg
          bottomPadding: Style.spacing.lg

          Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: Model.emptyText(root.podman.tab, {
              everLoaded: root.podman.everLoaded,
              daemonReachable: root.podman.daemonReachable,
              permissionDenied: root.podman.permissionDenied,
              filtered: root.podman.items.length > 0,
              showStopped: root.podman.showStopped
            })
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
            wrapMode: Text.WordWrap
          }

          Text {
            visible: text !== ""
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: {
              if (root.podman.permissionDenied) return "Rootless Podman needs a subuid/subgid range for your user.\nRun  podman info  to see what it found wrong."
              if (!root.podman.daemonReachable && root.podman.everLoaded) return "Run  podman info  to see what it found wrong."
              return ""
            }
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            wrapMode: Text.WordWrap
            lineHeight: 1.3
          }
        }

        // Podman's refusals are more useful than anything the panel could
        // invent, so they get their own line until the user dismisses them.
        Item {
          id: errorLine
          width: parent.width
          visible: root.podman.lastError !== ""
          implicitHeight: visible ? Math.max(errorText.implicitHeight, errorDismiss.height) : 0
          height: implicitHeight

          Text {
            id: errorGlyph
            anchors.left: parent.left
            anchors.top: parent.top
            text: Model.Glyph.alert
            textFormat: Text.PlainText
            color: Color.urgent
            font.family: root.fontFamily
            font.pixelSize: Style.font.iconSmall
          }

          Text {
            id: errorText
            anchors.left: errorGlyph.right
            anchors.leftMargin: Style.spacing.md
            anchors.right: errorDismiss.left
            anchors.rightMargin: Style.spacing.md
            anchors.top: parent.top
            text: root.podman.lastError
            textFormat: Text.PlainText
            color: Color.urgent
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            wrapMode: Text.WordWrap
          }

          PanelActionButton {
            id: errorDismiss
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.topMargin: -Style.spacing.xs
            iconText: Model.Glyph.close
            tooltipText: "Dismiss"
            foreground: root.foreground
            fontFamily: root.fontFamily
            fontSize: Style.font.iconSmall
            size: Style.space(20)
            onClicked: root.podman.lastError = ""
          }
        }

        PanelSeparator { id: separator; foreground: root.foreground }

        Item {
          id: footer
          width: parent.width
          implicitHeight: Math.max(usageRow.implicitHeight, pruneButton.implicitHeight)
          height: implicitHeight

          Row {
            id: usageRow
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            anchors.right: pruneButton.left
            anchors.rightMargin: Style.spacing.md
            spacing: Style.spacing.md

            Text {
              anchors.verticalCenter: parent.verticalCenter
              text: Model.Glyph.disk
              textFormat: Text.PlainText
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.iconSmall
            }

            Text {
              anchors.verticalCenter: parent.verticalCenter
              width: Math.min(implicitWidth, usageRow.width - Style.space(20))
              text: root.podman.usageLine
              textFormat: Text.PlainText
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              elide: Text.ElideRight
            }
          }

          Button {
            id: pruneButton
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            enabled: root.podman.prunable && !root.podman.busy
            bordered: true
            iconText: Model.Glyph.prune
            iconSize: Style.font.iconSmall
            text: Model.pruneSpec(root.podman.tab) ? Model.pruneSpec(root.podman.tab).label : ""
            tooltipText: "Reclaim what nothing is using  (p)"
            foreground: root.podman.prunable ? root.foreground : root.dim
            fontFamily: root.fontFamily
            fontSize: Style.font.caption
            verticalPadding: Style.spacing.xs
            opacity: root.podman.prunable ? 1.0 : 0.5
            onClicked: root.askPrune()
          }
        }
      }
    }

    ShortcutSheet {
      id: helpSheet
      anchors.fill: parent
      z: 5
      opened: root.helpOpen
      foreground: root.foreground
      background: Color.popups.background
      fontFamily: root.fontFamily
      onDismissed: root.helpOpen = false
    }

    ConfirmDialog {
      id: confirmDialog
      anchors.fill: parent
      z: 10
      opened: root.confirmOpen
      message: root.confirmMessage
      confirmText: root.confirmLabel
      background: Color.popups.background
      foreground: root.foreground
      fontFamily: root.fontFamily
      onCanceled: root.closeConfirm()
      onConfirmed: root.confirmAccepted()
    }
  }
}
