import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.Commons
import qs.Ui
import "Model.js" as Model

// Podman on a keybind or a menu row, over whatever you were working in.
//
// The same four tabs and the same keys as the bar popup — it hosts the same
// PodmanView — but it does not need the widget to be in the bar, and it
// holds the keyboard for as long as it is up.
//
//   omarchy-shell shell toggle nixarchy.podman '{}'
//   omarchy-shell shell toggle nixarchy.podman '{"tab":"volumes"}'
Item {
  id: root

  // Injected by omarchy-shell when this plugin is summoned.
  property var shell: null
  property var manifest: null

  property bool opened: false

  // The output Hyprland has focused, resolved on the way in so the menu does
  // not follow the focus to another screen while it is being read.
  property var targetScreen: null

  property var settings: ({})

  // The view is drawn larger by picking larger tokens, never by a factor:
  // `large: true` moves each of its text roles up a rung of the shell's own
  // ladder. A scale: transform used to do this and magnified after layout, so
  // wrap and elide were computed at the wrong size and content below the list
  // was clipped unreachably (#30). nix flake check fails if either returns.
  // A constant slice of whatever screen it opens on, bounded so a small
  // display stays usable and a very wide one does not become a letterbox. The
  // bounds are theme units and grow with [font] base-size; the target is a
  // fraction of real screen pixels, so it is not theme-scaled twice (#22).
  // No longer divided by a magnification factor: the card is this width (#30).
  readonly property int viewWidth: {
    if (!root.targetScreen) return Style.space(986)
    var target = Math.round(root.targetScreen.width * 0.46)
    return Math.max(Style.space(800), Math.min(target, Style.space(1200)))
  }

  function focusedScreen() {
    var monitor = Hyprland.focusedMonitor
    var name = monitor ? String(monitor.name || "") : ""
    var screens = Quickshell.screens
    for (var i = 0; i < screens.length; i++)
      if (screens[i].name === name) return screens[i]
    return null
  }

  function readSettings() {
    var defaults = manifest && manifest.barWidget && manifest.barWidget.defaults
      ? manifest.barWidget.defaults : ({})
    var id = manifest && manifest.id ? manifest.id : "nixarchy.podman"
    return Model.settingsFor(shell ? shell.barConfig : null, id, defaults)
  }

  function tabFrom(payloadJson, fallback) {
    try {
      var payload = JSON.parse(String(payloadJson || "{}"))
      var key = payload && payload.tab ? String(payload.tab).toLowerCase() : ""
      if (Model.isTabKey(key)) return key
    } catch (e) {}
    var configured = String(fallback || "").toLowerCase()
    return Model.isTabKey(configured) ? configured : "containers"
  }

  // Plugin lifecycle: the host calls open(payloadJson) on summon and close()
  // on hide, and reads `opened` to decide what `toggle` means — so a close
  // from inside (Esc, a click away) needs nothing more than `opened = false`.
  // keepLoaded, so every open starts from a clean slate.
  function open(payloadJson) {
    root.settings = root.readSettings()
    root.targetScreen = root.focusedScreen()
    view.defaultTab = root.tabFrom(payloadJson, root.settings.defaultTab)
    view.reset()
    root.opened = true
  }

  function close() {
    view.dismiss()
    root.opened = false
  }

  function toggle() {
    if (root.opened) root.close()
    else root.open("{}")
  }

  // Polls only while open: a closed menu costs nothing, and a hidden one
  // stays loaded, so a stop or prune in flight is never killed by Esc.
  PodmanState {
    id: podmanState
    active: root.opened
    background: false
    settings: root.settings
  }

  PanelWindow {
    id: panel

    visible: root.opened
    screen: root.targetScreen
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore

    WlrLayershell.namespace: "nixarchy-podman-menu"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    onVisibleChanged: if (visible) Qt.callLater(function() { view.keyTarget.forceActiveFocus() })

    Rectangle {
      anchors.fill: parent
      color: Color.menu.scrim
    }

    // A click away closes, as every summoned surface here does. The card
    // swallows its own clicks so they never reach this.
    MouseArea {
      anchors.fill: parent
      onClicked: root.close()
    }

    BorderSurface {
      id: card
      width: Math.min(root.viewWidth + card.contentLeftInset + card.contentRightInset,
                      Math.round(panel.width * 0.9))
      height: Math.min(view.implicitHeight + card.contentTopInset + card.contentBottomInset,
                       Math.round(panel.height * 0.85))
      anchors.horizontalCenter: parent.horizontalCenter
      // A fixed top edge: the card grows downward, so switching to a tab with
      // more or fewer rows never moves the tabs or the filter (#13). 0.075 is
      // half of what the 0.85 height cap leaves, so the tallest card is centred.
      y: Math.max(Style.gapsOut, Math.round(panel.height * 0.075))
      color: Color.popups.background
      borderSpec: Border.surfaceSpec("popups", "border", Color.popups.border, Math.max(1, Style.space(2)))
      padding: Style.spacing.popupPadding
      radius: Style.cornerRadius

      MouseArea { anchors.fill: parent; onClicked: {} }

      Item {
        id: frame
        anchors.fill: parent
        anchors.topMargin: card.contentTopInset
        anchors.rightMargin: card.contentRightInset
        anchors.bottomMargin: card.contentBottomInset
        anchors.leftMargin: card.contentLeftInset
        clip: true

        PodmanView {
          id: view
          // Fills its frame and lays out at the size it is drawn, so wrapping
          // and eliding are computed against what the reader sees.
          anchors.fill: parent
          large: true
          podman: podmanState
          // The card may take 85% of the screen; the list gets what the rest of
          // the view leaves of that, so the footer is never clipped (#10).
          // What the card's 85% leaves after the chrome. No fixed ceiling and
          // no division: nothing is magnified past it any more, so the footer
          // cannot be pushed out of a clipped frame (#30).
          listMaxHeight: Math.max(Style.space(120),
            Math.floor(panel.height * 0.85 - card.contentTopInset - card.contentBottomInset)
            - view.chromeHeight)
          foreground: Color.foreground
          fontFamily: Style.font.family
          onCloseRequested: root.close()
          // No neighbouring bar panel to hand over to: Tab walks the tabs.
          onSwitchPanelRequested: function(direction) {
            podmanState.setTab(Model.shiftTab(podmanState.tab, direction))
          }
        }
      }
    }
  }
}
