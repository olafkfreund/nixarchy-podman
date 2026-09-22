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
