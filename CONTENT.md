## What this plugin is

A `daukle.source` named `github`. A source answers one question, **where does a producer's manifest
come from**, and this one answers it with a GitHub release asset: it builds the download URL from
the repository, the version and a tag template, and fetches `daukle.toml` from the release.

It is the shape to use when the producer is a real project that publishes, rather than a directory
sitting next to yours. For the latter, use `daukle/path`.

## The tag is a template because a tag is the producer's choice

`tag = "greeter-{version}"` exists because a release tag belongs to whoever publishes it, not to
daukle. A repository holding several producers cannot tag one of them `2.0.0`, so the template is
the only form that works for both the single-producer and the multi-producer case.

## Caching comes before the network

A manifest already fetched is served from the cache without a request, so a build that resolves the
same producer twice reaches GitHub once. `DAUKLE_TOKEN` is honoured over `GITHUB_TOKEN` for a
private repository, which lets a build read a producer it is allowed to read without borrowing
whatever token the surrounding CI happens to export.

## Where the rest is

The keys, their defaults, the type errors they raise and the token precedence live in this
repository's `wiki/index.md`, which is rendered at <https://daukle.github.io/guide/>.
`AUTHORING.md` is the measured detail for anyone changing the plugin, and `examples/` holds a
project that resolves a real published release.
