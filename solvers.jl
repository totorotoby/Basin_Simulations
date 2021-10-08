using Plots


function ODE_RHS_D_MMS!(dq, q, p, t)

    nn = p.nn
    Nn = p.Nn
    R = p.R
    L = p.L
    Ã = p.Ã
    JIHP = p.JIHP
    P̃I = p.P̃I
    sJ = p.sJ
    Γ = p.Γ
    H = p.H
    Z̃f = p.Z̃f
    Cf = p.Cf
    B = p.B
    BCTH = p.BCTH
    BCTHL = p.BCTHL
    nCnΓ = p.nCnΓ
    nBBCΓL = p.nBBCΓL
    n = p.n
    fcs = p.fcs
    coord = p.coord
    τ̃ =  p.τ̃
    û =  p.û
    dû = p.dû
    τ̂ = p.τ̂
    τf = p.τf
    fault_v = p.fault_v
    B_p = p.B_p
    RS = p.RS
    MMS = p.MMS
    b = p.b
    Forcing = p.Forcing
    Char_Source = p.Char_Source
    RS_Source = p.RS_Source
    State_Source = p.State_Source

    u = q[1:Nn]
    v = q[Nn + 1:2Nn]
    for i in 1:4
        û[i] = q[2Nn + (i-1)*nn + 1 : 2Nn + i*nn]
    end
    ψ = q[2Nn + 4*nn + 1 : 2Nn + 5*nn]

    du = @view dq[1:Nn]
    dv = @view dq[Nn + 1:2Nn]
    for i in 1:4
        dû[i] = @view dq[2Nn + (i-1)*nn + 1 : 2Nn + i*nn]
    end

    dψ = @view dq[2Nn + 4*nn + 1 : 2Nn + 5*nn]
    
    ### numerical traction on face ###
    for i in 1:4
        τ̃[i] =  nBBCΓL[i] * u + nCnΓ[i] * û[i]
    end

    ### charcterstic boundary conditions ###
    for i in 1:4
        vf = L[i]*v
        fx = fcs[1][i]
        fy = fcs[2][i]
        S̃_c = sJ[i] .* Char_Source(fx, fy, t, i, R[i], B_p, MMS)
        dû[i] .= (1 + R[i])/2 * (vf - τ̃[i]./Z̃f[i]) + S̃_c ./ (2*Z̃f[i])
        τ̂[i] = -(1 - R[i])/2 * (Z̃f[i] .* vf - τ̃[i]) + S̃_c ./ 2
        
    end
    
    ### rate-state boundary condition ###
    # transformed quantities on face 1
    z̃f1 = Z̃f[1]
    vf1 = L[1] * v
    τ̃f1 = τ̃[1]
    sJ1 = sJ[1]
    f1x = fcs[1][1]
    f1y = fcs[2][1]
    
    # solve for velocity flux point by point
    for n in 1:nn

        z̃n = z̃f1[n]
        vn = vf1[n]
        sJn = sJ1[n]
        τ̃n = τ̃f1[n]
        ψn =ψ[n]
        bn = b[n]
        
        #@show n, z̃n, vn ,sJn, τ̃n, ψn, bn


        v̂_root(v̂) = rateandstateD(v̂, z̃n, vn, sJn, ψn, RS.a, τ̃n, RS.σn, RS.V0)
        
        left = -1e5#vn - τ̃n/z̃n
        right = 1e5#-left
        
        
        if left > right  
            tmp = left
            left = right
            right = tmp
        end
        
        (v̂n, _, _) = newtbndv(v̂_root, left, right, vn; ftol = 1e-12,
                               atolx = 1e-12, rtolx = 1e-12)
        
        if isnan(v̂n)
            @show left
            @show right
            println("NAN FROM ROOTFINDER!")
            quit()
        end
        
        fault_v[n] = v̂n
        #=
        # update state evolution
        if bn != 0
            #@show ψn, bn, exp((RS.f0 - ψn)/bn)
            dψ[n] = (bn * RS.V0 / RS.Dc) * (exp((RS.f0 - ψn) / bn) - abs(2*v̂n) / RS.V0)
        else
            dψ[n] = 0
        end
        =#
        # update traction flux on fault
        τf[n] = z̃n * (v̂n .- vn) + τ̃n
    end
    
    
    dû[1] .= fault_v
    dψ .= State_Source(f1x, f1y, t, B_p, RS, MMS) #(b .* RS.V0 ./ RS.Dc) .* (exp.((RS.f0 .- ψ) ./ b) .- abs.(2 .* fault_v) ./ RS.V0) .+ 
        #RS_Source(f1x, f1y, b, t, 1, B_p, RS, MMS)
    τ̂[1] = τf
    
    ### set velocity and displacement evolution ###
    du .= v
    mul!(dv, Ã, u, -1, 0)
    
    for i in 1:4
        dv .+= L[i]' * H[i] * τ̂[i] + BCTH[i] * û[i] + BCTHL[i] * u
    end

    dv .= JIHP * dv
    dv .+= P̃I * Forcing(coord[1][:], coord[2][:], t, B_p, MMS)

    #=
    contour(coord[1][:,1], coord[2][1,:],
            (reshape(u, (nn, nn)) .- ue(coord[1],coord[2], t, MMS))',
            xlabel="off fault", ylabel="depth", fill=true, yflip=true)
    gui()
    =# 
