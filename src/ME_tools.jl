import FileIO#, LinearAlgebra, JSON
dir = @__DIR__

erlangDParams = FileIO.load(dir*"/erlangParamsData/erlangDParams.jld2", "erlangDParams")

"""
    cme_params

A Dict storing parameters of concentrated matrix exponential distributions. See https://github.com/ghorvath78/iltcme.
"""
cme_params = FileIO.load(dir*"/CMEParamsData/CMEParams.jld2", "CMEParams")

"""
    AbstractMatrixExponential
"""
abstract type AbstractMatrixExponential end

"""
MatrixExponential constructor method
    
    MatrixExponential(
        a::Array{Float64,2},
        S::Array{Float64,2},
        s::Array{Float64,1},
        D::Array{Float64}=[0],
    )

Inputs: 
 - `a` a 1 by p Array of reals
 - `S` a p by p Array of reals
 - `s` a p by 1 Array of reals
 - `D` an optional argument, if empty then me.D is the identity, 
    else is a p by p matrix
 Throws an error if the dimensions are inconsistent.
"""
struct MatrixExponential <:AbstractMatrixExponential
    a::Array{Float64,2}
    S::Array{Float64,2}
    s::Array{Float64,1}
    D::Array{Float64,2}
    function MatrixExponential(
        a::Array{Float64,2},
        S::Array{Float64,2},
        s::Array{Float64,1},
        D::Array{Float64,2},
    )
    
        s1 = size(a,1)
        s2 = size(a,2)
        s3 = size(S,1)
        s4 = size(S,2)
        s5 = size(s,1)
        s6 = size(s,2)
        s7 = size(D,1)
        s8 = size(D,2)
        checksquare(D)
        checksquare(S)
        test = (s1!=1) || (s6!=1) || any(([s2;s3;s4;s7;s8].-s5).!=0)
        test && throw(DimensionMismatch("Dimensions of ME representation not consistent"))
        return new(a,S,s,D)
    end
end
MatrixExponential(a::Array{Float64,2},S::Array{Float64,2},s::Array{Float64,1}) = 
    MatrixExponential(a,S,s,Matrix{Float64}(LinearAlgebra.I(size(S,1))))

struct CMEOperator <: AbstractArray{Float64,2}
    S::Array{Float64,2}
end 
Base.size(S::CMEOperator) = size(S.S)
Base.size(S::CMEOperator,i) = size(S.S,i)
Base.getindex(S::CMEOperator,i) = S.S[i]
Base.getindex(S::CMEOperator,i,j) = S.S[i,j]
Base.setindex!(S::CMEOperator,x,i) = (S.S[i]=x)
Base.setindex!(S::CMEOperator,x,i,j) = (S.S[i,j]=x)
Base.:*(S::CMEOperator,x::Real) = CMEOperator(S.S*x)
Base.:*(x::Real,S::CMEOperator) = CMEOperator(x*S.S)
function Base.:-(D::LinearAlgebra.Diagonal{Bool, Vector{Bool}},S::CMEOperator) 
    !(size(D)==size(S))&&throw(DimensionMismatch("matrices must be same size"))
    S[1,1] = 1.0-S[1,1]
    two_n_blocks = (size(S,1)-1)
    for n in 2:2:two_n_blocks 
        S[n,n]      = 1.0-S[n,n]
        S[n+1,n]    = -S[n+1,n]
        S[n+1,n+1]  = 1.0-S[n+1,n+1]
        S[n,n+1]    = -S[n,n+1]
    end
    return S
end

function LinearAlgebra.exp(Q::CMEOperator)
    S = Q.S
    expS = zeros(size(S))
    tmp = exp(S[1,1])
    expS[1,1] = tmp
    two_n_blocks = (size(S,1)-1)
    for n in 2:2:two_n_blocks 
        kωt = S[n+1,n]
        expS[n,n]       =  tmp*cos(kωt)    # 1,1 top-left
        expS[n,n+1]     = -tmp*sin(kωt)    # 1,2 top-right
        expS[n+1,n]     =  tmp*sin(kωt)    # 2,1 bottom-left
        expS[n+1,n+1]   =  tmp*cos(kωt)    # 2,2 bottom-right
    end
    return CMEOperator(expS)
