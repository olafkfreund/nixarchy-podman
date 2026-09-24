const { test, eq, ok, Model, make, imageRow, volumeRow, networkRow } = require("../harness.js")

// A prune names what it takes (#14). In #10 one keypress and one confirm
// removed five real containers behind a question that named none of them.

const containers = () => [
  make("web", "shop", "running"),
  make("db", "shop", "exited"),
  make("migrate", "shop", "exited"),
  make("job", "", "created"),
  make("held", "", "paused"),
  make("old1", "", "exited"),
  make("old2", "", "exited")
]

test("a container prune takes the stopped ones, never a running or paused one", () => {
  eq(Model.pruneTargets("containers", containers()).map(c => c.name), ["db", "migrate", "job", "old1", "old2"])
})

test("images, volumes and networks take what Podman says is unused", () => {
  const images = Model.normalizeImages([
    imageRow({ ID: "aaaaaaaaaaaa", Repository: "localhost/demo/tools", Tag: "latest", Containers: "0" }),
    imageRow({ ID: "bbbbbbbbbbbb", Repository: "localhost/demo/shop", Tag: "latest", Containers: "3" })
  ])
  eq(Model.pruneTargets("images", images).map(i => i.name), ["localhost/demo/tools:latest"])

  const volumes = Model.normalizeVolumes([volumeRow({ Name: "demo-cache" }), volumeRow({ Name: "demo-empty" })], ["demo-empty"])
  eq(Model.pruneTargets("volumes", volumes).map(v => v.name), ["demo-empty"])

  const networks = Model.normalizeNetworks([
    networkRow({ ID: "aaa1", Name: "podman", Labels: "" }),
    networkRow({ ID: "aaa2", Name: "demo-net2", Labels: "" })
  ], ["podman", "demo-net2"])
  eq(Model.pruneTargets("networks", networks).map(n => n.name), ["demo-net2"])
})

test("the question counts and names what goes, three names then the rest", () => {
  eq(Model.pruneMessage("containers", containers(), {}),
    "Remove 5 stopped containers: db, migrate, job and 2 more?")
  const images = Model.normalizeImages([
    imageRow({ ID: "aaaaaaaaaaaa", Repository: "localhost/demo/tools", Tag: "latest", Containers: "0" })
  ])
  eq(Model.pruneMessage("images", images, {}), "Remove 1 unused image: localhost/demo/tools:latest?")
})

test("a volume prune still warns that the data goes with it", () => {
  const one = Model.normalizeVolumes([volumeRow({ Name: "demo-empty" })], ["demo-empty"])
  eq(Model.pruneMessage("volumes", one, {}),
    "Remove 1 unused volume: demo-empty? Whatever is stored in it goes with it.")
  const two = Model.normalizeVolumes([volumeRow({ Name: "a" }), volumeRow({ Name: "b" })], ["a", "b"])
  ok(Model.pruneMessage("volumes", two, {}).endsWith("Whatever is stored in them goes with them."))
})

test("an active filter is called out, because a prune ignores it", () => {
  ok(Model.pruneMessage("containers", containers(), { filter: "web" })
    .endsWith(" The filter does not limit a prune."))
  ok(Model.pruneMessage("containers", containers(), { filter: "" }).indexOf("filter") === -1)
})

// No number while they are hidden: on razer, system df's total minus active
// said 2 where the prune takes 1, because a paused container is not active.
test("hidden stopped containers are named as hidden, never counted", () => {
  const running = [make("web", "shop", "running")]
  eq(Model.pruneMessage("containers", running, { showStopped: false }),
    "Remove every stopped container? They are hidden because Show stopped containers is off.")
})

test("nothing to name falls back to the plain question rather than claiming zero", () => {
  eq(Model.pruneMessage("images", [], {}), Model.pruneSpec("images").message)
  eq(Model.pruneMessage("networks", null, {}), Model.pruneSpec("networks").message)
})

// Stopping every running container at once asks the same kind of question a
// prune does (#19): one keystroke took them all down and named none of them.

test("stop-all is offered only while something is running", () => {
  eq(Model.stopAllSpec([]), null)
  eq(Model.stopAllSpec(null), null)
  eq(Model.stopAllSpec([make("db", "", "exited"), make("job", "", "created")]), null)
})

// A paused container is not up, so counts.running does not count it and the
// button is not offered for it either -- the same field governs both.
test("stop-all takes the running ones and leaves the rest alone", () => {
  const spec = Model.stopAllSpec(containers())
  eq(spec.args, ["podman", "stop", "web"])
  ok(spec.message.indexOf("db") === -1, "a stopped container is never named")
  ok(spec.message.indexOf("held") === -1, "nor a paused one")
})

test("stop-all and the button that offers it read the same field", () => {
  const paused = [make("held", "", "paused")]
  eq(Model.counts(paused).running, 0)
  eq(Model.stopAllSpec(paused), null)
})

test("one running container is named in the singular", () => {
  const spec = Model.stopAllSpec([make("web", "shop", "running")])
  eq(spec.args, ["podman", "stop", "web"])
  eq(spec.message, "Stop 1 running container: web?")
  eq(spec.label, "Stop all")
})

test("three are all named, with nothing left over", () => {
  const spec = Model.stopAllSpec([
    make("web", "", "running"), make("db", "", "running"), make("api", "", "running")
  ])
  eq(spec.message, "Stop 3 running containers: web, db, api?")
  ok(spec.message.indexOf("more") === -1)
})

test("past three, the rest are counted rather than listed", () => {
  const five = ["web", "db", "api", "cache", "queue"].map(n => make(n, "", "running"))
  const spec = Model.stopAllSpec(five)
  eq(spec.message, "Stop 5 running containers: web, db, api and 2 more?")
  eq(spec.args, ["podman", "stop", "web", "db", "api", "cache", "queue"])
})

test("a container with no name is named by its id", () => {
  const spec = Model.stopAllSpec([make("", "", "running", { ID: "7fd8eaad6bb6" })])
  ok(spec.message.indexOf("7fd8eaad6bb6") !== -1, spec.message)
})
