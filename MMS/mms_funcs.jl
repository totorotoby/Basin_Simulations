include("../physical_params.jl")
using Plots

##################
#  MMS Function  #
##################


function ϕ(x, y, MMS)
    h = MMS.H
    return (h .* (h .+ x)) ./
        ((h .+ x).^2 .+ y.^2)
end

function ϕ_x(x, y, MMS)
    h = MMS.H
    return (h .* (y.^2 .- (h .+ x).^2)) ./ (((h .+ x).^2 .+ y.^2).^2)
end

function ϕ_xx(x, y, MMS)
    h = MMS.H
    return (2*h .* (h .+ x) .* (h^2 .+ 2*h .* x .+ x.^2 .- 3*y.^2)) ./
        ((h^2 .+ 2*h .* x .+ x.^2 .+ y.^2).^3)
end

function ϕ_y(x, y, MMS)
    h = MMS.H
    return - (2 * h .* y .* (h .+ x)) ./
        ((h .+ x).^2 .+ y.^2).^2
end

function ϕ_yy(x, y, MMS)
    h = MMS.H
    return (2*h .* (h .+ x) .* (3 .* y.^2 .- (h .+ x).^2)) ./
        (((h .+ x).^2 .+ y.^2).^3)
end

function K(t, MMS)
    
    t̄ = MMS.t̄
    tw = MMS.t_w
    δ = MMS.δ_e
    Vm = MMS.Vmin
    
    return 1/π * (atan((t - t̄)/tw) + π/2) + Vm/δ * t
end

function K_t(t, MMS)
    
    t̄ = MMS.t̄
    tw = MMS.t_w
    δ = MMS.δ_e
    Vm = MMS.Vmin
    
    return tw / (π * ((t - t̄)^2 + tw^2)) + Vm/δ
end

function K_tt(t, MMS)
    
    t̄ = MMS.t̄
    tw = MMS.t_w
    δ = MMS.δ_e
    Vm = MMS.Vmin

    return -(2 * tw * (t - t̄)) / (π * ((t - t̄)^2 + tw^2)^2)
end

he(x, y, t, MMS) = MMS.δ_e/2 .* K(t, MMS) .* ϕ(x, y, MMS) .+ MMS.Vp/2 .* t .* (1 .- ϕ(x,y,MMS)) .+
    MMS.τ∞/24 .* x

he_t(x, y, t, MMS) = MMS.δ_e/2 .* K_t(t, MMS) .* ϕ(x, y, MMS) .+ MMS.Vp/2 .* (1 .- ϕ(x,y,MMS))

he_tt(x, y, t, MMS) = MMS.δ_e/2 .* K_tt(t, MMS) .* ϕ(x, y, MMS)

he_x(x, y, t, MMS) =  MMS.δ_e/2 .* K(t, MMS) .* ϕ_x(x, y, MMS) .- MMS.Vp/2 .* t .* ϕ_x(x, y, MMS) .+ MMS.τ∞/24

he_xx(x, y, t, MMS) =  MMS.δ_e/2 .* K(t, MMS) .* ϕ_xx(x, y, MMS) .- MMS.Vp/2 .* t .* ϕ_xx(x, y, MMS)

he_y(x, y, t, MMS) =  MMS.δ_e/2 .* K(t, MMS) .* ϕ_y(x, y, MMS) .- MMS.Vp/2 .* t .* ϕ_y(x, y, MMS)

he_yy(x, y, t, MMS) =  MMS.δ_e/2 .* K(t, MMS) .* ϕ_yy(x, y, MMS) .- MMS.Vp/2 .* t .* ϕ_yy(x, y, MMS)

he_xt(x, y, t, MMS) = MMS.δ_e/2 .* K_t(t, MMS) .* ϕ_x(x, y, MMS) .- MMS.Vp/2 .* ϕ_x(x, y, MMS)

h_FORCE(x, y, t, B_p, MMS) = -(μ_x(x, y, B_p) .* he_x(x, y, t, MMS) .+
    μ(x, y, B_p) .* he_xx(x, y, t, MMS) .+
    μ_y(x, y, B_p) .* he_y(x, y, t, MMS) .+
    μ(x, y, B_p) .* he_yy(x, y, t, MMS))

