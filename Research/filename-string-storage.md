# Filename String Storage

<!--
---
version: 1.0.0
last_updated: 2026-05-22
status: RECOMMENDATION
tier: 2
scope: cross-package
applies_to:
  - swift-foundations/swift-file-system
  - swift-iso/swift-iso-9945
  - swift-foundations/swift-posix
  - swift-foundations/swift-manifests
  - swift-foundations/swift-environment
  - swift-microsoft/swift-windows-32
trigger: HANDOFF-filename-storage-design.md (2026-05-22)
predecessor: swift-institute/Research/path-type-ecosystem-model.md (canonical L3-Copyable-wraps-L1-~Copyable reference)
verification_experiment: none (design analysis; cascade verified by file:line evidence)
---
-->

## Context

`File.Name` (L3, swift-file-system) stores raw filesystem-native code
units as `[Path.Char]` (= `[UInt8]` POSIX / `[UInt16]` Windows).
`ISO_9945.Kernel.Directory.Entry` (L2, swift-iso-9945) stores raw bytes
as `[UInt8]` (POSIX) / `[UInt16]` (Windows), publicly exposed as
`rawName`. The byte-canonical migration ([API-BYTE-006]) just landed in
swift-file-system; the filename-storage question surfaces as the next
adjacent refactor.

The handoff brief proposes migrating `File.Name`'s storage to
`String_Primitives.String` (`~Copyable` owned null-terminated platform-
native code unit sequence) on the grounds that `UInt8`/`Byte` is the
wrong domain — filenames are encoded text, not opaque bytes. Storage
type, however, is not a free choice: `String_Primitives.String` is
`~Copyable`, which forces `File.Name` to be `~Copyable` too, breaking
its current `Sendable, Equatable, Hashable` conformances and its
`IteratorProtocol` return type, `Array` storage, and stdlib
`Swift.Error` payload sites.

This document decides Q1–Q4 from the brief.

### Prior Research

Per [RES-019] / [HANDOFF-013] step-0 grep
(`grep -lr <topic-keyword> swift-foundations/swift-file-system/Research/
swift-institute/Research/`):

| Document | Bearing |
|---|---|
| `swift-institute/Research/path-type-ecosystem-model.md` (2026-04-18) | **Canonical L3-Copyable-wraps-L1-~Copyable architectural reference.** `Paths.Path` (L3) is `Copyable, Sendable, Hashable` wrapping `[Char]` storage; `Path_Primitives.Path` (L1) is `~Copyable` wrapping `Memory.Contiguous<Char>`. This is the named precedent for the File.Name decision. |
| `swift-institute/Research/2026-05-13-noncopyable-adoption-ecosystem-corners-audit.md` v1.0.0 RECOMMENDATION | Cites `path-type-ecosystem-model.md` as **"the answer to 'should the Copyable wrapper become ~Copyable?' — definitively NO when the wrapper IS the architectural bridge to stdlib containers"** (Predecessor table, line 82). Row 13 scores `File.Directory.Contents.Iterator` 12/30 on the six-axis grid with Wave-5+6 shape **Stdlib-protocol** (`IteratorProtocol` requires Copyable Element); not recommended for ~Copyable adoption. |
| `swift-institute/Research/exported-chain-audit-string-primitives.md` v0.1.0 IN_PROGRESS | Establishes that `String_Primitives` is an L1 module whose viral `@_exported` chains have historically leaked through L3 consumer APIs. Direct L3 storage adoption of `String_Primitives.String` would re-introduce the propagation the audit is trying to bound. |
| `swift-institute/Research/file-path-type-unification-audit.md` (2026-03-19) | Establishes that `File`, `File.Directory`, `File.Path` are L3 value types with `ExpressibleByStringLiteral` and stdlib container support as core API requirements; the wrapper types' value IS API organization at the Copyable layer. |
| `swift-foundations/swift-posix/Research/glob-layering-research.md` (2026-04-13) | Documents the `entry.nameView: Path.Borrowed` zero-allocation pattern landed on `ISO_9945.Kernel.Directory.Entry` — `@_lifetime(borrow self)` property over the owned `[Path.Char]` buffer. This IS already the borrowed-view companion to the owned `rawName`. |
| `swift-foundations/swift-file-system/Research/_Package-Insights.md` | Generic package insights; no prior filename-storage analysis. |

**Conclusion of the prior-research grep**: the L3-Copyable-wraps-L1-
~Copyable pattern is documented as **definitively NO** for the
analogous question on Path, and a Wave-5+6 ecosystem-readiness audit
has already classified `File.Directory.Contents.Iterator` as not
~Copyable-adoptable due to `IteratorProtocol` cascade. This research
extends that analysis to `File.Name` and to the L2 substrate question
on `Kernel.Directory.Entry.rawName`, citing the prior research rather
than re-litigating it.

### Constraints

