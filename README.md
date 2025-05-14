# OLSPlots.jl

A Julia library for generating high-quality plots and visualizations of Ordinary Least Squares (OLS) regression results. Developed for researchers, analysts, and practitioners seeking to enhance the clarity and presentation of OLS models using Julia.

---

## Overview

OLSPlots.jl provides an intuitive and flexible interface for producing diagnostic and comparative plots for OLS regression analyses. The package is designed to fill the gap for statistical plotting tools in Julia, streamlining workflows for academics and professionals.

- Easy-to-use plotting functions tailored for common regression diagnostics.
- Seamless integration with standard Julia data structures and statistical modeling packages.
- Customizable outputs for publication-ready graphics.

It emulates the R Programming Lanugage's plot function for models produced by the `lm()` function.
---

## Installation

To install the latest version of OLSPlots.jl, use Julia’s package manager:

```julia
using Pkg
Pkg.add(url="https://github.com/technocrat/OLSPlots.jl")
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
diagnostic_plots(ols_model, which=[5])

# All six plots
diagnostic_plots(ols_model, which=[1,2,3,4,5,6])
```

Plots are returned as objects from the `CairoMakie` ecosystem, allowing further customization or direct export.

---

## Features

- Residuals diagnostics (histograms, Q-Q plots, scatter plots).
- Fitted vs. actual outcome comparison.
- Leverage and influence plots.
- Custom themes and labeling options.
- Designed for extensibility with new plot types.

---

## Documentation

Comprehensive documentation and examples are available at [Technocrat’s Toolbox](https://technocrat.site).

---

## Contributing

Contributions and feedback are welcome. Please submit issues or pull requests on the [GitHub repository](https://github.com/technocrat/OLSPlots.jl).

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
