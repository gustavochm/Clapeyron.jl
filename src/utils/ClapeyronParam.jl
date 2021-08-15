abstract type ClapeyronParam end


"""
    SingleParam{T}

Struct designed to contain single parameters. Basically a vector with some extra info.

## Creation:
```julia-repl
julia> mw = SingleParam("molecular weight",["water","ammonia"],[18.01,17.03])
SingleParam{Float64}("molecular weight") with 2 components:
 "water" => 18.01
 "ammonia" => 17.03

julia> mw.values
2-element Vector{Float64}:
 18.01
 17.03

julia> mw.components
2-element Vector{String}:
 "water"
 "ammonia"

julia> mw2 = SingleParam(mw,"new name")
SingleParam{Float64}("new name") with 2 components:
 "water" => 18.01
 "ammonia" => 17.03

julia> has_oxigen = [true,false]; has_o = SingleParam(mw2,has_oxigen)
SingleParam{Bool}("new name") with 2 components:
 "water" => true
 "ammonia" => false

```

## Example usage in models:

```
function molecular_weight(model,molar_frac)
    mw = model.params.mw.values
    res = zero(eltype(molarfrac))
    for i in @comps #iterating through all components
        res += molar_frac[i]*mw[i]
    end
    return res
end
```
"""
struct SingleParam{T} <: ClapeyronParam
    name::String
    components::Array{String,1}
    values::Array{T,1}
    ismissingvalues::Array{Bool,1}
    sourcecsvs::Array{String,1}
    sources::Array{String,1}
end

function Base.show(io::IO, param::SingleParam)
    print(io, typeof(param), "(\"", param.name, "\")[")
    for component in param.components
        component != first(param.components) && print(io, ",")
        print(io, "\"", component, "\"")
    end
    print(io, "]")
end

function Base.show(io::IO, ::MIME"text/plain", param::SingleParam)
    len = length(param.values)
    print(io, typeof(param), "(\"", param.name)
    println(io, "\") with ", len, " component", ifelse(len==1, ":", "s:"))
    i = 0
    for (name, val, miss) in zip(param.components, param.values, param.ismissingvalues)
        i += 1
        if i > 1
            println(io)
        end
        if miss == false
            if typeof(val) <: AbstractString
                print(io, " \"", name, "\" => \"", val, "\"")
            else
                print(io, " \"", name, "\" => ", val)
            end
        else
            print(io, " \"", name, " => -")
        end
    end
end

function SingleParam(x::SingleParam{T},name=x.name) where T
    return SingleParam(name, x.components,deepcopy(x.values), deepcopy(x.ismissingvalues), x.sourcecsvs, x.sources)
end

#a barebones constructor, in case we dont build from csv
function SingleParam(
    name::String,
    components::Vector{String},
    values::Vector{T},
    sourcecsvs = String[],
    sources = String[]
    ) where T
    _values,_ismissingvalues = defaultmissing(values)
    TT = eltype(_values)
    return  SingleParam{TT}(name,components, _values, _ismissingvalues, sourcecsvs, sources)
end

function SingleParam(x::SingleParam, v::Vector{T}) where T
    _values,_ismissingvalues = defaultmissing(values)
    return SingleParam(x.name, x.components,_values, _ismissingvalues , x.sourcecsvs, x.sources)
end
"""
    PairParam{T}

Struct designed to contain pair data. used a matrix as underlying data storage.

## Creation:
```julia-repl
julia> kij = PairParam("interaction params",["water","ammonia"],[0.1 0.0;0.1 0.0])
PairParam{Float64}["water", "ammonia"]) with values:
2×2 Matrix{Float64}:
 0.1  0.0
 0.1  0.0

julia> kij.values
2×2 Matrix{Float64}:
 0.1  0.0
 0.1  0.0

julia> kij.diagvalues
2-element view(::Vector{Float64}, 
1:3:4) with eltype Float64:
 0.1
 0.0
```

## Example usage in models:

```julia
#lets compute ∑xᵢxⱼkᵢⱼ
function alpha(model,x)
    kij = model.params.kij.values
    ki = model.params.kij.diagvalues
    res = zero(eltype(molarfrac))
    for i in @comps 
        @show ki[i]
        for j in @comps 
            res += x[i]*x[j]*kij[i,j]
        end
    end
    return res
end
"""
struct PairParam{T} <: ClapeyronParam
    name::String
    components::Array{String,1}
    values::Array{T,2}
    diagvalues::SubArray{T, 1, Vector{T}, Tuple{StepRange{Int64, Int64}}, true}
    ismissingvalues::Array{Bool,2}
    sourcecsvs::Array{String,1}
    sources::Array{String,1}
