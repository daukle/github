-- The toolchain a [publish.*] block's "from" names. A publish step runs in a
-- toolchain's derived directory and carries its context, so a publisher cannot
-- be exercised without one; this is the smallest thing that satisfies that and
-- builds nothing.
daukle.plugin{ api = 1 }

daukle.toolchain{
  name = "fixture",
  generate = function() return {} end,
}
