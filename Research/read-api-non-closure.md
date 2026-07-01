# Read API: Non-Closure (Owning Return)

<!--
---
version: 2.1.1
last_updated: 2026-06-26
status: RECOMMENDATION
tier: 2
scope: package (swift-file-system); rests on cross-package ecosystem decisions
trigger: HANDOFF-swift-file-system-read-non-closure.md (deferred from the closed swift-linter type-strengthening arc, 5722b5b)
rests_on:
  - swift-institute/Research/nonescapable-support-memory-storage-buffer.md (DECISION — owners must not be ~Escapable; vend .span)
  - swift-institute/Research/yielding-vs-returning-lifetime-models.md (RECOMMENDATION — dual model)
  - swift-institute/Research/apple-http-outputspan-writer-pattern.md (REFERENCE — write analog keeps closures, adds non-closure)
verification: all file:line claims read against live source 2026-06-25; type-system + toolchain claims swiftc-verified on Apple Swift 6.3.2; no source change made (investigation-only)
changelog:
  - v1.0.0 (2026-06-25): recommended a single non-closure full() -> [Byte]. SUPERSEDED — the eager [Byte]
    answer never addressed "potentially very large" content, and principal direction is to build on the
    institute data-structure tower rather than stdlib [Byte].
  - v2.0.0 (2026-06-25): tiered two-method model — full() -> Array<Byte> (eager, institute-native) plus
    mapped() -> Memory.Map (lazy, demand-paged) for large content; both vend Span<Byte> via Span.Protocol.
    Records the generic "merge full+mapped via a strategy generic" alternative as VERIFIED-FEASIBLE
    (3/4 shapes typecheck on 6.3.2) but DEFERRED, and the toolchain finding that async mapped() is blocked.
  - v2.1.0 (2026-06-25): the async-mapped block is toolchain-GATED, not permanent — SE-0528 Continuation
    (withContinuation, Success: ~Copyable, sending return, typed throws) resolves it; verified by clean
    swiftc compile of a run<T: ~Copyable> rewrite on the Swift 6.5-dev snapshot. Recorded the upstream
    swift-threads improvement path (gated on 6.4+ adoption + the @available OS gate).
  - v2.1.1 (2026-06-26): implementation DEFERRED by principal — recommendation is complete and stands.
    Status remains RECOMMENDATION (ready + parked, NOT blocked/awaiting-info). full() + sync mapped() are
    implementable on 6.3.2 whenever picked up; only the async-mapped/withContinuation rider is 6.4-gated.
---
-->

## Context

`swift-file-system`'s full-file read is **closure-only**. `File.Read.full` has four overloads
(`Sources/File System/File.Read.swift:67,80,98,116`), each `(Swift.Span<Byte>) -> R`. `Swift.Span` is
`~Escapable`, so a caller that wants to **keep** the bytes must hand-copy the span out via a manual
index walk (`Span` is not a `Sequence`; neither `Array(span)` nor `for x in span` compiles). swift-linter
carries this boilerplate at two file-read sites (`Lint.Run.swift:198-213`,
`Lint.File.Single.swift:92-106`). The `file.read.full()` / `full(as: String.self)` shown in the doc
comments (`File.Read.swift:23-24,135-136`) are **aspirational — no such overload exists today**.

The principal's requests (deferred from the closed swift-linter arc, `5722b5b`):
1. A **non-closure** read the caller can bind.
2. Reads return **BYTES, not `String`** — text decode left to the caller.

A third constraint surfaced during this investigation and is now first-class: **content is potentially
very large.** That reframes the problem — see below.

## Question

1. **Return type(s)** for a non-closure read, given the owner/view rules and large-content concern.
2. **Request 2:** the bytes-returning shape; does the package own any `String` decode?
3. **Closures: keep or drop?**
4. **Typed-error story** preservation.
5. **Should one *generic* read merge the eager and large-content paths**, with the generic selecting the
   backing and the result type?

## Analysis

### The governing model — three read tiers by ownership

A "read" is a question of *who owns the bytes and for how long*. There are three honest tiers, and the
"very large" concern is decided by **footprint**, which is orthogonal to the ownership keyword:

