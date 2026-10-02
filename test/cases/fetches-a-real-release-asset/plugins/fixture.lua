daukle.plugin{ api = 1, uses = { "region" } }

--- Named "npm" because this case resolves a REAL published producer manifest
--- and that manifest's module carries an npm block. The language is still a
--- fixture: what it renders is the project and module, so the assertion stays
--- on what the source plugin fetched rather than on npm's formatting.
daukle.language{
  name = "npm",
  apply = function(consumer, resolved, text)
    local lines = {}
    for index = 1, #resolved do
      lines[index] = resolved[index].project .. " " .. resolved[index].module
    end
    return daukle.region(text, "# begin", "# end", table.concat(lines, "\n"))
  end,
}
