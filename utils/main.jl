# Program for plotting Basin output, and getting new initial conditions.
using Printf
using Plots
using DelimitedFiles

get_line(data, i) = map(x -> parse(Float64, x), split.(data[i]))

function get_cycle_indices(slip_data)

        cycle_index = []
        count = 0
        for (i, line) in enumerate(slip_data)
            if line == "BREAK"
                count += 1
                if count%2 == 0
                    push!(cycle_index, i+1)
                end
            end
        end

    return count, cycle_index

end

# Function for reading in numerical parameters for basin simulations
function read_params(f_name)
    f = open(f_name, "r")
    params = []
    while ! eof(f)
        s = readline(f)
        if s[1] != '#'
            push!(params, split(s, '=')[2])
        end
    end
    close(f)
    p = parse(Int64, params[1])
    T = parse(Float64, params[2])
    N = parse(Int64, params[3])
    Lw = parse(Float64, params[4])
    r̂ = parse(Float64, params[5])
    l = parse(Float64, params[6])
    b_depth = parse(Float64, params[7])
    dynamic_flag = parse(Int64,params[8])
    d_to_s = parse(Float64, params[9])
    dt_scale = parse(Float64, params[10])
    ic_file = params[11]
    ic_t_file = params[12]
    Dc = parse(Float64, params[13])
    B_on = parse(Int64, params[14])
    return (p, T, N, Lw, r̂, l, b_depth, dynamic_flag, d_to_s, dt_scale, ic_file, ic_t_file, Dc, B_on)
end

let 
    
    v = false
    while v == false
        @printf "\nOutput directory: "
        folder_name = chomp(readline())
        try
            cd(string("../../erickson/output_files/", folder_name))
            v = true
        catch
            @printf "Directory not found\n"
        end
    end
    @printf "Found directory...\n\n"

  
    done = false
    while !done

        @printf "\t(1) Slip Plot\n"
        @printf "\t(2) Slip Rate Animation\n"
        @printf "\t(3) Traction Animation\n"
        @printf "\t(4) Station Data\n"
        @printf "\t(5) Single Cycle\n\n"
        @printf "\t(6) Done\n"

        v = false
        flag = [0]
        while v == false
            @printf "Option: "
            try
                flag[1] = parse(Int64, chomp(readline()))
                if 0 < flag[1] < 7
                    v = true
                end
            catch
                @printf "Not and Option\n"
            end
            
        end
        
        if flag[1] == 1
            
            slip_file = open("slip.dat", "r")
            slip_data = collect(eachline(slip_file))
            
            nn = parse(Int64, slip_data[1])
            y = get_line(slip_data, 2)[3:end]
            
            cycle_index = get_cycle_indices(slip_data)[2]
            
            @printf "\n%d cycles in this data\n" length(cycle_index)
            @printf "Offset contours by # of cycles: "
            cycle_offset = parse(Int64, chomp(readline()))
            if cycle_offset == 0
                index_offset = 1
            elseif cycle_offset == length(cycle_index)
                index_offset = cycle_index[cycle_offset]
            else
                index_offset = cycle_index[cycle_offset] + 30
            end
            
            plt = plot(legend=false, yflip = true, ylabel="Depth(Km)", xlabel="Slip(m)")

            δ = zeros(nn)
            break_count = 0
            δ_off = get_line(slip_data, index_offset)[3:end]
            for index in index_offset:length(slip_data)
                
                if slip_data[index] == "BREAK"
                    plt = plot!(δ-δ_off, y, linecolor=:black, linewidth = 1)
                    break_count += 1
                else
                    
                    δ .= get_line(slip_data, index)[3:end]
                    
                    if break_count % 2 == 0
                        plt = plot!(δ-δ_off, y, linecolor=:blue, linewidth = .2)
                    else
                    plt = plot!(δ-δ_off, y, linecolor=:red, linewidth = .2)
                    end 
                end
                
            end
            
            
            gui()
            
            close(slip_file)
            
        elseif flag[1] == 2
            
        elseif flag[1] == 3
            
        elseif flag[1] == 4
            
        elseif flag[1] == 5
            
            slip_file = open("slip.dat", "r")
            slip_data = collect(eachline(slip_file))
            
            nn = parse(Int64, split.(Iterators.take(slip_data, 1))[1][1])
            y = map(x -> parse(Float64, x), split.(slip_data[2]))[3:end]
            
            break_number, cycle_indices = get_cycle_indices(slip_data)
            
            @printf "\n%d cycles in this data\n" length(cycle_indices)
            @printf "Which Cycle: "
            
            cycle_number = parse(Int64, chomp(readline()))
            
            cycle_index = cycle_indices[cycle_number]
            done1 = false

            while !done1
                @printf "\n\t(1) Write-out cycle initial conditions\n"
                @printf "\t(2) Plot volume variables\n"
                @printf "\t(3) Back\n"
                
                @printf "\nOption: "
                option = parse(Int64, chomp(readline()))
            
                if option == 1
                
                    state_file = open("state.dat", "r")
                    state_data = collect(eachline(state_file))
                    state_index = cycle_index - break_number - 1
                    
                    ψ = get_line(state_data, state_index)[3:end]
                    line = get_line(slip_data, cycle_index)
                    δ = line[3:end]
                    t = line[1]

                    close(state_file)
                    close(slip_file)
                
                    ψδ = vcat(ψ, δ)
                    
                    @printf "Filename: "
                    name = chomp(readline())
                    filename = string("/home/tharvey2/Basin_Simulations/input_files/", name)
                    filename_t = string(filename, "_t")

                    fout = open(filename, "w")
                    writedlm(fout , ψδ)
                    close(fout)
                    
                    fout = open(filename_t, "w")
                    writedlm(fout, [t])
                    close(fout)

                    @printf "inital conditions write to %s\n" filename

                elseif option == 2

                elseif option == 3
                    done1 = true

                end
            end
        
        elseif flag[1] == 6
            exit()
        end

    end

    cd("/home/tharvey2/Basin_Simulations/utils")
end

 
