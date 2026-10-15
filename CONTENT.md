## What this plugin is

One plugin, two capabilities: a `daukle.source` that fetches a producer's manifest from a GitHub
release, and a `daukle.publisher` named `github-release` that uploads what your build produced to
one. A source answers one question, **where does a producer's manifest come from**, and this one
answers it with a GitHub release asset: it builds the download URL from the repository, the version
and a tag template, and fetches `daukle.toml` from the release.

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

## Publishing to a GitHub release

The publisher takes files a toolchain built and uploads them as assets on a GitHub release, through
a `gh` it provisions and pins by sha256. Your repository holds `daukle.toml` and sources, and no
publishing plugin, no `gh` on the host and no token in any file.

```toml
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

### A publisher cannot order itself, and this is the one thing to read

**No plugin declares `build`, and a publisher may declare no `dependsOn` of its own**, because it
cannot know the toolchain's name until the manifest says `from`. So a destination with nothing wired
uploads whatever was last built, or fails on a file that is not there. The `[tasks."publish:..."]`
block above is not decoration.

### The token is a variable name, never a token

`tokenEnv` names an environment variable and defaults to `GITHUB_TOKEN`. daukle reads it, hands it
to `gh` as `GH_TOKEN` for that one process, and **core never copies, stores or prints a credential**:
`--verbose` traces the tool, the argv and the directory, and never the environment.

A variable that is empty or unset is refused by name before anything runs, because `gh`'s own
message for a missing token says nothing about which variable daukle looked in.

### Which command runs is the forge's answer, not a key

`gh release create` fails if the release exists and `gh release upload` fails if it does not, so
asking you to state which one applies would be asking for something the forge already knows. The
step looks first, then creates the release or adds to it with `--clobber`.

A release created here always carries a note, defaulting to the project and version, because `gh`
opens an editor when a release is created with no body, and in CI that is a job that hangs rather
than one that fails.

### There are no globs

daukle runs no shell, so `build/libs/*.jar` reaches `gh` as a literal asterisk. Spell every file,
and interpolate a version with `{version}`, which is substituted in `files` and in `tag` from the
manifest's own `version`. An asterisk is refused with that sentence rather than left to `gh`.

| key | meaning |
| --- | --- |
| `from` | core's own, required: the toolchain whose derived directory the step runs in |
| `repo` | `owner/name` to release into. Required, and never guessed from the project id, which only resembles one |
| `files` | the files to upload, each spelled exactly, relative to that derived directory |
| `tag` | the tag to create or add to, `{version}` interpolated. Defaults to `{version}` |
| `tokenEnv` | the NAME of the variable holding the token. Defaults to `GITHUB_TOKEN` |
| `notes` | the release body, used only when the release is created. Defaults to `<project> <version>` |

### What it does not do

**It does not check that a file exists**, and cannot: there is no listing verb, `daukle.read` raises
rather than returning nothing, and the sandbox has no `pcall`, so the only route is to let `gh`
report it. It reports it before contacting GitHub.

**It does not publish to Maven, or to GitHub Packages.** A second destination is a second publisher.

**It pins ONE `gh`, not a range**, unlike a toolchain's version table. Which Gradle or JDK a project
builds with is the project's decision and belongs in its manifest; `gh` is this plugin's own
implementation detail, and nothing a user writes names it.

## Where the rest is

The keys, their defaults, the type errors they raise and the token precedence live in this
repository's `wiki/index.md`, which is rendered at <https://daukle.github.io/guide/>.
`AUTHORING.md` is the measured detail for anyone changing the plugin, and `examples/` holds a
project that resolves a real published release.
