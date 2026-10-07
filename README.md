# OLSPlots.jl

A Julia library for generating high-quality plots and visualizations of Ordinary Least Squares (OLS) regression results. Developed for researchers, analysts, and practitioners seeking to enhance the clarity and presentation of OLS models using Julia.

---

## Overview

OLSPlots.jl provides an intuitive and flexible interface for producing diagnostic and comparative plots for OLS regression analyses. The package is designed to fill the gap for statistical plotting tools in Julia, streamlining workflows for academics and professionals.

- Easy-to-use plotting functions tailored for common regression diagnostics.
- Seamless integration with standard Julia data structures and statistical modeling packages.
- Customizable outputs for publication-ready graphics.

Its six diagnostics are inspired by R's `plot.lm` function.
---

## Installation

OLSPlots requires Julia 1.10 or later. To install the package, use Julia’s package manager:

```julia
using Pkg
Pkg.add(url="https://github.com/technocrat/OLSPlots.jl")
# Dependencies used directly by the example below:
Pkg.add(["GLM", "DataFrames"])
```

---

## Usage

```julia
using OLSPlots, GLM, DataFrames

# Fit a simple OLS model
df = DataFrame(X1 = randn(100), X2 = randn(100))
df.y = 1.5 .* df.X1 - 2.0 .* df.X2 + randn(100)

ols_model = lm(@formula(y ~ X1 + X2), df)

# Generate the four default plots
diagnostic_plots(ols_model)

# Cook's Distance only 
diagnostic_plots(ols_model, which=[4])

# All six plots
diagnostic_plots(ols_model, which=[1,2,3,4,5,6])
```

Plots are returned as objects from the `CairoMakie` ecosystem, allowing further customization or direct export.

For a reproducible comparison with R, use the checked-in
[`mtcars` CSV and R diagnostic reference](data/README.md). The included scripts
fit the same model in Julia and R, compare numeric diagnostics, and export all
six plots. The Julia comparison does not require R or RDatasets.jl.

---

## Features

- Residuals vs fitted values, normal Q-Q, and scale-location plots.
- Cook's distance, residuals vs leverage, and Cook's distance vs transformed leverage.
- Selection of individual panels or all six diagnostics.
- R-inspired smoothing and observation labels, controlled by `r_style`.
- CairoMakie figures that can be customized and exported.

Unweighted GLM.jl linear models are supported, including models with redundant
predictors. Calculations use the fitted model's effective rank. Weighted and
generalized linear models are rejected with an informative `ArgumentError`.

Plots 2–6 need positive residual degrees of freedom and positive, finite
residual variance. When those diagnostics are undefined, the function raises
an `ArgumentError`; `which=[1]` still shows raw residuals. Observations with
leverage within `sqrt(eps(T))` of one (for the calculation's floating-point type
`T`) are omitted from standardized and influence diagnostics. Smoothing is
skipped when too few usable data remain.

---

## Documentation

Documentation is available at [technocrat.github.io/OLSPlots.jl](https://technocrat.github.io/OLSPlots.jl/stable/). Development docs track `main` at [/dev](https://technocrat.github.io/OLSPlots.jl/dev/).

---

## Contributing

Contributions and feedback are welcome. Please submit issues or pull requests on the [GitHub repository](https://github.com/technocrat/OLSPlots.jl).

Run the tests from the repository root:

```sh
julia --project=. -e 'using Pkg; Pkg.test()'
```

The suite checks numerical diagnostics against the checked-in R reference,
rank-deficient and degenerate fits, selected panels, contour coordinates,
and PNG/PDF export.

---

## About

**Author:** Richard Careaga, Independent Political Researcher  
**Affiliation:** [Technocrat's Toolbox](https://technocrat.site)  
**Contact:** Please use the issue tracker for feature requests or bug reports.

---

## License

This project is distributed under the MIT License.

---

Julia provides a strong foundation for statistical modeling. With OLSPlots.jl, visualization and diagnostic workflows become efficient and accessible, supporting advanced research and data-driven projects.
