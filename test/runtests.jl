using Test
using OLSPlots
using GLM
using DataFrames
using CairoMakie
using LinearAlgebra
using Random
using DelimitedFiles

plot_axes(fig) = filter(block -> block isa CairoMakie.Axis, fig.content)
scatter_points(ax) = only(filter(plot -> plot isa CairoMakie.Scatter, ax.scene.plots))[1][]
line_plots(ax) = filter(plot -> plot isa CairoMakie.Lines, ax.scene.plots)

@testset "OLSPlots.jl" begin
    Random.seed!(1)
    df = DataFrame(X1 = randn(100), X2 = randn(100))
    df.y = 2.0 .* df.X1 - 1.5 .* df.X2 + 0.5 .* randn(100)
    model = lm(@formula(y ~ X1 + X2), df)

    @testset "export" begin
        @test :diagnostic_plots in names(OLSPlots)
    end

    @testset "plot selection" begin
        titles = ["Residuals vs Fitted", "Normal Q-Q Plot", "Scale-Location",
                  "Cook's Distance", "Residuals vs Leverage",
                  "Cook's dist vs Leverage h/(1-h)"]
        for which in ([1, 2, 3, 5], 1:6, [1], [2, 4, 6], [6, 6, 1])
            fig = diagnostic_plots(model, which=which)
            axes = plot_axes(fig)
            @test length(axes) == length(unique(which))
            @test [ax.title[] for ax in axes] == titles[sort(unique(which))]
        end
        plain = diagnostic_plots(model, which=[1, 2, 3], r_style=false)
        @test all(isempty ∘ line_plots, plot_axes(plain))
        styled = diagnostic_plots(model, which=[1, 2, 3])
        @test all(ax -> length(line_plots(ax)) == 1, plot_axes(styled))
    end

    @testset "leverage matches hat matrix" begin
        X = modelmatrix(model)
        @test OLSPlots._leverage(X) ≈ diag(X * inv(X'X) * X')
    end

    @testset "invalid which" begin
        @test_throws ArgumentError diagnostic_plots(model, which=[0])
        @test_throws ArgumentError diagnostic_plots(model, which=[1, 7])
        @test_throws ArgumentError diagnostic_plots(model, which=Int[])
        for invalid in ([1.0], [true], [missing], [:residuals])
            @test_throws ArgumentError diagnostic_plots(model, which=invalid)
        end
    end

    @testset "leverage-1 point" begin
        # The singleton indicator has leverage exactly one and an extreme fit.
        d = DataFrame(x = [zeros(20); 1.0], y = [randn(20); 10.0])
        m = lm(@formula(y ~ x), d)
        values = OLSPlots._diagnostics(m)
        @test values.h_ii[end] ≈ 1
        @test !values.h_ok[end]
        @test count(values.h_ok) == 20
        @test isnan(values.std_resids[end])
        @test isnan(values.cooks_d[end])
        for selection in ([1, 2, 3, 5], 1:6)
            fig = diagnostic_plots(m; which=selection)
            @test length(plot_axes(fig)) == length(selection)
        end
        fig = diagnostic_plots(m; which=[2, 3, 5, 6])
        axes = plot_axes(fig)
        @test length(scatter_points(axes[1])) == 20
        @test length(scatter_points(axes[3])) == 20
        @test length(scatter_points(axes[4])) == 20
    end

    @testset "undefined diagnostics" begin
        # An exact zero response makes zero variance deterministic across BLAS.
        d = DataFrame(x = collect(1.0:10.0))
        d.y = zeros(10)
        m = lm(@formula(y ~ x), d)
        @test OLSPlots._diagnostics(m).mse == 0
        for selection in ([1, 2, 3, 5], 1:6, [2], [3], [4], [5], [6])
            err = try
                diagnostic_plots(m; which=selection)
            catch error
                error
            end
            @test err isa ArgumentError
            @test occursin("residual variance", sprint(showerror, err))
        end
        fig = diagnostic_plots(m; which=[1])
        points = scatter_points(only(plot_axes(fig)))
        @test all(point -> point[2] == 0, points)

        saturated = lm(Matrix{Float64}(I, 4, 4), collect(1.0:4.0))
        @test dof_residual(saturated) == 0
        @test diagnostic_plots(saturated; which=[1]) isa CairoMakie.Figure
        err = try
            diagnostic_plots(saturated)
        catch error
            error
        end
        @test err isa ArgumentError
        @test occursin("residual degrees of freedom", sprint(showerror, err))
    end

    @testset "rank-deficient models" begin
        x = collect(1.0:20.0)
        y = 1 .+ 2 .* x .+ sin.(x)
        for X in (hcat(ones(20), x, x), hcat(zeros(20), x, ones(20), 2 .* x))
            m = lm(X, y)
            values = OLSPlots._diagnostics(m)
            h = diag(X * pinv(X))
            @test values.p == rank(X) == 2
            @test values.residual_df == 18
            @test sum(values.h_ii) ≈ 2
            @test values.h_ii ≈ h
            expected_mse = sum(abs2, residuals(m)) / 18
            expected_std = residuals(m) ./ sqrt.(expected_mse .* (1 .- h))
            expected_cooks = residuals(m).^2 .* h ./ (2 * expected_mse .* (1 .- h).^2)
            @test values.mse ≈ expected_mse
            @test values.std_resids ≈ expected_std
            @test values.cooks_d ≈ expected_cooks
            @test length(plot_axes(diagnostic_plots(m; which=1:6))) == 6
        end
        # The formula wrapper must preserve the same effective rank.
        table = DataFrame(x=x, duplicate=x, y=y)
        wrapped = lm(@formula(y ~ x + duplicate), table)
        @test OLSPlots._diagnostics(wrapped).p == 2
        @test OLSPlots._leverage(hcat(x, x)) ≈ diag(hcat(x, x) * pinv(hcat(x, x)))

        # Honor the fit's tolerance when it drops a nearly dependent column
        # that a fresh matrix-rank estimate would retain.
        X = hcat(ones(20), x, x .+ 1e-9 .* sin.(x))
        nearly = lm(X, y)
        values = OLSPlots._diagnostics(nearly)
        @test rank(X) == 3
        @test values.p == 2
        retained = findall(isfinite, stderror(nearly))
        reduced_X = X[:, retained]
        @test values.h_ii ≈ diag(reduced_X * pinv(reduced_X))
        @test sum(values.h_ii) ≈ values.p
        axis = only(plot_axes(diagnostic_plots(nearly; which=[6], r_style=false)))
        for (b, line) in zip([0.5, 1.0, 1.5, 2.0], line_plots(axis))
            points = line[1][]
            @test last.(points) ≈ (b^2 / 2) .* first.(points) rtol=1e-6
        end

        # A single zero-leverage row does not mean all leverage is constant.
        zero_row = lm(reshape(collect(0.0:9.0), :, 1), sin.(0.0:9.0))
        axis = only(plot_axes(diagnostic_plots(zero_row; which=[5], r_style=false)))
        @test length(scatter_points(axis)) == 10
    end

    @testset "smoothing with filtered or insufficient data" begin
        @test OLSPlots._smooth_values(ones(10), collect(1.0:10.0)) === nothing
        @test OLSPlots._smooth_values(collect(1.0:4.0), ones(4)) === nothing
        @test OLSPlots._smooth_values(collect(1.0:10.0), fill(NaN, 10)) === nothing
        xs = collect(1.0:12.0)
        ys = sin.(xs)
        ys[[1, 12]] .= NaN
        grid, curve = OLSPlots._smooth_values(xs, ys)
        @test extrema(grid) == (2.0, 11.0)
        @test all(isfinite, curve)
        # Filtering leverage-one observations leaves only three usable points.
        X = hcat(ones(5), [0., 0., 0., 1., 0.], [0., 0., 0., 0., 1.])
        small = lm(X, [1., 3., 2., 10., 20.])
        @test count(OLSPlots._diagnostics(small).h_ok) == 3
        @test length(plot_axes(diagnostic_plots(small; which=1:6))) == 6
        intercept = lm(ones(10, 1), sin.(1.0:10.0))
        @test diagnostic_plots(intercept) isa CairoMakie.Figure
    end

    @testset "R reference and plotted diagnostics" begin
        raw, header = readdlm(joinpath(@__DIR__, "..", "data", "mtcars.csv"), ',', Any; header=true)
        cars = DataFrame(model=String.(raw[:, 1]))
        for j in 2:size(raw, 2)
            cars[!, Symbol(header[j])] = Float64.(raw[:, j])
        end
        m = lm(@formula(mpg ~ hp + drat + wt), cars)
        reference, reference_header = readdlm(
            joinpath(@__DIR__, "..", "data", "mtcars-r-diagnostics.csv"), ',', Any; header=true)
        @test vec(String.(reference_header)) == ["model", "fitted", "residual", "leverage", "standardized_residual", "cooks_distance"]
        @test String.(reference[:, 1]) == cars.model
        expected = Float64.(reference[:, 2:end])
        values = OLSPlots._diagnostics(m)
        actual = hcat(values.fitted_vals, values.resids, values.h_ii, values.std_resids, values.cooks_d)
        @test all(isapprox.(actual, expected; atol=1e-9, rtol=1e-9))
        @test values.cooks_d ≈ cooksdistance(m)
        fig = diagnostic_plots(m; which=1:6, r_style=false)
        axes = plot_axes(fig)
        expected_points = (
            (expected[:, 1], expected[:, 2]),
            nothing,
            (expected[:, 1], sqrt.(abs.(expected[:, 4]))),
            (collect(1:32), expected[:, 5]),
            (expected[:, 3], expected[:, 4]),
            (expected[:, 3] ./ (1 .- expected[:, 3]), expected[:, 5]),
        )
        for i in (1, 3, 4, 5, 6)
            points = scatter_points(axes[i])
            @test length(points) == 32
            @test first.(points) ≈ expected_points[i][1] rtol=1e-6
            @test last.(points) ≈ expected_points[i][2] rtol=1e-6
        end
        qqpoints = scatter_points(axes[2])
        @test last.(qqpoints) ≈ sort(expected[:, 4]) rtol=1e-6

        # Verify rendered contour geometry, including clipped and full lines.
        for (b, line) in zip([0.5, 1.0, 1.5, 2.0], line_plots(axes[6]))
            points = line[1][]
            @test last.(points) ≈ (b^2 / 4) .* first.(points) rtol=1e-6
        end
        @test length(line_plots(axes[6])) == 4
        for (level, positive, negative) in zip([0.5, 1.0], line_plots(axes[5])[1:2:end], line_plots(axes[5])[2:2:end])
            for line in (positive, negative)
                points = line[1][]
                x, y = first.(points), last.(points)
                @test (y.^2 ./ 4) .* x ./ (1 .- x) ≈ fill(level, length(x)) rtol=1e-5
            end
        end
        @test length(line_plots(axes[5])) == 4
        mktempdir() do directory
            for extension in ("png", "pdf")
                file = joinpath(directory, "diagnostics." * extension)
                save(file, fig)
                @test filesize(file) > 1000
            end
        end
    end

    @testset "model boundary" begin
        @test_throws ArgumentError diagnostic_plots(nothing)
        weighted = lm(modelmatrix(model), response(model); wts=fill(2.0, 100))
        @test_throws ArgumentError diagnostic_plots(weighted)
        generalized = glm(ones(10, 1), collect(1.0:10.0), Poisson())
        @test_throws ArgumentError diagnostic_plots(generalized)
    end
end
