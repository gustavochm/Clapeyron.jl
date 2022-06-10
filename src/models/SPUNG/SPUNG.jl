"""
SPUNG: State Research Program for Utilization of Natural Gas

based on:
Unification of the two-parameter equation of state and the principle ofcorresponding states
Jørgen Mollerup

The idea is to use a "shape model" that provides a corresponding states parameters
and a "reference model" that implements a helmholtz energy function.

this SPUNG by default uses the propane reference equation of state (`PropaneRef`) as the reference model
and SRK for the shape model.
"""
struct SPUNG{S<:EoSModel,E<:EoSModel} <: EoSModel
    shape_model::S
    shape_ref::S
    model_ref::E
end

function SPUNG(components::Vector{String},refmodel=PropaneRef(),shapemodel=SRK(components),shaperef = SRK(refmodel.components))
    model = SPUNG(shapemodel,shaperef,refmodel)
    return model
end

Base.length(model::SPUNG) = length(model.shape_model)

function eos(model::SPUNG,V,T,z=SA[1.0])
    f,h = shape_factors(model,V,T,z)
    n = sum(z)
    T0 = T/f
    V0 = V/h/n
    #eos(V,T)/RT = eos0(V0,T0)/RT0
    #eos(V,T) = eos0(V0,T0)*T/T0
    return n*eos(model.model_ref,V0,T0)*f
end

function eos_res(model::SPUNG,V,T,z=SA[1.0])
    f,h = shape_factors(model,V,T,z)
    n = sum(z)
    T0 = T/f
    V0 = V/h/n
    return n*eos_res(model.model_ref,V0,T0)*f
end

function shape_factors(model::SPUNG{<:ABCubicModel},V,T,z=SA[1.0])
    a,b = cubic_ab(model.shape_model,V,T,z)
    n = sum(z)
    v = V/n
    # initial point
    shape_ref = model.shape_ref
    amix = dot(z,model.shape_model.params.a.values,z)/(n*n)
    a00 = shape_ref.params.a.values[1,1]
    b00 = shape_ref.params.b.values[1,1]
    
    fT0 = one(T)*b00*amix/a00/b
    function f_0(f)
        a0f,b0f = cubic_ab(shape_ref,v,T/f)
        return f*b/b0f - a/a0f
    end

    prob = Roots.ZeroProblem(f_0,fT0)
    f = Roots.solve(prob)
    _,b0 = cubic_ab(shape_ref,v,T/f)
    h = b/b0
    return f,h
end

mw(model::SPUNG) = mw(model.shape_model)
molecular_weight(model::SPUNG,z=SA[1.0]) = molecular_weight(model.shape_model,z)

function Base.show(io::IO,mime::MIME"text/plain",model::SPUNG)
    println(io,"Extended Corresponding States model")
    println(io," reference model: ",model.model_ref)
    print(io," shape model: ",model.shape_model)
end

function Base.show(io::IO,model::SPUNG)
    print(io,string(typeof(model)),model.shape_model.components)
end

function lb_volume(model::SPUNG,z=SA[1.0])
    lb_v0 = lb_volume(model.model_ref)
    T0 = T_scale(model.model_ref)
    f,h = shape_factors(model,lb_v0,T0,z) #h normaly should be independent of temperature
    return lb_v0*h
end

function T_scale(model::SPUNG,z=SA[1.0])
    lb_v0 = lb_volume(model.model_ref)
    T0 = T_scale(model.model_ref)
    f,h = shape_factors(model,lb_v0,T0,z) #h normaly should be independent of temperature
    return T0*f
end

function p_scale(model::SPUNG,z=SA[1.0])
     lb_v0 = lb_volume(model.model_ref)
     T0 = T_scale(model.model_ref)
     p0 = p_scale(model.model_ref)
     f,h = shape_factors(model,lb_v0,T0,z) #h normaly should be independent of temperature
     ps = p0*f/h
     return ps
end

function x0_sat_pure(model::SPUNG,T,z = SA[1.0])
    f,h = shape_factors(model,zero(T),T) 
    T0 = T/f
    v0l,v0v = x0_sat_pure(model.model_ref,T0)
    lh = log10(h)
    v0l = v0l + lh
    v0v = v0v + lh
    v0 = (v0l,v0v) 
    return v0
end

function split_model(model::SPUNG,subset=nothing)
    shape_model_vec = split_model(model.shape_model,subset)
    shape_ref,model_ref = model.shape_ref, model.model_ref
    return [SPUNG(shape_modeli,shape_ref,model_ref) for shape_modeli in shape_model_vec]
end

#==
Experimental way of trying to make general shape factors
WIP

function shape_factors(model::SPUNG,V,T,z=SA[1.0])
    n = sum(z)
    x = z * (1/n)
    RT = R̄*T
    b = lb_volume(model.shape_model,x)
    b0 = lb_volume(model.shape_ref,x)
    B = second_virial_coefficient(model.shape_model,T,x)
    B0 = second_virial_coefficient(model.shape_ref,T)
    #B = b-a/RT
    #a/RT = b-B
    #a = RT(b-B)
    a = RT*(b-B)
    a0 = RT*(b0-B0)
    tau = 1/(1-4(B/b))
    tau0 = 1/(1-4(B0/b0))
    Tc = T_scale(model.shape_model,x)
    Tc0 = T_scale(model.shape_ref,x)

    f0 = (tau*Tc)/(tau0*Tc0)
    #f0 = tau/tau0
    #@show T/f0
     #T0 = Roots.find_zero(f0_f,T/f0)
    #@show T0
     #B0 = second_virial_coefficient(model.shape_ref,T0)
    #tau0 = 1-(B0/b0)
    #tau0 = 1-(B0/b0)
    #f = tau/tau0

    #a,b = cubic_ab(model.shape_model,T,x)
    #a0,b0 = cubic_ab(model.shape_ref,T,SA[1.0])
    h = b/b0
    #fh = n*a/a0
    #f = fh/h
    f = f0
    return f,h
end


Tc = 0.26+2.1R
R = λ-1
=#

export SPUNG
