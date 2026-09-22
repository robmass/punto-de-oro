# Punto de Oro

A padel score-tracking app for Apple Watch (native SwiftUI).

**[`docs/spec.md`](docs/spec.md) is the build-ready spec** — every decision, locked. Start there.
[`CONTEXT.md`](CONTEXT.md) fixes the domain language it uses.

Planning is tracked as a Wayfinder map in this repo's issues — see the issue labelled `wayfinder:map`.

## Building

The Xcode project is generated from [`project.yml`](project.yml) by
[XcodeGen](https://github.com/yonaskolb/XcodeGen). The generated `PuntoDeOro.xcodeproj` is
committed, so a clean checkout builds without XcodeGen. After editing `project.yml`, run
`xcodegen generate` and commit both files.

[`docs/sideloading.md`](docs/sideloading.md) covers installing onto the watch and running the tests (on the simulator by default).