function τhe(fx, fy, t, fnum, B_p, MMS)

    if fnum == 1
        τ = -μ(fx, fy, B_p) .* he_x(fx, fy, t, MMS)
    elseif fnum == 2
        τ = μ(fx, fy, B_p) .* he_x(fx, fy, t, MMS)
    elseif fnum == 3
        τ = -μ(fx, fy, B_p) .* he_y(fx, fy, t, MMS)
    elseif fnum == 4 
        τ = μ(fx, fy, B_p) .* he_y(fx, fy, t, MMS)
    end
    return τ

end


function ψe_d(x, y, t, B_p, RS, MMS)
    
    τe = τhe(x, y, t, 1, B_p, MMS)
    Ve = 2 .* he_t(x, y, t, MMS)

    return RS.a .* log.((2 * RS.V0 ./ Ve) .* sinh.((-τe .- η(y, B_p) .* Ve) ./ (RS.a .* RS.σn)))
end


function ψe_td(x, y, t, B_p, RS, MMS)

    τe = τhe(x, y, t, 1, B_p, MMS)
    Ve = 2 * he_t(x, y, t, MMS)
    Ve_t = 2 * he_tt(x, y, t, MMS)
    τe_t = - μ(x, y, B_p) .* he_xt(x, y, t, MMS)

    ψ_t = τe_t .* coth.(τe ./ (RS.a * RS.σn)) ./ RS.σn .- RS.a .* Ve_t ./ Ve

    return ψ_t

end


    
function ψe(x, y, t, B_p, RS, MMS)

    τe = τhe(x, y, t, 1, B_p, MMS)
    Ve = 2 .* he_t(x, y, t, MMS)

    return RS.a .* log.((2 * RS.V0 ./ Ve) .* sinh.((-τe .- η(y, B_p) .* Ve) ./ (RS.a .* RS.σn)))
    
end

function ψe_t(x, y, t, B_p, RS, MMS)

    τe = τhe(x, y, t, 1, B_p, MMS)
    Ve = 2 * he_t(x, y, t, MMS)
    Ve_t = 2 * he_tt(x, y, t, MMS)
    τe_t = - μ(x, y, B_p) .* he_xt(x, y, t, MMS)

    ψ_t = (-τe_t .- η(y, B_p) .* Ve_t) .* coth.((-τe .- η(y, B_p) .* Ve) ./ (RS.a * RS.σn)) ./ RS.σn .- RS.a .* Ve_t ./ Ve

    return ψ_t

end


function findNanInf(a)

    for i in 1:length(a)
        
        if isnan(a[i])
            return true, 1, i
        end

        if isinf(a[i])
            return true, 2, i
        end

    end

    return false, 0, 0
    
end



function fault_force(x, y, t, b, B_p, RS, MMS)

    ψ = ψe(x, y, t, B_p, RS, MMS)
    Ve = 2 * he_t(x, y, t, MMS)
    G = (b .* RS.V0 ./ RS.Dc) .* (exp.((RS.f0 .- ψ) ./ b) .- abs.(Ve) / RS.V0)


    s_rs = ψe_t(x, y, t, B_p, RS, MMS) .- G
    #=
    if any(!isfinite, s_rs)

        ψ_test = findNanInf(ψ)
        V_test = findNanInf(Ve)
        G_test = findNanInf(G)
        
        @show ψ_test
        @show V_test
        @show G_test

    end
    =#
    
    return s_rs

end

function h_face2(x, y, t, MMS, RS, μf2)
    return he(x, y, t, MMS) .- (MMS.Vp/2 * t .+ (RS.τ_inf * MMS.Lw) ./ μf2)
                                
end

function Forcing(x, y, t, B_p, MMS)
        
    Force = ρ(x, y, B_p) .* he_tt(x, y, t, MMS) .-
        (μ_x(x, y, B_p) .* he_x(x, y, t, MMS) .+ μ(x, y, B_p) .* he_xx(x, y, t, MMS) .+
         μ_y(x, y, B_p) .* he_y(x, y, t, MMS) .+ μ(x, y, B_p) .* he_yy(x, y, t, MMS))

    return Force
end

function S_c(fx, fy, t, fnum, R, B_p, MMS)
       
    Z = sqrt.(μ(fx, fy, B_p) .* ρ(fx, fy, B_p))
    v = he_t(fx, fy, t, MMS)
    τ = τhe(fx, fy, t, fnum, B_p, MMS)

    return Z .* v .+ τ .- R .* (Z .* v .- τ)
end

