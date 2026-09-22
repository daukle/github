daukle.plugin{ api = 1, uses = { "region" } }

daukle.language{
  name = "plaintext",
  apply = function(consumer, resolved, text)
    local lines = {}
    for index = 1, #resolved do
      lines[index] = resolved[index].project .. " " .. resolved[index].module
    end
    return daukle.region(text, "# begin", "# end", table.concat(lines, "\n"))
  end,
}