- **Toolchain matrix**: Swift 6.3 stable + 6.4-dev nightly. SE-0499
  (stdlib `Hashable`/`Equatable` on `~Copyable`) lands in 6.4; SE-0437
  ships `~Copyable` `Optional`/`Result` but stdlib `Array`, `Set`,
  `Dictionary` remain Copyable-only.
- **`Swift.Error` is Copyable**: stdlib `Error` cannot be implemented
  by a `~Copyable` type pre-SE-revision. Any `~Copyable` storage in an
  `Error` payload (e.g., `Walk.Error.undecodableEntry(name: File.Name)`)
  forces that case to drop from the enum.
- **`IteratorProtocol` is Copyable**: stdlib `IteratorProtocol.next()
  -> Element?` requires Copyable Element.
- **The byte-IO migration (`Span<UInt8>` → `Span<Byte>`) is a separate
  program** (`HANDOFF-byte-io-migration.md`); this doc explicitly does
  not conflate the two.
- **No source modifications** in this dispatch.

### Scope

Decide Q1–Q4 from the handoff brief; produce an actionable API sketch
and migration path; quantify the cascade.

---

## Q1 — Should `File.Name` be `~Copyable`?

**Decision**: **NO.** `File.Name` remains `Copyable, Sendable,
Equatable, Hashable`. Storage stays `[Path.Char]` (option (c) in the
brief — wrapper to remain Copyable).

### Rationale

This question reduces to the same shape `path-type-ecosystem-model.md`
already answered for `Paths.Path` vs `Path_Primitives.Path`:

| Layer | Type | Storage | Copyability | Role |
|---|---|---|---|---|
| L1 | `Path_Primitives.Path` | `Memory.Contiguous<Char>` (NUL-term) | `~Copyable` | Owned syscall-boundary primitive |
| L3 | `Paths.Path` | `[Char]` (NUL-term) | `Copyable, Sendable, Hashable` | High-level value type, stdlib-container-friendly |
| L1 | `String_Primitives.String` | `Memory.Contiguous<Char>` (NUL-term) | `~Copyable` | Owned syscall-boundary primitive |
| L3 | **`File.Name` (this question)** | `[Path.Char]` (current) | **`Copyable, Sendable, Equatable, Hashable`** | High-level value type, stdlib-container-friendly |

The brief's framing — *"the right type is `String_Primitives.String`"*
— picks the L1 ~Copyable variant when File.Name's structural role is
the L3 Copyable variant. The L1 type's existence does **not** force L3
storage adoption. The pattern is settled across the ecosystem.

### Consumer cascade (if File.Name became ~Copyable)

| Site | File | Required of File.Name today | Status under `~Copyable` |
|---|---|---|---|
| `File.Directory.Entry.name: File.Name` | `File.Directory.Entry.swift:19` | Stored as struct field; Entry is `Sendable` | Entry becomes `~Copyable` (Copyable struct cannot contain `~Copyable`) |
| `Iterator.next() -> File.Name?` | `File.Directory.Contents.Iterator.swift:24` | `IteratorProtocol` requires Copyable Element | **Hard block** — must drop `IteratorProtocol` |
| `[File.Name]` array | `File.Directory.Contents+Convenience.swift:21,25` | Array element | **Hard block** — stdlib Array requires Copyable Element |
| `[File.Directory.Entry]` from `Contents.list` | `File.Directory.Contents.swift:30-37` | Array element via Entry | **Hard block** — propagates via Entry |
| `Walk.Error.undecodableEntry(parent:name:)` | `File.Directory.Walk.Error.swift:18` | Enum case payload; `Swift.Error` | **Hard block** — `Swift.Error` is Copyable; case must drop |
| `Walk.Undecodable.Context.name` | `File.Directory.Walk.Undecodable.Context.swift:22` | `Sendable` struct field | Context becomes `~Copyable` |
| `Decode.Error.name: File.Name` | `File.Name.Decode.Error.swift:19` | Error payload | **Hard block** — `Swift.Error` is Copyable; field must drop or move to opaque storage |
| `Swift.String(entry.name) == "Package.swift"` | `swift-manifests/Manifest.NestedPackage.swift:56` | `Swift.String.init?(File.Name)` | Works under `borrowing` receiver |
| `try! Swift.String(entry.name)` | `swift-environment/Environment.Read.swift:59` | Same | Works under `borrowing` receiver |
| `entry.name.asPathComponent()` | `File.System.Copy.Recursive.swift:124`, `File.System.Delete.swift:198` | Method on borrowed instance | Works under `borrowing` receiver |
| `entry.name.isHiddenByDotPrefix` | `File.Directory.Walk.swift:229` | Property on borrowed instance | Works under `borrowing` receiver |
| `File.Name == File.Name` (implicit) | `File.Name.swift:48-50` (`isDotOrDotDot`) | Stdlib `Equatable` on Array | SE-0499 covers in Swift 6.4; viable |
| `Set<File.Name>` / `[File.Name: T]` | **Not used** in current code | Stdlib container | Stdlib container requires Copyable — would block any future use |