| Tier | Owner | Footprint | Use |
|------|-------|-----------|-----|
| **Borrow** (today's closures) | the library, during the call | none kept | compute a derived `R` over the bytes without keeping them (checksum, parse-in-place) |
| **Own-eager** (`full()`) | the caller, one heap buffer | **whole file in RAM** | "I want it all, it fits" |
| **Map-lazy** (`mapped()`) | the caller, an mmap handle | **proportional to pages touched** | "potentially very large" |

The decisive correction this investigation produced: **`~Copyable` discipline does not address large
content** — a move-only heap buffer (`Storage.Contiguous<Byte>`) still allocates the entire file, same
peak RAM as `[Byte]`. Only *not materializing the file* — memory-mapping (Tier 3) — makes "very large"
cheap. So the large-content requirement is answered by a distinct tier, not by re-typing the eager read.

### Q1/Q5 — Return types: `full() -> Array<Byte>` (eager) + `mapped() -> Memory.Map` (lazy)

The owner/view rule (`nonescapable-support-memory-storage-buffer.md`, DECISION): *"Owners MUST NOT be
`~Escapable`"* — an owning return stays `Escapable` and **vends `.span`**, never is a span itself. Both
tier types obey this and meet at one capability — **`Span.\`Protocol\`** (`swift-span-primitives`),
which both conform to and which vends `Swift.Span<Byte>`:

**Eager → institute `Array<Byte>` (Array_Primitives), NOT stdlib `[Byte]`, NOT `Storage.Contiguous`.**
- `Array` conforms `Span.\`Protocol\`` (`swift-array-primitives/.../Array.Conformances.swift:50`:
  `extension Array: Span.\`Protocol\` where S: Span.\`Protocol\` & ~Copyable`), so it vends `.span`.
- It is the **tower's user-facing ADT rung**. `Storage.Contiguous<Byte>` (the move-only contiguous
  *leaf*) is a building block "beneath collections" per its own README — exposing it raw from a Layer-3
  read is a Layer-1 leak (flagged by every reviewer), and its real spelling carries an allocator generic
  (`Storage<Memory.Heap>.Contiguous<Byte>`). Use the ADT rung.
- For `Byte` (Copyable), `Array<Byte>` is Copyable — semantically ≈ `[Byte]`, but institute-native and
  `Span.\`Protocol\``-conforming. This is the deliberate choice over stdlib `[Byte]` (principal
  direction: build on the institute tower; `[Byte]` was the v1.0.0 recommendation, superseded).

**Lazy → `Memory.Map` (swift-memory-map-primitives).**
- `~Copyable` owner of the kernel mapping + `munmap` witness (`Memory.Map.swift:40`), conforms
  `Span.\`Protocol\`` with `Element == Byte`, vends `span: Swift.Span<Byte>` under `@_lifetime(borrow self)`
  (`Memory.Map+Span.Protocol.swift:25-46`). Demand-paged: a 10 GB file costs ~no RAM until pages are
  touched through `.span`. This is the large-content answer, and it is exactly where the
  `~Copyable`/`~Escapable`/Span machinery earns its keep.
- Construction goes through `Memory.Map.File` + the platform mmap (POSIX via the kernel/ISO_9945 stack
  swift-file-system already depends on); typed error is `Memory.Map.Error` (`Memory.Map.Error.swift:16`).

These two do **not** fuse at the storage level and should not: `Memory.Map.Region` is not a
`Memory.Region` (it carries `length`, not `capacity`, and is Copyable not `~Copyable`), and an mmap is
pre-populated file pages, not an element-lifecycle region. They unify only at `Span.\`Protocol\``.

### Q5 — Why NOT a generic merge (verified feasible, deferred)

The merge — one generic read whose strategy type-parameter selects the backing and determines the
result type — was **empirically tested**: a minimal model of each shape was `swiftc -typecheck`-ed on
Apple Swift 6.3.2 with the institute experimental flags (Lifetimes, LifetimeDependence,
SuppressedAssociatedTypes, Swift 6). **3 of 4 shapes typecheck** — a generic function *can* return an
associated `~Copyable` output, throw an associated typed error, and have both an `Array<Byte>` owner and
a `Memory.Map` owner conform to the `~Copyable & ~Escapable` span protocol. So the merge is **expressible
— not a type-system limitation.** (The one failing shape over-exposed a public `init(descriptor:)`.)

