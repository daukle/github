--- Which `gh` this plugin provisions, per host, and the digest it is pinned by.
---
--- @implNote one version rather than a range, unlike a toolchain's table: the
--- Gradle or JDK a project builds with is the project's decision and belongs in
--- its manifest, while `gh` is this plugin's own implementation detail. Nothing
--- a user writes names it, so there is nothing to range over.

-- Transcribed from the checksums.txt the cli/cli release publishes beside the
-- assets. NEVER computed from a file on disk, for the reason daukle/java's
-- lib/jdks.lua gives: a digest taken from a working tree is a digest of
-- whatever the checkout did to it.
local VERSION = "2.102.0"

local DIGESTS = {
  ["linux/x86_64"]   = "bb766f710eef8ede859c18578c72c327597cd4c8a85b06001b1f3843c6019386",
  ["linux/aarch64"]  = "7862c86c72f43df3a2d93ddde6f473285b4e2af61b494849846827e513ef6484",
  ["macos/x86_64"]   = "b245f24eb2bf5f75b426b4c26da3651a107f8d5b6f4fddfbfccc5679041378b3",
  ["macos/aarch64"]  = "da922c20d1792e5b2cbf375593d7a658acf034c12c84e007e71c76ef959c337e",
  ["windows/x86_64"] = "ae64e556ecc240b200f7eba60d550e4bb60d78e860e69dd88c449405b86067f4",
}

local ASSET_OS = { linux = "linux", windows = "windows", macos = "macOS" }
local ASSET_ARCH = { x86_64 = "amd64", aarch64 = "arm64" }
local ASSET_EXT = { linux = "tar.gz", windows = "zip", macos = "zip" }

local function asset_name(os_name, arch)
  return string.format("gh_%s_%s_%s.%s", VERSION, ASSET_OS[os_name], ASSET_ARCH[arch],
                       ASSET_EXT[os_name])
end

--[[ MEASURED against all three archive shapes on 2026-10-13, because they do
     not agree and assuming they did would have failed on the host this was
     written on. The linux tarball and the macOS zip each carry a
     gh_<version>_<os>_<arch>/ directory; the WINDOWS zip has no leading
     component at all and holds bin/gh.exe at its root. The unpacker strips
     nothing, so the difference has to be answered here rather than by the
     caller concatenating a home. ]]
local function executable_path(os_name, arch)
  if os_name == "windows" then return "bin/gh.exe" end
  return string.format("gh_%s_%s_%s/bin/gh", VERSION, ASSET_OS[os_name], ASSET_ARCH[arch])
end

local function hosts()
  local keys = {}
  for key in pairs(DIGESTS) do keys[#keys + 1] = key end
  table.sort(keys)
  return table.concat(keys, ", ")
end

local function for_host(request)
  local os_name = request.os
  local arch = request.arch
  local key = tostring(os_name) .. "/" .. tostring(arch)

  if DIGESTS[key] == nil then
    error(string.format('no pinned gh for %s. This plugin pins %s, and publishing needs a tool it'
                        .. ' can verify, so a host gh is not used instead', key, hosts()), 0)
  end

  return {
    version = VERSION,
    url = "https://github.com/cli/cli/releases/download/v" .. VERSION .. "/"
          .. asset_name(os_name, arch),
    sha256 = DIGESTS[key],
    executable = executable_path(os_name, arch),
  }
end

return { for_host = for_host, version = VERSION, hosts = hosts }