end

function PairParam(name::String,
                    components::Array{String,1},
                    values::Array{T,2},
                    sourcecsvs::Array{String,1} = String[], 
                    sources::Array{String,1} = String[]) where T
    
    _values,_ismissingvalues = defaultmissing(values)
    diagvalues = view(_values, diagind(_values))

    return PairParam{T}(name, components,_values, diagvalues, _ismissingvalues, sourcecsvs, sources)
end

function PairParam(x::PairParam,name::String=x.name)
    return PairParam(name, x.components, deepcopy(x.values),deepcopy(x.diagvalues), deepcopy(x.ismissingvalues), x.sourcecsvs, x.sources)
end

function PairParam(x::SingleParam{T},name::String=x.name) where T
    pairvalues = singletopair(x.values,missing)
    _values,_ismissingvalues = defaultmissing(pairvalues)
    diagvalues = view(_values, diagind(_values))
    return PairParam(name, x.components, _values,diagvalues,_ismissingvalues,x.sourcecsvs, x.sources)
end

function PairParam(x::PairParam, v::Matrix{T},name::String=x.name) where T
    return PairParam(name, x.components,deepcopy(v), x.sourcecsvs, x.sources)
end
function PairParam(x::SingleParam, v::Vector{T},name::String=x.name) where T
    pairvalues = singletopair(v,missing)
    return PairParam(x.name, x.components, pairvalues,x.sourcecsvs, x.sources)
end
function PairParam(x::SingleParam, v::Matrix{T},name::String=x.name) where T
    return PairParam(x.name, x.components, deepcopy(v),x.sourcecsvs, x.sources)
end

function Base.show(io::IO,mime::MIME"text/plain",param::PairParam{T}) where T
    print(io,"PairParam{",string(T),"}")
    show(io,param.components)
    println(io,") with values:")
    show(io,mime,param.values)
end

function Base.show(io::IO,param::PairParam)
    print(io,"PairParam(",param.name)
    print(io,"\"",param.name,"\"",")[")
    for (name,val,miss,i) in zip(param.components,param.values,param.ismissingvalues,1:length(param.values))
        i != 1 && print(io,",")
        if miss == false
            print(io,name,"=",val)
        else
            print(io,name,"=","-")
        end
    end
    print(io,"]")
end
"""
    AssocParam{T}

Struct holding association parameters.
"""
struct AssocParam{T} <: ClapeyronParam
    name::String
    components::Array{String,1}
    values::Array{Array{T,2},2}
    ismissingvalues::Array{Array{Bool,2},2}
    allcomponentsites::Array{Array{String,1},1}
    sourcecsvs::Array{String,1}
    sources::Array{String,1}
end

function AssocParam(x::AssocParam{T}) where T
    return PairParam{T}(x.name,x.components, deepcopy(x.values), deepcopy(x.ismissingvalues), x.allcomponentsites, x.sourcecsvs, x.sources)
end

function AssocParam{T}(x::AssocParam, v::Matrix{Matrix{T}}) where T
    return AssocParam{T}(x.name, x.components,deepcopy(v), deepcopy(x.ismissingvalues), x.allcomponentsites, x.sourcecsvs, x.sources)
end

function Base.show(io::IO,mime::MIME"text/plain",param::AssocParam{T}) where T
    print(io,"AssocParam{",string(T),"}")
    show(io,param.components)
    println(io,") with values:")
    show(io,mime,param.values)
