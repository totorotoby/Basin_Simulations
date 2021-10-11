using Plots


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


function ODE_RHS_BLOCK_CPU_MMS_FAULT!(dq, q, p, t)

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
    ψ = @view q[2nn^2 + 4nn + 1 : 2nn^2 + 5nn]
    
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
                                  ψ[n],
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

        if isnan(v̂n)
            #println("Not bracketing root")
        end
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
    dq[2nn^2 + 4nn + 1 : 2nn^2 + 5nn] .= (b .* RS.V0 ./ RS.Dc) .* (exp.((RS.f0 .- ψ) ./ b) .- abs.(2 .* v̂_fric) ./ RS.V0)
    dq[2nn^2 + 4nn + 1 : 2nn^2 + 5nn] .+= STATE_SOURCE(fc[1][1], fc[2][1], b, t, B_p, RS, MMS)

end


function ODE_RHS_BLOCK_CPU_FAULT!(dq, q, p, t)

    nn = p.nn
    fc = p.fc
    R = p.R
    B_p = p.B_p
    RS = p.RS
    b = p.b
    Λ = p.d_ops.Λ
    sJ = p.sJ
    Z̃f = p.d_ops.Z̃f
    L = p.d_ops.L
    H = p.d_ops.H
    P̃I = p.d_ops.P̃I
    JIHP = p.d_ops.JIHP
    nCnΓ1 = p.d_ops.nCnΓ1
    nBBCΓL1 = p.d_ops.nBBCΓL1
    vf = p.vf
    τ̃f = p.τ̃f
    v̂_fric = p.v̂_fric
    
    u = @view q[1:nn^2]
    û1 = @view q[2nn^2 + 1 : 2nn^2 + nn]
    ψ = @view q[2nn^2 + 4nn + 1 : 2nn^2 + 5nn]
    
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
                                  ψ[n],
                                  RS.a,
                                  τ̃f[n],
                                  RS.σn,
                                  RS.V0)

        left = -1e10#vf[n] - τ̃f[n]/Z̃f[1][n]
        right = 1e10#-left
        
        if left > right  
            tmp = left
            left = right
            right = tmp
        end
        
        (v̂n, _, _) = newtbndv(v̂_root, left, right, vf[n]; ftol = 1e-12,
                              atolx = 1e-12, rtolx = 1e-12)

        if isnan(v̂n)
            println("Not bracketing root")
        end
        v̂_fric[n] = v̂n
    end
                 
    # write velocity flux into q
    dq[2nn^2 + 1 : 2nn^2 + nn] .= v̂_fric
    dq[nn^2 + 1 : 2nn^2] .+= L[1]' * H[1] * (Z̃f[1] .* v̂_fric)
    dq[nn^2 + 1:2nn^2] .= JIHP * dq[nn^2 + 1:2nn^2]
    
    # psi source
    dq[2nn^2 + 4nn + 1 : 2nn^2 + 5nn] .= (b .* RS.V0 ./ RS.Dc) .* (exp.((RS.f0 .- ψ) ./ b) .- abs.(2 .* v̂_fric) ./ RS.V0)

end

function ODE_RHS_GPU_FAULT!(dq, q, p, t_span)






end
