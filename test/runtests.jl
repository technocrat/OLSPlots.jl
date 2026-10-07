using Test
using OLSPlots
using GLM
using DataFrames
using CairoMakie
using LinearAlgebra
using Random

@testset "OLSPlots.jl" begin
    Random.seed!(1)
    df = DataFrame(X1 = randn(100), X2 = randn(100))
    df.y = 2.0 .* df.X1 - 1.5 .* df.X2 + 0.5 .* randn(100)
    model = lm(@formula(y ~ X1 + X2), df)

    @testset "export" begin
        @test :diagnostic_plots in names(OLSPlots)
    end

    @testset "plot selection" begin
        for which in ([1, 2, 3, 5], 1:6, [1], [2, 4, 6], [6, 6, 1])
            @test diagnostic_plots(model, which=which) isa CairoMakie.Figure
        end
        @test diagnostic_plots(model, r_style=false) isa CairoMakie.Figure
    end

    @testset "leverage matches hat matrix" begin
        X = modelmatrix(model)
        @test OLSPlots._leverage(X) ≈ diag(X * inv(X'X) * X')
    end

    @testset "invalid which" begin
        @test_throws ArgumentError diagnostic_plots(model, which=[0])
        @test_throws ArgumentError diagnostic_plots(model, which=[1, 7])
        @test_throws ArgumentError diagnostic_plots(model, which=Int[])
    end

    @testset "leverage-1 point" begin
        d = DataFrame(x = [collect(1.0:20.0); 1000.0])
        d.y = 3 .* d.x .+ randn(21)
        m = lm(@formula(y ~ x), d)
        X = modelmatrix(m)
        @test maximum(diag(X * inv(X'X) * X')) > 0.9
        @test diagnostic_plots(m, which=1:6) isa CairoMakie.Figure
    end

    @testset "perfect fit" begin
        d = DataFrame(x = collect(1.0:10.0))
        d.y = 2 .* d.x .+ 1
        m = lm(@formula(y ~ x), d)
        @test diagnostic_plots(m, which=[4, 6]) isa CairoMakie.Figure
    end
end
