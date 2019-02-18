
# ---------------------------------------------------------------------------
# Violin Plot

const _violin_warned = [false]

function violin_coords(y; trim::Bool=false)
    kd = KernelDensity.kde(y, npoints = 200)
    if trim
        xmin, xmax = Plots.ignorenan_extrema(y)
        inside = Bool[ xmin <= x <= xmax for x in kd.x]
        return(kd.density[inside], kd.x[inside])
    end
    kd.density, kd.x
end

get_quantiles(quantiles::AbstractVector) = quantiles
get_quantiles(x::Real) = [x]
get_quantiles(b::Bool) = b ? [0.5] : Float64[]
get_quantiles(n::Int) = range(0, 1, length = n + 2)[2:end-1]

@recipe function f(::Type{Val{:violin}}, x, y, z; trim=true, side=:both, mean = false, median = false, quantiles = Float64[])
    # if only y is provided, then x will be UnitRange 1:length(y)
    if typeof(x) <: AbstractRange
        if step(x) == first(x) == 1
            x = plotattributes[:series_plotindex]
        else
            x = [getindex(x, plotattributes[:series_plotindex])]
        end
    end
    xsegs, ysegs = Segments(), Segments()
    glabels = sort(collect(unique(x)))
    bw = plotattributes[:bar_width]
    bw == nothing && (bw = 0.8)
    msc = plotattributes[:markerstrokecolor]
    for (i,glabel) in enumerate(glabels)
        fy = y[filter(i -> _cycle(x,i) == glabel, 1:length(y))]
        widths, centers = violin_coords(fy, trim=trim)
        isempty(widths) && continue

        # normalize
        hw = 0.5_cycle(bw, i)
        widths = hw * widths / Plots.ignorenan_maximum(widths)

        # make the violin
        xcenter = Plots.discrete_value!(plotattributes[:subplot][:xaxis], glabel)[1]
        if (side==:right)
          xcoords = vcat(widths, zeros(length(widths))) .+ xcenter
        elseif (side==:left)
          xcoords = vcat(zeros(length(widths)), -reverse(widths)) .+ xcenter
        else
          xcoords = vcat(widths, -reverse(widths)) .+ xcenter
        end
        ycoords = vcat(centers, reverse(centers))

        @series begin
            seriestype := :shape
            x := xcoords
            y := ycoords
            ()
        end

        if mean
            mea = StatsBase.mean(fy)
            mw = maximum(widths)
            mx = xcenter .+ [-mw, mw] * 0.75
            my = [mea, mea]
            if side == :right
                mx[1] = xcenter
            elseif side == :left
                mx[2] = xcenter
            end

            @series begin
                primary := false
                seriestype := :shape
                linestyle := :dot
                x := mx
                y := my
                ()
            end
        end

        if median
            med = StatsBase.median(fy)
            mw = maximum(widths)
            mx = xcenter .+ [-mw, mw] / 2
            my = [med, med]
            if side == :right
                mx[1] = xcenter
            elseif side == :left
                mx[2] = xcenter
            end

            @series begin
                primary := false
                seriestype := :shape
                x := mx
                y := my
                ()
            end
        end

        quantiles = get_quantiles(quantiles)
        if !isempty(quantiles)
            qy = quantile(fy, quantiles)
            maxw = maximum(widths)

            for i in eachindex(qy)
                qxi = xcenter .+ [-maxw, maxw] * (0.5 - abs(0.5 - quantiles[i]))
                qyi = [qy[i], qy[i]]
                if side == :right
                    qxi[1] = xcenter
                elseif side == :left
                    qxi[2] = xcenter
                end

                @series begin
                    primary := false
                    seriestype := :shape
                    x := qxi
                    y := qyi
                    ()
                end
            end

            @series begin
                primary :=false
                seriestype := :shape
                x := [xcenter, xcenter]
                y := [extrema(qy)...]
            end
        end
    end

    seriestype := :shape
    primary := false
    x := []
    y := []
    ()
end
Plots.@deps violin shape

# ------------------------------------------------------------------------------
# Grouped Violin

@userplot GroupedViolin

recipetype(::Val{:groupedviolin}, args...) = GroupedViolin(args)

@recipe function f(g::GroupedViolin; spacing = 0.1)
    x, y = grouped_xy(g.args...)

    # extract xnums and set default bar width.
    # might need to set xticks as well
    ux = unique(x)
    x = if eltype(x) <: Number
        bar_width --> (0.8 * mean(diff(sort(ux))))
        float.(x)
    else
        bar_width --> 0.8
        xnums = [findfirst(isequal(xi), ux) for xi in x] .- 0.5
        xticks --> (eachindex(ux) .- 0.5, ux)
        xnums
    end

    # shift x values for each group
    group = get(plotattributes, :group, nothing)
    if group != nothing
        ug = unique(group)
        n = length(ug)
        bws = plotattributes[:bar_width] / n
        bar_width := bws * clamp(1 - spacing, 0, 1)
        for i in 1:n
            groupinds = findall(isequal(ug[i]), group)
            Δx = _cycle(bws, i) * (i - (n + 1) / 2)
            x[groupinds] .+= Δx
        end
    end

    seriestype := :violin
    x, y
end

Plots.@deps groupedviolin violin
