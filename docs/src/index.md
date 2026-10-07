# OLSPlots.jl

OLSPlots.jl is a Julia package for creating diagnostic plots for ordinary least squares (OLS) regression models, similar to those provided by R's `plot.lm` function.

## Features

- Creates standard diagnostic plots for OLS regression models
- Styled to match R's default diagnostic plot presentation
- Works with models created using GLM.jl
- Supports customization of which plots to display

## Installation

With Julia 1.10 or later, install the package and the dependencies used directly
by the example:

```julia
using Pkg
Pkg.add(url="https://github.com/technocrat/OLSPlots.jl")
Pkg.add(["GLM", "DataFrames", "CairoMakie"])
```

## Quick Start

Here's a simple example of how to use OLSPlots.jl:

```julia
using GLM, DataFrames, OLSPlots, CairoMakie

# Create sample data
df = DataFrame(x1 = rand(100), x2 = rand(100))
df.y = 2.0 .* df.x1 - 1.5 .* df.x2 + 0.5 .* randn(100)

# Fit an OLS model
ols_model = lm(@formula(y ~ x1 + x2), df)

# Generate default diagnostic plots (1,2,3,5) - same as R's default
fig = diagnostic_plots(ols_model)

# Save the figure to a file
save("diagnostic_plots.png", fig)
```

## Available Plots

The package can generate six different diagnostic plots:

1. Residuals vs Fitted Values
2. Normal Q-Q Plot
3. Scale-Location Plot
4. Cook's Distance Plot
5. Residuals vs Leverage (with Cook's distance contours)
6. Cook's Distance vs Leverage h/(1-h)

By default, plots 1, 2, 3, and 5 are displayed (the same default as R's `plot.lm` function).

## Customizing Plots

You can customize which plots to display using the `which` parameter:

```julia
# Show the first four plots (1,2,3,4)
fig = diagnostic_plots(ols_model, which=[1,2,3,4])

# Generate all six plots
fig = diagnostic_plots(ols_model, which=1:6)

# Show only the Q-Q plot and Cook's distance plot
fig = diagnostic_plots(ols_model, which=[2,4])
```

By default, plots use R-inspired smoothers, observation labels, and a Q-Q
reference line. These additions can be disabled with:

```julia
fig = diagnostic_plots(ols_model, r_style=false)
```

The input must be an unweighted linear model. Redundant predictor columns are
supported. If residual variance is zero or there are no residual degrees of
freedom, use `which=[1]` for raw residuals; requests for standardized or influence
diagnostics raise an informative `ArgumentError`. See the API reference for
the calculation and filtering rules.
