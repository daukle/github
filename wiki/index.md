# daukle/github

A **source** and a **publisher** in one plugin. The source says where a producer manifest comes
from, and fetches it from a GitHub release asset; the publisher ships what a toolchain built as
assets on a GitHub release. **Both need `1.1.0` and `daukle 0.8.0`**; before that the publisher was
`daukle/github-release`, and its `[publish.github-release]` block is unchanged.

## Declaring the source

```toml
[plugins]
github = "daukle/github@^1.1"

[sources."example/greeter"]
kind = "github-releases"
repo = "daukle/github"
version = "2.0.0"
tag = "greeter-{version}"
```

## Source keys

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

## Declaring the publisher

```toml
[plugins]
github = "daukle/github@^1.1"

[toolchains.java]
main = "example.Greeter"

[publish.github-release]
from = "java"
repo = "example/greeter"
files = ["greeter.jar"]

[tasks."publish:github-release"]
dependsOn = ["java:jar"]
```

```sh
daukle publish                   # every destination the manifest declares
daukle publish github-release    # one of them
```

## That last block is the one to not leave out

**A publisher cannot order itself.** No plugin declares `build`, and a publisher cannot know the
toolchain's name until the manifest says `from`, so it may declare no `dependsOn` of its own. A
destination with nothing wired uploads whatever was last built, or fails on a file that is not
there.

## Publisher keys

| key | meaning |
| --- | --- |
| `from` | core's own, required: the toolchain whose derived directory the step runs in |
| `repo` | `owner/name` to release into. Required, and never guessed from the project id, which only resembles one |
| `files` | the files to upload, each spelled exactly, relative to that derived directory. `{version}` is interpolated |
| `tag` | the tag to create or add to. Defaults to `{version}` |
| `tokenEnv` | the NAME of the environment variable holding the token, never a token. Defaults to `GITHUB_TOKEN` |
| `notes` | the release body, used only when the release is created. Defaults to `<project> <version>` |

## The token

The manifest names a variable and daukle reads it, handing it to `gh` for that one process.
**Core never stores or prints a credential**: `--verbose` traces the tool, the arguments and the
directory, and never the environment. A variable that is empty or unset is refused by name, because
`gh`'s own message for a missing token does not say which variable daukle looked in.

## There are no globs

daukle runs no shell, so `build/libs/*.jar` would reach `gh` as a literal asterisk. Spell every
file; an asterisk is refused with that reason rather than passed on.

## What it cannot show you

**No test here publishes anything**, so "it uploads" is proven by use and not by the suite: the
cases assert the exact command from daukle's own trace, against a repository that does not exist.
`gh` checks the files before it contacts GitHub, so those runs make no network call at all.

**It pins one `gh`**, not a range: which Gradle or JDK a project builds with is the project's
decision, while `gh` is this plugin's own implementation detail and nothing you write names it.
