module ModelSpectrum

# Abstract Types
abstract type AbstractSpectrum end
abstract type AbstractConvolutionKernel end

# Constants
const limit_kernel_width_default = 10.0
const speed_of_light = 299792458.0 # m/s

# spectrum.jl:  utils for computing simple spectrum models
using Distributions
export AbstractSpectrum, SimpleSpectrum, SimulatedSpectrum, ConvolvedSpectrum
#export continuum_model, absorption_lines, gaussian_convolution_kernel
#export std_gaussian_line, absorption_line
include("spectrum.jl")

# convolution_kernels.jl:  utils for convolution kernels
using QuadGK
export AbstractConvolutionKernel, GaussianConvolutionKernel, GaussianMixtureConvolutionKernel
include("convolution_kernels.jl")

end  # module ModelSpectrum
