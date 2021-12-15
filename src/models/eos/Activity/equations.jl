function excess_gibbs_free_energy(model::ActivityModel,p,T,z)
    lnγ = log.(activity_coefficient(model,p,T,z))
    return sum(z[i]*R̄*T*lnγ[i] for i ∈ @comps)
end

function eos(model::ActivityModel,V,T,z)
    x = z./sum(z)
    g_E = excess_gibbs_free_energy(model,V,T,z)
    g_pure = VT_gibbs_free_energy.(model.puremodel,V,T)
    p      = pressure.(model.puremodel,V,T)
    g_ideal = sum(z[i]*R̄*T*log(x[i]) for i ∈ @comps)
    return g_E+g_ideal+sum(z[i]*g_pure[i] for i ∈ @comps)-sum(x[i]*p[i] for i ∈ @comps)*V
end

function eos_res(model::ActivityModel,V,T,z)
    x = z./sum(z)
    g_E = excess_gibbs_free_energy(model,V,T,z)
    g_pure_res = VT_chemical_potential_res.(model.puremodel,V,T)
    p_res      = pressure.(model.puremodel,V,T).-sum(z)*R̄*T/V
    return g_E+sum(z[i]*g_pure_res[i][1] for i ∈ @comps)-sum(z[i]*p_res[i] for i ∈ @comps)*V
end

function bubble_pressure(model::ActivityModel,T,x)
    sat = saturation_pressure.(model.puremodel,T)
    p_sat = [tup[1] for tup in sat]
    γ     = activity_coefficient(model,1e-4,T,x)
    p     = sum(x.*γ.*p_sat)
    y     = x.*γ.*p_sat ./ p
    return (p,y)
end

function bubble_temperature(model::ActivityModel,p,x;T0=nothing)
    f(z) = Obj_bubble_temperature(model,z,p,x)
    if T0===nothing
        pure = model.puremodel
        sat = saturation_temperature.(pure,p)
        Ti   = zero(x)
        for i ∈ 1:length(x)
            if isnan(sat[i][1])
                Tc,pc,vc = crit_pure(pure[i])
                g(x) = p-pressure(pure[i],vc,x,[1.])
                Ti[i] = Roots.find_zero(g,(Tc))
            else
                Ti[i] = sat[i][1]
            end
        end
        T = Roots.find_zero(f,(minimum(Ti)*0.9,maximum(Ti)*1.1))
    else
        T = Roots.find_zero(f,T0)
    end
    p,y = bubble_pressure(model,T,x)
    return (T,y)
end

function Obj_bubble_temperature(model::ActivityModel,T,p,x)
    sat = saturation_pressure.(model.puremodel,T)
    p_sat = [tup[1] for tup in sat]
    γ     = activity_coefficient(model,1e-4,T,x)
    y     = x.*γ.*p_sat ./ p
    return sum(y)-1
end