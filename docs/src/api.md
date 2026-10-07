# API Reference

## Functions

```@docs
diagnostic_plots
```

## Implementation Details

OLSPlots.jl makes use of the following components in its implementation:

- GLM.jl - For working with linear models
- CairoMakie.jl - For creating the visualizations
- Distributions.jl - For statistical distributions and quantiles
- Loess.jl - For smoothing curves in the diagnostic plots

### Diagnostic Plot Types

The package can generate six different diagnostic plots:

1. **Residuals vs Fitted Values**: Shows if residuals have non-linear patterns, which would indicate a non-linear relationship that is not captured by the model.

2. **Normal Q-Q Plot**: Plots the distribution of standardized residuals against a normal distribution to check if residuals are normally distributed.

3. **Scale-Location Plot**: Shows if residuals are spread equally along the ranges of predictors, used to check the homoscedasticity assumption.

4. **Cook's Distance Plot**: Identifies influential observations that might have a large effect on the regression.

5. **Residuals vs Leverage**: Shows the relationship between standardized residuals and leverage, with Cook's distance contours, to help identify influential observations.

6. **Cook's Distance vs Leverage h/(1-h)**: An alternative view of Cook's distance against leverage transformed by h/(1-h).

### Calculation Methods

The package calculates the following metrics:

- **Leverage values**: Diagonal elements of the projection onto the fitted predictor space, computed using the independent directions of a pivoted thin QR factorisation. The ``n \times n`` hat matrix is never formed; for full-rank models it is ``H = X(X'X)^{-1}X'``.
- **Standardized residuals**: ``r_i / (\hat\sigma\sqrt{1-h_{ii}})``
- **Cook's distances**: ``D_i = \dfrac{r_i^2}{p\hat\sigma^2}\dfrac{h_{ii}}{(1-h_{ii})^2}``

The QR factor keeps its orthogonal transformations implicit. Leverage
calculation applies them in place to one dense ``n \times p`` buffer containing
the retained columns of ``Q``, then sums squared entries by row. This workspace
is ``O(np)`` in addition to the QR factorization storage; avoiding the hat matrix
does not make the calculation allocation-free. For ``p=n``, this buffer is
naturally square.

Here ``p`` is the fitted model's effective rank, including the intercept when
present, and ``\hat\sigma^2 = \sum_i r_i^2 / \mathrm{dof}_{residual}``.
Redundant predictor columns do not add to ``p``. In plot 6, a line for
standardized residual magnitude ``b`` has slope ``b^2/p`` against ``h/(1-h)``.

Observations with leverage within `sqrt(eps(T))` of one, where `T` is the
leverage calculation's floating-point type, have undefined
standardized residuals and Cook's distances. They are omitted from standardized
and influence diagnostics; their raw residuals remain available in plot 1.
Cook's distance flags observations above the ``4/n`` threshold.

### Supported models and undefined diagnostics

Both matrix-based and formula-based unweighted `GLM.lm` fits are supported.
Weighted fits and generalized linear models raise an `ArgumentError` because
their diagnostic formulas differ from the OLS formulas above.

Plots 2–6 require positive residual degrees of freedom, positive finite
residual variance, at least one estimated coefficient, and at least one
observation with defined standardized diagnostics. A request for these panels
raises an informative `ArgumentError` if a condition fails. In particular,
zero-variance exact fits and saturated models can still be inspected using
`diagnostic_plots(model; which=[1])`, which pads zero-height residual axes.
An algebraically perfect fit can have small nonzero floating-point residuals;
the variance check uses the computed variance without a heuristic cutoff.

Smoothers use only finite observations and predict within the retained
predictor range. They are skipped with fewer than six usable observations,
fewer than three distinct predictor values, or nonfinite smoothing results.

### R-inspired presentation

`r_style=true` enables LOESS smoothers and observation labels, and the Q-Q
reference line. These choices are inspired by R rather than an exact visual
replica: labels use Cook's distance greater than ``4/n`` across panels, and
plot 5 includes an optional smoother. Reference thresholds and Cook's contours
remain visible with `r_style=false`.

These metrics are used to create the diagnostic plots that help assess model fit, detect outliers, and identify influential observations.
