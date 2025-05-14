using Documenter
using OLSPlots

makedocs(
    sitename = "OLSPlots.jl",
    format = Documenter.HTML(),
    modules = [OLSPlots],
    pages = [
        "Home" => "index.md",
        "API" => "api.md"
    ]
)

# Documenter can also automatically deploy documentation to gh-pages.
# See "Hosting Documentation" and deploydocs() in the Documenter manual
# for more information.
deploydocs(
    repo = "github.com/technocrat/OLSPlots.jl.git",
    devbranch = "main"
)