It is nonetheless **deferred**, because it does not earn its complexity for a *closed two-backing set*:

- The headline payoff — a uniform `.span` regardless of backing — **does not need the merge.** Both
  return types already conform `Span.\`Protocol\``, so a *consumer-side* generic
  `func f<R: Span.\`Protocol\`>(_ r: borrowing R) where R.Element == Byte` gets the uniformity from two
  plain methods. The merge moves genericity to the wrong side (the producer).
- Eager-vs-mmap is a **static** choice with sharply divergent semantics (OOM vs SIGBUS-on-truncation;
  different lifetime and cost) — never runtime-polymorphic. Collapsing it under one defaulted name hides
  the distinction the call site should advertise, and reusing `full` for the lazy path is a misnomer.
- Two methods keep typed throws crisp (each a flat `Failure`, no `Either`-nesting threaded through an
  associated `S.Failure`) and let the async surface differ where it should (see Q4).

The generic earns its machinery only under (a) 3+/open third-party strategies, (b) a shared algorithm
parameterized by policy, or (c) downstream code that must stay generic over an unknown backing — none of
which hold; the heap/mmap seam is deliberately closed. **Escalation path** if that changes: the
value-carrying strategy generic, renamed off `full` to a backing-neutral verb:

```swift
public protocol File.Read.Strategy {
    associatedtype Output: Span.`Protocol`, ~Copyable where Output.Element == Byte
    associatedtype Failure: Swift.Error
    func load(from path: File.Path) throws(Failure) -> Output
}
public func contents<S: File.Read.Strategy>(_ strategy: S = File.Read.Eager()) throws(S.Failure) -> S.Output
// File.Read.Eager.Output = Array<Byte>;  File.Read.Mapped.Output = Memory.Map  (NOT Storage.Contiguous)
```

### Q2 — Request 2: bytes, not `String`

Both `full() -> Array<Byte>` and `mapped() -> Memory.Map` vend bytes; the package owns **no** `String`
decode and should not — the decode *failure policy is the caller's*. **Do NOT add `full(as: String.self)`.**
The caller decodes from the vended `Span<Byte>` / collection, exactly as swift-linter does today over a
byte collection: `Swift.String(validating: bytes, as: UTF8.self)` (`Lint.Run.swift:211`) /
`Swift.String(decoding: bytes, as: UTF8.self)` (`Lint.File.Single.swift:105`). The aspirational
`full(as: String.self)` DocC and the non-compiling `Array(span)` examples
(`File.Read.swift:53-54`, `File.System.Read.Full.swift:105-106`) must be **corrected**.

### Q3 — Closures: ADDITIVE

Keep all four closure overloads; the two owning returns are additive. Per Apple's write analog
(`apple-http-outputspan-writer-pattern.md`: closure primary, non-closure additive) and the
yielding/returning dual model (closures dominate 21:1; both needed). Zero-arg `full()` / `mapped()` carry
no closure, so `full { … }` still binds the closure forms — no resolution conflict. The closures
deliberately keep handing the `~Escapable` `Swift.Span<Byte>` so the compiler prevents the body from
squirreling the view away.

### Q4 — Typed errors, and why `mapped()` is sync-only

| Method | Throws |
|--------|--------|
| `full()` sync | `File.System.Read.Full.Error` |
| `full()` async | `Either<Kernel.Thread.Pool.Error, File.System.Read.Full.Error>` |
| `mapped()` sync | `Memory.Map.Error` |

`full()` keeps both sync and async: `Array<Byte>` is Copyable + Sendable, so it passes cleanly through
`Kernel.Thread.Pool.run`'s `sending T` return, and the async form genuinely offloads a large blocking
read to the pool.

