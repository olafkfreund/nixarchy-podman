const { test, eq, ok, Model, container, make } = require("../harness.js")

test("summaryText leads with trouble, and says so when Podman is not there", () => {
  const running = container({ ID: "a" })
  const sick = container({ ID: "b", HealthStatus: "unhealthy", Status: "Up 1 hour (unhealthy)" })
  const stopped = container({ ID: "c", State: "exited", Status: "Exited (0) 1 hour ago" })

  eq(Model.summaryText([running, stopped], true), "1 of 2 running")
  eq(Model.summaryText([running, sick], true), "1 needs attention · 2 of 2 running")
  eq(Model.summaryText([sick, sick], true), "2 need attention · 2 of 2 running")
  eq(Model.summaryText([], true), "No containers")
  eq(Model.summaryText([running], false), "Podman unreachable")
})

test("a stale non-zero exit does not claim the user's attention", () => {
  const stale = container({ State: "exited", Status: "Exited (1) 17 hours ago" })
  eq(Model.summaryText([stale], true), "0 of 1 running")
})

test("statusText drops the health Podman repeats and names a bad exit", () => {
  eq(Model.statusText(container({ Status: "Up 2 hours (healthy)", HealthStatus: "healthy" })),
    "Up 2 hours")
  eq(Model.statusText(container({ Status: "Up 2 hours" })), "Up 2 hours")
  eq(Model.statusText(container({ State: "exited", Status: "Exited (137) 3 minutes ago" })),
    "Exited (137)")
  eq(Model.statusText(container({ State: "exited", Status: "Exited (0) 3 minutes ago" })),
    "Exited (0) 3 minutes ago")
  eq(Model.statusText(null), "")
})

test("subtitleText leads with the service, then the image, then the ports", () => {
  eq(Model.subtitleText(container({
    Names: "shop-api",
    Image: "ghcr.io/acme/api:1",
    Ports: "127.0.0.1:4000->4000/tcp",
    Labels: "com.docker.compose.service=api"
  })), "api · acme/api  :4000")

  eq(Model.subtitleText(container({
    Names: "web", Image: "nginx:1", Labels: "com.docker.compose.service=web"
  })), "nginx")

  eq(Model.subtitleText(container({ Image: "alpine:latest", Ports: "" })), "alpine")
  eq(Model.subtitleText(null), "")
})

test("every glyph is a single code point, not a mangled sequence", () => {
  for (const name of Object.keys(Model.Glyph)) {
    const glyph = Model.Glyph[name]
    ok(typeof glyph === "string", name + " is a string")
    eq(Array.from(glyph).length, 1, name + " is one code point")
    ok(glyph.codePointAt(0) > 0xE000, name + " is in a private-use range")
  }
})

// A container you stop exits 143 (SIGTERM) or 137 (killed after the stop
// timeout); neither is a failure (#10). An OOM kill also exits 137 and now
// reads as a clean stop, accepted at intent approval.
test("a stop is not a failure, a crash still is", () => {
  const exited = code => make("c" + code, "", "exited", { Status: "Exited (" + code + ") 3 seconds ago" })
  ok(!exited(137).failing)
  ok(!exited(143).failing)
  ok(!exited(0).failing)
  ok(exited(1).failing)
  ok(exited(139).failing)
  eq(exited(137).exitCode, 137)
})

test("only a running container is marked unhealthy", () => {
  const stopped = make("s1", "", "exited", { Status: "Exited (137) 3 seconds ago (unhealthy)" })
  const running = make("r1", "", "running", { Status: "Up 2 minutes (unhealthy)" })
  ok(!Model.containerRow(stopped).unhealthy)
  ok(Model.containerRow(running).unhealthy)
})

// Podman's refusal on razer, verbatim; at 160 characters it was cut off at
// "force-", and the 64-hex id was most of the length (#13).
test("Podman's refusal reads in full, with its id shortened", () => {
  const raw = "Error: image used by e4a591c1459e692b98700f6815b60dc960a5ba477ef627772cad8c899a6f991f: " +
    "image is in use by a container: consider listing external containers and force-removing image"
  eq(Model.errorText(raw),
    "image used by e4a591c1459e: image is in use by a container: consider listing external containers and force-removing image")
})
