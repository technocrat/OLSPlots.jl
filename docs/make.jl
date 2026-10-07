using Documenter
using MaterialDocs
using OLSPlots

makedocs(
    sitename = "OLSPlots.jl",
    modules = [OLSPlots],
    format = Material3(theme = :ocean_depth, dark_mode = :toggle, edit_link = "main"),
    pages = [
        "Home" => "index.md",
        "API" => "api.md",
    ],
)

deploydocs(
    repo = "github.com/technocrat/OLSPlots.jl.git",
    devbranch = "main",
)
