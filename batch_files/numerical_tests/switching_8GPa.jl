push!(ARGS, "../../input_files/dynamic/basin_switching/8GPa/switch1.dat")
include("../../Basin.jl")
pop!(ARGS)
push!(ARGS, "../../input_files/dynamic/basin_switching/8GPa/switch2.dat")
include("../../Basin.jl")
pop!(ARGS)
push!(ARGS, "../../input_files/dynamic/basin_switching/8GPa/switch3.dat")
include("../../Basin.jl")
#=
pop!(ARGS)
push!(ARGS, "../../input_files/dynamic/basin_switching/8GPa/switch4.dat")
include("../../Basin.jl")
pop!(ARGS)
push!(ARGS, "../../input_files/dynamic/basin_switching/8GPa/switch5.dat")
include("../../Basin.jl")
pop!(ARGS)
=#