end

function LinearAlgebra.inv(Q::CMEOperator)
    S = Q.S
    invS = zeros(size(S))
    invS[1,1] = 1.0./S[1,1]

    two_n_blocks = (size(S,1)-1)
    for n in 2:2:two_n_blocks 
        det_block = S[n,n]*S[n+1,n+1] - S[n+1,n]*S[n,n+1]
        invS[n,n]       =  S[n+1,n+1]/det_block # 1,1 top-left
        invS[n,n+1]     = -S[n,n+1]/det_block   # 1,2 top-right
        invS[n+1,n]     = -S[n+1,n]/det_block   # 2,1 bottom-left
        invS[n+1,n+1]   =  S[n,n]/det_block     # 2,2 bottom-right
    end
    return invS
end

_order(ME::AbstractMatrixExponential) = length(ME.a)

"""
Similar to MatrixExponential but has a neater implementation of `orbit()` due to nice structure.
"""
struct ConcentratedMatrixExponential <: AbstractMatrixExponential
    a::Array{Float64,2}
    S::CMEOperator
    s::Array{Float64,1}
    D::Array{Float64,2}
    function ConcentratedMatrixExponential(
        a::Array{Float64,2},
        S::CMEOperator,
        s::Array{Float64,1},
        D::Array{Float64,2},
    )
        s1 = size(a,1)
        s2 = size(a,2)
        s3 = size(S,1)
        s4 = size(S,2)
        s5 = size(s,1)
        s6 = size(s,2)
        s7 = size(D,1)
        s8 = size(D,2)
        checksquare(D)
        checksquare(S)
        test = (s1!=1) || (s6!=1) || any(([s2;s3;s4;s7;s8].-s5).!=0)
        if test
            error("Dimensions of ME representation not consistent")
        else
            return new(a,S,s,D)
        end
    end
end

function ConcentratedMatrixExponential(a::Array{Float64,2},S::CMEOperator,
    s::Array{Float64,1})
    return ConcentratedMatrixExponential(a,S,s,Matrix{Float64}(LinearAlgebra.I(size(S,1))))
end

pdf(me::AbstractMatrixExponential) = x->only(me.a*exp(me.S*x)*me.s)
"""
    pdf([a::Array{Float64, 2},] me::AbstractMatrixExponential)

Return a the probability density function of a matrix exponential as a function.

If `a` is not specified then the initial vector of the `me` is `me.a`

# Arguments:
- `a`: a row vector with length `size(me.S,1)`
"""
pdf(a::Array{Float64,2}, me::AbstractMatrixExponential) = 
    (length(a)==size(me.S,1)) ? (x->only(a*exp(me.S*x)*me.s)) : throw(
        DomainError("a and me.S must have compatible size"))

pdf(me::AbstractMatrixExponential, x::Real) = pdf(me)(x)
"""
    pdf(a::Array{Float64, 2}, me::AbstractMatrixExponential, x::Real)  

Return a the probability density function of a matrix exponential evaluated at `x`.
"""
pdf(a::Array{Float64,2}, me::AbstractMatrixExponential, x::Real) = pdf(a,me)(x)

pdf(me::AbstractMatrixExponential, x::Array{Float64}) = pdf(me).(x)
pdf(a::Array{Float64,2}, me::AbstractMatrixExponential, x::Array{Float64}) = pdf(a,me).(x)

ccdf(me::AbstractMatrixExponential) = x->sum(me.a*exp(me.S*x))
"""
    ccdf(a::Array{Float64, 2}, me::AbstractMatrixExponential)  

Return a the complimentary cumulative distribution function (1-cdf) of a matrix exponential as a function.

If `a` is not specified then the initial vector of the `me` is `me.a`

# Arguments:
- `a`: a row vector with length `size(me.S,1)`
"""
ccdf(a::Array{Float64,2}, me::AbstractMatrixExponential) = (length(a)==size(me.S,1)) ? (x->sum(a*exp(me.S*x))) : throw(
    DomainError("a and me.S must have compatible size"))

