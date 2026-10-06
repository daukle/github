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
`https://github.com/daukle/github/releases/download/greeter-2.0.0/daukle.toml` from `repo`,
`tag` and the default asset name. `tag = "greeter-{version}"` is a template because a release tag
is the producer's naming choice, not daukle's: this repository also releases the plugin as `1.0.0`
and could not tag the manifest `2.0.0` beside it.

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

The `console` block above is the assertion: core's `tools/run-examples.sh` runs each `$ ` line and
requires the remaining lines in the output. It then syncs a second time and compares every file in
`expected/` byte for byte, which is the claim that applying twice equals applying once.

**It does a real network fetch every run**, unlike most examples here, whose network traffic is
plugin acquisition alone. That is why it carries `needs-tools` and is skipped unless
`DAUKLE_EXAMPLE_E2E=1` is set; CI sets it on every runner. A release deleted or retagged breaks this example and nothing else.

## The release it fetches is published from HERE

`producer/daukle.toml` beside this example is the file the release carries, and
`.github/workflows/publish-producer.yml` publishes it on a `greeter-*` tag. The two used to sit in
different repositories, where the published asset and any committed copy could legitimately differ;
in one repository a release and the file it was built from move together, so
`test/cases/release-asset-matches-producer` compares them and a difference is a defect.

**`daukle/npm`'s `npm-dependency-ledger` holds the same bytes**, because the pair's whole claim is
that one manifest arrives two ways. Nothing compares the two copies across repositories: each
example proves its own claim, and the file here is the one the release is built from.

## What this example deliberately does not claim

**It does not exercise the cross-org case, which is the only genuinely untested one.** The producer
and the consumer are now the same REPOSITORY, which is weaker still than when they were two
repositories of one org: the same release this example fetches is published from the directory
beside it.
The case that has never run is a producer owned by someone who did not write the consumer, where
the manifest's author cannot be asked to change it. Nothing here covers that, and using our own
release looks identical to using a stranger's right up to the point where it does not.

**It does not install anything.** As with `npm-dependency-ledger`, `daukle sync` is a file edit and
`npm install` is still yours to run.
