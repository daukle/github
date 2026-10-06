# daukle/github

A **source**: it says where a producer manifest comes from. This one fetches it from a GitHub
release asset.

## Declaring it

```toml
[plugins]
github = "daukle/github@^1"

[sources."example/greeter"]
kind = "github-releases"
repo = "daukle/github"
version = "2.0.0"
tag = "greeter-{version}"
```

## Keys

| key | meaning |
| --- | --- |
| `repo` | required, `owner/name` |
| `version` | required |
| `asset` | defaults to `daukle.toml` |
| `tag` | defaults to `{version}`, with `{version}` substituted into the template |

Both optional keys **raise on a wrong type**.

## Caching and tokens

The body is cached before the network is touched, and it is parsed **inside** the cache producer as
well as after it, so an unparseable body is never served from cache.

`DAUKLE_TOKEN` wins over `GITHUB_TOKEN`, so a daukle-specific token cannot be shadowed by whatever
the surrounding CI already exports. A plugin may only read a variable it declared.

## A coverage gap, stated rather than hidden

This repository tests its validation and little else. The release-asset URL it builds, the tag
substitution, serving a second load from cache and refusing one repository's manifest for another
all need a local HTTP server, and this plugin hardcodes `https://github.com/...` with no injectable
base. Closing it needs either that base or a live test gated behind an environment variable.