Three of the blockers above (`IteratorProtocol`, `Array<Element>`,
`Swift.Error` payload) are **hard blocks**: they are not resolved by
SE-0499 / SE-0437 / current 6.4 stdlib state. Mitigating them requires
either (a) abandoning each stdlib protocol/container, or (b) waiting
on upstream evolution. Either path is structurally inferior to keeping
File.Name Copyable.

The **cascade size below the 50-file `ask:` threshold**:

| Bucket | Files |
|---|---|
| swift-file-system production sources (touch File.Name directly) | 14 |
| swift-file-system tests | 6 |
| External production consumers | 2 (`swift-manifests`, `swift-environment`) |
| **Total** | **~22** |

Below threshold; no escalation required per the handoff brief's `ask:`
clause.

### Architectural alignment

- **[ARCH-LAYER-001]** Five-layer architecture: L3 wraps L1; L3
  Copyable wrapping L1 ~Copyable storage IS the canonical bridge.
- **`feedback_correctness_and_evergreen.md`**: ownership-model decisions
  are judged on structural correctness, not adoption count. The
  structural argument here is the L3-Copyable-wraps-L1-~Copyable pattern.
- **Row 13 in `2026-05-13-noncopyable-adoption-ecosystem-corners-audit.md`**:
  `File.Directory.Contents.Iterator` was already evaluated as a
  ~Copyable candidate and scored 12/30 with Wave-5+6 shape "Stdlib-
  protocol" — explicitly deferred. The File.Name question is the
  upstream of that cascade; the same blocker applies.

### What the brief's complaint actually identifies

The brief's structural concern — *"`UInt8` says 'arithmetic 8-bit
integer' — wrong domain; `Byte` says 'byte-stream payload' — also
wrong"* — is **correct for the public accessor surface** of
`File.Name`, not for the internal storage shape. Internal storage is
already `[Path.Char]` (= `[String.Char]`) — the right code-unit
domain. The byte-domain leakage is at the **public accessors**:

| Public accessor | Current type | Domain leak |
|---|---|---|
| `posixBytes: [UInt8]?` | `[UInt8]?` | `UInt8` byte-domain return |
| `windowsCodeUnits: [UInt16]?` | `[UInt16]?` | `UInt16` raw-integer return |
| `withUnsafeUTF8Bytes<R, E>` | `(UnsafeBufferPointer<UInt8>) throws(E) -> R` | UTF-8 byte view, POSIX-only |
| `withCodeUnits<R>` / `withCodeUnits<R, E>` | `(Span<UInt16>) -> R` / `(Span<UInt16>) throws(E) -> R` | UTF-16 code-unit view, Windows-only |
| `withBytes<R>` / `withBytes<R, E>` | `(Span<UInt8>) -> R` / `(Span<UInt8>) throws(E) -> R` | POSIX-only, byte-domain |
| `withUTF8Bytes<R, E>` | `([UInt8]) throws(E) -> R` | Always-allocating UTF-8 bytes |

This cleanup is the **actionable structural correction** the brief is
reaching for. It does not require changing storage to
`String_Primitives.String` — it requires converging the byte-domain
accessors onto code-unit-typed accessors. See Q3 below.

### Recommendation — resolution (option (c))

`File.Name` remains:

```swift
extension File {
    public struct Name: Sendable, Equatable, Hashable {
        @usableFromInline
        package let rawBytes: [Path.Char]   // unchanged

        // ... semantic predicates, decode bridges, Path.Component bridge,
        //     Binary.Serializable conformance — all unchanged
    }
}
```

No conformance changes; no storage substrate change. Cleanup happens
at the public accessor surface (Q3), and the cascade question is
closed without further investigation.

---

## Q2 — `Kernel.Directory.Entry` Lifetime: Borrowed vs Owned?

**Decision**: **Owned, as today.** No Borrowed variant is added.

### Reframing the brief's premise

The brief's lifetime concern *"readdir(3) invalidates dirent.d_name on
next call"* is **true at the libc level but already mitigated** in the
ecosystem. Inspect
`swift-iso-9945/Sources/ISO 9945 Kernel Directory/ISO 9945.Kernel.Directory.swift:107-116`:

```swift
let rawName: [UInt8] = unsafe withUnsafePointer(to: entry.pointee.d_name) { ptr in
    let bufferSize = MemoryLayout.size(ofValue: unsafe entry.pointee.d_name)
    return unsafe ptr.withMemoryRebound(to: UInt8.self, capacity: bufferSize) { bytes in
        var length = 0
        while length < bufferSize && (unsafe bytes[length]) != 0 {
            length += 1
        }
        return unsafe Array(UnsafeBufferPointer(start: bytes, count: length + 1))
    }
}

return ISO_9945.Kernel.Directory.Entry(rawName: rawName, ...)
```

