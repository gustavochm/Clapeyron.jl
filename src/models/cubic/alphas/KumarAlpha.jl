abstract type KumarAlphaModel <: AlphaModel end

struct KumarAlphaParam <: EoSParam
    acentricfactor::SingleParam{Float64}
end

@newmodelsimple KumarAlpha KumarAlphaModel KumarAlphaParam
export KumarAlpha

"""
    KumarAlpha <: AlphaModel
    
    KumarAlpha(components::Vector{String};
    userlocations::Vector{String}=String[],
    verbose::Bool=false)

## Input Parameters

- `w`: Single Parameter (`Float64`)

## Model Parameters

- `acentricfactor`: Single Parameter (`Float64`)

## Description

Cubic alpha `(α(T))` model. Default for [`KumarCubic`](@ref) EoS.

For `Tr < 1`
```
αᵢ = (1+mᵢ(1-√(Trᵢ))^nᵢ)^2
Trᵢ = T/Tcᵢ
mᵢ = 0.37790 + 1.51959ωᵢ - 0.46904ωᵢ^2 + 0.015679ωᵢ^3
nᵢ = 0.97016 + 0.05495ωᵢ - 0.1293ωᵢ^2 + 0.0172028ωᵢ^3
```
For `Tr > 1` is a 6th order taylor expansion around `T = Tc`.

## References
1. Kumar, A., & Upadhyay, R. (2021). A new two-parameters cubic equation of state with benefits of three-parameters. Chemical Engineering Science, 229(116045), 116045. doi:10.1016/j.ces.2020.116045

"""
KumarAlpha

function KumarAlpha(components::Vector{String}; userlocations::Vector{String}=String[], verbose::Bool=false)
    params = getparams(components, ["properties/critical.csv"]; userlocations=userlocations, verbose=verbose)
    acentricfactor = SingleParam(params["w"],"acentric factor")
    packagedparams = KumarAlphaParam(acentricfactor)
    model = KumarAlpha(packagedparams, verbose=verbose)
    return model
end

function taylor_alpha_kumar(Tr,m,n)
    k1 = m*n
    k2 = k1*((m-1)*n + 2)/4
    t3 = k1*(n-2)
    k3 = t3*((3*m-1)*n+4)/24
    k4 = t3*evalpoly(n,(-24,10-22m,7m-1))/192
    t5 = t3*(n-4)
    k5 = t5*evalpoly(n,(-48,14-50*m,15*m-1))/1920
    k6 = t5*evalpoly(n,(480,4*(137*m-47),24-264*m,31*m-1))/23040
    ΔT = (Tr-1)
    αpol = (1,k1,k2,k3,k4,k5,k6)
    return evalpoly(ΔT,αpol)
end

function α_function(model::CubicModel,V,T,z,alpha_model::KumarAlphaModel)
    Tc = model.params.Tc.values
    ω  = alpha_model.params.acentricfactor.values
    α = zeros(typeof(T),length(Tc))
    coeff_m = (0.37790, 1.51959, -0.46904, 0.015679)
    coeff_n = (0.97016, 0.05495, -0.1293, 0.0172028)
    for i in @comps

        ωi = ω[i]
        Tr = T/Tc[i]
        m = evalpoly(ωi,coeff_m)
        n = evalpoly(ωi,coeff_n)
        if Tr <= 1
            α[i]  = (1+m*(1-√(Tr))^n)^2
        else
            α[i] = taylor_alpha_kumar(Tr,m,n)
        end
    end
    return α
end

function α_function(model::CubicModel,V,T,z::SingleComp,alpha_model::KumarAlphaModel)
    Tc = model.params.Tc.values[1]
    ω  = alpha_model.params.acentricfactor.values[1]
    coeff_m = (0.37790, 1.51959, -0.46904, 0.015679)
    coeff_n = (0.97016, 0.05495, -0.1293, 0.0172028)
    Tr = T/Tc
    m = evalpoly(ω,coeff_m)
    n = evalpoly(n,coeff_n)
    if Tr <= 1
        α  = (1+m*(1-√(Tr))^n)^2
    else
        α = taylor_alpha_kumar(Tr,m,n)
    end

    return α
end

#6th order taylor expansion at T = Tc