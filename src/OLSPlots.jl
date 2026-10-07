module OLSPlots

using GLM, CairoMakie, Distributions, LinearAlgebra, Loess, Statistics

export diagnostic_plots

# Only the independent QR directions contribute to the projection. Callers
# with a fitted model supply its effective rank instead of estimating it again.
function _leverage(X, p::Integer=rank(X))
    0 <= p <= min(size(X)...) || throw(ArgumentError("invalid model rank: $p"))
    p == 0 && return zeros(float(eltype(X)), size(X, 1))
    factor = qr(X, ColumnNorm())
    # Apply the packed Householder reflectors to a single n×p buffer in place.
    # Materialize only the retained Q columns, without a second dense result.
    Q = Matrix{eltype(factor.Q)}(I, size(X, 1), p)
    lmul!(factor.Q, Q)
    return clamp.(vec(sum(abs2, Q, dims=2)), 0, 1)
end

# Keep the GLM/StatsModels wrapper handling at the model boundary. Weighted
# fits need different influence formulas and are intentionally not OLS inputs.
_ols_model(model::GLM.LinearModel) = model
_ols_model(model::GLM.StatsModels.TableRegressionModel) = _ols_model(model.model)
_ols_model(model) = throw(ArgumentError("expected an unweighted GLM.jl linear model fitted with lm"))

function _diagnostics(model)
    model = _ols_model(model)
    isempty(model.rr.wts) || throw(ArgumentError("weighted models are not supported; expected an unweighted OLS fit"))
    X = modelmatrix(model)
    fitted_vals = predict(model)
    resids = residuals(model)
    n = length(resids)
    n > 0 || throw(ArgumentError("the fitted model has no observations"))
    all(isfinite, X) && all(isfinite, fitted_vals) && all(isfinite, resids) ||
        throw(ArgumentError("model matrix, fitted values, and residuals must be finite"))
    p = Int(dof(model) - 1) # GLM counts the dispersion parameter in dof.
    residual_df = dof_residual(model)
    # Use the columns retained by GLM's pivoted fit, including when GLM treats
    # nearly dependent columns as redundant at its own rank tolerance.
    predictor = model.pp
    active_X = if p < size(X, 2) && predictor isa GLM.DensePredChol && predictor.chol isa CholeskyPivoted
        view(X, :, predictor.chol.p[1:p])
    else
        X
    end
    h_ii = _leverage(active_X, p)
    h_ok = h_ii .< 1 - sqrt(eps(eltype(h_ii)))
    mse = residual_df > 0 ? sum(abs2, resids) / residual_df : NaN
    undefined_reason = if residual_df <= 0
        "diagnostics require positive residual degrees of freedom"
    elseif p == 0
        "influence diagnostics require at least one estimated coefficient"
    elseif !isfinite(mse) || mse <= 0
        "standardized diagnostics require positive, finite residual variance"
    elseif !any(h_ok)
        "no observations have defined standardized diagnostics (all leverage values are near one)"
    else
        nothing
    end
    denom = ifelse.(h_ok, 1 .- h_ii, NaN)
    std_resids = undefined_reason === nothing ? resids ./ (sqrt(mse) .* sqrt.(denom)) : fill(NaN, n)
    cooks_d = undefined_reason === nothing ? (std_resids.^2 ./ p) .* (h_ii ./ denom) : fill(NaN, n)
    return (; fitted_vals, resids, n, p, residual_df, mse, h_ii, h_ok,
            std_resids, cooks_d, undefined_reason)
end

# LOESS needs enough finite observations and distinct x values for its local
# quadratic fit. Never predict beyond the range of the retained observations.
function _smooth_values(x, y)
    ok = isfinite.(x) .& isfinite.(y)
    xs, ys = x[ok], y[ok]
    length(xs) >= 6 && length(unique(xs)) >= 3 || return nothing
    model = loess(xs, ys, span=2/3)
    grid = range(extrema(xs)..., length=100)
    values = Loess.predict(model, grid)
    all(isfinite, values) || return nothing
    return grid, values
end

