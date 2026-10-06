# github-release-source

**The same thing as `daukle/npm`'s `npm-dependency-ledger`, delivered the other way.** That example
reads its producer's manifest off disk with `daukle/path`; this one fetches a real release asset
with `daukle/github`. The producer manifest is byte-identical in both, so the only difference is how it
arrives.

```console
$ daukle sync
daukle: updated
```

That fetches `example/greeter@2.0.0` from a real release and writes `package.json`. The harness
then syncs a second time and compares every file in `expected/` byte for byte, which is where the
real assertion is.

## What to look at

**`[sources."example/greeter"]` names a repository and a version, not a URL.** The plugin builds
`https://github.com/daukle/examples/releases/download/greeter-2.0.0/daukle.toml` from `repo`,
`tag` and the default asset name. `tag = "greeter-{version}"` is a template because a release tag
is the producer's naming choice, not daukle's: this repository holds four examples and could not
tag one of them `2.0.0`.

**The asset name defaults to `daukle.toml` and is not written here.** A `source` block naming
`asset = "daukle.json"` fails at parse time with a message naming the format, which is the one
thing about this plugin a user is most likely to get wrong.

**This is the first consumer anywhere to resolve a real published manifest.** Every manifest writer
in daukle was proved against fixtures until this example existed, because nothing had published a
manifest asset. The resolver path had real releases from the start; the source path did not.

**The `github` plugin is pinned by COORDINATE**, since `daukle/github@1.0.0` was published on
2026-10-03. Until then this entry was a pinned URL and a digest, for the plain reason that
there was no coordinate to name. A `[plugins]` entry takes either shape, and the URL shape is
still here: `[resolvers.github]` pins a chunk that is not a release asset at all. **The digest
is what the two shapes have in common, and it is the digest rather than the coordinate that
pins the bytes.**

## How CI checks this example

No `task.txt`, so nothing is run: `test/run.sh` syncs twice and compares `expected/package.json`
byte for byte. The second sync is the assertion that applying twice equals applying once.

**It does a real network fetch every run**, unlike most examples here, whose network traffic is
plugin acquisition alone. That is why it carries `needs-tools` and is skipped unless
`DAUKLE_EXAMPLE_E2E=1` is set; CI sets it on every runner. A release deleted or retagged breaks this example and nothing else.

## What this example deliberately does not claim

**It does not exercise the cross-org case, which is the only genuinely untested one.** The producer
here is `daukle/examples` and so is the consumer: the same org publishes the manifest and reads it.
The case that has never run is a producer owned by someone who did not write the consumer, where
the manifest's author cannot be asked to change it. Nothing here covers that, and using our own
release looks identical to using a stranger's right up to the point where it does not.

**It does not install anything.** As with `npm-dependency-ledger`, `daukle sync` is a file edit and
`npm install` is still yours to run.
