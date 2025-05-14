using Test
using OLSPlots
using GLM
using DataFrames
using CairoMakie

@testset "OLSPlots.jl" begin
    # Create sample data
    df = DataFrame(X1 = randn(100), X2 = randn(100))
    df.y = 2.0 .* df.X1 - 1.5 .* df.X2 + 0.5 .* randn(100)

    # Fit OLS model
    model = lm(@formula(y ~ X1 + X2), df)

    # Test that diagnostic_plots is exported
    @test isdefined(Main, :diagnostic_plots)
    
    # Test default plots (which=[1,2,3,5])
    fig_default = diagnostic_plots(model)
    @test fig_default isa CairoMakie.Figure
    
    # Test with all plots (which=1:6)
    fig_all = diagnostic_plots(model, which=1:6)
    @test fig_all isa CairoMakie.Figure
    
    # Test with individual plots
    fig_single = diagnostic_plots(model, which=[1])
    @test fig_single isa CairoMakie.Figure
    
    # Test with custom combination
    fig_custom = diagnostic_plots(model, which=[2,4,6])
    @test fig_custom isa CairoMakie.Figure
    
    # Test r_style parameter
    fig_no_rstyle = diagnostic_plots(model, r_style=false)
    @test fig_no_rstyle isa CairoMakie.Figure
end
