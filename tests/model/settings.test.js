const { test, eq, ok, Model } = require("../harness.js")

const ID = "nixarchy.podman"
const defaults = () => ({ refreshIntervalSec: 15, defaultTab: "Containers", showStats: true })

test("settingsFor falls back to the defaults when there is no bar config", () => {
  eq(Model.settingsFor(undefined, ID, defaults()), defaults())
  eq(Model.settingsFor({}, ID, defaults()), defaults())
  eq(Model.settingsFor({ layout: { right: [ID] } }, ID, defaults()), defaults())
})

test("settingsFor finds the entry in any region of bar.layout", () => {
  for (const region of ["left", "center", "right"]) {
    const bar = { layout: { [region]: [{ id: "other", showStats: true }, { id: ID, showStats: false }] } }
    eq(Model.settingsFor(bar, ID, defaults()).showStats, false)
  }
})

test("settingsFor reads a layout passed without the bar wrapper", () => {
  eq(Model.settingsFor({ left: [{ id: ID, defaultTab: "Volumes" }] }, ID, defaults()).defaultTab, "Volumes")
})

test("settingsFor takes the first matching entry", () => {
  const bar = { layout: { left: [{ id: ID, refreshIntervalSec: 30 }], right: [{ id: ID, refreshIntervalSec: 60 }] } }
  eq(Model.settingsFor(bar, ID, defaults()).refreshIntervalSec, 30)
})

test("settingsFor ignores values of the wrong type and keys it does not know", () => {
  const bar = { layout: { right: [{ id: ID, showStats: "no", refreshIntervalSec: 45, bogus: 1 }] } }
  const got = Model.settingsFor(bar, ID, defaults())
  eq(got.showStats, true)
  eq(got.refreshIntervalSec, 45)
  ok(!("bogus" in got))
})

test("settingsFor reads Qt sequence wrappers, which are not JS arrays", () => {
  // What QML hands over for a list read through a QObject property.
  const wrapped = { length: 2, 0: { id: "other" }, 1: { id: ID, showStats: false } }
  ok(!Array.isArray(wrapped))
  eq(Model.settingsFor({ layout: { right: wrapped } }, ID, defaults()).showStats, false)
})

test("settingsFor never mutates the defaults it is given", () => {
  const d = defaults()
  Model.settingsFor({ layout: { right: [{ id: ID, showStats: false }] } }, ID, d)
  eq(d, defaults())
})