`d_name` is copied into an owned `[UInt8]` at the point of
`readdir`-extraction. The Entry returned from `Stream.next()` is
already independent of `dirent`'s lifetime. The Borrowed-vs-Owned
question therefore concerns the **owned-storage type**, not lifetime.

### Consumer audit (does any caller hold Entry across iterator advancement?)

| Consumer site | File | Holds entry across `next()`? |
|---|---|---|
| `File.Directory.Contents.iterate(at:body:)` | `File.Directory.Contents.swift:80-121` | No — entry is created inside the per-step closure, consumed by body, never escapes |
| `File.System.Delete.deleteRecursive` | `File.System.Delete.swift:177-209` | No — per-step pattern, recurses into child directories with a fresh stream |
| `File.Directory.Iterator.next()` | `File.Directory.Iterator.swift:111-156` | No — kernelEntry is bridged to `File.Directory.Entry` (with owned `File.Name`) and returned; kernelEntry doesn't escape |
| `swift-posix Glob.listDirectory` | `Kernel.Glob+Match.swift:286-312` | **Yes** — collects `[ISO_9945.Kernel.Directory.Entry]` into an array, returns to caller, then iterates the collected entries via `for entry in matchedEntries` (line 187) and uses `appendPath(currentPath, entry)` (line 336) on each. Entries persist across the stream's lifetime. |

The glob consumer is the load-bearing counter-example. Glob's
implementation depends on **owned-Entry semantics** — the array
collection (`var entries: [ISO_9945.Kernel.Directory.Entry] = []` →
`return entries`) requires Copyable Entry. A Borrowed-only Entry
shape would break this consumer.

### Recommendation

Keep owned `[UInt8]`/`[UInt16]` storage on `Kernel.Directory.Entry`.
The existing `nameView: Path.Borrowed` zero-allocation property
(`Kernel.Directory.Entry.swift:102-109`) is **already the borrowed-
view companion** to the owned storage; callers that can scope within
a step (e.g., dotfile-skip in `File.Directory.Contents.iterate`) can
use `nameView` without copying. No new type required.

The Entry stays:

```swift
extension ISO_9945.Kernel.Directory {
    public struct Entry: Sendable {
        #if os(Windows)
        public let rawName: [UInt16]    // unchanged (subject to Q3)
        #else
        public let rawName: [UInt8]     // unchanged (subject to Q3)
        #endif
        public let inode: ISO_9945.Kernel.Inode?
        public let type: ISO_9945.Kernel.File.Stats.Kind?

        // nameView: Path.Borrowed — unchanged; preferred zero-copy access path
    }
}
```

---

## Q3 — Should `rawName` / `rawBytes` Exist as Public API?

**Decision**: differentiated by site.

| Field | Visibility today | Decision |
|---|---|---|
| `File.Name.rawBytes: [Path.Char]` | `package` (file-system internal) | **Keep as-is.** Already non-public; no consumer outside the package can reach it directly. |
| `File.Name.posixBytes: [UInt8]?` | `public` | **Deprecate then remove.** Byte-domain leak per [API-BYTE-006] / byte-discipline; redundant with `withUnsafeBytes`-style scoped access. |
| `File.Name.windowsCodeUnits: [UInt16]?` | `public` | **Deprecate then remove.** Same domain leak. |
| `File.Name.withUnsafeUTF8Bytes` | `public` | **Deprecate then remove.** UTF-8 byte-domain accessor; replace with platform-agnostic `Path.Char`/`String.Borrowed` view. |
| `File.Name.withCodeUnits` | `public` | **Deprecate then remove.** UTF-16 raw-integer accessor; replace with same code-unit view. |
| `File.Name.withBytes` (POSIX-only) | `public` | **Deprecate then remove.** Same. |
| `File.Name.withUTF8Bytes` (allocating) | `public` | **Keep.** Cross-platform always-UTF-8 accessor is a real consumer convenience (wire-format serialization); not a domain leak — UTF-8 IS the canonical wire format. |
| `ISO_9945.Kernel.Directory.Entry.rawName: [UInt8]/[UInt16]` | `public` | **Keep public for now, schedule eventual `@_spi(Syscall)` gate.** One known production consumer (swift-posix Glob); migration requires Glob to switch to `nameView`-based access. |

### Consumer audit for `Kernel.Directory.Entry.rawName`

| Consumer | File | Pattern | Migration target |
|---|---|---|---|
| `Glob.shouldSkipEntry` | `swift-posix/Sources/POSIX Kernel Glob/Kernel.Glob+Match.swift:265` | `entry.rawName.first == ASCII.Character.Graphic.period` | `entry.nameView.span[0] == 0x2E` |
| `Glob.appendPath(_ base, _ entry)` | `Kernel.Glob+Match.swift:336-358` | `entry.rawName` indexed read + `rawName.count - 1` | `entry.nameView.span` indexed read + `entry.nameView.count` |
| `Glob.listDirectory` | `Kernel.Glob+Match.swift:286-312` | Returns `[ISO_9945.Kernel.Directory.Entry]` — does NOT reach into rawName | None (the array-storage consumer; orthogonal to rawName) |
| `Path.Component+PlatformNative.POSIX.swift:19` / `Windows.swift:19` | doc-comment example only | Not a code consumer | N/A (doc fix) |
| `Windows.Kernel.Directory.swift:171` | constructs `Entry(rawName: nameChars, …)` | Constructor caller; needs rawName as init parameter | Init form must stay |

