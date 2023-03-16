struct EmpiricSingleFluidIdealParam <:EoSParam
    a1::Float64
    a2::Float64
    c0::Float64
    n_gpe::Vector{Float64} #gpe terms (Generalized Plank-Einstein)
    t_gpe::Vector{Float64}
    c_gpe::Vector{Float64}
    d_gpe::Vector{Float64}
    n_p::Vector{Float64} #power terms
    t_p::Vector{Float64}

    function EmpiricSingleFluidIdealParam(a1,a2,c0,n = Float64[],t = Float64[],c = fill(1.0,length(n)),d = fill(-1.0,length(n)),n_p = Float64[], t_p  = Float64[])
        @assert length(n) == length(t) == length(c) == length(d)
        @assert length(n_p) == length(t_p)
        return new(a1,a2,c0,n,t,c,d,n_p,t_p)
    end
end

struct GaoBTerm
    active::Bool
    n::Vector{Float64}
    t::Vector{Float64}
    d::Vector{Float64}
    eta::Vector{Float64}
    beta::Vector{Float64}
    gamma::Vector{Float64}
    epsilon::Vector{Float64}
    b::Vector{Float64}
    function GaoBTerm(n,t,d,eta,beta,gamma,epsilon,b)
        @assert length(eta) == length(beta) == length(gamma) == length(epsilon) == length(b)
        @assert length(eta) == length(n) == length(t) == length(d)
        active = (length(n) != 0)
        return new(active,n,t,d,eta,beta,gamma,epsilon,b)
    end
end

GaoBTerm() = GaoBTerm(Float64[],Float64[],Float64[],Float64[],Float64[],Float64[],Float64[],Float64[])

struct NonAnalyticTerm 
    active::Bool
    A::Vector{Float64}
    B::Vector{Float64}
    C::Vector{Float64}
    D::Vector{Float64}
    a::Vector{Float64}
    b::Vector{Float64}
    beta::Vector{Float64}
    n::Vector{Float64}
    function NonAnalyticTerm(A,B,C,D,a,b,beta,n)
        @assert length(A) == length(B) == length(C) == length(D)
        @assert length(A) == length(a) == length(b) == length(beta)
        @assert length(beta) == length(n)
        active = (length(n) != 0)
        return new(active,A,B,C,D,a,b,beta,n)
    end
end

NonAnalyticTerm() = NonAnalyticTerm(Float64[],Float64[],Float64[],Float64[],Float64[],Float64[],Float64[],Float64[])

mutable struct Associating2BTerm #mutable because someone would want to fit this?
    active::Bool
    epsilonbar::Float64
    kappabar::Float64
    a::Float64
    m::Float64
    vbarn::Float64
    function Associating2BTerm(epsilonbar,kappabar,a,m,vbarn)
        active = (kappabar != 0.0)
        return new(active,epsilonbar,kappabar,a,m,vbarn)
    end
end
Associating2BTerm() = Associating2BTerm(0.0,0.0,0.0,0.0,0.0)

struct ExponentialTerm
    active::Bool
    n::Vector{Float64}
    t::Vector{Float64}
    d::Vector{Float64}
    l::Vector{Float64}
    gamma::Vector{Float64}

    function ExponentialTerm(n,t,d,l,gamma)
        @assert length(n) == length(t) == length(d) == length(gamma) == length(l)
        active = (length(n) != 0)
        return new(active,n,t,d,l,gamma)
    end
end
ExponentialTerm() = ExponentialTerm(Float64[],Float64[],Float64[],Float64[],Float64[])


#we store power, exponential and gaussian terms inline, because those are the most used.
struct EmpiricSingleFluidResidualParam <: EoSParam
    iterators::Vector{UnitRange{Int}}
    n::Vector{Float64}
    t::Vector{Float64}
    d::Vector{Int}
    l::Vector{Int}
    eta::Vector{Float64}
    beta::Vector{Float64}
    gamma::Vector{Float64}
    epsilon::Vector{Float64}
    gao_b::GaoBTerm
    na::NonAnalyticTerm
    assoc::Associating2BTerm
    exp::ExponentialTerm
    
    function EmpiricSingleFluidResidualParam(n,t,d,l = Int[],
        eta = Float64[],beta = Float64[],gamma = Float64[], epsilon = Float64[]
        ;gao_b = GaoBTerm(),
        na = NonAnalyticTerm(),
        assoc = Associating2BTerm(),
        exp = ExponentialTerm())

        param = new(Vector{UnitRange{Int}}(undef,0),n,t,d,l,eta,beta,gamma,epsilon,gao_b,na,assoc,exp)
        _calc_iterators!(param)
        return param
    end
end

function _calc_iterators!(param::EmpiricSingleFluidResidualParam)
    n,t,d,l = param.n,param.t,param.d,param.l
    eta,beta,gamma,epsilon = param.eta,param.beta,param.gamma,param.epsilon

    @assert length(n) == length(t) == length(d)
    @assert length(l) < length(d)
    @assert length(eta) == length(beta) == length(gamma) == length(epsilon)
    #we start from the assoc term, backwards
    length_n = length(n)
    length_beta = length(beta)

    length_pol = length_n - length_beta - length(l)
    length_exp = length_n - length_beta
    length_gauss = length_n
    k_pol = 1:length_pol
    k_exp = (length_pol+1):length_exp
    k_gauss = (length_exp+1):length_gauss
    resize!(param.iterators,3)
    param.iterators .= (k_pol,k_exp,k_gauss)
    return param
end

struct EmpiricSingleFluidProperties <: EoSParam
    Mw::Float64 #Molecular Weight, g/mol
    Tc::Float64 #Critical temperature, K
    Pc::Float64 #Critical Pressure,Pa
    rhoc::Float64 #Critical density, mol/m3
    lb_volume::Float64 #lower bound volume, mol/m3
    Ttp::Float64 #triple point temperature, K
    ptp::Float64 #triple point pressure, Pa
    rhov_tp::Float64 #triple point vapor volume, mol/m3
    rhol_tp::Float64 #triple point liquid volume, mol/m3
    acentricfactor::Float64 #acentric factor
    Rgas::Float64 #gas constant used

    function EmpiricSingleFluidProperties(Mw,Tc,Pc,rhoc,lb_volume,
        Ttp = NaN,ptp = NaN, rhov_tp = NaN,rhol_tp = NaN, acentric_factor = NaN, Rgas = R̄)
        return new(Mw,Tc,Pc,rhoc,lb_volume, Ttp,ptp,rhov_tp,rhol_tp,acentric_factor,Rgas)
    end
end

const ESFProperties = EmpiricSingleFluidProperties
const ESFIdealParam = EmpiricSingleFluidIdealParam
const ESFResidualParam = EmpiricSingleFluidResidualParam
