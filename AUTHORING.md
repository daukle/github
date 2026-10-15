# Authoring notes

`plugin.lua` and `lib/gh.lua` are the whole plugin, published together as one tar asset and acquired
by a `[plugins]` table entry naming `daukle/github@<range>`. **One chunk holds two capabilities**:
the `github-releases` SOURCE and the `github-release` PUBLISHER. Until `1.1.0` the publisher was its
own repository, `daukle/github-release`, because core refused a source beside `exec`; `daukle 0.8.0`
lifted that (`D-133`) and the two merged (`D-136`).

## Why one chunk may hold `exec` beside a source

**The grant is temporal, not per kind.** The chunk declares `exec` and `provision` for the
publisher, and core withholds both from the source's `load` by name (`daukle 0.8.0`), and from
everything outside a task or publish callback (`daukle 0.8.1`). So the source cannot start a process
even though its chunk may. `api = 2` is what makes a core older than `0.8.0` refuse this chunk by
name rather than with a declaration error.

## The source

Fetching a producer manifest published as a GitHub release asset. A source block needs `repo` and
`version`; `asset` defaults to `daukle.toml` and `tag` to `{version}`, with `{version}` substituted
into the tag template. The body is cached before the network is touched, and it is parsed inside
the cache producer as well as after it, so an unparseable body is never served from cache.

Both optional keys **raise on a wrong type**, which `daukle/c` does not do for its own optional
key. That difference is faithful to the C each replaced, and is stated here rather than inferred.

`DAUKLE_TOKEN` wins over `GITHUB_TOKEN`, so a daukle-specific token cannot be shadowed by whatever
the surrounding CI already exports.

## The coverage gap, stated rather than hidden

**This repository tests its validation and nothing else.** Four of the five assertions
`test_source_github.c` carried needed a local HTTP server: the release-asset URL it builds, the tag
template substitution, serving a second load from the cache, and refusing to serve one repository's
manifest for another. This plugin hardcodes `https://github.com/...` with no injectable base, so
none of the four can run offline, and daukle's suite must stay offline by spec section 7.

They are not lost. They are recoverable from history until someone needs them and cannot find them:

```sh
git -C /path/to/daukle show b77a2b0^:test/test_source_github.c
```

Closing this needs either an injectable base URL in the plugin or a live test gated behind an
environment variable and pointed at a real release. Neither is done. `D-9` in the daukle queue
tracks exactly this class of gap.

**One more thing nothing detects:** this plugin and `src/plugins_remote.c` in `daukle/daukle`
implement the same `DAUKLE_TOKEN` over `GITHUB_TOKEN` rule in two languages, and no test compares
them. If one changes, the other will not follow and nothing will say so.
## Conventions this repository is held to

These are set here because they are cheap to set at publication and expensive to change
afterwards. They apply to all five extracted plugins.

**An optional key with the wrong type.** Whether it raises is a per-plugin decision, not a rule:
`daukle/github` raises on a non-string `asset` or `tag`, `daukle/c` does not raise on its optional
`sha256`, and both are faithful to the C they replaced. Each repository states its own answer
rather than leaving the reader to infer one.

**Every error carries a `plugin.lua:<line>:` prefix.** Lua's `error()` adds it and the C this
replaced never had it. A test asserting on a message must assert on a clause, never on a token that
could also appear in the file path the message echoes.

## Tests

`test/cases.sh` runs every directory under `test/cases/` against a real daukle, because this
plugin's output is a host verb's formatting and a stub of that verb would be testing the stub.

- a case with `expected/` must sync cleanly and match every file in it, byte for byte
- a case with `expect-error.txt` must fail with a message carrying that clause
- every success case is synced **twice** and must match after both, so applying twice equals
  applying once for every case rather than only the one that remembered to say so
- a case whose `expected/` is empty is a failure, not a pass

```sh
DAUKLE=/path/to/daukle sh test/cases.sh
```

With no `DAUKLE`, the runner looks for a build under `.daukle/`, which is where CI checks
`daukle/daukle` out. **A source case names its plugin as `./plugins`, a directory**: the chunk
requires `lib/gh`, and a plugin named as a single file has no modules.

The publisher's cases live apart, under `test/publish/`, with their own runner and the pin check,
because their layout differs (a fixture toolchain and a `task` file per case) and merging the two
runners would change what each case proves. Run them with `DAUKLE_PUBLISH_E2E=1` to include the one
that provisions `gh`.

