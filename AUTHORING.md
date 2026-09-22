# Authoring notes

`plugin.lua` is the whole plugin. It is published as a release asset and acquired by a `[plugins]`
table entry naming `daukle/github@<range>`.

## What this plugin owns

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

`test/run.sh` runs every directory under `test/cases/` against a real daukle, because this
plugin's output is a host verb's formatting and a stub of that verb would be testing the stub.

- a case with `expected/` must sync cleanly and match every file in it, byte for byte
- a case with `expect-error.txt` must fail with a message carrying that clause
- every success case is synced **twice** and must match after both, so applying twice equals
  applying once for every case rather than only the one that remembered to say so
- a case whose `expected/` is empty is a failure, not a pass

```sh
DAUKLE=/path/to/daukle sh test/run.sh
```

With no `DAUKLE`, the runner looks for a build under `.daukle/`, which is where CI checks
`daukle/daukle` out.

`.gitattributes` pins `* -text`, and it is load bearing rather than tidy. daukle writes LF on every
platform, so a checkout under `core.autocrlf=true` rewrites the fixtures and the byte-exact cases
fail on Windows for a reason that has nothing to do with the plugin. Measured on Windows, not
assumed: removing the file and re-checking out reproduces the failures.