function _smooth!(ax, x, y)
    smooth = _smooth_values(x, y)
    smooth === nothing && return
    CairoMakie.lines!(ax, smooth..., color=:red, linewidth=1.5)
end

_finite_max(v) = (f = filter(isfinite, v); isempty(f) ? 0.0 : maximum(f))
_residual_limit(v) = (limit = 1.1 * _finite_max(abs.(v)); limit > 0 ? limit : 1.0)

"""
    diagnostic_plots(model; which=[1,2,3,5], r_style=true)

Generate standard diagnostic plots for an ordinary least squares (OLS) regression model,
with presentation inspired by R's default diagnostic plots.

# Arguments
- `model`: An unweighted linear model from GLM.jl, created with `lm()`;
  redundant predictor columns are supported using the fitted model's effective rank.
- `which`: Vector of integers specifying which plots to show (default: [1,2,3,5], matching R's default)
  1. Residuals vs Fitted Values
  2. Normal Q-Q Plot
  3. Scale-Location Plot
  4. Cook's Distance Plot
  5. Residuals vs Leverage (with Cook's distance contours)
  6. Cook's Distance vs Leverage h/(1-h)
- `r_style`: Boolean, if true uses R-like styling (default: true)

# Returns
- A CairoMakie Figure object containing the diagnostic plots

# Undefined diagnostics
Plots 2–6 require positive residual degrees of freedom and positive, finite
residual variance. Otherwise an `ArgumentError` explains the undefined
diagnostics; use `which=[1]` to show raw residuals. Observations with leverage
within `sqrt(eps(T))` of one, where `T` is the leverage calculation's floating-point
type, are omitted from standardized diagnostics and influence plots. Smoothing
is skipped when too few usable observations remain.

# Examples
```julia
using GLM, DataFrames, OLSPlots

# Create sample data
df = DataFrame(x1 = rand(100), x2 = rand(100), y = rand(100) .+ 2 .* rand(100))

# Fit an OLS model
ols_model = lm(@formula(y ~ x1 + x2), df)

# Generate default diagnostic plots (1,2,3,5) - same as R's default
fig = diagnostic_plots(ols_model)

# Show the first four plots (1,2,3,4) - without Residuals vs Leverage
fig = diagnostic_plots(ols_model, which=[1,2,3,4])

# Or generate all six plots
fig = diagnostic_plots(ols_model, which=1:6)
```
"""
function diagnostic_plots(model; which=[1,2,3,5], r_style=true)
    which = collect(which)
    all(w -> w isa Integer && !(w isa Bool) && w in 1:6, which) ||
        throw(ArgumentError("`which` must contain integers in 1:6, got $which"))
    isempty(which) && throw(ArgumentError("`which` must not be empty"))
    which = sort(unique(which))
    data = _diagnostics(model)
    if data.undefined_reason !== nothing && any(!=(1), which)
        throw(ArgumentError(data.undefined_reason * "; use `which=[1]` for raw residuals"))
    end
    (; fitted_vals, resids, n, p, h_ii, h_ok, std_resids, cooks_d) = data
    influential_idx = findall(isfinite.(cooks_d) .& (cooks_d .> 4/n))
    
    # Create a figure with appropriate layout
    num_plots = length(which)
    rows = num_plots <= 1 ? 1 : ceil(Int, num_plots / 2)
    fig = CairoMakie.Figure(size=(900, 450 * rows))
    
    # Set styling parameters based on r_style
    marker_fill = :white  # Always white for open circles
    marker_color = :black
    
    # Plot counter and positions
    plot_positions = Dict{Int, Tuple{Int, Int}}()
    
    # Calculate positions for each plot
    for i in 1:num_plots
        row_pos = ceil(Int, i / 2)
        col_pos = 2 - (i % 2)
        col_pos = col_pos == 0 ? 2 : col_pos
        plot_positions[i] = (row_pos, col_pos)
    end
    
    # Map of which plot goes in which position
    plot_indices = Dict{Int, Int}()
    for (i, w) in enumerate(which)
        plot_indices[w] = i
    end
    
    # 1. Residuals vs Fitted Values
    if 1 ∈ which
        position = plot_positions[plot_indices[1]]
        
        ax1 = CairoMakie.Axis(fig[position[1], position[2]], 
                   title="Residuals vs Fitted", 
                   xlabel="Fitted values", 
                   ylabel="Residuals",
                   titlecolor=:black)
        
        # Set x and y-axis limits to match R
        CairoMakie.xlims!(ax1, minimum(fitted_vals) - 0.5, maximum(fitted_vals) + 0.5)
        yr = _residual_limit(resids)
        CairoMakie.ylims!(ax1, -yr, yr)
                   
        # Using open circles with black outline to match R
        CairoMakie.scatter!(ax1, fitted_vals, resids, 
                            color=marker_fill,
                            strokecolor=marker_color,
                            strokewidth=1,
                            marker=:circle)
                            
        r_style && _smooth!(ax1, fitted_vals, resids)
        
        CairoMakie.hlines!(ax1, [0], color=:black, linestyle=:dash)
        
        # Label influential points as R does
        if r_style
            for idx in influential_idx
                CairoMakie.text!(ax1, fitted_vals[idx], resids[idx], text=string(idx), 
                        fontsize=8, align=(:center, :bottom))
            end
        end
    end

    # 2. Normal Q-Q Plot
    if 2 ∈ which
        position = plot_positions[plot_indices[2]]
        
        ax2 = CairoMakie.Axis(fig[position[1], position[2]], 
                   title="Normal Q-Q Plot", 
                   xlabel="Theoretical Quantiles", 
                   ylabel="Standardized Residuals",
                   titlecolor=:black)

        # Create a Q-Q plot from finite standardized residuals.
        qq_idx = findall(isfinite, std_resids)
        sorted_resids = sort(std_resids[qq_idx])
        n_resids = length(sorted_resids)
        
        # Half-step plotting positions for the normal quantiles.
        p_points = [(i - 0.5) / n_resids for i in 1:n_resids]
        theoretical_quantiles = [quantile(Normal(), p) for p in p_points]

        CairoMakie.scatter!(ax2, theoretical_quantiles, sorted_resids,
                            color=marker_fill, 
                            strokecolor=marker_color,
                            strokewidth=1,
                            marker=:circle)

        # Add reference line following R's exact qqline approach
        if r_style
            # R uses qqline() which draws line through the quartiles
            q1_probs = 0.25
            q3_probs = 0.75
            y_q1 = quantile(sorted_resids, q1_probs) 
            y_q3 = quantile(sorted_resids, q3_probs)
            x_q1 = quantile(Normal(), q1_probs)
            x_q3 = quantile(Normal(), q3_probs)
            
            slope = (y_q3 - y_q1) / (x_q3 - x_q1)
            intercept = y_q1 - slope * x_q1
            
            ref_line_x = [minimum(theoretical_quantiles), maximum(theoretical_quantiles)]
            ref_line_y = slope .* ref_line_x .+ intercept
            
            CairoMakie.lines!(ax2, ref_line_x, ref_line_y, color=:gray50, linestyle=:dash)
        end
        
        # Label influential points
        if r_style
            # Map the standardized residuals to their original indices
            rank_of = Dict(orig => r for (r, orig) in enumerate(qq_idx[sortperm(std_resids[qq_idx])]))
            for idx in influential_idx
                idx_in_sorted = get(rank_of, idx, nothing)
                if idx_in_sorted !== nothing
                    x_pos = theoretical_quantiles[idx_in_sorted]
                    y_pos = sorted_resids[idx_in_sorted]
                    CairoMakie.text!(ax2, x_pos, y_pos, 
                            text=string(idx), fontsize=8, align=(:center, :bottom))
                end
            end
        end
    end

    # 3. Scale-Location Plot
    if 3 ∈ which
        position = plot_positions[plot_indices[3]]
        
        ax3 = CairoMakie.Axis(fig[position[1], position[2]], 
                   title="Scale-Location", 
                   xlabel="Fitted values", 
                   ylabel="√|Standardized residuals|",
                   titlecolor=:black)
                   
        sqrt_std_resids = sqrt.(abs.(std_resids))
        
        # Set x-axis limits to match R
        CairoMakie.xlims!(ax3, minimum(fitted_vals) - 0.5, maximum(fitted_vals) + 0.5)
        
        CairoMakie.scatter!(ax3, fitted_vals, sqrt_std_resids,
                            color=marker_fill, 
                            strokecolor=marker_color,
                            strokewidth=1,
                            marker=:circle)
                            
        r_style && _smooth!(ax3, fitted_vals, sqrt_std_resids)
        
        # Label influential points
        if r_style
            for idx in influential_idx
                CairoMakie.text!(ax3, fitted_vals[idx], sqrt_std_resids[idx], 
                        text=string(idx), fontsize=8, align=(:center, :bottom))
            end
        end
    end
    
    # 4. Cook's Distance Plot
    if 4 ∈ which
        position = plot_positions[plot_indices[4]]
        
        ax4 = CairoMakie.Axis(fig[position[1], position[2]], 
                   title="Cook's Distance", 
                   xlabel="Obs. number", 
                   ylabel="Cook's distance",
                   titlecolor=:black)
                   
        # Calculate y-axis limit following R's approach
        ymx = max(_finite_max(cooks_d) * 1.075, eps())
        CairoMakie.ylims!(ax4, 0, ymx)
        
        # Draw stems like in R's implementation (type="h")
        CairoMakie.rangebars!(ax4, 1:n, zeros(n), cooks_d, color=:black, linewidth=0.5)
        
        # Add points at the top of stems
        CairoMakie.scatter!(ax4, 1:n, cooks_d,
                            color=marker_fill, 
                            strokecolor=marker_color,
                            strokewidth=1,
                            marker=:circle)
                            
        # Add threshold line
        CairoMakie.hlines!(ax4, [4/n], color=:red, linestyle=:dash)
        
        # Label influential points
        if r_style
            for idx in influential_idx
                CairoMakie.text!(ax4, idx, cooks_d[idx], 
                        text=string(idx), fontsize=8, align=(:center, :bottom))
            end
        end
    end

    # 5. Residuals vs Leverage
    if 5 ∈ which
        position = plot_positions[plot_indices[5]]
        
        ax5 = CairoMakie.Axis(fig[position[1], position[2]], 
                   title="Residuals vs Leverage", 
                   xlabel="Leverage", 
                   ylabel="Standardized Residuals",
                   titlecolor=:black)
        
        # R checks for constant leverage
        r_hat = extrema(h_ii)
        isConst_hat = r_hat[2] == 0 || (r_hat[2] - r_hat[1]) < 1e-10 * mean(h_ii)
        
        if isConst_hat
            # Handle constant leverage case (typically not needed for most models)
            # This would need factor handling which is complex
            CairoMakie.text!(ax5, 0.5, 0.5, text="Constant leverage: no plot", 
                     align=(:center, :center))
        else
            # Normal residuals vs leverage plot
            # Filter out leverage values of 1 (as R does)
            valid_idx = h_ok
            
            # Set appropriate y-axis limits
            yr = _residual_limit(std_resids[valid_idx])
            CairoMakie.ylims!(ax5, -yr, yr)
            
            CairoMakie.scatter!(ax5, h_ii[valid_idx], std_resids[valid_idx],
                                color=marker_fill, 
                                strokecolor=marker_color,
                                strokewidth=1,
                                marker=:circle)
                                
            CairoMakie.hlines!(ax5, [0], color=:black, linestyle=:dash)
            CairoMakie.vlines!(ax5, [0], color=:black, linestyle=:dash)

            # Add Cook's distance contours as in R
            cook_contours = [0.5, 1.0]
            
            # Ensure valid range for x_range to avoid division by zero
            min_h = maximum([minimum(h_ii[valid_idx]), 0.001])
            max_h = minimum([maximum(h_ii[valid_idx]), 0.999])
            x_range = range(min_h, max_h, length=100)

            for level in cook_contours
                y_curve = @. sqrt(level * p * (1 - x_range) / x_range)
                CairoMakie.lines!(ax5, x_range, y_curve, color=:red, linestyle=:dash)
                CairoMakie.lines!(ax5, x_range, -y_curve, color=:red, linestyle=:dash)
            end
            
            # Add legend as in R
            CairoMakie.text!(ax5, 0.01, 0.95 * yr, 
                      text="Cook's distance", color=:red, fontsize=8)
            
            # Add LOESS smoother
            r_style && _smooth!(ax5, h_ii[valid_idx], std_resids[valid_idx])
            
            # Add secondary axis labels for Cook's distance as in R
            if r_style
                # Calculate positions for secondary axis labels
                xmax = max_h
                ymult = sqrt(p * (1 - xmax) / xmax)
                
                # Add the secondary axis labels
                for level in cook_contours
                    level_pos = sqrt(level) * ymult
                    CairoMakie.text!(ax5, xmax + 0.02, level_pos, text=string(level), 
                             fontsize=8, color=:red, align=(:left, :center))
                    CairoMakie.text!(ax5, xmax + 0.02, -level_pos, text=string(level), 
                             fontsize=8, color=:red, align=(:left, :center))
                end
            end
            
            # Label influential points
            if r_style
                for idx in influential_idx
                    if h_ii[idx] < 1.0  # Only label points with leverage < 1
                        CairoMakie.text!(ax5, h_ii[idx], std_resids[idx], 
                                text=string(idx), fontsize=8, align=(:center, :bottom))
                    end
                end
            end
        end
    end
    

    # 6. Cook's Distance vs Leverage h/(1-h)
    if 6 ∈ which
      position = plot_positions[plot_indices[6]]
      
      # Create custom tick positions and labels
      at_hat = [0.1, 0.2, 0.3, 0.4, 0.5]  # Leverage values
      at_g = at_hat ./ (1 .- at_hat)      # Transformed for plotting
      
      ax6 = CairoMakie.Axis(fig[position[1], position[2]], 
                title="Cook's dist vs Leverage h/(1-h)", 
                xlabel="Leverage hᵢᵢ", 
                ylabel="Cook's distance",
                titlecolor=:black,
                xticks = (at_g, string.(at_hat)))  # Set ticks during axis creation
      
      # Calculate h/(1-h) as in R
      g = h_ii ./ (1 .- h_ii)
      
      # Filter out points with leverage = 1
      valid_idx = h_ok
      
      # Set y-axis limit as in R
      ymx = max(_finite_max(cooks_d) * 1.025, eps())
      CairoMakie.ylims!(ax6, 0, ymx)
      
      CairoMakie.scatter!(ax6, g[valid_idx], cooks_d[valid_idx],
                          color=marker_fill, 
                          strokecolor=marker_color,
                          strokewidth=1,
                          marker=:circle)
      
      # Add contour lines for constant standardized residuals
      b_vals = [0.5, 1.0, 1.5, 2.0]  # Standardized residual values
      
      xmax = maximum(g[valid_idx])
      ymax = ymx
      
      for b in b_vals
          slope = b^2 / p
          x_vals = range(0, xmax, length=100)
          y_vals = slope .* x_vals
          
          if maximum(y_vals) < ymax
              # Draw full line
              CairoMakie.lines!(ax6, x_vals, y_vals, color=:red, linestyle=:dash)
              
              # Add label at the end of the line
              CairoMakie.text!(ax6, xmax + 0.05, slope * xmax, text=string(b),
                      fontsize=8, color=:red, align=(:left, :center))
          else
              # Find where line intersects with top of plot
              x_intersect = ymax / slope
              CairoMakie.lines!(ax6, range(0, x_intersect, length=100),
                        slope .* range(0, x_intersect, length=100),
                        color=:red, linestyle=:dash)
                        
              # Add label at the top
              CairoMakie.text!(ax6, x_intersect, 0.95 * ymax, text=string(b),
                      fontsize=8, color=:red, align=(:center, :top))
          end
      end
      
      # Label influential points
      if r_style
          for idx in influential_idx
              if h_ii[idx] < 1.0  # Only label points with leverage < 1
                  CairoMakie.text!(ax6, g[idx], cooks_d[idx], 
                          text=string(idx), fontsize=8, align=(:center, :bottom))
              end
          end
      end
    end
    return fig
end


end # module