`.gitattributes` pins `* -text`, and it is load bearing rather than tidy. daukle writes LF on every
platform, so a checkout under `core.autocrlf=true` rewrites the fixtures and the byte-exact cases
fail on Windows for a reason that has nothing to do with the plugin. Measured on Windows, not
assumed: removing the file and re-checking out reproduces the failures.

## The publisher: what core does and does not do with the token

**Measured 2026-10-13 rather than assumed, because the design depended on it.** Core's credential
handling is narrower than "an env allowlist":

- **`daukle.env` gates exactly two names**, `DAUKLE_TOKEN` and `GITHUB_TOKEN` (`CORE_CREDENTIALS`,
  `src/lua/lua_verbs.c:67`), and refuses them unless the chunk declares them in `env`. **Any other
  name is readable undeclared**, which is what makes a free-form `tokenEnv` work at all.
- **A child process is scrubbed of those same two names, and only when undeclared**
  (`fr_lua_verbs_env_to_scrub`). This plugin declares both, so neither is scrubbed and `gh` also
  inherits an ambient `GITHUB_TOKEN`.
- **`report_verbose_exec` prints the tool, the argv and the cwd and never the environment**
  (`src/lua/lua_verbs.c:1013`), which the publishing spec turned from an accident into a
  requirement. The composing test case depends on it.

**So the refusal for an empty `tokenEnv` is worth its lines**: a project with an ambient
`GITHUB_TOKEN` would otherwise publish through inheritance while the key the manifest names was
unset, which is a success nobody asked for.

## The archive layout is NOT uniform, and Windows is the odd one

**Measured against all three shapes on 2026-10-13, because assuming they agreed would have failed on
the host this was written on:**

| asset | layout |
| --- | --- |
| `gh_<v>_linux_<arch>.tar.gz` | `gh_<v>_linux_<arch>/bin/gh` |
| `gh_<v>_macOS_<arch>.zip` | `gh_<v>_macOS_<arch>/bin/gh` |
| `gh_<v>_windows_amd64.zip` | **`bin/gh.exe`, no leading component at all** |

The unpacker strips nothing, so `lib/gh.lua` returns a full `executable` path rather than a `home`
for the caller to concatenate. That keeps the asymmetry at the table boundary instead of leaking it
into `plugin.lua`, and it is why this table's shape differs from `daukle/java`'s `lib/jdks.lua`.

**There is no `windows/aarch64` asset**, so that host is refused by name.

## `lib/gh.lua` is NOT exported

`exports` on `daukle.plugin{}` governs what ANOTHER plugin may require; a chunk's own
`daukle.require("lib/gh")` needs no entry. `daukle/java` exports `lib/jdks` because `daukle/gradle`
consumes it; nothing consumes this table, and it is an implementation detail rather than a surface.

## Create versus upload is decided by looking

`gh release create` fails if the release exists; `gh release upload` fails if it does not. The step
runs `release view` first with `check = false`, which returns the exit code instead of raising, and
branches on it. **`check = false` is what makes this possible at all**: there is no `pcall` in the
sandbox, so a raising exec could not be recovered from and the plugin would have had to ask the user
which command to run.

## The publisher's tests, and what they deliberately do not cover

`test/publish/cases.sh` runs every directory under `test/publish/cases/` against a real daukle.
`test/publish/pins.sh` checks every row of `lib/gh.lua` against the `checksums.txt` the release
publishes, **fails on a row it cannot parse** rather than skipping it, and both negative controls
were run: a wrong digest fails, and a row with no digest fails to parse.

**NOTHING PUBLISHES, on any runner, ever.** The composing case asserts the argv from daukle's own
`--verbose` trace, which is printed before the exec, with `--repo` naming a repository that does not
exist.

**Measured while writing that case, and it makes the case safer than designed**: `gh` validates the
asset file locally *before* contacting GitHub (`no matches found for 'greeter.jar'`), so the case
fails without a single network call. **What that also means is that no test reaches the API**, so
"the command is well formed enough for GitHub to answer it" is unverified here, and so is any
upload. The first real upload will be a release of something, under the STOP point.

**A case's `expect-error.txt` holds ONE clause, not several.** The harness reads the whole file and
greps `-F`, which treats several lines as alternatives, so a two-line file asserts an OR while
reading like an AND. `expect-output.txt` is the one that loops per line. Measured in
`daukle/gradle`'s harness while writing a two-line expectation there.

**The fixture toolchain is the smallest thing that satisfies `from`.** A publish step runs in a
toolchain's derived directory and carries its context, so a publisher cannot be exercised without a
declared toolchain; `test/publish/cases/*/fixtures/toolchain.lua` declares one that builds nothing.
