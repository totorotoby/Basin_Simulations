push!(ARGS, "../../input_files/dynamic/basin_refinement/8GPa/3n.dat")
include("../../Basin.jl")
pop!(ARGS)
push!(ARGS, "../../input_files/dynamic/basin_refinement/8GPa/6n.dat")
include("../../Basin.jl")
pop!(ARGS)
push!(ARGS, "../../input_files/dynamic/basin_refinement/8GPa/9n.dat")
include("../../Basin.jl")
pop!(ARGS)
push!(ARGS, "../../input_files/dynamic/basin_refinement/8GPa/12n.dat")
include("../../Basin.jl")
pop!(ARGS)