**`mapped()` is sync-only — a *toolchain-gated* limitation on 6.3.2, not permanent.** An async `mapped()`
would have to return the `~Copyable` `Memory.Map` through `Kernel.Thread.Pool.run`. That return is
`sending T` (`Kernel.Thread.Pool+Run.swift:17,47` — no `T: Sendable` needed) but `T` is **Copyable-bound**
(no `~Copyable` suppression), and the implementation hands the value back via stdlib
`withCheckedContinuation`, which is itself Copyable-constrained on 6.3.2 (`swiftc` note: *"'where T:
Copyable' is implicit here"*). The institute's own `Async.Completion` does not help — it is
`Completion<Success: Sendable, …>` wrapping the same `CheckedContinuation` + `Result`, so it inherits the
Copyable wall. So a `~Copyable` return cannot cross the pool **on 6.3.2**. It is also currently
**unnecessary**: `mmap()` is a cheap, non-blocking syscall (it maps page tables; data faults in lazily on
`.span` access), so there is no blocking read to offload.

**Upstream resolution path (verified, gated on 6.4+ adoption).** SE-0528 `Continuation` lifts this. Its
new `Continuation<Success, Failure>` struct is `~Copyable` with `Success : ~Copyable`, and the
`withContinuation` / `withContinuation(of:throwing:)` entry points return `sending Success` with typed
throws — *distinct from* the old `withCheckedContinuation`, which stays Copyable-bound even on 6.5-dev.
A faithful `run<T: ~Copyable>(_ op: sending @escaping () -> T) async -> sending T` rewrite (continuation
consumed into a worker `Task`, `resume(returning: consuming sending T)`) **compiles clean on the Swift
6.5-dev snapshot** (`@available`-gated only). So when the institute moves to a 6.4+ toolchain (SE-0528 is
already its `Async.Completion` convergence item per `swift-institute/Research/tower-research-arc-riders-2026-06-10.md`),
`Kernel.Thread.Pool.run` SHOULD adopt `withContinuation`, which unblocks `~Copyable` `sending` returns
through the pool generally (async `mapped()` becomes possible — though still low-priority on its own merits,
per the cheap-syscall point above). Two gates remain: the 6.4+ toolchain, and the API's `@available(… 9999)`
OS gate (all entry points are `@_alwaysEmitIntoClient`, so back-deployment *may* be available — confirm at
adoption). [Verified: 2026-06-25, swift-6.5-dev snapshot 2026-05-27-a — see `Async.Completion.swift:58`,
`_Concurrency.swiftinterface` lines 199/238/250, and the swiftc compile probe.]

## Verified findings

| Claim | Evidence |
|-------|----------|
| Closure core already materializes the owned bytes then discards them | `File.System.Read.Full.swift:154-161` (`let buffer:[Byte] = try readAll(...); return body(buffer.span)`) |
| Owning-return precedent in-package | `File.Handle.read(count:) -> [Byte]` (`File.Handle.swift:79`) |
| `Array` conforms `Span.\`Protocol\`` (uniform `.span`) | `swift-array-primitives/.../Array.Conformances.swift:50` |
| `Memory.Map` is `~Copyable`, vends `Span<Byte>`, error `Memory.Map.Error` | `Memory.Map.swift:40`, `Memory.Map+Span.Protocol.swift:25-46`, `Memory.Map.Error.swift:16` |
| Heap and mmap don't fuse at storage (`Memory.Map.Region` ≠ `Memory.Region`) | `Memory.Map.Region.swift:32-45` vs `Memory.Region.swift:34-40` |
| Generic merge typechecks (3/4 shapes) on Swift 6.3.2 | swiftc probes, this session (institute flags) |
| Async `mapped()` blocked **on 6.3.2**: `run` is `sending T` but Copyable-bound; `withCheckedContinuation` Copyable-constrained; `Async.Completion` inherits it | `Kernel.Thread.Pool+Run.swift:17,47`; swiftc note *"'where T: Copyable' is implicit"*; `Async.Completion.swift:58` |
| **Resolvable on 6.4+**: SE-0528 `Continuation<Success: ~Copyable, …>` + `withContinuation` (`sending Success`, typed throws) — a `run<T: ~Copyable>` rewrite compiles clean on 6.5-dev (`@available`-gated). Old `withCheckedContinuation` stays Copyable-bound even on 6.5-dev. | `_Concurrency.swiftinterface:199,238,250` (swift-6.5-dev snapshot); swiftc compile probe 2026-06-25 |

## Outcome

**Status: RECOMMENDATION** (implementation gated on a separate sign-off per the handoff).

**Disposition — DEFERRED (2026-06-26):** the principal has parked the implementation. The recommendation
is complete and ready; this is a deliberate defer, **not** a block (status stays RECOMMENDATION rather
than DEFERRED because nothing here awaits new information — it awaits a decision to build). `full()` +
sync `mapped()` are implementable on the current 6.3.2 toolchain whenever the work is picked up; only the
async-`mapped()` `withContinuation` rider is gated on the institute's move to a 6.4+ toolchain (≈ fall 2026).
Pick-up is a fresh decision.

Add, on `File.Read`, **two owning-return methods** alongside the four (kept) closure overloads:

```swift
// Eager — whole file into an owned institute Array<Byte> (Array_Primitives); conforms Span.`Protocol`.
public func full() throws(File.System.Read.Full.Error) -> Array<Byte>
public func full() async throws(Either<Kernel.Thread.Pool.Error, File.System.Read.Full.Error>) -> Array<Byte>

// Lazy — demand-paged mmap; ~Copyable owner, vends .span; sync-only (async blocked + unnecessary).
public func mapped() throws(Memory.Map.Error) -> Memory.Map
// Optional refinement: mapped(advise: Memory.Map.Advice) — Advice constants are platform-package-provided.
```

Consumers get a uniform surface without any merged method: hold the owner and walk `.span`, or write one
generic helper `f<R: Span.\`Protocol\`>(_:) where R.Element == Byte`. The generic-merge `contents<S:>` is
recorded above as verified-feasible-but-deferred.

**New dependencies** (the deliberate cost of institute-native + large-content): `swift-array-primitives`
(eager return; pulls the storage tower transitively) and `swift-memory-map-primitives` (mapped). If the
array-primitives dep weight is ever a concern, stdlib `[Byte]` remains the zero-dep eager fallback that
`[DS-021]` sanctions for data-shaped values — but the chosen direction is institute-native.

### Implementation notes (for the later, gated change)

- New non-closure core `File.System.Read.Full.read(from:) -> Array<Byte>` returning the bytes the existing
  `readAll` produces; refactor the closure core to delegate (`let bytes = try read(from:); return body(bytes.span)`) to dedup open/stat/isDirectory/empty/EINTR.
- Single-allocation read: build the `Array<Byte>` storage directly (uninitialized-capacity + `pread` into
  it) instead of `readAll`'s current raw-buffer-then-`Array(...)` second copy (`File.System.Read.Full.swift:206,235`).
- `mapped()` constructs via `Memory.Map.File` + the platform mmap; confirm the exact constructor + the
  `advise:` default in-package.
- Correct the aspirational DocC (`full(as: String.self)`, `Array(span)`) and sweep `[UInt8]` → `[Byte]` in
  `File System Core/Documentation.docc/Type-Design-Analysis.md`.

### Expected consumer benefit (illustrative — swift-linter is do-not-touch)

- `Lint.File.Single.contents(of:)` → `Swift.String(decoding: try File(path).read.full(), as: UTF8.self)`.
- `Lint.Run.parsedSource` drops its 5-line copy closure for `bytes = try file.read.full()`.
- The third swift-linter copy site (`Linter CLI.swift:96-116`) is **not** fixed by this — it's a
  `Kernel.Directory.Working.withCurrentBytes` getcwd over `Span<UInt8>` in **swift-kernel**; an analogous
  owning-return gap for that package, flagged not addressed.

## References

- `Sources/File System/File.Read.swift` — closure overloads (`:67,80,98,116`), accessor (`:142`), aspirational DocC (`:23-24,53-54,135-136`).
- `Sources/File System Core/File.System.Read.Full.swift` — sync core (`:115`), `body(buffer.span)` (`:154-161`), `readAll` (`:202-236`), `Error` (`:25-34`).
- `Sources/File System Core/File.Handle.swift:79` — `read(count:) -> [Byte]` precedent.
- `swift-array-primitives/.../Array.Conformances.swift:50` — `Array: Span.\`Protocol\``.
- `swift-memory-map-primitives/.../Memory.Map.swift:40`, `Memory.Map+Span.Protocol.swift:25-46`, `Memory.Map.Error.swift:16`, `Memory.Map.Advice.swift:20`.
- `swift-threads/Sources/Thread Pool/Kernel.Thread.Pool+Run.swift:17,47` — `sending T`, Copyable-bound.
- swift-linter consumer sites: `Lint.Run.swift:198-213`, `Lint.File.Single.swift:92-106`, `Linter CLI.swift:96-116`.
