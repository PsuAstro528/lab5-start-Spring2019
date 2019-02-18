"Compute the mean continuum flux as a function of wavelength (x) using polynomial model (coeff)."
function continuum_model(x::Number, coeff::AbstractArray; center = zero(typeof(x)) )
    @assert 2 <= length(coeff) <= 10
    y = coeff[end]
    for i in (length(coeff)-1):-1:1      # a range starting a degree and running backwards to 1
        y *= (x.-center)
        y += coeff[i]
    end
    return y
end

function continuum_model(x::AbstractArray{T}, coeff::AbstractArray; center = zero(typeof(x)) ) where T<:Number
    f(y) = continuum_model(y,coeff,center=center)  # make helper function so that broadcasting over x is unambiguous
    @inbounds f.(x)
end

"Compute a transmission coefficient for a Gaussian absorption line with given depth.  Optionally, truncate absorption at limit_line_effect."
function std_gaussian_line(x::Number, depth::Number; limit_line_effect = Inf)
   return abs(x)>limit_line_effect ? one(x) : one(x)-depth*exp(-0.5*x^2)
end

"Compute spectrum for an Gaussian absorption line give it's location, width and depth"
function absorption_line(x::Number, location::Number, width::Number, depth::Number; limit_line_effect = Inf)
    std_gaussian_line((x-location)/width, depth, limit_line_effect=limit_line_effect)
end


"Compute product of absorption lines at one wavelength given a list of locations, widths and depths"
function absorption_lines(x::Number, locations::AbstractArray, widths::AbstractArray, depths::AbstractArray; limit_line_effect = Inf)
    @assert length(locations) == length(widths) == length(depths) >= 1
    @inbounds trans = absorption_line(x, locations[1], widths[1], depths[1], limit_line_effect = limit_line_effect )
    for i in 2:length(locations)
        @inbounds trans = trans * absorption_line(x, locations[i],widths[i], depths[i], limit_line_effect = limit_line_effect )
    end
    return trans
end

function absorption_lines(x::AbstractArray, locations::AbstractArray, widths::AbstractArray, depths::AbstractArray; limit_line_effect = Inf)
    @assert length(locations) == length(widths) == length(depths) >= 1
    trans = absorption_line.(x, locations[1], widths[1], depths[1], limit_line_effect = limit_line_effect )
    @inbounds for i in 2:length(locations)
        trans = trans .* absorption_line.(x, locations[i],widths[i], depths[i], limit_line_effect = limit_line_effect )
    end
    return trans
end

"Wrapper to turn an arbitrary function of one variable into a sub-type of AbstractSpectrum."
struct SimpleSpectrum <: AbstractSpectrum
    spectrum::Function
    function SimpleSpectrum(f::Function)
        new(f)
    end
end

"Evaluate simple spectrum at wavelength(s) x."
function (s::SimpleSpectrum)(x::Number)
    s.spectrum(x)
end

function (s::SimpleSpectrum)(x::AbstractArray{T}) where T<:Number
    s.spectrum(x)
end

"Simulated spectrum consists of stellar lines, telluric lines, and optionally continuum and Doppler shift."
struct SimulatedSpectrum{T1,T2,T3,T4,T5,T6,T7,T8,T9} <: AbstractSpectrum
    star_line_locs::Array{T1,1}
    star_line_widths::Array{T2,1}
    star_line_depths::Array{T3,1}
    telluric_line_locs::Array{T4,1}
    telluric_line_widths::Array{T5,1}
    telluric_line_depths::Array{T6,1}
    continuum_param::Array{T7,1}
    z::T8
    lambda_mid::T9
    limit_line_effect::T9

    function SimulatedSpectrum(star_line_locs::Array{T1,1}, star_line_widths::Array{T2,1}, star_line_depths::Array{T3,1},
        telluric_line_locs::Array{T4,1}, telluric_line_widths::Array{T5,1}, telluric_line_depths::Array{T6,1};
        continuum_param::Array{T7,1} = [1.0], z::T8 = 0.0, lambda_mid::T9 = 0.0, limit_line_effect::T9 = Inf
        ) where {T1<:Number, T2<:Number, T3<:Number, T4<:Number, T5<:Number, T6<:Number, T7<:Number, T8<:Number, T9<:Number}
        @assert length(star_line_locs) == length(star_line_widths) == length(star_line_depths)
        @assert length(telluric_line_locs) == length(telluric_line_widths) == length(telluric_line_depths)
        @assert length(continuum_param) >= 1
        new{T1,T2,T3,T4,T5,T6,T7,T8,T9}(star_line_locs,star_line_widths,star_line_depths,
            telluric_line_locs,telluric_line_widths,telluric_line_depths,
            continuum_param,z,lambda_mid,limit_line_effect)
    end
end

"Evaluate simulated spectrum at wavelength(s) x."
function (spectrum::SimulatedSpectrum)(x::Number)
    continuum_model(x*(one(spectrum.z)+spectrum.z),spectrum.continuum_param,center=spectrum.lambda_mid) *
            absorption_lines(x*(one(spectrum.z)+spectrum.z), spectrum.star_line_locs, spectrum.star_line_widths, spectrum.star_line_depths, limit_line_effect=spectrum.limit_line_effect ) *
            absorption_lines(x, spectrum.telluric_line_locs, spectrum.telluric_line_widths, spectrum.telluric_line_depths, limit_line_effect=spectrum.limit_line_effect )
end

function (spectrum::SimulatedSpectrum)(x::AbstractArray{T}) where T<:Number
    #@inbounds spectrum.(x)
    f_cont(y) = continuum_model(y*(one(spectrum.z)+spectrum.z),spectrum.continuum_param,center=spectrum.lambda_mid)
    f_star(y) = absorption_lines(y*(one(spectrum.z)+spectrum.z), spectrum.star_line_locs, spectrum.star_line_widths, spectrum.star_line_depths, limit_line_effect=spectrum.limit_line_effect )
    f_telluric(y) = absorption_lines(y, spectrum.telluric_line_locs, spectrum.telluric_line_widths, spectrum.telluric_line_depths, limit_line_effect=spectrum.limit_line_effect )
    @inbounds f_cont.(x) .* f_star.(x) .* f_telluric.(x)
end

"Spectrum based on conlving another spectrum with a point spread function.  Optionally, limit the width of the convolution."
struct ConvolvedSpectrum{T1,T2} <: AbstractSpectrum
    spectrum::T1
    kernel::T2
    limit_conv_width::Float64
    function ConvolvedSpectrum(spectrum::T1, kernel::T2;
         limit_conv_width = limit_kernel_width_default) where {T1<:AbstractSpectrum, T2<:AbstractConvolutionKernel}
        new{T1,T2}(spectrum,kernel,limit_conv_width)
    end
end

"Evaluate the convolved spectrum a wavelenth(s) x"
function (s::ConvolvedSpectrum)(x::Number)
    quadgk(y -> s.spectrum(x+y) * s.kernel(y),
                -s.limit_conv_width,s.limit_conv_width)[1]
end

function (s::ConvolvedSpectrum)(x::AbstractArray{T}) where T<:Number
    @inbounds quadgk(y -> s.spectrum(x.+y) .* s.kernel.(y),
                -s.limit_conv_width,s.limit_conv_width)[1]
end