end

function Base.show(io::IO,param::AssocParam)
    print(io,"AssocParam(",param.name)
    print(io,"\"",param.name,"\"",")[")
    for (name,val,miss,i) in zip(param.components,param.values,param.ismissingvalues,1:length(param.values))
        i != 1 && print(io,",")
        if miss == false
            print(io,name,"=",val)
        else
            print(io,name,"=","-")
        end
    end
    print(io,"]")
end
const PARSED_GROUP_VECTOR_TYPE =  Vector{Tuple{String, Vector{Pair{String, Int64}}}}

"""
    GroupParam

Struct holding group parameters.
"""
struct GroupParam <: ClapeyronParam
    components::Array{String,1}
    groups::Array{Array{String,1},1}
    n_groups::Array{Array{Int,1},1}
    i_groups::Array{Array{Int,1},1}
    flattenedgroups::Array{String,1}
    n_flattenedgroups::Array{Array{Int,1},1}
    i_flattenedgroups::UnitRange{Int}
    sourcecsvs::Array{String,1}
end

function GroupParam(input::PARSED_GROUP_VECTOR_TYPE,sourcecsvs::Vector{String}=String[],options::ParamOptions = ParamOptions())
    components = [first(i) for i ∈ input]
    raw_groups =  [last(i) for i ∈ input]
    groups = [first.(grouppairs) for grouppairs ∈ raw_groups]
    n_groups = [last.(grouppairs) for grouppairs ∈ raw_groups]
    flattenedgroups = unique!(reduce(vcat,groups))
    i_groups = [[findfirst(isequal(group), flattenedgroups) for group ∈ componentgroups] for componentgroups ∈ groups]
    len_flattenedgroups = length(flattenedgroups)
    i_flattenedgroups = 1:len_flattenedgroups
    n_flattenedgroups = [zeros(Int,len_flattenedgroups) for _ ∈ 1:length(input)]
    for i in length(input)
        setindex!.(n_flattenedgroups,n_groups,i_groups)
    end

    return GroupParam(components, 
    groups, 
    n_groups,
    i_groups, 
    flattenedgroups,
    n_flattenedgroups, 
    i_flattenedgroups,
    sourcecsvs)
end

function Base.show(io::IO, mime::MIME"text/plain", param::GroupParam)
    print(io,"GroupParam ")
    len = length(param.components)
    println(io,"with ", len, " component", ifelse(len==1, ":", "s:"))
    
    for i in 1:length(param.components)
        
        print(io, " \"", param.components[i], "\": ")
        firstloop = true
        for j in 1:length(param.n_groups[i])
            firstloop == false && print(io, ", ")
            print(io, "\"", param.groups[i][j], "\" => ", param.n_groups[i][j])
            firstloop = false
        end
        i != length(param.components) && println(io)
    end 
end

function Base.show(io::IO, param::GroupParam)
    print(io,"GroupParam[")
    len = length(param.components)
    
    for i in 1:length(param.components)
        
        print(io, "\"", param.components[i], "\" => [")
        firstloop = true
        for j in 1:length(param.n_groups[i])
            firstloop == false && print(io, ", ")
            print(io, "\"", param.groups[i][j], "\" => ", param.n_groups[i][j])
            firstloop = false
        end
        print(io,']')
        i != length(param.components) && print(io,", ")
    end
    print(io,"]")
end

"""
    SiteParam

Struct holding site parameters.
"""
struct SiteParam <: ClapeyronParam
    components::Array{String,1}
    sites::Array{Array{String,1},1}
    n_sites::Array{Array{Int,1},1}
    i_sites::Array{Array{Int,1},1}
    flattenedsites::Array{String,1}
    n_flattenedsites::Array{Array{Int,1},1}
    i_flattenedsites::UnitRange{Int}
    sourcecsvs::Array{String,1}
end