ccdf(me::AbstractMatrixExponential, x::Real) = ccdf(me)(x)
"""
    ccdf(a::Array{Float64, 2}, me::AbstractMatrixExponential, x::Real) 

Return a the complimentary cumulative distribution function (1-cdf) of a matrix exponential evaluated at `x`.
"""
ccdf(a::Array{Float64,2}, me::AbstractMatrixExponential, x::Real) = ccdf(a,me)(x)

ccdf(me::AbstractMatrixExponential, x::Array{Float64}) = ccdf(me).(x)
ccdf(a::Array{Float64,2}, me::AbstractMatrixExponential, x::Array{Float64}) = ccdf(a,me).(x)

cdf(me::AbstractMatrixExponential) = x->1-ccdf(me,x)
"""
    cdf(a::Array{Float64, 2}, me::AbstractMatrixExponential) = begin


Return a the cumulative distribution function of a matrix exponential as a function.

If `a` is not specified then the initial vector of the `me` is `me.a`

# Arguments:
- `a`: a row vector with length `size(me.S,1)`
"""
cdf(a::Array{Float64,2}, me::AbstractMatrixExponential) = (length(a)==size(me.S,1)) ? (x->1-ccdf(a,me)(x)) : throw(
    DomainError("a and me.S must have compatible size"))

cdf(me::AbstractMatrixExponential, x::Real) = cdf(me)(x)
"""
    cdf(a::Array{Float64, 2}, me::AbstractMatrixExponential, x::Real)

Return a the cumulative distribution function of a matrix exponential evaluated at `x`.
"""
cdf(a::Array{Float64,2}, me::AbstractMatrixExponential, x::Real) = cdf(a,me)(x)

cdf(me::AbstractMatrixExponential, x::Array{Float64}) = cdf(me).(x)
cdf(a::Array{Float64,2}, me::AbstractMatrixExponential, x::Array{Float64}) = cdf(a,me).(x)


"""
    build_me(params; mean::Real = 1)

Return a ConcentratedMatrixExponential as defined by the dictionary params. i.e. see CMEParams[3]
for an order 3 CME. 
"""
function build_me(params; mean::Real = 1)
    N = 2*params["n"]+1
    α = zeros(1,N)
    α[1] = params["c"]
    a = params["a"]
    b = params["b"]
    ω =  params["omega"]
    for k in 1:params["n"]
        kω = k*ω
        α[2*k] = (1/2)*( a[k]*(1+kω) - b[k]*(1-kω) )/(1+kω^2)
        α[2*k+1] = (1/2)*( a[k]*(1-kω) + b[k]*(1+kω) )/(1+kω^2)
    end
    α = α./sum(α)
    Q = zeros(N,N)
    Q[1,1] = -1
    for k in 1:params["n"]
        kω = k*ω
        idx = 2*k:(2*k+1)
        Q[idx,idx] = [-1 -kω; kω -1]
    end
    Q = CMEOperator(Q.*-sum(α/Q)./mean)
    q = -sum(Q,dims=2)[:]
    return ConcentratedMatrixExponential(α,Q,q,params["D"])
end

ConcentratedMatrixExponential(order::Int; mean::Float64 = 1.0) = 
    build_me(cme_params[order], mean=mean)

function fast_exp(S::Matrix)

end

function build_erlang(order; mean::Float64 = 1.0)
    α = zeros(1,order) # inital distribution
    α[1] = 1
    λ = order/mean
    Q = zeros(order,order)
    Q = Q + LinearAlgebra.diagm(0=>repeat(-[λ],order), 1=>repeat([λ],order-1))
    q = -sum(Q,dims=2)[:]
    D = Array{Float64}(LinearAlgebra.I(order))[end:-1:1,:]
    return MatrixExponential(α,Q,q,D)
end

