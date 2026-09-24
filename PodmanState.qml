import QtQuick
import Quickshell
import Quickshell.Io
import "Model.js" as Model

// Everything the panel knows about Podman, and every way it talks to it.
// Nothing here draws: the bar popup and the full-screen menu each hold one of
// these and hand it to a PodmanView.
//
// ponytail: one instance per surface, so both open at once query Podman
// twice. A shared service-kind plugin would fix that if it ever matters.
Item {
  id: root
  visible: false

  // {refreshIntervalSec, showStopped, showStats, showVolumeSizes}
  property var settings: ({})
  // The surface is open: poll fast, fetch stats and resources.
  property bool active: false
  // Keep the slow container poll running while closed (the bar badge).
  property bool background: false

  signal closeRequested()
  // Fired before `tab` changes, so the list can empty itself first.
  signal tabReset()

  readonly property int refreshIntervalSec: Math.max(5, Number(settings.refreshIntervalSec || 15))
  readonly property bool showStopped: settings.showStopped !== false
  readonly property bool showStats: settings.showStats !== false
  readonly property bool showVolumeSizes: settings.showVolumeSizes !== false

  // ------------------------------------------------------------------ state

  property string tab: "containers"

  property var containers: []
  property var images: []
  property var volumes: []
  property var networks: []
  property var volumeSizes: []
  property var usage: ({})
  property var stats: ({})

  property bool daemonReachable: true
  property bool permissionDenied: false
  property bool loading: false
  property bool everLoaded: false
  property string lastError: ""
  property string pendingId: ""

  readonly property bool busy: actionProcess.running

  // ------------------------------------------------------------- derivation

  // `podman system df -v` is the only source for what a volume costs, and it
  // arrives on its own schedule, so it is folded in here rather than stored.
  readonly property var sizedVolumes: Model.mergeVolumeUsage(volumes, showVolumeSizes ? volumeSizes : [])

  readonly property var items: {
    if (tab === "images") return images
    if (tab === "volumes") return sizedVolumes
    if (tab === "networks") return networks
    return containers
  }

  readonly property var counts: Model.counts(containers)
  readonly property var tabCounts: ({
    containers: containers.length,
    images: images.length,
    volumes: volumes.length,
    networks: networks.length
  })

  readonly property string usageLine: Model.usageText(usage, tab, items)
  readonly property bool prunable: Model.canPrune(tab, usage, items)

  // ------------------------------------------------------------------- tabs

  function setTab(key) {
    if (!Model.isTabKey(key) || key === root.tab) return
    // Empty the list before the rows underneath it change, so the new tab is
    // inserted into an empty model rather than diffed against the old one.
    root.tabReset()
    root.tab = key
    root.lastError = ""
    refreshResources()
    refreshUsage()
  }

  // --------------------------------------------------------------- refresh

  function refresh() {
    if (listProcess.running) return
    root.loading = true
    listProcess.running = true
  }

  function refreshStats() {
    if (!showStats || statsProcess.running || !active) return
    if (counts.running === 0) return
    statsProcess.running = true
  }

  // All three lists, not just the one on screen: the tab strip carries a count
  // for each of them, and a count that only appears once you visit the tab is
  // not a count, it is a surprise. Each of these is a single cheap query — the
  // expensive one is refreshVolumeSizes below, which stays lazy.
  function refreshResources() {
    if (!active) return
    if (!imagesProcess.running) imagesProcess.running = true
    if (!volumesProcess.running) volumesProcess.running = true
    if (!networksProcess.running) networksProcess.running = true
    if (root.tab === "volumes") refreshVolumeSizes()
  }

  function refreshUsage() {
    if (!active || usageProcess.running) return
    usageProcess.running = true
  }

  // Deliberately off every timer. Walking every volume on disk takes a second
  // or two, so it runs when the tab is opened and after something has
  // changed, and never once a second in the background.
  function refreshVolumeSizes() {
    if (!showVolumeSizes || !active || volumeSizeProcess.running) return
    volumeSizeProcess.running = true
  }

  function refreshAll() {
    refresh()
    refreshStats()
    refreshResources()
    refreshUsage()
  }

  Timer {
    interval: root.refreshIntervalSec * 1000
    running: root.background || root.active
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  Timer {
    interval: 3000
    running: root.active
    repeat: true
    onTriggered: root.refresh()
  }

  Timer {
    interval: 5000
    running: root.active && root.showStats
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refreshStats()
  }

  // Images, volumes and networks change when someone changes them, not on
  // their own, so they get a far lazier beat than the container list.
  Timer {
    interval: 10000
    running: root.active
    repeat: true
    onTriggered: { root.refreshResources(); root.refreshUsage() }
  }

  onActiveChanged: {
    if (active) refreshAll()
    else stats = ({})
  }

  // --------------------------------------------------------------- actions

  function runCommand(command) {
    if (!command || actionProcess.running) return
    root.lastError = ""
    actionProcess.command = command
    actionProcess.running = true
  }

  function runAction(ids, verb) {
    if (!ids || ids.length === 0 || actionProcess.running) return
    root.pendingId = ids.length === 1 ? ids[0] : ""
    runCommand(["podman", verb].concat(ids))
  }

  function toggleContainer(container) {
    if (!container) return
    runAction([container.id], container.up ? "stop" : "start")
  }

  function restartContainer(container) {
    if (container && container.up) runAction([container.id], "restart")
  }

  function stopEverything() {
    var ids = []
    for (var i = 0; i < containers.length; i++) {
      if (containers[i].up) ids.push(containers[i].id)
    }
    runAction(ids, "stop")
  }

  // ----------------------------------------------------------- side effects

  function copyText(value) {
    if (!value || copyProcess.running) return
    copyProcess.command = ["wl-copy", "--trim-newline", String(value)]
    copyProcess.running = true
  }

  function viewLogs(id) {
    if (!Model.isContainerId(id)) return
    root.closeRequested()
    // The terminal is held open by the shell, not by a launcher flag: not
    // every omarchy-launch-tui out there understands --hold.
    Quickshell.execDetached(["omarchy-launch-tui", "--app-id=org.omarchy.podman-logs",
      "sh", "-c",
      "podman logs --tail 200 --follow \"$1\"; printf '\\n[logs ended — press enter to close]'; read -r _",
      "sh", id])
  }

  function openShell(id) {
    if (!Model.isContainerId(id)) return
    root.closeRequested()
    Quickshell.execDetached(["omarchy-launch-tui", "--app-id=org.omarchy.podman-shell",
      "sh", "-c",
      "podman exec -it \"$1\" sh -c 'command -v bash >/dev/null 2>&1 && exec bash || exec sh'",
      "sh", id])
  }

  function launchTui() {
    root.closeRequested()
    Quickshell.execDetached(["omarchy-launch-or-focus-tui", "podman-tui"])
  }

  // -------------------------------------------------------------- processes
  //
  // Every listing goes through a custom Go template rather than `{{json .}}`:
  // Podman's own JSON dump uses field names and shapes (arrays for Names and
  // Ports, an object for Labels, health status crammed into the Status field)
  // that differ tab by tab and version by version. Naming every field
  // explicitly gets back exactly the flattened, Docker-shaped strings
  // Model.js expects — "key=value,key=value" labels, "0.0.0.0:80->80/tcp"
  // ports, "Up 2 hours (healthy)" status — so one parser works for both.

  readonly property string containerFormat:
    "{\"ID\":{{json .ID}},\"Names\":{{json .Names}},\"Image\":{{json .Image}}," +
    "\"State\":{{json .State}},\"Status\":{{json .Status}},\"Labels\":{{json .Labels}}," +
    "\"Ports\":{{json .Ports}}}"

  Process {
    id: listProcess
    command: root.showStopped
      ? ["sh", "-c", "set -o pipefail; podman ps --all --format '" + root.containerFormat + "' | head -c 1M"]
      : ["sh", "-c", "set -o pipefail; podman ps --format '" + root.containerFormat + "' | head -c 1M"]
    stdout: StdioCollector { id: listOut; waitForEnd: true }
    stderr: StdioCollector { id: listErr; waitForEnd: true }

    onExited: function(code) {
      root.loading = false
      root.everLoaded = true

      if (!Model.commandSucceeded(code)) {
        var message = String(listErr.text || "")
        root.daemonReachable = false
        root.permissionDenied = /permission denied/i.test(message)
        root.containers = []
        root.images = []
        root.volumes = []
        root.networks = []
        root.volumeSizes = []
        root.usage = ({})
        root.stats = ({})
        return
      }

      root.daemonReachable = true
      root.permissionDenied = false

      root.containers = Model.normalizeContainers(Model.parseJsonLines(listOut.text))
      root.refreshStats()
    }
  }

  Process {
    id: statsProcess
    command: ["sh", "-c",
      "set -o pipefail; podman stats --no-stream --format '{\"ID\":{{json .ID}},\"CPUPerc\":{{json .CPUPerc}}," +
      "\"MemUsage\":{{json .MemUsage}},\"MemPerc\":{{json .MemPerc}}}' | head -c 1M"]
    stdout: StdioCollector { id: statsOut; waitForEnd: true }

    onExited: function(code) {
      if (Model.commandSucceeded(code)) root.stats = Model.indexStats(Model.parseJsonLines(statsOut.text))
    }
  }

  Process {
    id: imagesProcess
    command: ["sh", "-c",
      "set -o pipefail; podman images --format '{\"ID\":{{json .ID}},\"Repository\":{{json .Repository}}," +
      "\"Tag\":{{json .Tag}},\"Size\":{{json .Size}},\"CreatedSince\":{{json .CreatedSince}}," +
      "\"Containers\":{{json .Containers}}}' | head -c 1M"]
    stdout: StdioCollector { id: imagesOut; waitForEnd: true }

    onExited: function(code) {
      if (Model.commandSucceeded(code)) root.images = Model.normalizeImages(Model.parseJsonLines(imagesOut.text))
    }
  }

  // One shell, two questions: the whole list, then the names `prune` would
  // take. Podman decides what counts as unused, so the panel never has to.
  Process {
    id: volumesProcess
    command: ["sh", "-c",
      "set -o pipefail; { podman volume ls --format '{\"Name\":{{json .Name}},\"Driver\":{{json .Driver}}," +
      "\"Mountpoint\":{{json .Mountpoint}},\"Labels\":{{json .Labels}}}' || exit 1; echo '#UNUSED'; " +
      "podman volume ls --filter dangling=true --format '{{.Name}}'; } | head -c 1M"]
    stdout: StdioCollector { id: volumesOut; waitForEnd: true }

    onExited: function(code) {
      if (!Model.commandSucceeded(code)) return
      var parsed = Model.parseTagged(volumesOut.text)
      root.volumes = Model.normalizeVolumes(parsed.records, parsed.unused)
    }
  }

  Process {
    id: networksProcess
    command: ["sh", "-c",
      "set -o pipefail; { podman network ls --format '{\"ID\":{{json .ID}},\"Name\":{{json .Name}}," +
      "\"Driver\":{{json .Driver}},\"Internal\":{{json .Internal}},\"Labels\":{{json .Labels}}}' " +
      "|| exit 1; echo '#UNUSED'; podman network ls --filter dangling=true --format '{{.Name}}'; } | head -c 1M"]
    stdout: StdioCollector { id: networksOut; waitForEnd: true }

    onExited: function(code) {
      if (!Model.commandSucceeded(code)) return
      var parsed = Model.parseTagged(networksOut.text)
      root.networks = Model.normalizeNetworks(parsed.records, parsed.unused)
    }
  }

  Process {
    id: usageProcess
    command: ["sh", "-c", "set -o pipefail; podman system df --format '{{json .}}' | head -c 64k"]
    stdout: StdioCollector { id: usageOut; waitForEnd: true }

    onExited: function(code) {
      if (Model.commandSucceeded(code)) root.usage = Model.indexUsage(Model.parseJsonLines(usageOut.text))
    }
  }

  // `system df -v` refuses to combine with `--format`, so this reads the
  // plain "Local Volumes space usage:" table instead of JSON — see
  // Model.parseVolumeSizeTable for how that text turns back into records.
  Process {
    id: volumeSizeProcess
    command: ["sh", "-c",
      "set -o pipefail; podman system df -v 2>/dev/null | awk '/^Local Volumes space usage:/{f=1;next} " +
      "f&&/^VOLUME NAME/{g=1;next} g&&NF==0{g=0} g' | head -c 1M"]
    stdout: StdioCollector { id: volumeSizeOut; waitForEnd: true }

    onExited: function(code) {
      if (Model.commandSucceeded(code) && root.showVolumeSizes) root.volumeSizes = Model.parseVolumeSizeTable(volumeSizeOut.text)
    }
  }

  Process {
    id: actionProcess
    stderr: StdioCollector { id: actionErr; waitForEnd: true }

    onExited: function(code) {
      root.pendingId = ""
      // Podman refuses plenty of reasonable-looking requests — a volume still
      // mounted, an image still referenced — and its reason is the only
      // useful thing the panel can say, so it says it verbatim.
      // Not commandSucceeded: this is plain argv with no head, so there is no
      // pipeline to truncate and any non-zero code is a real refusal (#21).
      if (code !== 0) root.lastError = Model.errorText(actionErr.text)
      // A closed menu stays loaded; it must not poll just because an action ended.
      if (root.active || root.background) root.refresh()
      root.refreshResources()
      root.refreshUsage()
      if (root.tab === "volumes") root.volumeSizes = []
    }
  }

  Process { id: copyProcess }
}