function S_rs(fx, fy, b, t, B_p, RS, MMS)
    
    ψ = ψe_d(fx, fy, t, B_p, RS, MMS)
    V = 2*he_t(fx, fy, t, MMS)
    G = (b .* RS.V0 ./ RS.Dc) .* (exp.((RS.f0 .- ψ) ./ b) .- abs.(V) / RS.V0)
    ψ_t = ψe_td(fx, fy, t, B_p, RS, MMS)
    return  ψ_t .- G

end


Pe(x, y, t, MMS) = sin.(2/MMS.Lw .* x) .* cos.(2/MMS.Lw .* (y.-1)) .* sin.(2/MMS.Lw .* t) .+ MMS.ϵ .* x .+ MMS.ϵ .* t

Pe_y(x, y, t, MMS) = - 2/MMS.Lw .* sin.(2/MMS.Lw * x) .* sin.(2/MMS.Lw * (y.-1)) .* sin.(2/MMS.Lw .* t)

Pe_yy(x, y, t, MMS) = - 2^2/MMS.Lw^2 .* sin.(2/MMS.Lw * x) .* cos.(2/MMS.Lw * (y.-1)) .* sin.(2/MMS.Lw .* t)

Pe_x(x, y, t, MMS) = 2/MMS.Lw * cos.(2/MMS.Lw * x) .* cos.(2/MMS.Lw * (y.-1)) .* sin.(2/MMS.Lw .* t) .+ MMS.ϵ

Pe_xt(x, y, t, MMS) = 2^2/MMS.Lw^2 * cos.(2/MMS.Lw * x) .* cos.(2/MMS.Lw * (y.-1)) .* cos.(2/MMS.Lw .* t)

Pe_xx(x, y, t, MMS) = - 2^2/MMS.Lw^2 * sin.(2/MMS.Lw * x) .* cos.(2/MMS.Lw * (y.-1)) .* sin.(2/MMS.Lw .* t)

Pe_t(x, y, t, MMS) = 2/MMS.Lw .* sin.(2/MMS.Lw .* x) .* cos.(2/MMS.Lw .* (y.-1)) .* cos.(2/MMS.Lw .* t) .+ MMS.ϵ

Pe_tt(x, y, t, MMS) = - 2^2/MMS.Lw^2 .* sin.(2/MMS.Lw .* x) .* cos.(2/MMS.Lw .* (y.-1)) .* sin.(2/MMS.Lw .* t)

P_FORCE(x, y, t, B_p, MMS) = - (μ_x(x, y, B_p) .* Pe_x(x, y, t, MMS) .+
    μ(x, y, B_p) .* Pe_xx(x, y, t, MMS) .+
    μ_y(x, y, B_p) .* Pe_y(x, y, t, MMS) .+
    μ(x, y, B_p) .* Pe_yy(x, y, t, MMS))


function τPe(fx, fy, t, fnum, B_p, MMS)

    if fnum == 1
        τ = -μ(fx, fy, B_p) .* Pe_x(fx, fy, t, MMS)
    elseif fnum == 2
        τ = μ(fx, fy, B_p) .* Pe_x(fx, fy, t, MMS)
    elseif fnum == 3
        τ = -μ(fx, fy, B_p) .* Pe_y(fx, fy, t, MMS)
    elseif fnum == 4 
        τ = μ(fx, fy, B_p) .* Pe_y(fx, fy, t, MMS)
    end
    return τ

end

function ψe_P(x, y, t, B_p, RS, MMS)

    τe = τPe(x, y, t, 1, B_p, MMS)
    Ve = 2 .* Pe_t(x, y, t, MMS)

    return RS.a .* log.((2 * RS.V0 ./ Ve) .* sinh.(-τe ./ (RS.a .* RS.σn))) .- η(y, B_p) .* Ve
    
end


function ψe_Pt(x, y, t, B_p, RS, MMS)

    τe = τPe(x, y, t, 1, B_p, MMS)
    Ve = 2 * Pe_t(x, y, t, MMS)
    Ve_t = 2 * Pe_tt(x, y, t, MMS)
    τe_t = - μ(x, y, B_p) .* Pe_xt(x, y, t, MMS)

    return τe_t ./ RS.σn .* coth.(τe ./ (RS.σn .* RS.a)) - RS.a .* Ve_t ./ Ve .- η(y, B_p) .* Ve_t
end


P_face2(x, y, t, MMS) = Pe(x, y, t, MMS) .- t

