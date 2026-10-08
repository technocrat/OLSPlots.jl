# OLSPlots.jl release notes

## v0.2.0

### Breaking changes

- Julia 1.10 or later is now required (previously 1.6). CairoMakie 0.13, 0.14
  and 0.15 are supported.
- `diagnostic_plots` now accepts only unweighted OLS fits from `GLM.lm`, either
  matrix-based or formula-based. Weighted fits and generalized linear models
  raise an `ArgumentError`; their diagnostic formulas differ from the OLS ones.
- `which` is validated. Values outside `1:6`, non-integers, and an empty
  collection raise an `ArgumentError`, and duplicates are dropped. Previously an
  operator-precedence bug in the range filter let invalid values through.
- Plots 2–6 raise an `ArgumentError` when the standardized diagnostics are
  undefined: no residual degrees of freedom, zero or non-finite residual
  variance, no estimated coefficients, or every observation at leverage near
  one. Use `which=[1]` to view raw residuals in those cases.
- The `DataFrames`, `Documenter` and `StatsBase` dependencies are removed; none
  was used by the package code. `Statistics` and `LinearAlgebra` are now
  declared explicitly.

### Fixed

- Plot 6 (Cook's distance vs leverage): the contours of constant standardized
  residual now use slope `b²/p` against `h/(1-h)`, as in R. They previously
  used `b²`.
- Models with redundant predictor columns use the fitted model's effective rank
  for the leverage and Cook's distance calculations, rather than the number of
  columns in the model matrix.
- Observations with leverage within `sqrt(eps(T))` of one are omitted from
  standardized-residual and influence plots instead of producing infinite or
  NaN values.
- The constant-leverage check in plot 5 tested the wrong end of the range.
- LOESS smoothers are skipped, instead of erroring, when fewer than six finite
  observations or three distinct predictor values remain. They no longer
  extrapolate beyond the observed range.
- Zero-height residual axes are padded so that exact fits can still be drawn
  with `which=[1]`.
- The docstring example loaded a package named `OLSDiagnosticPlots`; it now
  loads `OLSPlots`.

### Changed

- Leverage is computed from a pivoted thin QR factorization. The `n × n` hat
  matrix is no longer formed, so memory use scales with `n × p`.
- Cook's distance stems in plot 4 are drawn with a single `rangebars!` call
  instead of one `lines!` call per observation.

### Added

- `examples/compare_with_r.jl` and `examples/compare_with_r.R`, with the
  reference output in `data/mtcars-r-diagnostics.csv`, for comparing the
  diagnostics with R's `plot.lm`.
- Expanded API documentation covering the formulas, supported models, and when
  diagnostics are undefined.
- Documentation is hosted at <https://technocrat.github.io/OLSPlots.jl/>.
- A much larger test suite.

## v0.1.0

Initial release: `diagnostic_plots` produces R-style diagnostic plots for
OLS models fitted with GLM.jl.