function Base.show(io::IO, mime::MIME"text/plain", param::SiteParam)
    print(io,"SiteParam ")
    len = length(param.components)
    println(io,"with ", len, " site", ifelse(len==1, ":", "s:"))
    
    for i in 1:length(param.components)
        
        print(io, " \"", param.components[i], "\": ")
        firstloop = true
        if length(param.n_sites[i]) == 0
            print(io,"(no sites)")
        end
        for j in 1:length(param.n_sites[i])
            firstloop == false && print(io, ", ")
            print(io, "\"", param.sites[i][j], "\" => ", param.n_sites[i][j])
            firstloop = false
        end
        i != length(param.components) && println(io)
    end 
end

function Base.show(io::IO, param::SiteParam)
    print(io,"SiteParam[")
    len = length(param.components)
    
    for i in 1:length(param.components)
        
        print(io, "\"", param.components[i], "\" => [")
        firstloop = true
    
        for j in 1:length(param.n_sites[i])
            firstloop == false && print(io, ", ")
            print(io, "\"", param.sites[i][j], "\" => ", param.n_sites[i][j])
            firstloop = false
        end
        print(io,']')
        i != length(param.components) && print(io,", ")
    end
    print(io,"]")
end


function SiteParam(pairs::Dict{String,SingleParam{Int}},allcomponentsites)
    arbitraryparam = first(values(pairs))
    components = arbitraryparam.components
    sites = allcomponentsites
    
    sourcecsvs = String[]
    for x in values(pairs)
        vcat(sourcecsvs,x.sourcecsvs)  
    end
    if length(sourcecsvs) >0
        unique!(sourcecsvs)
    end
    n_sites = [[pairs[sites[i][j]].values[i] for j ∈ 1:length(sites[i])] for i ∈ 1:length(components)]  # or groupsites
    length_sites = [length(componentsites) for componentsites ∈ sites]
    i_sites = [1:length_sites[i] for i ∈ 1:length(components)]
    flattenedsites = unique!(reduce(vcat,sites,init = String[]))
    len_flattenedsites = length(flattenedsites)
    i_flattenedsites = 1:len_flattenedsites
    n_flattenedsites = [zeros(Int,len_flattenedsites) for _ ∈ 1:length(components)]
    for i in length(components)
        setindex!.(n_flattenedsites,n_sites,i_sites)
    end
    return SiteParam(components, 
    sites, 
    n_sites,
    i_sites, 
    flattenedsites,
    n_flattenedsites, 
    i_flattenedsites,
    sourcecsvs)
end

function SiteParam(input::PARSED_GROUP_VECTOR_TYPE,sourcecsvs::Vector{String}=String[])
    components = [first(i) for i ∈ input]
    raw_sites =  [last(i) for i ∈ input]
    sites = [first.(sitepairs) for sitepairs ∈ raw_sites]
    n_sites = [last.(sitepairs) for sitepairs ∈ raw_sites]
    flattenedsites = unique!(reduce(vcat,sites,init = String[]))
    i_sites = [[findfirst(isequal(site), flattenedsites) for site ∈ componentsites] for componentsites ∈ sites]
    len_flattenedsites = length(flattenedsites)
    i_flattenedsites = 1:len_flattenedsites
    n_flattenedsites = [zeros(Int,len_flattenedsites) for _ ∈ 1:length(input)]
    for i in length(input)
        setindex!.(n_flattenedsites,n_sites,i_sites)
    end

    return SiteParam(components, 
    sites, 
    n_sites,
    i_sites, 
    flattenedsites,
    n_flattenedsites, 
    i_flattenedsites,
    sourcecsvs)


end
#empty SiteParam

#=
struct SiteParam <: ClapeyronParam
    components::Array{String,1}
    sites::Array{Array{String,1},1}
    n_sites::Array{Array{Int,1},1}
    i_sites::Array{Array{Int,1},1}
    flattenedsites::Array{String,1}
    n_flattenedsites::Array{Array{Int,1},1}
    i_flattenedsites::UnitRange{Int}
    sourcecsvs::Array{String,1}
