# Shared R and Julia comparison fixture

`mtcars.csv` contains all 32 observations, in R's original order, with car names
in `model` and the columns `mpg`, `hp`, `drat`, and `wt`. It matches the
corresponding columns of R's built-in `datasets::mtcars`; RDatasets.jl is not
needed. The R comparison script verifies every name and input value.

Source: R's `datasets::mtcars` (see `help("mtcars", package="datasets")`),
originally data from the 1974 *Motor Trend* magazine. R cites Henderson and
Velleman (1981), *Building Multiple Regression Models Interactively*,
Biometrics 37(2), 391–411, doi:10.2307/2530428.

`mtcars-r-diagnostics.csv` is the numeric reference generated with R 4.6.1
using the unweighted, intercept-containing model `mpg ~ hp + drat + wt`.
Its columns are car name, fitted value, raw residual, leverage, internally
standardized residual (`rstandard`, not `rstudent`), and Cook's distance.

From the repository root, run:

```sh
julia --project=examples -e 'using Pkg; Pkg.develop(path="."); Pkg.instantiate()'
julia --project=examples examples/compare_with_r.jl /tmp/olsplots-comparison
Rscript --vanilla examples/compare_with_r.R /tmp/olsplots-comparison
```

The first command sets up the isolated example environment with this checkout
of OLSPlots, DataFrames, and DelimitedFiles. DataFrames and DelimitedFiles are
example/test dependencies, not OLSPlots runtime dependencies. The Julia
comparison uses DelimitedFiles to read the fixtures and does not require R.
It checks the five numeric columns against the checked-in R reference with
absolute and relative tolerances of `1e-9`, then exports Julia diagnostics and
a six-panel PNG. The R command uses only packages shipped with R and exports
the equivalent diagnostics and a six-panel PDF into the same directory.

The comparison checks the package's numerical diagnostics helper, which also
supplies the plotted values. Plot regression tests separately check contour
scaling and representative plotted coordinates. Smoothing and labeling are
R-inspired and are not intended to reproduce R's output exactly.
Use the PNG and PDF to compare the plots visually. Both programs preserve CSV
row order; Julia's numeric observation labels correspond to the car names in
the CSV and R plots.

To regenerate the checked-in numeric reference, run the R command above,
review the output, then copy it into the repository:

```sh
cp /tmp/olsplots-comparison/mtcars-r-diagnostics.csv data/mtcars-r-diagnostics.csv
```

Record the R version here when updating the reference. Keep the model formula,
input rows, and column order synchronized between both scripts.
