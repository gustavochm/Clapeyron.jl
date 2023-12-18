function obj_sublimation_pressure(model::CompositeModel,F,T,vs,vv,p_scale,μ_scale)
    z = SA[1.0]
    eos_solid(V) = eos(model.solid,V,T,z)
    eos_fluid(V) = eos(model.fluid,V,T,z)
    A_v,Av_v = Solvers.f∂f(eos_fluid,vv)
    A_s,Av_s =Solvers.f∂f(eos_solid,vs)
    μv = muladd(-vv,Av_v,A_v)
    μs = muladd(-vs,Av_s,A_s)
    ps = - Av_s
    pv = - Av_v
    #=
    μs = VT_chemical_potential(model.solid, vs, T)[1]
    μv = VT_chemical_potential(model.fluid, vv, T)[1]
    ps = pressure(model.solid, vs, T)
    pv = pressure(model.fluid, vv, T) =#
    F[1] = (μs - μv)*μ_scale
    F[2] = (ps - pv)*p_scale
    return F
end

struct ChemPotSublimationPressure{V} <: ThermodynamicMethod
    v0::V
    check_triple::Bool
    f_limit::Float64
    atol::Float64
    rtol::Float64
    max_iters::Int
end

function ChemPotSublimationPressure(;v0 = nothing,
                                    check_triple = false,
                                    f_limit = 0.0,
                                    atol = 1e-8,
                                    rtol = 1e-12,
                                    max_iters = 100)

    return ChemPotSublimationPressure(v0,check_triple,f_limit,atol,rtol,max_iters)
end

"""
    psub,vs,vv = sublimation_pressure(model::CompositeModel,T;v0=x0_sublimation_pressure(model,T))

Calculates the sublimation pressure of a `CompositeModel` containing a solid and fluid phase EoS, at a specified pressure.
You can pass a tuple of initial values for the volumes `(vs0,vv0)`.

returns:
- Sublimation Pressure [`Pa`]
- Sublimation solid volume at specified temperature [`m³`]
- Sublimation vapour volume at specified temperature [`m³`]
"""
function sublimation_pressure(model::CompositeModel,T;kwargs...)
    method = init_preferred_method(sublimation_pressure,model,kwargs)
    return sublimation_pressure(model,T,method)
end

function init_preferred_method(method::typeof(sublimation_pressure),model::CompositeModel{<:EoSModel,<:EoSModel},kwargs)
    ChemPotSublimationPressure(;kwargs...)
end

function sublimation_pressure(model,T,method::ThermodynamicMethod)
    single_component_check(sublimation_pressure,model)
    T = T*T/T
    return sublimation_pressure_impl(model,T,method)
end

function sublimation_pressure_impl(model::CompositeModel,T,method::ChemPotSublimationPressure)
    fluid = fluid_model(model)
    solid = solid_model(model)
    if method.v0 == nothing
        v0 = x0_sublimation_pressure(model,T)
    else
        v0 = method.v0
    end
    vs,vv = v0
    p_scale,μ_scale = scale_sat_pure(fluid)

    V0 = vec2(log(v0[1]),log(v0[2]),T)
    f!(F,x) = obj_sublimation_pressure(model,F,T,exp(x[1]),exp(x[2]),p_scale,μ_scale)
    results = Solvers.nlsolve(f!,V0,LineSearch(Newton()))
    #@show results
    x = Solvers.x_sol(results)
    vs = exp(x[1])
    vv = exp(x[2])
    return pressure(fluid,vv,T),vs,vv
    #=
    z = SA[1.0]
    f1(_V) = eos(solid,_V,T,z)
    f2(_V) = eos(fluid,_V,T,z)
    a1,da1,d2a1 = Solvers.f∂f∂2f(f1,vs)
    a2,da2,d2a2 = Solvers.f∂f∂2f(f2,vv)
    p1 = -da1
    p2 = -da2
    if p1 ≈ p2 && g1 ≈ g2 && (d2a1 > 0) && (d2a2 > 0)
        return p2,vs,vv
    end
    for i in 1:method.max_iters
        vs,vv = solve_2ph_taylor(vs,vv,a1,da1,d2a1,a2,da2,d2a2,p_scale,μ_scale)
        a1,da1,d2a1 = Solvers.f∂f∂2f(f1,vs)
        a2,da2,d2a2 = Solvers.f∂f∂2f(f2,vv)
        p1 = -da1
        p2 = -da2
        g1 = a1 + p1*vs
        g2 = a2 + p2*vv     
        if p1 ≈ p2 && g1 ≈ g2 && (d2a1 > 0) && (d2a2 > 0)
            return p2,vs,vv
        end
    end
    nan = p1/p1
    return nan,nan,nan
    =#
    
end

function x0_sublimation_pressure(model,T)
    #we can suppose we are in a low pressure regime, we treat the solid as a liquid,
    #and apply the zero pressure aproximation.
    solid = solid_model(model)
    fluid = fluid_model(model)
    R̄ = Rgas(solid)
    z = SA[1.0]
    vs_at_0 = volume(solid,0.0,T,phase = :s)
    ares = a_res(solid, vs_at_0, T, z)
    lnϕ_s0 = ares - 1 + log(R̄*T/vs_at_0)
    P0 = exp(lnϕ_s0)
    vv0 = R̄*T/P0
    vs0 = vs_at_0
    return vs0,vv0
end
