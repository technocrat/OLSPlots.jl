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

- **Leverage values**: Diagonal elements of the hat matrix H = X(X'X)⁻¹X'
- **Standardized residuals**: Residuals divided by their standard deviation
- **Cook's distances**: Measures of how much the regression would change if an observation were removed

These metrics are used to create the diagnostic plots that help assess model fit, detect outliers, and identify influential observations.