end

=#
function SiteParam(components::Vector{String})
    n = length(components)
    return SiteParam(
    components,
    [String[] for _ ∈ 1:n],
    [Int[] for _ ∈ 1:n],
    [Int[] for _ ∈ 1:n],
    String[],
    [Int[] for _ ∈ 1:n],
    1:0,
    String[])
end

paramvals(param::ClapeyronParam) = param.values
paramvals(x) = x

#=
struct SingleParam{T} <: ClapeyronParam
    name::String
    values::Array{T,1}
    ismissingvalues::Array{Bool,1}
    components::Array{String,1}
    allcomponentsites::Array{Array{String,1},1}
    sourcecsvs::Array{String,1}
    sources::Array{String,1}
end
=#
function split_model(param::SingleParam{T},
    splitter =split_model(1:length(param.components))) where T
    return [SingleParam(
    param.name,
    param.values[i],
    param.ismissingvalues[i],
    param.components[i],
    param.sourcecsvs,
    param.sources
    ) for i in splitter]
end

function split_model(param::SingleParam,groups::GroupParam)
    return split_model(param,groups.i_groups)
end
#this conversion is lossy, as interaction between two or more components are lost.

function split_model(param::PairParam{T},
    splitter = split_model(1:length(param.components))) where T
    function generator(I) 
        value = param.values[I,I]
        diagvalue = view(value,diagind(value))
        ismissingvalues = param.ismissingvalues[I,I]
        components = param.components[I]
        return PairParam{T}(
                param.name,
                value,
                diagvalue,
                ismissingvalues,
                components,
                param.sourcecsvs,
                param.sources
                )
    end 
    return [generator(I) for I in splitter]
end

function split_model(param::AbstractVector)
    return [[xi] for xi in param]
end 

#this conversion is lossy, as interaction between two or more components are lost.
function split_model(param::AssocParam{T},components = param.components) where T
    function generator(i)     
        _value = Matrix{Matrix{T}}(undef,1,1)
        _value[1,1] = param.values[i,i]
        _ismissingvalues = Matrix{Matrix{Bool}}(undef,1,1)
        _ismissingvalues[1,1] = param.ismissingvalues[i,i]
        return AssocParam{T}(
                param.name,
                _value,
                _ismissingvalues,
                [components[i]],
                [param.allcomponentsites[i]],
                param.sourcecsvs,
                param.sources
                )
    end 
    return [generator(i) for i in 1:length(components)]
end

#this param has a defined split form
function split_model(groups::GroupParam)
    len = length(groups.components)
    function generator(i)
        return GroupParam(
        [groups.components[i]],
        [groups.groups[i]],
        [groups.n_groups[i]],
        [collect(1:length(groups.n_groups[i]))],
        groups.flattenedgroups[groups.i_groups[i]],
        [groups.n_groups[i]],
        1:length(groups.n_groups[i]),
        groups.sourcecsvs)
    end
    [generator(i) for i in 1:len]
end

export SingleParam, SiteParam, PairParam, AssocParam, GroupParam
#=
* allcomponentgroups: a list of groups for each component
* lengthallcomponentgroups: a list containing the number of groups for each component
* allcomponentngroups: a list of the group multiplicity of each group corresponding to each group in allcomponentsgroup
* igroups: an iterable that contains a list of group indices corresponding to flattenedgroups for each component

* flattenedgroups: a list of all unique groups--the parameters correspond to this list
* lengthflattenedgroups: the number of unique groups
* allcomponentnflattenedgroups: the group multiplicities corresponding to each group in flattenedgroups
* iflattenedgroups: an iterator that goes through the indices for each flattenedgroup

* allgroupsites: a list containing a list of all sites corresponding to each group in flattenedgroups
* lengthallgroupsites: a list containing the number of unique sites for each group in flattenedgroups
* allgroupnsites: a list of the site multiplicities corresponding to each group in flattenedgroups
* isites: an iterator that goes through the indices corresponding to each group in flattenedgroups

=#