function orbit(me::AbstractMatrixExponential)
    function _orbit(t)
        num = me.a*exp(me.S*t)
        denom = sum(num)
        return num./denom
    end
    return t->_orbit(t)
end
orbit(me::AbstractMatrixExponential,t::Float64) = 
    orbit(me)(t)

function orbit(me::ConcentratedMatrixExponential)
    params = cme_params[_order(me)]
    mean = -sum(me.a/me.S)
    function _orbit(t)
        position = zeros(size(me.a))
        position[1] = me.a[1]
        for k in 1:params["n"]
            kωt = k*params["omega"]*t
            idx = 2*k
            idx2 = idx+1
            position[idx] = me.a[idx]*cos(kωt) + me.a[idx2]*sin(kωt)
            position[idx2] = -me.a[idx]*sin(kωt) + me.a[idx2]*cos(kωt)
        end
        position = position./sum(position)
        return position
    end
    mu1 = params["mu1"]
    return t->_orbit(mu1*t/mean)
end

function expected_orbit_from_pdf(pdf::Function,me::AbstractMatrixExponential,a::Float64,b::Float64,evals::Int=10)
    # evals is an integer specifying how many points to eval the function at
    # params is a cme_params dictionary entry, i.e. cme_params[3]
    (b<=a)&&throw(DomainError("must have b>a"))
    delta = b-a # the orbit repeats after this time
    edges = range(0,delta,length=evals+1) # points at which to evaluate the fn
    h = delta/evals

    orbit_LHS = me.a
    pdf_LHS = pdf(a)

    E_orbit = zeros(size(me.a))
    for t in edges[2:end]
        orbit_RHS = orbit(me,t)
        orbit_estimate = (orbit_LHS+orbit_RHS)./2.0

        pdf_RHS = pdf(a+t)
        prob_estimate = (pdf_RHS+pdf_LHS)/2.0*h

        orbit_LHS = copy(orbit_RHS)
        pdf_LHS = copy(pdf_RHS)

        E_orbit += orbit_estimate*prob_estimate
    end
    return E_orbit
end

function expected_orbit_from_cdf(cdf::Function,me::AbstractMatrixExponential,a::Float64,b::Float64,evals::Int=10)
    # evals is an integer specifying how many points to eval the function at
    # params is a cme_params dictionary entry, i.e. cme_params[3]
    (b<=a)&&throw(DomainError("must have b>a"))
    delta = b-a # the orbit repeats after this time
    edges = range(0,delta,length=evals+1) # points at which to evaluate the fn

    orbit_LHS = me.a
    cdf_LHS = cdf(a)

    E_orbit = zeros(size(me.a))
    for t in edges[2:end]
        orbit_RHS = orbit(me,t)
        orbit_estimate = (orbit_LHS+orbit_RHS)./2

        cdf_RHS = cdf(a+t)
        prob_estimate = (cdf_RHS-cdf_LHS)

        orbit_LHS = copy(orbit_RHS)
        cdf_LHS = copy(cdf_RHS)

        E_orbit += orbit_estimate*prob_estimate
    end
    return E_orbit
end

## not used, but kept them because they might be / are cool 
# function renewalProperties(me::AbstractMatrixExponential)
#     density(t) = begin
#         Q = me.S
#         q = me.s
#         α = me.a
#         e = ones(size(q))
#         (α*exp((Q+q*α)*t)*q)[1]
#     end
#     mean(t) = begin
#         Q = me.S
#         q = me.s
#         α = me.a
#         e = ones(size(q))
#         temp1 = α*-Q^-1
#         temp2 = temp1*e
#         temp3 = temp1./temp2
#         temp4 = Q + (q*α)
#         ((t./temp2) - α*(I - exp(temp4*t))*(temp4 + e*temp3)^-1*q)[1]
#     end
#     ExpectedOrbit(t) = begin
#         Q = me.S
#         q = me.s
#         α = me.a
#         e = ones(size(q))
#         (α*exp((Q + q*α)*t))[1]
#     end
#     return (density=density,mean=mean,ExpectedOrbit=ExpectedOrbit)
# end

