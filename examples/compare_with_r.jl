# Run from the repository root:
# julia --project=examples examples/compare_with_r.jl /tmp/olsplots-comparison
using OLSPlots, GLM, DataFrames, CairoMakie, DelimitedFiles

length(ARGS) == 1 || error("Supply an output directory as the only argument.")
output_dir = only(ARGS)
mkpath(output_dir)
data_dir = joinpath(@__DIR__, "..", "data")

raw, header = readdlm(joinpath(data_dir, "mtcars.csv"), ',', Any; header=true)
cars = DataFrame(model=String.(raw[:, 1]))
for j in 2:size(raw, 2)
    cars[!, Symbol(header[j])] = Float64.(raw[:, j])
end
fit = lm(@formula(mpg ~ hp + drat + wt), cars)

# Compare the same numerical diagnostics consumed by the plotting code.
diagnostics = OLSPlots._diagnostics(fit)
values = hcat(diagnostics.fitted_vals, diagnostics.resids, diagnostics.h_ii,
              diagnostics.std_resids, diagnostics.cooks_d)
columns = ["fitted", "residual", "leverage", "standardized_residual", "cooks_distance"]
reference, reference_header = readdlm(
    joinpath(data_dir, "mtcars-r-diagnostics.csv"), ',', Any; header=true)
@assert vec(String.(reference_header)) == ["model"; columns]
@assert String.(reference[:, 1]) == cars.model
expected = Float64.(reference[:, 2:end])
@assert size(values) == size(expected)
for (j, column) in enumerate(columns)
    delta = maximum(abs.(values[:, j] .- expected[:, j]))
    println(column, ": maximum absolute difference = ", delta)
    @assert all(isapprox.(values[:, j], expected[:, j]; atol=1e-9, rtol=1e-9)) column
end

open(joinpath(output_dir, "mtcars-julia-diagnostics.csv"), "w") do io
    writedlm(io, permutedims(["model"; columns]), ',')
    writedlm(io, hcat(cars.model, values), ',')
end
fig = diagnostic_plots(fit; which=1:6)
save(joinpath(output_dir, "mtcars-julia.png"), fig)
println("All five diagnostic columns agree with R within atol=rtol=1e-9.")
println("Julia diagnostics and six-panel PNG written to: ", output_dir)