end


function ODE_RHS_ACTION_CPU!(dq, q, p, t)

    nn = p.nn
    Nn = p.Nn
    R = p.R
    L = p.L
    Ã = p.Ã
    JIHP = p.JIHP
    P̃I = p.P̃I
    sJ = p.sJ
    H = p.H
    Z̃f = p.Z̃f
    Cf = p.Cf
    BCTH = p.BCTH
    BCTHL = p.BCTHL
    nCnΓ = p.nCnΓ
    nBBCΓL = p.nBBCΓL
    n = p.n
    fcs = p.fcs
    coord = p.coord
    τ̃ =  p.τ̃
    û =  p.û
    dû = p.dû
    τ̂ = p.τ̂
    B_p = p.B_p
    MMS = p.MMS
    Forcing = p.Forcing
    Char_Source = p.Char_Source
    State_Source = p.State_Source


    u = q[1:Nn]
    v = q[Nn + 1:2Nn]
    for i in 1:4
        û[i] = q[2Nn + (i-1)*nn + 1 : 2Nn + i*nn]
    end
    ψ = q[2Nn + 4*nn + 1 : 2Nn + 5*nn]

    du = @view dq[1:Nn]
    dv = @view dq[Nn + 1:2Nn]
    for i in 1:4
        dû[i] = @view dq[2Nn + (i-1)*nn + 1 : 2Nn + i*nn]
    end

    dψ = @view dq[2Nn + 4*nn + 1 : 2Nn + 5*nn]
    
    ### numerical traction on face ###
    #for i in 1:4
    #    τ̃[i] =  nBBCΓL[i] * u + nCnΓ[i] * û[i]
    #end


    ### charcterstic boundary conditions ###
    for i in 1:4
        #vf = L[i]*v
        fx = fcs[1][i]
        fy = fcs[2][i]
        S̃_c = sJ[i] .* Char_Source(fx, fy, t, i, R[i], B_p, MMS)

        
        dû[i] .=
            (1 + R[i])/2 .* L[i]*v -
            (1 + R[i])/2 .* nBBCΓL[i]./Z̃f[i] * u -
            (1 + R[i])/2 .* nCnΓ[i]./Z̃f[i] * û[i] +
            S̃_c ./ (2*Z̃f[i])
    end

    ### set velocity and displacement evolution ###
    du .= v
    mul!(dv, Ã, u, -1, 0)
    
    for i in 1:4
        fx = fcs[1][i]
        fy = fcs[2][i]
        S̃_c = sJ[i] .* Char_Source(fx, fy, t, i, R[i], B_p, MMS)
        dv .+=
            L[i]' * H[i] * (-(1 - R[i])/2 .* Z̃f[i] .* L[i]) * v +
            L[i]' * H[i] * S̃_c ./ 2 +
            ((L[i]' * H[i] * ((1 - R[i])/2 .* nCnΓ[i])) + BCTH[i]) * û[i] +
            ((L[i]' * H[i] * ((1 - R[i])/2 .* nBBCΓL[i])) + BCTHL[i]) * u
    end

    dv .= JIHP * dv
    dv .+= P̃I * Forcing(coord[1][:], coord[2][:], t, B_p, MMS)

end


function ODE_RHS_BLOCK_CPU!(dq, q, p, t)

    nn = p.nn
    fc = p.fc
    coord = p.coord
    R = p.R
    B_p = p.B_p
    MMS = p.MMS
    Λ = p.d_ops.Λ
    sJ = p.sJ
    Z̃f = p.d_ops.Z̃f
    L = p.d_ops.L
    H = p.d_ops.H
    P̃I = p.d_ops.P̃I
    JIHP = p.d_ops.JIHP
    CHAR_SOURCE = p.CHAR_SOURCE
    FORCE = p.FORCE

    u = q[1:nn^2]

    # compute all temporal derivatives
    dq .= Λ * q


    for i in 1:4
        fx = fc[1][i]
        fy = fc[2][i]
        
        S̃_c = sJ[i] .* CHAR_SOURCE(fx, fy, t, i, R[i], B_p, MMS)
        
        dq[2nn^2 + (i-1)*nn + 1 : 2nn^2 + i*nn] .+= S̃_c ./ (2*Z̃f[i])
        
        dq[nn^2 + 1:2nn^2] .+= L[i]' * H[i] * S̃_c ./ 2
    end

    dq[nn^2 + 1:2nn^2] .= JIHP * dq[nn^2 + 1:2nn^2]
    
    dq[nn^2 + 1:2nn^2] .+= P̃I * FORCE(coord[1][:], coord[2][:], t, B_p, MMS)

    contour(coord[1][:,1], coord[2][1,:],
            (reshape(u, (nn, nn)) .- ue(coord[1],coord[2], t, MMS))',
            xlabel="off fault", ylabel="depth", fill=true, yflip=true)
    gui()
   
    
end


function ODE_RHS_BLOCK_CPU_FAULT!(dq, q, p, t)

    nn = p.nn
    fc = p.fc
    coord = p.coord
    R = p.R
    B_p = p.B_p
    RS = p.RS
    b = p.b
    MMS = p.MMS
    Λ = p.d_ops.Λ
    sJ = p.sJ
    Z̃f = p.d_ops.Z̃f
    L = p.d_ops.L
    H = p.d_ops.H
    P̃I = p.d_ops.P̃I
    JIHP = p.d_ops.JIHP
    nCnΓ1 = p.d_ops.nCnΓ1
    nBBCΓL1 = p.d_ops.nBBCΓL1
    CHAR_SOURCE = p.CHAR_SOURCE
    STATE_SOURCE = p.STATE_SOURCE
    FORCE = p.FORCE
    vf = p.vf
    τ̃f = p.τ̃f
    v̂_fric = p.v̂_fric
    
    u = @view q[1:nn^2]
    û1 = @view q[2nn^2 + 1 : 2nn^2 + nn]

    # compute all temporal derivatives
    dq .= Λ * q
    # get velocity on fault
    vf .= L[1] * q[nn^2 + 1 : 2nn^2]
    # compute numerical traction on face 1
    τ̃f .= nBBCΓL1 * u + nCnΓ1 * û1

    # Root find for RS friction
    for n in 1:nn
        
        v̂_root(v̂) = rateandstateD(v̂,
                                  Z̃f[1][n],
                                  vf[n],
                                  sJ[1][n],
                                  q[2nn^2 + 4nn + n],
                                  RS.a,
                                  τ̃f[n],
                                  RS.σn,
                                  RS.V0)

        left = -1e5#vn - τ̃n/z̃n
        right = 1e5#-left
        
        if left > right  
            tmp = left
            left = right
            right = tmp
        end
        
        (v̂n, _, _) = newtbndv(v̂_root, left, right, vf[n]; ftol = 1e-12,
                              atolx = 1e-12, rtolx = 1e-12)

        v̂_fric[n] = v̂n
    end
                 
    # write velocity flux into q
    dq[2nn^2 + 1 : 2nn^2 + nn] .= v̂_fric
    dq[nn^2 + 1 : 2nn^2] .+= L[1]' * H[1] * (Z̃f[1] .* v̂_fric)

    # Non-fault Source injection
    for i in 2:4
        SOURCE = sJ[i] .* CHAR_SOURCE(fc[1][i], fc[2][i], t, i, R[i], B_p, MMS)
        dq[2nn^2 + (i-1)*nn + 1 : 2nn^2 + i*nn] .+= SOURCE ./ (2*Z̃f[i])
        dq[nn^2 + 1:2nn^2] .+= L[i]' * H[i] * SOURCE ./ 2
    end
    
    dq[nn^2 + 1:2nn^2] .= JIHP * dq[nn^2 + 1:2nn^2]
    dq[nn^2 + 1:2nn^2] .+= P̃I * FORCE(coord[1][:], coord[2][:], t, B_p, MMS)

    # psi source
    dq[2nn^2 + 4nn + 1 : 2nn^2 + 5nn] .= (b .* RS.V0 ./ RS.Dc) .* (exp.((RS.f0 .- q[2nn^2 + 4nn + 1 : 2nn^2 + 5nn]) ./ b) .- abs.(2 .* v̂_fric) ./ RS.V0)     dq[2nn^2 + 4nn + 1 : 2nn^2 + 5nn] .+= STATE_SOURCE(fc[1][1], fc[2][1], b, t, B_p, RS, MMS)


    contour(coord[1][:,1], coord[2][1,:],
            (reshape(u, (nn, nn)) .- ue(coord[1],coord[2], t, MMS))',
            xlabel="off fault", ylabel="depth", fill=true, yflip=true)
    gui()
   
end
