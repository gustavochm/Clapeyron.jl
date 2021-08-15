"""
    arbitraryparam(params)

returns the first field in the struct that is a subtype of `ClapeyronParam`. errors if it finds none.
"""
function arbitraryparam(params)
    paramstype = typeof(params)
    idx = findfirst(z->z <: ClapeyronParam,fieldtypes(paramstype))
    if isnothing(idx)
        error("The paramater struct ", paramstype, " must contain at least one ClapeyronParam")
    end
     return fieldnames(paramstype)[idx] |> z->getfield(params,z)
end

"""
    @comps

This macro is an alias to

    model.icomponents

The caveat is that `model` has to exist in the local namespace.
`model` is expected to be an EoSModel type that contains the `icomponents` field.
`icomponents` is an iterator that goes through all component indices.
"""
macro comps()
    return :($(esc(:(model.icomponents))))
end

"""
    @groups

This macro is an alias to

    model.groups.i_flattenedgroups

`iflattenedgroups` is an iterator that goes through all groups in flattenedgroups.
"""
macro groups()
    return :($(esc(:(model.groups.i_flattenedgroups))))
end

"""
    @groups(component)

This macro is an alias to

    model.groups.i_groups[component]

`i_groups[component]` is an iterator that goes through all groups in relevent to a given component.
"""
macro groups(component)
    return :($(esc(:(model.groups.i_groups[$(component)]))))
end

"""
    @sites(component)

This macro is an alias to

    model.sites.i_sites[component]

`i_sites[component]` is an iterator that goes through all sites relevant to
each group in a GC model, and to each main component in a non-GC model.
"""
macro sites(component)
    return :($(esc(:(model.sites.i_sites[$(component)]))))
end

"""
    @f(func,a,b,c,...)

This macro is an alias to
    
    func(model, V, T, z, a, b, c, ...)

where `func` is the name of the function, `model` is the model struct,
`V` is the volume, `T` is the absolute temperature, `z` is an array of number
of moles of each component, and `a`, `b`, `c`, ... are arbitrary parameters
that get passed to `func`.

It is very common for functions that are involved in the models to contain the
`model`, `V`, `T` and `z` parameters, so this macro helps reduce code repetition
as long as the first four parameters in the function are written exactly as above.

"""
macro f(func, args...)
    f = func
    model = :model
    V = :V
    T = :T
    z = :z
    quote
        $f($model,$V,$T,$z,$(args...))
    end |> esc
end


"""
    @nan(function_call,default=NaN)

Wraps the function in a `try-catch` block, and if a `DomainError` or `DivideError` is raised, then returns `default`.
for better results, its best to generate the default result beforehand
"""
macro nan(Base.@nospecialize(fcall),default = nothing)
    e = gensym(:error)
    quote
      try $fcall
      catch $e
        if $e isa Union{DomainError,DivideError}
          $default
        else
          rethrow($e)
        end
      end
    end
  end

"""
    @newmodelgc modelname parent paramstype

This is a data type that contains all the information needed to use an EoS model.
It also functions as an identifier to ensure that the right functions are called.

The user is expected to create an outter constructor that takes this signature

    function modelname(components::Array{String,1})

It should then return name(params::paramtype, groups::GroupParam, sites::SiteParam, idealmodel::IdealModel)

= Fields =
The Struct consists of the following fields:

* components: a string lists of components
* icomponents: an iterator that goes through the indices corresponding to each component
* groups: a [`GroupParam`](@ref)
* sites: a [`SiteParam`](@ref)
* params: the Struct paramstype that contains all parameters in the model
* idealmodel: the IdealModel struct that determines which ideal model to use
* absolutetolerance: the absolute tolerance for solvers; the default value is 1E-12
* references: reference for this EoS

See the tutorial or browse the implementations to see how this is used.
"""
macro newmodelgc(name, parent, paramstype)
    quote 
    struct $name{T <: IdealModel} <: $parent
        components::Array{String,1}
        icomponents::UnitRange{Int}
        groups::GroupParam
        sites::SiteParam
        params::$paramstype
        idealmodel::T
        absolutetolerance::Float64
        references::Array{String,1}
    end

    has_sites(::Type{$name}) = true
    has_groups(::Type{$name}) = true
    built_by_macro(::Type{$name}) = true

    function Base.show(io::IO, mime::MIME"text/plain", model::$name)
        return eosshow(io, mime, model)
    end

    function Base.show(io::IO, model::$name)
        return eosshow(io, model)
    end

    Base.length(model::$name) = Base.length(model.icomponents)

    molecular_weight(model::$name,z=SA[1.0]) = group_molecular_weight(model.groups,mw(model),z)

end |> esc
end

