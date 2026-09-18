const { test, eq, ok, Model, imageRow } = require("../harness.js")

// Issue #6: one image under several tags. Podman lists it once per tag, all
// with the same image id.
const ID = "aaaaaaaaaaaa"
const shop = imageRow({ ID: ID, Repository: "localhost/demo/shop", Tag: "latest", Containers: "2" })
const alpine = imageRow({ ID: ID, Repository: "docker.io/library/alpine", Tag: "3", Containers: "2" })
const tools = imageRow({ ID: "bbbbbbbbbbbb", Repository: "localhost/demo/tools", Tag: "latest", Containers: "0" })
const dangling = imageRow({ ID: "cccccccccccc", Repository: "<none>", Tag: "<none>" })

const images = () => Model.normalizeImages([shop, alpine, tools, dangling])
const rowsFor = items => Model.rowsForSections(Model.usageSectionsFor(items), "images")

// The same op application ResourceList.qml performs, over a list of keys.
function applyPlan(currentKeys, rows) {
  const keys = currentKeys.slice()
  for (const op of Model.reconcilePlan(keys, rows)) {
    if (op.op === "remove") keys.splice(op.index, 1)
    else if (op.op === "move") keys.splice(op.to, 0, keys.splice(op.from, 1)[0])
    else keys.splice(op.index, 0, op.row.key)
  }
  return keys
}

test("each tag of an image is its own row, keyed by its reference", () => {
  const rows = rowsFor(images())
  const keys = rows.map(r => r.key)
  eq(new Set(keys).size, keys.length)
  ok(keys.includes("localhost/demo/shop:latest"))
  ok(keys.includes("docker.io/library/alpine:3"))
  for (const r of rows) eq(r.id, r.key)
})

test("an untagged image is keyed by its id, the only name it has", () => {
  const row = rowsFor(images()).find(r => r.name === "cccccccccccc")
  ok(row, "untagged image has a row")
  eq(row.key, "cccccccccccc")
})

test("filtering a multi-tag image away leaves exactly the rows the model built", () => {
  const all = rowsFor(images())
  const filtered = rowsFor(Model.filterResources(images(), "demo"))
  eq(applyPlan(all.map(r => r.key), filtered), filtered.map(r => r.key))
})

test("the reconcile ends on the target rows even from a list holding duplicates", () => {
  const row = key => ({ key: key })
  eq(applyPlan(["b", "a", "a"], [row("b"), row("a")]), ["b", "a"])
  eq(applyPlan(["a", "a", "b"], [row("b"), row("a")]), ["b", "a"])
  eq(applyPlan(["b", "a", "a", "c"], [row("b"), row("c")]), ["b", "c"])
  eq(applyPlan(["a", "a"], []), [])
})

test("a row looks up the tag under it, not the first tag of its image", () => {
  const items = images()
  eq(Model.itemById(items, "docker.io/library/alpine:3").reference, "docker.io/library/alpine:3")
  eq(Model.itemById(items, "localhost/demo/shop:latest").reference, "localhost/demo/shop:latest")
})

test("removing a tagged row removes that tag, by reference, never with -f", () => {
  eq(Model.removeCommand("images", "localhost/demo/shop:latest"),
    ["podman", "rmi", "localhost/demo/shop:latest"])
  eq(Model.removeCommand("images", "cccccccccccc"), ["podman", "rmi", "cccccccccccc"])
  eq(Model.removeCommand("images", "-rf"), null)
  eq(Model.removeCommand("images", "--all"), null)
  eq(Model.removeCommand("images", "a b"), null)
})

test("the remove question names the tag the cursor is on", () => {
  const item = Model.itemById(images(), "docker.io/library/alpine:3")
  ok(Model.removeMessage("images", item).includes("docker.io/library/alpine:3"))
})

test("copy on any tag still copies the image id", () => {
  const item = Model.itemById(images(), "docker.io/library/alpine:3")
  eq(Model.copyValue("images", item), ID)
})