Direct readers: **two functions in one file** in `swift-posix`. The
migration cost is bounded; the eventual `@_spi(Syscall)` gate
(coordinated with a Glob update) is preferred but not blocking for
v1.

### Recommendation

**Phase A (this refactor)**:
- `File.Name`: deprecate the five byte-domain public accessors with
  `@available(*, deprecated, renamed: "<new-accessor>")`; introduce
  one platform-agnostic accessor:
  ```swift
  /// Scoped access to the name's code units as a borrowed view.
  @inlinable
  public borrowing func withCodeUnits<R, E: Swift.Error>(
      _ body: (String.Borrowed) throws(E) -> R
  ) throws(E) -> R
  ```
  *(Name choice tracked in §"Naming follow-up" below.)*
- `File.Name`: optionally expose `var view: String.Borrowed` with
  `@_lifetime(borrow self)` for unconstrained borrowed access (parallel
  to `Path.view: Path.View`).
- `File.Name.withUTF8Bytes` retained — wire-format helper, not domain
  leak.

**Phase B (post-Glob migration)**:
- `ISO_9945.Kernel.Directory.Entry.rawName` → `@_spi(Syscall)`. Land
  alongside the Glob migration commit so no public consumer breaks.
- Doc-comment references in `Path.Component+PlatformNative.{POSIX,
  Windows}.swift` updated to cite `entry.nameView` rather than
  `entry.rawName` / `File.Name.rawBytes`.

---

## Q4 — `String_Primitives.String` Gap Audit

Given Q1's decision (File.Name stays Copyable with `[Path.Char]`
storage), **no L1 surface additions to `String_Primitives.String` are
required** by this refactor. The gap audit below documents what
**would** be needed if a future structural revision adopted
`String_Primitives.String` storage at File.Name; it is informational
for that hypothetical, not a precondition of the present
recommendation.

### File.Name operations today and their L1 substrate fit

