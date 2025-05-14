module OLSPlots

using GLM, DataFrames, CairoMakie, LinearAlgebra, Distributions, Loess

export diagnostic_plots

"""
    diagnostic_plots(model; which=[1,2,3,5], r_style=true)

Generate standard diagnostic plots for an ordinary least squares (OLS) regression model,
styled to match R's default diagnostic plot presentation.

# Arguments
- `model`: A fitted regression model from GLM.jl (e.g., created with `lm()`)
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

# Examples
```julia
using GLM, DataFrames, OLSDiagnosticPlots

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
"""
function diagnostic_plots(model; which=[1,2,3,5], r_style=true)
    # Extract model information
    X = modelmatrix(model)
    y = response(model)
    n, p = size(X)
    
    # Get fitted values and residuals
    fitted_vals = predict(model)
    resids = residuals(model)

    # Calculate hat matrix (leverage)
    H = X * inv(X'X) * X'
    h_ii = diag(H)

    # Calculate standardized residuals
    σ̂² = sum(resids.^2) / (n - p)  # MSE (mean squared error)
    std_resids = resids ./ (sqrt(σ̂²) * sqrt.(1 .- h_ii))

    # Calculate studentized residuals (R uses this for standardized residuals)
    student_resids = resids ./ (sqrt(σ̂²) * sqrt.(1 .- h_ii))

    # Calculate Cook's distance
    cooks_d = (resids.^2 / (p * σ̂²)) .* (h_ii ./ (1 .- h_ii).^2)

    # Identify influential points (Cook's distance > 4/n is often used as threshold)
    influential_idx = findall(cooks_d .> 4/n)
    
    # Filter which plots to show
    which = sort(which)
    which = which[which .>= 1 .& which .<= 6]
    
    # Create a figure with appropriate layout
    num_plots = length(which)
    rows = num_plots <= 1 ? 1 : ceil(Int, num_plots / 2)
    fig = CairoMakie.Figure(size=(900, 450 * rows))
    
    # Set styling parameters based on r_style
    marker_fill = :white  # Always white for open circles
    marker_color = :black
    
    # Plot counter and positions
    plot_counter = 1
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
        yr = maximum(abs.(resids)) * 1.1
        CairoMakie.ylims!(ax1, -yr, yr)
                   
        # Using open circles with black outline to match R
        CairoMakie.scatter!(ax1, fitted_vals, resids, 
                            color=marker_fill,
                            strokecolor=marker_color,
                            strokewidth=1,
                            marker=:circle)
                            
        # Add LOESS smoother with R's exact approach
        if r_style && length(fitted_vals) > 3
            # R uses panel.smooth which uses loess with span=2/3
            model_loess = loess(fitted_vals, resids, span=2/3)
            x_smooth = range(minimum(fitted_vals), maximum(fitted_vals), length=100)
            y_smooth = Loess.predict(model_loess, x_smooth)
            CairoMakie.lines!(ax1, x_smooth, y_smooth, color=:red, linewidth=1.5)
        end
        
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

        # Create Q-Q plot exactly following R's approach
        sorted_resids = sort(std_resids)
        n_resids = length(sorted_resids)
        
        # R uses (i-0.5)/n quantiles
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
            sorted_indices = sortperm(std_resids)
            for idx in influential_idx
                idx_in_sorted = findfirst(sorted_indices .== idx)
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
                            
        # Add LOESS smoother using R's approach
        if r_style && length(fitted_vals) > 3
            # R uses panel.smooth which uses loess with span=2/3
            model_loess = loess(fitted_vals, sqrt_std_resids, span=2/3)
            x_smooth = range(minimum(fitted_vals), maximum(fitted_vals), length=100)
            y_smooth = Loess.predict(model_loess, x_smooth)
            CairoMakie.lines!(ax3, x_smooth, y_smooth, color=:red, linewidth=1.5)
        end
        
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
        ymx = maximum(cooks_d) * 1.075
        CairoMakie.ylims!(ax4, 0, ymx)
        
        # Draw stems like in R's implementation (type="h")
        for i in 1:n
            CairoMakie.lines!(ax4, [i, i], [0, cooks_d[i]], color=:black, linewidth=0.5)
        end
        
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
        isConst_hat = r_hat[1] == 0 || (r_hat[2] - r_hat[1]) < 1e-10 * mean(h_ii)
        
        if isConst_hat
            # Handle constant leverage case (typically not needed for most models)
            # This would need factor handling which is complex
            CairoMakie.text!(ax5, 0.5, 0.5, text="Constant leverage: no plot", 
                     align=(:center, :center))
        else
            # Normal residuals vs leverage plot
            # Filter out leverage values of 1 (as R does)
            valid_idx = h_ii .< 1.0
            
            # Set appropriate y-axis limits
            yr = maximum(abs.(std_resids[valid_idx])) * 1.1
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
            if r_style && length(h_ii) > 3
                valid_h = h_ii[valid_idx]
                valid_r = std_resids[valid_idx]
                model_loess = loess(valid_h, valid_r, span=2/3)
                x_smooth = range(minimum(valid_h), maximum(valid_h), length=100)
                y_smooth = Loess.predict(model_loess, x_smooth)
                CairoMakie.lines!(ax5, x_smooth, y_smooth, color=:red, linewidth=1.5)
            end
            
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
      valid_idx = h_ii .< 1.0
      
      # Set y-axis limit as in R
      ymx = maximum(cooks_d) * 1.025
      CairoMakie.ylims!(ax6, 0, ymx)
      
      CairoMakie.scatter!(ax6, g[valid_idx], cooks_d[valid_idx],
                          color=marker_fill, 
                          strokecolor=marker_color,
                          strokewidth=1,
                          marker=:circle)
      
      # Add contour lines for constant standardized residuals
      p_vals = length(coef(model))
      b_vals = [0.5, 1.0, 1.5, 2.0]  # Standardized residual values
      
      xmax = maximum(g[valid_idx])
      ymax = ymx
      
      for b in b_vals
          b2 = b^2
          x_vals = range(0, xmax, length=100)
          y_vals = b2 .* x_vals
          
          if maximum(y_vals) < ymax
              # Draw full line
              CairoMakie.lines!(ax6, x_vals, y_vals, color=:red, linestyle=:dash)
              
              # Add label at the end of the line
              CairoMakie.text!(ax6, xmax + 0.05, b2 * xmax, text=string(b), 
                      fontsize=8, color=:red, align=(:left, :center))
          else
              # Find where line intersects with top of plot
              x_intersect = ymax / b2
              CairoMakie.lines!(ax6, range(0, x_intersect, length=100), 
                        b2 .* range(0, x_intersect, length=100), 
                        color=:red, linestyle=:dash)
                        
              # Add label at the top
              CairoMakie.text!(ax6, x_intersect, ymax - 0.02, text=string(b), 
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