"""

    @newmodel name parent paramstype

This is exactly the same as the above but for non-GC models.
All group parameters are absent in this struct.
The sites are associated to the main component rather than the groups,
and the respective fieldnames are named correspondingly.
"""
macro newmodel(name, parent, paramstype)
    quote 
    struct $name{T <: IdealModel} <: $parent
        components::Array{String,1}
        icomponents::UnitRange{Int}
        sites::SiteParam
        params::$paramstype
        idealmodel::T
        absolutetolerance::Float64
        references::Array{String,1}
    end
    has_sites(::Type{$name}) = true
    has_groups(::Type{$name}) = false
    built_by_macro(::Type{$name}) = true
   
    function Base.show(io::IO, mime::MIME"text/plain", model::$name)
        return eosshow(io, mime, model)
    end

    function Base.show(io::IO, model::$name)
        return eosshow(io, model)
    end
    molecular_weight(model::$name,z=SA[1.0]) = comp_molecular_weight(mw(model),z)
    Base.length(model::$name) = Base.length(model.icomponents)
    end |> esc
end

"""
Even simpler model, primarily for the ideal models.
Contains neither sites nor ideal models.
"""
macro newmodelsimple(name, parent, paramstype)
    quote 
    struct $name <: $parent
        components::Array{String,1}
        icomponents::UnitRange{Int}
        params::$paramstype
        absolutetolerance::Float64
        references::Array{String,1}
    end
    has_sites(::Type{$name}) = false
    has_groups(::Type{$name}) = false
    built_by_macro(::Type{$name}) = true

    function Base.show(io::IO, mime::MIME"text/plain", model::$name)
        return eosshow(io, mime, model)
    end

    function Base.show(io::IO, model::$name)
        return eosshow(io, model)
    end

    Base.length(model::$name) = Base.length(model.icomponents)

    end |> esc
end

export @newmodel, @f, @newmodelgc




const IDEALTYPE = Union{T,Type{T}} where T<:IdealModel

function (::Type{model})(params::EoSParam,
        groups::GroupParam,
        sites::SiteParam,
        idealmodel::IDEALTYPE = BasicIdeal;
        ideal_userlocations::Vector{String}=[],
        references::Vector{String}=[],
        absolutetolerance::Float64 = 1e-12,
        verbose::Bool = false) where model <:EoSModel

        components = groups.components
        icomponents = 1:length(components)
        init_idealmodel = initialize_idealmodel(idealmodel,components,ideal_userlocations,verbose)
        return model(components, icomponents,
        groups,
        sites,
        params, init_idealmodel, absolutetolerance, references)
end

function (::Type{model})(params::EoSParam,
        groups::GroupParam,
        idealmodel::IDEALTYPE = BasicIdeal;
        ideal_userlocations::Vector{String}=[],
        references::Vector{String}=[],
        absolutetolerance::Float64 = 1e-12,
        verbose::Bool = false) where model <:EoSModel

    sites = SiteParam(groups.components)
    return model(params,groups,sites,idealmodel;ideal_userlocations,references,absolutetolerance,verbose)
end


#non GC
function (::Type{model})(params::EoSParam,
        sites::SiteParam,
        idealmodel::IDEALTYPE = BasicIdeal;
        ideal_userlocations::Vector{String}=[],
        references::Vector{String}=[],
        absolutetolerance::Float64 = 1e-12,
        verbose::Bool = false) where model <:EoSModel
    
    components = sites.components
    icomponents = 1:length(components)

    init_idealmodel = initialize_idealmodel(idealmodel,components,ideal_userlocations,verbose)
    return model(components, icomponents,
    sites, params, init_idealmodel, absolutetolerance, references)

end

#non GC, may be shared with model simple
function (::Type{model})(params::EoSParam,
        idealmodel::IDEALTYPE = BasicIdeal;
        ideal_userlocations::Vector{String}=[],
        references::Vector{String}=[],
        absolutetolerance::Float64 = 1e-12,
        verbose::Bool = false) where model <:EoSModel

    arbparam = arbitraryparam(params)
    components = arbparam.components
    
    if has_sites(model)
        sites = SiteParam(components)
        return model(params,sites,idealmodel;ideal_userlocations,references,absolutetolerance,verbose)
    end
    #With sites out of the way, this is a simplemodel, no need to initialize the ideal model
    icomponents = 1:length(components)
    return model(components,icomponents,params,references,absolutetolerance)
end

function initialize_idealmodel(idealmodel::IdealModel,components,userlocations,verbose)
    return idealmodel
end

function initialize_idealmodel(idealmodel::BasicIdeal,components,userlocations,verbose)
    return BasicIdeal()
end

function initialize_idealmodel(idealmodel::Type{<:IdealModel},components,userlocations,verbose)
    verbose && @info("""Now creating ideal model:
    $idealmodel""")
    return idealmodel(components;userlocations,verbose)
end