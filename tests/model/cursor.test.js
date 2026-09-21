const { test, eq, Model } = require("../harness.js")

// The first j/k after opening only shows the cursor, on the row it already
// points at; before #10 it moved first and landed on the second row.
test("a hidden cursor is revealed where it is, not moved", () => {
  eq(Model.nextCursor(false, 0, 1, 5).index, 0)
  eq(Model.nextCursor(false, 0, -1, 5).index, 0)
  eq(Model.nextCursor(false, 7, 1, 3).index, 2)
})

test("a visible cursor moves and stops at the ends", () => {
  eq(Model.nextCursor(true, 0, 1, 5).index, 1)
  eq(Model.nextCursor(true, 4, 1, 5).index, 4)
  eq(Model.nextCursor(true, 0, -1, 5).index, 0)
})
