const { test, eq, ok, Model, make } = require("../harness.js")

// Rows hold their order while the pointer is over the list, so a click never
// lands on a container that moved under it (#13).

const ids = sections => Model.rowsForSections(sections, "containers").map(r => r.id)

test("without a snapshot the sections are returned as they are", () => {
  const sections = Model.sectionsFor([make("a", "p", "exited"), make("b", "p")])
  eq(Model.holdOrder(sections, null), sections)
})

test("a held order survives a re-sort within its section", () => {
  const before = Model.sectionsFor([make("a", "p", "exited"), make("b", "p", "exited")])
  const held = ids(before)
  // "b" starts, so the natural order puts it first; the hold keeps it second.
  const after = Model.sectionsFor([make("a", "p", "exited"), make("b", "p", "running")])
  eq(ids(after)[0], "b")
  eq(ids(Model.holdOrder(after, held)), held)
})

test("new rows follow the held ones, gone rows drop out", () => {
  const held = ["a", "b", "c"]
  const now = Model.sectionsFor([make("c", "p"), make("d", "p"), make("a", "p")])
  eq(ids(Model.holdOrder(now, held)), ["a", "c", "d"])
})

test("a hold never moves a row across sections, and headers stay on the first row", () => {
  const now = Model.sectionsFor([make("a", "x"), make("b", "y"), make("c", "x")])
  const held = ["c", "b", "a"]
  const kept = Model.holdOrder(now, held)
  eq(kept.map(s => s.key), now.map(s => s.key))
  eq(kept[0].items.map(i => i.id), ["c", "a"])
  const rows = Model.rowsForSections(kept, "containers")
  eq(rows.filter(r => r.sectionTitle !== "").map(r => r.id), ["c", "b"])
})

test("image rows are held by their per-tag key, not the shared image id", () => {
  const images = Model.normalizeImages([
    { ID: "aaaaaaaaaaaa", Repository: "r/x", Tag: "1", Size: "1MB", Containers: "0" },
    { ID: "aaaaaaaaaaaa", Repository: "r/x", Tag: "2", Size: "1MB", Containers: "0" }
  ])
  const sections = Model.usageSectionsFor(images)
  const held = ["r/x:2", "r/x:1"]
  eq(Model.rowsForSections(Model.holdOrder(sections, held), "images").map(r => r.key), held)
})

test("the cursor follows its row's id, and clamps when that row is gone", () => {
  const rows = [{ id: "b" }, { id: "a" }, { id: "c" }]
  eq(Model.cursorFollow(rows, "a", 0), 1)
  eq(Model.cursorFollow(rows, "zzz", 7), 2)
  eq(Model.cursorFollow([], "a", 3), 0)
  ok(Model.cursorFollow(rows, "", 1) === 1)
  const tags = [{ key: "r/x:1", id: "aaaaaaaaaaaa" }, { key: "r/x:2", id: "aaaaaaaaaaaa" }]
  eq(Model.cursorFollow(tags, "r/x:2", 0), 1)
})