| Operation (File.Name use-site) | Today via `[Path.Char]` | `String_Primitives.String` today (owned + Borrowed) | Gap? |
|---|---|---|---|
| Length / `count` | `rawBytes.count` | `count: Int` ([`String.swift:59`](file:///Users/coen/Developer/swift-primitives/swift-string-primitives/Sources/String%20Primitives/String.swift)); `Borrowed.count: Int` ([`String.Borrowed.swift:41`](file:///Users/coen/Developer/swift-primitives/swift-string-primitives/Sources/String%20Primitives/String.Borrowed.swift)) | None |
| Span access (zero-copy) | `rawBytes.span` (Array.span) | `span: Span<Char>` ([`String.swift:178`](file:///Users/coen/Developer/swift-primitives/swift-string-primitives/Sources/String%20Primitives/String.swift)); `Borrowed.span` ([`String.Borrowed.swift:103`](file:///Users/coen/Developer/swift-primitives/swift-string-primitives/Sources/String%20Primitives/String.Borrowed.swift)) | None |
| Scoped UnsafeBufferPointer | `rawBytes.withUnsafeBufferPointer` | `withUnsafeBufferPointer` (via `Memory.Contiguous.Protocol`, [`String.swift:206`](file:///Users/coen/Developer/swift-primitives/swift-string-primitives/Sources/String%20Primitives/String.swift)) | None for owned; Borrowed lacks an equivalent (has `withUnsafePointer` only) |
| Equality (`== "." / == ".."`) | `rawBytes == [0x2E]` etc. (Array `==`) | **No `Equatable` conformance** on `String` or `Borrowed` | **Gap #1** |
| Hash (Set/Dict key membership) | Array `Hashable` | **No `Hashable` conformance** | **Gap #2** (load-bearing if any consumer adds `Set<File.Name>` or `[File.Name: T]` — none today; potential future) |
| First-byte check (`.first == 0x2E`) | `rawBytes.first` | No direct accessor; reachable via `view.span[0]` after `count > 0` guard | **Gap #3** (workaround viable; convenience missing) |
| `[Path.Char]` literal init | `init(rawBytes: Array(".gitignore".utf8))` | No literal-init at L1; `init(ascii: StaticString)` covers ASCII-only literals | **Gap #4** (test ergonomics only — Tests construct `File.Name` from literal byte arrays; would need different fixture shape) |
| Lossy / strict UTF-8 decode to `Swift.String` | `Swift.String.lossy/strict(platformNative: [Char])` in `Strings` L3 | `Swift.String.init(_ owned:)` / `init(_ view:)` in `Strings` L3 (already exists) — but lossy decode is not on the L1 type | None at L1 (Strings L3 does the bridging; same as today) |
| `Sendable` cross-isolation | Array `Sendable` | `@unsafe @unchecked Sendable` ([`String.swift:47`](file:///Users/coen/Developer/swift-primitives/swift-string-primitives/Sources/String%20Primitives/String.swift)) | None |
| Init from kernel d_name span | `[UInt8](copying: …)` | `init(_ span: Span<Char>)` ([`String.swift:99`](file:///Users/coen/Developer/swift-primitives/swift-string-primitives/Sources/String%20Primitives/String.swift)); `init(copying view: String.Borrowed)` ([`String.swift:87`](file:///Users/coen/Developer/swift-primitives/swift-string-primitives/Sources/String%20Primitives/String.swift)) | None |

**Gap count (counting only the load-bearing gaps for File.Name's
existing operations)**: **4** — `Equatable`, `Hashable`, `first`-style
accessor, byte-array literal init. The Equality gap subsumes the
literal-init gap operationally (both are about comparing/constructing
against a known fixed sequence). Strict count is 3 conformance-level
+ 1 ergonomic = 4. **Below the `> 5` ask: threshold** in the handoff
brief.

### Why this matters even though Q1 decided NO

Even with Q1 settled, the gap inventory is documented so that:

1. A future structural revision (e.g., a successor proposal that
   re-opens the ~Copyable substrate question with different ecosystem
   constraints) has the verified-now baseline.
2. The two Equatable/Hashable conformances on
   `String_Primitives.String` are **broadly useful** at L1
   independently of File.Name — they unblock `Set<String>` and `[String:
   T]` for any L1/L2/L3 consumer that needs owned-string membership
   semantics, which IS likely to surface elsewhere (e.g., kernel-name
   deduplication, environment variable maps). These conformances are
   permitted by SE-0499 in Swift 6.4. **They are NOT in scope of this
   refactor**, but worth surfacing as a separate skill-incorporation
   candidate.

---

## API Sketch

### `File.Name` (post-cleanup, Q1 + Q3)

```swift
extension File {
    /// A directory entry name preserving raw filesystem encoding.
    ///
    /// Stores platform-native code units (`Path.Char` = `UInt8` POSIX,
    /// `UInt16` Windows) exactly as returned by the filesystem, supporting
    /// undecodable names. The storage element is the **code-unit** type,
    /// not the byte type — File.Name is encoded text, not a byte payload.
    public struct Name: Sendable, Equatable, Hashable {
        @usableFromInline
        package let rawBytes: [Path.Char]   // unchanged — package-scoped

        @usableFromInline
        internal init(rawBytes: [Path.Char]) {
            self.rawBytes = rawBytes
        }

        // Semantic predicates — unchanged
        package var isDotOrDotDot: Bool { … }
        public var isHiddenByDotPrefix: Bool { rawBytes.first == 0x2E }

        // Borrowed view over the code units — new, replaces byte-domain
        // public accessors
        @inlinable
        public var view: String.Borrowed {
            @_lifetime(borrow self) borrowing get {
                let ptr = unsafe rawBytes.withUnsafeBufferPointer { $0.baseAddress! }
                // rawBytes is not NUL-terminated; the Borrowed contract
                // requires NUL-termination — see open question O1 below.
                ...
            }
        }

        // Scoped code-unit access — new, replaces withBytes / withCodeUnits /
        // withUnsafeUTF8Bytes / withUnsafeCodeUnits
        @inlinable
        public borrowing func withCodeUnits<R, E: Swift.Error>(
            _ body: (Span<Path.Char>) throws(E) -> R
        ) throws(E) -> R

        // Always-UTF-8 wire-format helper — unchanged
        @inlinable
        public func withUTF8Bytes<R, E: Swift.Error>(
            _ body: ([UInt8]) throws(E) -> R
        ) throws(E) -> R
    }
}

// MARK: - Deprecated byte-domain accessors (Phase A)

extension File.Name {
    @available(*, deprecated, renamed: "view")
    public var posixBytes: [UInt8]? { … }

    @available(*, deprecated, renamed: "view")
    public var windowsCodeUnits: [UInt16]? { … }

    @available(*, deprecated, renamed: "withCodeUnits")
    public func withUnsafeUTF8Bytes<R, E: Swift.Error>(…) -> R? { … }

    @available(*, deprecated, renamed: "withCodeUnits")
    public func withCodeUnits<R, E: Swift.Error>(_ body: (Span<UInt16>) throws(E) -> R) throws(E) -> R? { … }

    @available(*, deprecated, renamed: "withCodeUnits")
    public func withBytes<R, E: Swift.Error>(_ body: (Span<UInt8>) throws(E) -> R) throws(E) -> R? { … }
}
```

### `File.Directory.Entry` (Q1 + Q2)

```swift
extension File.Directory {
    public struct Entry: Sendable {
        public let name: File.Name       // unchanged — Copyable
        public let parent: File.Path     // unchanged — Copyable
        public let type: Kind            // unchanged

        public init(name: File.Name, parent: File.Path, type: Kind) {
            self.name = name
            self.parent = parent
            self.type = type
        }
    }
}
```

### `ISO_9945.Kernel.Directory.Entry` (Phase A — no change; Phase B — `@_spi`)

```swift
extension ISO_9945.Kernel.Directory {
    public struct Entry: Sendable {
        // Phase A: rawName stays public.
        // Phase B: @_spi(Syscall) public let rawName: [Path.Char]
        #if os(Windows)
        public let rawName: [UInt16]
        #else
        public let rawName: [UInt8]
        #endif

        public let inode: ISO_9945.Kernel.Inode?
        public let type: ISO_9945.Kernel.File.Stats.Kind?

        // Preferred zero-copy access — unchanged from current
        @inlinable
        public var nameView: Path.Borrowed { … }
    }
}
```

---

## Migration Path

### Phase A — File.Name byte-discipline cleanup (this refactor)

**Scope**: `swift-foundations/swift-file-system` only (single-package
refactor); no L2 / L1 changes.

| Step | Action | File:line | Risk |
|---|---|---|---|
| A.1 | Add `var view: String.Borrowed` on `File.Name` (open question O1) | `File.Name.swift` (new) | Low |
| A.2 | Add `borrowing func withCodeUnits<R, E>(_:) throws(E) -> R` on `File.Name` returning `Span<Path.Char>` | `File.Name.swift` (new) | Low |
| A.3 | Deprecate `posixBytes`, `windowsCodeUnits`, `withUnsafeUTF8Bytes`, `withUnsafeCodeUnits`, `withBytes` (POSIX), `withCodeUnits<R>` (Windows variant) | `File.Name.swift:282-306, 181-264` | Low — `@available(*, deprecated)` |
| A.4 | Update `File.Name+Convenience.swift` ([UInt8]/[UInt16] copying inits) — either deprecate, or keep as bridge if external consumer demand surfaces | `File.Name+Convenience.swift:10-40` | Low |
| A.5 | Update test fixtures that use deprecated accessors | `Tests/File System Core Tests/File.Name Tests.swift` (a few sites) | Low |
| A.6 | Big-bang vs parallel: **parallel** — keep deprecated accessors for one release cycle to ease external consumer migration | — | Low |

**External-consumer impact (A)**:

| Consumer | Site | Action |
|---|---|---|
| `swift-manifests/Manifest.NestedPackage.swift:56` | `Swift.String(entry.name) == "Package.swift"` | No change — uses `Swift.String(_:)` init, not deprecated accessor |
| `swift-environment/Environment.Read.swift:59` | `try! Swift.String(entry.name)` | No change — same |

No external consumer of the deprecated accessors found in the
workspace.

### Phase B — Kernel.Directory.Entry.rawName SPI gate (separate dispatch)

**Scope**: `swift-iso-9945` + `swift-posix` + `swift-microsoft/swift-windows-32`.

| Step | Action | File:line | Risk |
|---|---|---|---|
| B.1 | Migrate `swift-posix/Sources/POSIX Kernel Glob/Kernel.Glob+Match.swift` from `entry.rawName.first` / `entry.rawName[i]` / `entry.rawName.count` to `entry.nameView.span` indexed reads | `Kernel.Glob+Match.swift:265, 336-358` | Medium — Glob is performance-sensitive; benchmark before/after |
| B.2 | Gate `rawName` with `@_spi(Syscall)` on `ISO_9945.Kernel.Directory.Entry` | `Kernel.Directory.Entry.swift:21-25` | Low — once B.1 lands |
| B.3 | Update doc-comments in `Path.Component+PlatformNative.{POSIX,Windows}.swift` to cite `entry.nameView` | `Path.Component+PlatformNative.{POSIX,Windows}.swift:19` | Trivial |
| B.4 | Confirm `Windows.Kernel.Directory.swift:171` constructor still has access to the `rawName:` init parameter (constructor side, not field-read side; should remain unaffected by `@_spi` of the field) | `Windows.Kernel.Directory.swift:171` | Low |

Phase B is **dependent on Phase A landing first** (so the cleanup
narrative is coherent) and on a Glob micro-benchmark confirming the
`nameView`-based access path is performance-equivalent.

### Big-bang vs parallel API

**Parallel API with deprecation** — both phases — is recommended. The
total cascade size (~22 files) does not warrant a big-bang switch;
deprecated overloads carry zero ongoing maintenance cost beyond the
`@available` annotation and provide a graceful migration window for
any out-of-tree consumer.

---

## Estimated Cascade Size

| Package | Files touched | Sites |
|---|---|---|
| `swift-foundations/swift-file-system` (Phase A) | 4 source + ~6 test | ~25 sites |
| `swift-foundations/swift-posix` (Phase B) | 1 source | 4 sites (lines 265, 339, 340, 353) |
| `swift-iso/swift-iso-9945` (Phase B) | 1 source | 1 line (@_spi annotation) |
| `swift-foundations/swift-paths` (Phase B) | 2 source | 2 doc-comment fixes |
| `swift-microsoft/swift-windows-32` | 0 | 0 (constructor unaffected) |
| **Total** | **~14 files** | **~32 sites** |

Below the 50-file `ask:` threshold from the brief; Phase A is
self-contained within a single package and can land without
inter-package coordination.

---

## Open Questions

| ID | Question | Why deferred |
|---|---|---|
| O1 | `String.Borrowed`'s NUL-termination invariant ([`String.Borrowed.swift:31`](file:///Users/coen/Developer/swift-primitives/swift-string-primitives/Sources/String%20Primitives/String.Borrowed.swift): *"Invariant: Points to a null-terminated sequence"*) vs `File.Name.rawBytes` storage which is NOT NUL-terminated (`File.Name.swift:35`: *"NUL-terminator excluded"*). The proposed `File.Name.view: String.Borrowed` accessor must reconcile this — options: (a) change File.Name storage to include trailing NUL (changes serialization shape, see `Binary.Serializable` conformance at `File.Name.swift:310-331`), (b) expose `Span<Path.Char>` instead of `String.Borrowed` (loses null-termination guarantee but doesn't depend on changing storage), (c) introduce a non-NUL-terminated borrowed view at L1. **Defer**: this design decision lives at L1 and is not unique to File.Name; surfacing it as a separate question to be settled before Phase A.2 implementation. |
| O2 | Should `String_Primitives.String` adopt `Equatable` / `Hashable` per SE-0499 in Swift 6.4? Independently useful at L1 for owned-string membership; outside scope of this refactor but on the skill-incorporation radar. **Defer**: separate research / experiment, not blocking. |
| O3 | Should `ISO_9945.Kernel.Directory.Entry` itself become `~Copyable` (substrate-level)? Not gated by File.Name, but adjacent. The Glob consumer's `[Entry]` collection is the load-bearing blocker. **Defer**: out of scope; would require redesigning Glob's directory listing in addition to nameView migration. |

---

## Outcome

**Status**: RECOMMENDATION (pending principal review).

**Q1**: `File.Name` stays `Copyable, Sendable, Equatable, Hashable`
with `[Path.Char]` storage. The brief's storage-change premise is
declined on structural grounds; the L3-Copyable-wraps-L1-~Copyable
pattern is canonical (Paths.Path precedent) and the cascade through
`IteratorProtocol`, stdlib `Array<Element>`, and `Swift.Error` payload
sites is a hard block under Swift 6.3 + 6.4-dev.

**Q2**: `Kernel.Directory.Entry` keeps owned `[UInt8]`/`[UInt16]`
storage. The brief's lifetime concern about `readdir(3)` is already
mitigated by the existing owned-copy in `Stream.next()`. The
`nameView: Path.Borrowed` zero-allocation accessor already covers the
"borrowed when possible" use case; the `[Entry]` consumer in
`swift-posix Glob.listDirectory` requires Copyable Entry, which forces
owned storage.

**Q3**: `File.Name.rawBytes` is already `package`-scoped (correct).
Five byte-domain public accessors (`posixBytes`, `windowsCodeUnits`,
`withUnsafeUTF8Bytes`, `withUnsafeCodeUnits`, `withBytes` POSIX
variants) are deprecated and replaced by a single platform-agnostic
code-unit accessor. `Kernel.Directory.Entry.rawName` stays public for
v1 (one known consumer in swift-posix Glob); Phase B SPI-gate is
scheduled after Glob migrates to `nameView`-based access.

**Q4**: No new L1 surface required by this refactor. Four
`String_Primitives.String` gaps (Equatable, Hashable, first-style
accessor, byte-array literal init) are documented for future
reference; conformance gaps (Equatable, Hashable per SE-0499) are
broadly useful at L1 and tracked as a separate skill-incorporation
candidate.

**Implementation path**: parallel API with `@available(deprecated)`,
Phase A self-contained in swift-file-system, Phase B coordinated with
swift-posix Glob migration. Total cascade ~14 files / ~32 sites.

---

## References

- `swift-institute/Research/path-type-ecosystem-model.md`
- `swift-institute/Research/2026-05-13-noncopyable-adoption-ecosystem-corners-audit.md`
- `swift-institute/Research/exported-chain-audit-string-primitives.md`
- `swift-institute/Research/file-path-type-unification-audit.md`
- `swift-foundations/swift-posix/Research/glob-layering-research.md`
- SE-0437 — `~Copyable` `Optional` / `Result`
- SE-0499 — Stdlib `Hashable`/`Equatable`/`Comparable` for `~Copyable`
  (Swift 6.4)
- `feedback_correctness_and_evergreen.md` (auto-memory)
