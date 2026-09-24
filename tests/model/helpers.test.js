const { test, eq, ok, Model } = require("../harness.js")

// itemKey is the image-tag-collision fix (#6): an image with several tags
// needs a rowId distinct from its id, or the list leaves stale duplicate rows.
test("itemKey prefers rowId, and an empty rowId is still a rowId", () => {
  eq(Model.itemKey({ id: "abc", rowId: "abc:latest" }), "abc:latest")
  eq(Model.itemKey({ id: "abc" }), "abc")
  // The one that matters: itemKey tests `!== undefined`, not truthiness, so a
  // simplification to `item.rowId || item.id` would silently break this.
  eq(Model.itemKey({ id: "abc", rowId: "" }), "")
})

test("copyTooltip names the right thing on every tab", () => {
  eq(Model.copyTooltip("volumes"), "Copy the mount path")
  eq(Model.copyTooltip("networks"), "Copy the network id")
  eq(Model.copyTooltip("images"), "Copy the image id")
  eq(Model.copyTooltip("containers"), "Copy the container id")
})

// The shapes below were read off `podman images --format '{{json .Labels}}'`
// and `podman network ls` on a real machine, not invented.
test("labelMap reads the object form podman emits for an image", () => {
  const real = {
    "com.github.containers.toolbox": "true",
    "io.buildah.version": "1.43.2",
    "org.opencontainers.image.title": "fedora-toolbox"
  }
  const m = Model.labelMap(real)
  eq(m["com.github.containers.toolbox"], "true")
  eq(m["org.opencontainers.image.title"], "fedora-toolbox")
  eq(Object.keys(m).length, 3)
})

test("labelMap survives what podman sends when there are no labels", () => {
  eq(Object.keys(Model.labelMap(null)).length, 0)
  eq(Object.keys(Model.labelMap("")).length, 0)
  eq(Object.keys(Model.labelMap(undefined)).length, 0)
})

test("labelMap still reads the comma-separated string form", () => {
  const m = Model.labelMap("com.docker.compose.project=shop,role=web")
  eq(m["com.docker.compose.project"], "shop")
  eq(m.role, "web")
})

// The object-vs-string branch keys off `length === undefined`, which is how it
// tells a plain object from a string or a Qt sequence wrapper (AGENTS.md).
test("labelMap decides by shape, not by truthiness", () => {
  const sequenceish = { length: 2, "0": "a=1", "1": "b=2" }
  const m = Model.labelMap(sequenceish)
  ok(m["com.docker.compose.project"] === undefined, "not read as an object")
})
