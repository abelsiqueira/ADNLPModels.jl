export ADNLSModel, ADNLSModel!

mutable struct ADNLSModel{T, S, Si} <: AbstractADNLSModel{T, S}
  meta::NLPModelMeta{T, S}
  nls_meta::NLSMeta{T, S}
  counters::NLSCounters
  adbackend::ADModelBackend

  # Function
  F!

  clinrows::Si
  clincols::Si
  clinvals::S

  c!
end

ADNLSModel(
  meta::NLPModelMeta{T, S},
  nls_meta::NLSMeta{T, S},
  counters::NLSCounters,
  adbackend::ADModelBackend,
  F,
  c,
) where {T, S} = ADNLSModel(meta, nls_meta, counters, adbackend, F, Int[], Int[], T[], c)

ADNLPModels.show_header(io::IO, nls::ADNLSModel) = println(
  io,
  "ADNLSModel - Nonlinear least-squares model with automatic differentiation backend $(nls.adbackend)",
)

"""
    ADNLSModel(F, x0, nequ)
    ADNLSModel(F, x0, nequ, lvar, uvar)
    ADNLSModel(F, x0, nequ, clinrows, clincols, clinvals, lcon, ucon)
    ADNLSModel(F, x0, nequ, A, lcon, ucon)
    ADNLSModel(F, x0, nequ, c, lcon, ucon)
    ADNLSModel(F, x0, nequ, clinrows, clincols, clinvals, c, lcon, ucon)
    ADNLSModel(F, x0, nequ, A, c, lcon, ucon)
    ADNLSModel(F, x0, nequ, lvar, uvar, clinrows, clincols, clinvals, lcon, ucon)
    ADNLSModel(F, x0, nequ, lvar, uvar, A, lcon, ucon)
    ADNLSModel(F, x0, nequ, lvar, uvar, c, lcon, ucon)
    ADNLSModel(F, x0, nequ, lvar, uvar, clinrows, clincols, clinvals, c, lcon, ucon)
    ADNLSModel(F, x0, nequ, lvar, uvar, A, c, lcon, ucon)

ADNLSModel is an Nonlinear Least Squares model using automatic differentiation to
compute the derivatives.
The problem is defined as

     min  ½‖F(x)‖²
    s.to  lcon ≤ (  Ax  ) ≤ ucon
                 ( c(x) )
          lvar ≤   x  ≤ uvar

where `nequ` is the size of the vector `F(x)` and the linear constraints come first.

The following keyword arguments are available to all constructors:

- `linequ`: An array of indexes of the linear equations (default: `Int[]`)
- `minimize`: A boolean indicating whether this is a minimization problem (default: true)
- `name`: The name of the model (default: "Generic")

The following keyword arguments are available to the constructors for constrained problems:

- `y0`: An inital estimate to the Lagrangian multipliers (default: zeros)

`ADNLSModel` uses `ForwardDiff` and `ReverseDiff` for the automatic differentiation.
One can specify a new backend with the keyword arguments `backend::ADNLPModels.ADBackend`.
There are three pre-coded backends:
- the default `ForwardDiffAD`.
- `ReverseDiffAD`.
- `ZygoteDiffAD` accessible after loading `Zygote.jl` in your environment.
For an advanced usage, one can define its own backend and redefine the API as done in [ADNLPModels.jl/src/forward.jl](https://github.com/JuliaSmoothOptimizers/ADNLPModels.jl/blob/main/src/forward.jl).

# Examples
```julia
using ADNLPModels
F(x) = [x[2]; x[1]]
nequ = 2
x0 = ones(3)
nvar = 3
ADNLSModel(F, x0, nequ) # uses the default ForwardDiffAD backend.
ADNLSModel(F, x0, nequ; backend = ADNLPModels.ReverseDiffAD) # uses ReverseDiffAD backend.

using Zygote
ADNLSModel(F, x0, nequ; backend = ADNLPModels.ZygoteAD)
```

```julia
using ADNLPModels
F(x) = [x[2]; x[1]]
nequ = 2
x0 = ones(3)
c(x) = [1x[1] + x[2]; x[2]]
nvar, ncon = 3, 2
ADNLSModel(F, x0, nequ, c, zeros(ncon), zeros(ncon)) # uses the default ForwardDiffAD backend.
ADNLSModel(F, x0, nequ, c, zeros(ncon), zeros(ncon); backend = ADNLPModels.ReverseDiffAD) # uses ReverseDiffAD backend.

using Zygote
ADNLSModel(F, x0, nequ, c, zeros(ncon), zeros(ncon); backend = ADNLPModels.ZygoteAD)
```

For in-place constraints and residual function, use one of the following constructors:

    ADNLSModel!(F!, x0, nequ)
    ADNLSModel!(F!, x0, nequ, lvar, uvar)
    ADNLSModel!(F!, x0, nequ, c!, lcon, ucon)
    ADNLSModel!(F!, x0, nequ, clinrows, clincols, clinvals, c!, lcon, ucon)
    ADNLSModel!(F!, x0, nequ, clinrows, clincols, clinvals, lcon, ucon)
    ADNLSModel!(F!, x0, nequ, A, c!, lcon, ucon)
    ADNLSModel!(F!, x0, nequ, A, lcon, ucon)
    ADNLSModel!(F!, x0, nequ, lvar, uvar, c!, lcon, ucon)
    ADNLSModel!(F!, x0, nequ, lvar, uvar, clinrows, clincols, clinvals, c!, lcon, ucon)
    ADNLSModel!(F!, x0, nequ, lvar, uvar, clinrows, clincols, clinvals, lcon, ucon)
    ADNLSModel!(F!, x0, nequ, lvar, uvar, A, c!, lcon, ucon)
    ADNLSModel!(F!, x0, nequ, lvar, uvar, A, clcon, ucon)

where the constraint function has the signature `c!(output, input)`.

```julia
using ADNLPModels
function F!(output, x)
  output[1] = x[2]
  output[2] = x[1]
end
nequ = 2
x0 = ones(3)
function c!(output, x) 
  output[1] = 1x[1] + x[2]
  output[2] = x[2]
end
nvar, ncon = 3, 2
nls = ADNLSModel!(F!, x0, nequ, c!, zeros(ncon), zeros(ncon))
```
"""
function ADNLSModel(F, x0::S, nequ::Integer; kwargs...) where {S}
  function F!(output, x)
    Fx = F(x)
    for i = 1:nequ
      output[i] = Fx[i]
    end
    return output
  end

  return ADNLSModel!(F!, x0, nequ; kwargs...)
end

function ADNLSModel!(
  F!,
  x0::S,
  nequ::Integer;
  linequ::AbstractVector{<:Integer} = Int[],
  name::String = "Generic",
  minimize::Bool = true,
  kwargs...,
) where {S}
  T = eltype(S)
  nvar = length(x0)

  adbackend = ADModelNLSBackend(nvar, F!, nequ; x0 = x0, kwargs...)
  nnzh = get_nln_nnzh(adbackend, nvar)

  meta = NLPModelMeta{T, S}(nvar, x0 = x0, nnzh = nnzh, name = name, minimize = minimize)
  nls_nnzj = get_residual_nnzj(adbackend, nvar, nequ)
  nls_meta =
    NLSMeta{T, S}(nequ, nvar, nnzj = nls_nnzj, nnzh = div(nvar * (nvar + 1), 2), lin = linequ)
  return ADNLSModel(meta, nls_meta, NLSCounters(), adbackend, F!, (cx, x) -> cx)
end

function ADNLSModel(F, x0::S, nequ::Integer, lvar::S, uvar::S; kwargs...) where {S}
  function F!(output, x)
    Fx = F(x)
    for i = 1:nequ
      output[i] = Fx[i]
    end
    return output
  end

  return ADNLSModel!(F!, x0, nequ, lvar, uvar; kwargs...)
end

function ADNLSModel!(
  F!,
  x0::S,
  nequ::Integer,
  lvar::S,
  uvar::S;
  linequ::AbstractVector{<:Integer} = Int[],
  name::String = "Generic",
  minimize::Bool = true,
  kwargs...,
) where {S}
  T = eltype(S)
  nvar = length(x0)
  @lencheck nvar lvar uvar

  adbackend = ADModelNLSBackend(nvar, F!, nequ; x0 = x0, kwargs...)
  nnzh = get_nln_nnzh(adbackend, nvar)

  meta = NLPModelMeta{T, S}(
    nvar,
    x0 = x0,
    lvar = lvar,
    uvar = uvar,
    nnzh = nnzh,
    name = name,
    minimize = minimize,
  )
  nls_nnzj = get_residual_nnzj(adbackend, nvar, nequ)
  nls_meta =
    NLSMeta{T, S}(nequ, nvar, nnzj = nls_nnzj, nnzh = div(nvar * (nvar + 1), 2), lin = linequ)
  return ADNLSModel(meta, nls_meta, NLSCounters(), adbackend, F!, (cx, x) -> cx)
end

function ADNLSModel(F, x0::S, nequ::Integer, c, lcon::S, ucon::S; kwargs...) where {S}
  function F!(output, x)
    Fx = F(x)
    for i = 1:nequ
      output[i] = Fx[i]
    end
    return output
  end

  function c!(output, x)
    cx = c(x)
    for i = 1:length(cx)
      output[i] = cx[i]
    end
    return output
  end

  return ADNLSModel!(F!, x0, nequ, c!, lcon, ucon; kwargs...)
end

function ADNLSModel!(
  F!,
  x0::S,
  nequ::Integer,
  c!,
  lcon::S,
  ucon::S;
  y0::S = fill!(similar(lcon), zero(eltype(S))),
  linequ::AbstractVector{<:Integer} = Int[],
  name::String = "Generic",
  minimize::Bool = true,
  kwargs...,
) where {S}
  T = eltype(S)
  nvar = length(x0)
  ncon = length(lcon)
  @lencheck ncon ucon y0

  adbackend = ADModelNLSBackend(nvar, F!, nequ, ncon, c!; x0 = x0, kwargs...)

  nnzh = get_nln_nnzh(adbackend, nvar)
  nnzj = get_nln_nnzj(adbackend, nvar, ncon)

  meta = NLPModelMeta{T, S}(
    nvar,
    x0 = x0,
    ncon = ncon,
    y0 = y0,
    lcon = lcon,
    ucon = ucon,
    nnzj = nnzj,
    nnzh = nnzh,
    nln_nnzj = nnzj,
    name = name,
    minimize = minimize,
  )
  nls_nnzj = get_residual_nnzj(adbackend, nvar, nequ)
  nls_meta =
    NLSMeta{T, S}(nequ, nvar, nnzj = nls_nnzj, nnzh = div(nvar * (nvar + 1), 2), lin = linequ)
  return ADNLSModel(meta, nls_meta, NLSCounters(), adbackend, F!, c!)
end

function ADNLSModel(
  F,
  x0::S,
  nequ::Integer,
  clinrows::Si,
  clincols::Si,
  clinvals::S,
  lcon::S,
  ucon::S;
  kwargs...,
) where {S, Si}
  function F!(output, x)
    Fx = F(x)
    for i = 1:nequ
      output[i] = Fx[i]
    end
    return output
  end
  return ADNLSModel!(F!, x0, nequ, clinrows, clincols, clinvals, lcon, ucon; kwargs...)
end

function ADNLSModel(
  F,
  x0::S,
  nequ::Integer,
  A::AbstractSparseMatrix{Tv, Ti},
  lcon::S,
  ucon::S;
  kwargs...,
) where {S, Tv, Ti}
  function F!(output, x)
    Fx = F(x)
    for i = 1:nequ
      output[i] = Fx[i]
    end
    return output
  end
  return ADNLSModel!(F!, x0, nequ, A, lcon, ucon; kwargs...)
end

function ADNLSModel(
  F,
  x0::S,
  nequ::Integer,
  clinrows::Si,
  clincols::Si,
  clinvals::S,
  c,
  lcon::S,
  ucon::S;
  kwargs...,
) where {S, Si}
  function F!(output, x)
    Fx = F(x)
    for i = 1:nequ
      output[i] = Fx[i]
    end
    return output
  end

  function c!(output, x)
    cx = c(x)
    for i = 1:length(cx)
      output[i] = cx[i]
    end
    return output
  end

  return ADNLSModel!(F!, x0, nequ, clinrows, clincols, clinvals, c!, lcon, ucon; kwargs...)
end

function ADNLSModel!(
  F!,
  x0::S,
  nequ::Integer,
  clinrows::Si,
  clincols::Si,
  clinvals::S,
  lcon::S,
  ucon::S;
  kwargs...,
) where {S, Si}
  return ADNLSModel!(
    F!,
    x0,
    nequ,
    clinrows,
    clincols,
    clinvals,
    (cx, x) -> cx,
    lcon,
    ucon;
    kwargs...,
  )
end

function ADNLSModel!(
  F!,
  x0::S,
  nequ::Integer,
  clinrows::Si,
  clincols::Si,
  clinvals::S,
  c!,
  lcon::S,
  ucon::S;
  y0::S = fill!(similar(lcon), zero(eltype(S))),
  linequ::AbstractVector{<:Integer} = Int[],
  name::String = "Generic",
  minimize::Bool = true,
  kwargs...,
) where {S, Si}
  T = eltype(S)
  nvar = length(x0)
  ncon = length(lcon)
  @lencheck ncon ucon y0

  nlin = maximum(clinrows)
  lin = 1:nlin
  lin_nnzj = length(clinvals)
  @lencheck lin_nnzj clinrows clincols

  adbackend = ADModelNLSBackend(nvar, F!, nequ, ncon - nlin, c!; x0 = x0, kwargs...)

  nnzh = get_nln_nnzh(adbackend, nvar)

  nln_nnzj = get_nln_nnzj(adbackend, nvar, ncon - nlin)
  nnzj = lin_nnzj + nln_nnzj

  meta = NLPModelMeta{T, S}(
    nvar,
    x0 = x0,
    ncon = ncon,
    y0 = y0,
    lcon = lcon,
    ucon = ucon,
    nnzj = nnzj,
    nnzh = nnzh,
    name = name,
    lin = lin,
    lin_nnzj = lin_nnzj,
    nln_nnzj = nln_nnzj,
    minimize = minimize,
  )
  nls_nnzj = get_residual_nnzj(adbackend, nvar, nequ)
  nls_meta =
    NLSMeta{T, S}(nequ, nvar, nnzj = nls_nnzj, nnzh = div(nvar * (nvar + 1), 2), lin = linequ)
  return ADNLSModel(meta, nls_meta, NLSCounters(), adbackend, F!, clinrows, clincols, clinvals, c!)
end

function ADNLSModel(
  F,
  x0::S,
  nequ::Integer,
  A::AbstractSparseMatrix{Tv, Ti},
  c,
  lcon::S,
  ucon::S;
  kwargs...,
) where {S, Tv, Ti}
  clinrows, clincols, clinvals = findnz(A)
  return ADNLSModel(F, x0, nequ, clinrows, clincols, clinvals, c, lcon, ucon; kwargs...)
end

function ADNLSModel!(
  F!,
  x0::S,
  nequ::Integer,
  A::AbstractSparseMatrix{Tv, Ti},
  c!,
  lcon::S,
  ucon::S;
  kwargs...,
) where {S, Tv, Ti}
  clinrows, clincols, clinvals = findnz(A)
  return ADNLSModel!(F!, x0, nequ, clinrows, clincols, clinvals, c!, lcon, ucon; kwargs...)
end

function ADNLSModel!(
  F!,
  x0::S,
  nequ::Integer,
  A::AbstractSparseMatrix{Tv, Ti},
  lcon::S,
  ucon::S;
  kwargs...,
) where {S, Tv, Ti}
  clinrows, clincols, clinvals = findnz(A)
  return ADNLSModel!(
    F!,
    x0,
    nequ,
    clinrows,
    clincols,
    clinvals,
    (cx, x) -> cx,
    lcon,
    ucon;
    kwargs...,
  )
end

function ADNLSModel(
  F,
  x0::S,
  nequ::Integer,
  lvar::S,
  uvar::S,
  clinrows::Si,
  clincols::Si,
  clinvals::S,
  lcon::S,
  ucon::S;
  kwargs...,
) where {S, Si}
  function F!(output, x)
    Fx = F(x)
    for i = 1:nequ
      output[i] = Fx[i]
    end
    return output
  end
  return ADNLSModel!(F!, x0, nequ, lvar, uvar, clinrows, clincols, clinvals, lcon, ucon; kwargs...)
end

function ADNLSModel!(
  F!,
  x0::S,
  nequ::Integer,
  lvar::S,
  uvar::S,
  clinrows::Si,
  clincols::Si,
  clinvals::S,
  lcon::S,
  ucon::S;
  kwargs...,
) where {S, Si}
  return ADNLSModel!(
    F!,
    x0,
    nequ,
    lvar,
    uvar,
    clinrows,
    clincols,
    clinvals,
    (cx, x) -> cx,
    lcon,
    ucon;
    kwargs...,
  )
end

function ADNLSModel(
  F,
  x0::S,
  nequ::Integer,
  lvar::S,
  uvar::S,
  A::AbstractSparseMatrix{Tv, Ti},
  lcon::S,
  ucon::S;
  kwargs...,
) where {S, Tv, Ti}
  function F!(output, x)
    Fx = F(x)
    for i = 1:nequ
      output[i] = Fx[i]
    end
    return output
  end
  return ADNLSModel!(F!, x0, nequ, lvar, uvar, A, lcon, ucon; kwargs...)
end

function ADNLSModel!(
  F!,
  x0::S,
  nequ::Integer,
  lvar::S,
  uvar::S,
  A::AbstractSparseMatrix{Tv, Ti},
  lcon::S,
  ucon::S;
  kwargs...,
) where {S, Tv, Ti}
  clinrows, clincols, clinvals = findnz(A)
  return ADNLSModel!(F!, x0, nequ, lvar, uvar, clinrows, clincols, clinvals, lcon, ucon; kwargs...)
end

function ADNLSModel(
  F,
  x0::S,
  nequ::Integer,
  lvar::S,
  uvar::S,
  c,
  lcon::S,
  ucon::S;
  kwargs...,
) where {S}
  function F!(output, x)
    Fx = F(x)
    for i = 1:nequ
      output[i] = Fx[i]
    end
    return output
  end

  function c!(output, x)
    cx = c(x)
    for i = 1:length(cx)
      output[i] = cx[i]
    end
    return output
  end

  return ADNLSModel!(F!, x0, nequ, lvar, uvar, c!, lcon, ucon; kwargs...)
end

function ADNLSModel!(
  F!,
  x0::S,
  nequ::Integer,
  lvar::S,
  uvar::S,
  c!,
  lcon::S,
  ucon::S;
  y0::S = fill!(similar(lcon), zero(eltype(S))),
  linequ::AbstractVector{<:Integer} = Int[],
  name::String = "Generic",
  minimize::Bool = true,
  kwargs...,
) where {S}
  T = eltype(S)
  nvar = length(x0)
  ncon = length(lcon)
  @lencheck nvar lvar uvar
  @lencheck ncon ucon y0

  adbackend = ADModelNLSBackend(nvar, F!, nequ, ncon, c!; x0 = x0, kwargs...)

  nnzh = get_nln_nnzh(adbackend, nvar)
  nnzj = get_nln_nnzj(adbackend, nvar, ncon)

  meta = NLPModelMeta{T, S}(
    nvar,
    x0 = x0,
    lvar = lvar,
    uvar = uvar,
    ncon = ncon,
    y0 = y0,
    lcon = lcon,
    ucon = ucon,
    nnzj = nnzj,
    nnzh = nnzh,
    nln_nnzj = nnzj,
    name = name,
    minimize = minimize,
  )
  nls_nnzj = get_residual_nnzj(adbackend, nvar, nequ)
  nls_meta =
    NLSMeta{T, S}(nequ, nvar, nnzj = nls_nnzj, nnzh = div(nvar * (nvar + 1), 2), lin = linequ)
  return ADNLSModel(meta, nls_meta, NLSCounters(), adbackend, F!, c!)
end

function ADNLSModel(
  F,
  x0::S,
  nequ::Integer,
  lvar::S,
  uvar::S,
  clinrows::Si,
  clincols::Si,
  clinvals::S,
  c,
  lcon::S,
  ucon::S;
  kwargs...,
) where {S, Si}
  function F!(output, x)
    Fx = F(x)
    for i = 1:nequ
      output[i] = Fx[i]
    end
    return output
  end

  function c!(output, x)
    cx = c(x)
    for i = 1:length(cx)
      output[i] = cx[i]
    end
    return output
  end

  return ADNLSModel!(
    F!,
    x0,
    nequ,
    lvar,
    uvar,
    clinrows,
    clincols,
    clinvals,
    c!,
    lcon,
    ucon;
    kwargs...,
  )
end

function ADNLSModel!(
  F!,
  x0::S,
  nequ::Integer,
  lvar::S,
  uvar::S,
  clinrows::Si,
  clincols::Si,
  clinvals::S,
  c!,
  lcon::S,
  ucon::S;
  y0::S = fill!(similar(lcon), zero(eltype(S))),
  linequ::AbstractVector{<:Integer} = Int[],
  name::String = "Generic",
  minimize::Bool = true,
  kwargs...,
) where {S, Si}
  T = eltype(S)
  nvar = length(x0)
  ncon = length(lcon)
  @lencheck nvar lvar uvar
  @lencheck ncon ucon y0

  nlin = maximum(clinrows)
  lin = 1:nlin
  lin_nnzj = length(clinvals)
  @lencheck lin_nnzj clinrows clincols

  adbackend = ADModelNLSBackend(nvar, F!, nequ, ncon - nlin, c!; x0 = x0, kwargs...)

  nnzh = get_nln_nnzh(adbackend, nvar)

  nln_nnzj = get_nln_nnzj(adbackend, nvar, ncon - nlin)
  nnzj = lin_nnzj + nln_nnzj

  meta = NLPModelMeta{T, S}(
    nvar,
    x0 = x0,
    lvar = lvar,
    uvar = uvar,
    ncon = ncon,
    y0 = y0,
    lcon = lcon,
    ucon = ucon,
    nnzj = nnzj,
    name = name,
    lin = lin,
    lin_nnzj = lin_nnzj,
    nln_nnzj = nln_nnzj,
    nnzh = nnzh,
    minimize = minimize,
  )
  nls_nnzj = get_residual_nnzj(adbackend, nvar, nequ)
  nls_meta =
    NLSMeta{T, S}(nequ, nvar, nnzj = nls_nnzj, nnzh = div(nvar * (nvar + 1), 2), lin = linequ)
  return ADNLSModel(meta, nls_meta, NLSCounters(), adbackend, F!, clinrows, clincols, clinvals, c!)
end

function ADNLSModel(
  F,
  x0,
  nequ::Integer,
  lvar::S,
  uvar::S,
  A::AbstractSparseMatrix{Tv, Ti},
  c,
  lcon::S,
  ucon::S;
  kwargs...,
) where {S, Tv, Ti}
  clinrows, clincols, clinvals = findnz(A)
  return ADNLSModel(F, x0, nequ, lvar, uvar, clinrows, clincols, clinvals, c, lcon, ucon; kwargs...)
end

function ADNLSModel!(
  F!,
  x0,
  nequ::Integer,
  lvar::S,
  uvar::S,
  A::AbstractSparseMatrix{Tv, Ti},
  c!,
  lcon::S,
  ucon::S;
  kwargs...,
) where {S, Tv, Ti}
  clinrows, clincols, clinvals = findnz(A)
  return ADNLSModel!(
    F!,
    x0,
    nequ,
    lvar,
    uvar,
    clinrows,
    clincols,
    clinvals,
    c!,
    lcon,
    ucon;
    kwargs...,
  )
end

function NLPModels.residual!(nls::ADNLSModel, x::AbstractVector, Fx::AbstractVector)
  @lencheck nls.meta.nvar x
  @lencheck nls.nls_meta.nequ Fx
  increment!(nls, :neval_residual)
  nls.F!(Fx, x)
  return Fx
end

function NLPModels.jac_structure_residual!(
  nls::ADNLSModel,
  rows::AbstractVector{<:Integer},
  cols::AbstractVector{<:Integer},
)
  @lencheck nls.nls_meta.nnzj rows cols
  return jac_structure_residual!(nls.adbackend.jacobian_residual_backend, nls, rows, cols)
end

function NLPModels.jac_coord_residual!(nls::ADNLSModel, x::AbstractVector, vals::AbstractVector)
  @lencheck nls.meta.nvar x
  @lencheck nls.nls_meta.nnzj vals
  increment!(nls, :neval_jac_residual)
  jac_coord_residual!(nls.adbackend.jacobian_residual_backend, nls, x, vals)
  return vals
end

function NLPModels.jprod_residual!(
  nls::ADNLSModel,
  x::AbstractVector,
  v::AbstractVector,
  Jv::AbstractVector,
)
  @lencheck nls.meta.nvar x v
  @lencheck nls.nls_meta.nequ Jv
  increment!(nls, :neval_jprod_residual)
  F = get_F(nls, nls.adbackend.jprod_residual_backend)
  Jprod!(nls.adbackend.jprod_residual_backend, Jv, F, x, v, Val(:F))
  return Jv
end

function NLPModels.jtprod_residual!(
  nls::ADNLSModel,
  x::AbstractVector,
  v::AbstractVector,
  Jtv::AbstractVector,
)
  @lencheck nls.meta.nvar x Jtv
  @lencheck nls.nls_meta.nequ v
  increment!(nls, :neval_jtprod_residual)
  F = get_F(nls, nls.adbackend.jtprod_residual_backend)
  Jtprod!(nls.adbackend.jtprod_residual_backend, Jtv, F, x, v, Val(:F))
  return Jtv
end

#=
function NLPModels.hess_residual(nls::ADNLSModel, x::AbstractVector, v::AbstractVector)
  @lencheck nls.meta.nvar x
  @lencheck nls.nls_meta.nequ v
  increment!(nls, :neval_hess_residual)
  F = get_F(nls, nls.adbackend.hessian_residual_backend)
  ϕ(x) = dot(F(x), v)
  return Symmetric(hessian(nls.adbackend.hessian_residual_backend, ϕ, x), :L)
end
=#

function NLPModels.hess_structure_residual!(
  nls::ADNLSModel,
  rows::AbstractVector{<:Integer},
  cols::AbstractVector{<:Integer},
)
  @lencheck nls.nls_meta.nnzh rows cols
  n = nls.meta.nvar
  I = ((i, j) for i = 1:n, j = 1:n if i ≥ j)
  rows .= getindex.(I, 1)
  cols .= getindex.(I, 2)
  return rows, cols
end

function NLPModels.hess_coord_residual!(
  nls::ADNLSModel,
  x::AbstractVector,
  v::AbstractVector,
  vals::AbstractVector,
)
  @lencheck nls.meta.nvar x
  @lencheck nls.nls_meta.nequ v
  @lencheck nls.nls_meta.nnzh vals
  increment!(nls, :neval_hess_residual)
  F = get_F(nls, nls.adbackend.hessian_residual_backend)
  Hx = hessian(nls.adbackend.hessian_residual_backend, x -> dot(F(x), v), x)
  k = 1
  for j = 1:(nls.meta.nvar)
    for i = j:(nls.meta.nvar)
      vals[k] = Hx[i, j]
      k += 1
    end
  end
  return vals
end

function NLPModels.jth_hess_residual(nls::ADNLSModel, x::AbstractVector, i::Int)
  @lencheck nls.meta.nvar x
  increment!(nls, :neval_jhess_residual)
  F = get_F(nls, nls.adbackend.hessian_residual_backend)
  return Symmetric(hessian(nls.adbackend.hessian_residual_backend, x -> F(x)[i], x), :L)
end

function NLPModels.hprod_residual!(
  nls::ADNLSModel,
  x::AbstractVector,
  i::Int,
  v::AbstractVector,
  Hiv::AbstractVector,
)
  @lencheck nls.meta.nvar x v Hiv
  increment!(nls, :neval_hprod_residual)
  hprod_residual!(nls.adbackend.hprod_residual_backend, nls, x, v, i, Hiv)
  return Hiv
end

function NLPModels.cons_lin!(nls::ADNLSModel, x::AbstractVector, c::AbstractVector)
  @lencheck nls.meta.nvar x
  @lencheck nls.meta.nlin c
  increment!(nls, :neval_cons_lin)
  coo_prod!(nls.clinrows, nls.clincols, nls.clinvals, x, c)
  return c
end

function NLPModels.cons_nln!(nls::ADNLSModel, x::AbstractVector, c::AbstractVector)
  @lencheck nls.meta.nvar x
  @lencheck nls.meta.nnln c
  increment!(nls, :neval_cons_nln)
  nls.c!(c, x)
  return c
end

function NLPModels.jac_lin_structure!(
  nls::ADNLSModel,
  rows::AbstractVector{<:Integer},
  cols::AbstractVector{<:Integer},
)
  @lencheck nls.meta.lin_nnzj rows cols
  rows .= nls.clinrows
  cols .= nls.clincols
  return rows, cols
end

function NLPModels.jac_nln_structure!(
  nls::ADNLSModel,
  rows::AbstractVector{<:Integer},
  cols::AbstractVector{<:Integer},
)
  @lencheck nls.meta.nln_nnzj rows cols
  return jac_structure!(nls.adbackend.jacobian_backend, nls, rows, cols)
end

function NLPModels.jac_lin_coord!(nls::ADNLSModel, x::AbstractVector, vals::AbstractVector)
  @lencheck nls.meta.nvar x
  @lencheck nls.meta.lin_nnzj vals
  increment!(nls, :neval_jac_lin)
  vals .= nls.clinvals
  return vals
end

function NLPModels.jac_nln_coord!(nls::ADNLSModel, x::AbstractVector, vals::AbstractVector)
  @lencheck nls.meta.nvar x
  @lencheck nls.meta.nln_nnzj vals
  increment!(nls, :neval_jac_nln)
  return jac_coord!(nls.adbackend.jacobian_backend, nls, x, vals)
end

function NLPModels.jprod_lin!(
  nls::ADNLSModel,
  x::AbstractVector,
  v::AbstractVector,
  Jv::AbstractVector{T},
) where {T}
  @lencheck nls.meta.nvar x v
  @lencheck nls.meta.nlin Jv
  increment!(nls, :neval_jprod_lin)
  coo_prod!(nls.clinrows, nls.clincols, nls.clinvals, v, Jv)
  return Jv
end

function NLPModels.jprod_nln!(
  nls::ADNLSModel,
  x::AbstractVector,
  v::AbstractVector,
  Jv::AbstractVector,
)
  @lencheck nls.meta.nvar x v
  @lencheck nls.meta.nnln Jv
  increment!(nls, :neval_jprod_nln)
  c = get_c(nls, nls.adbackend.jprod_backend)
  Jprod!(nls.adbackend.jprod_backend, Jv, c, x, v, Val(:c))
  return Jv
end

function NLPModels.jtprod!(
  nls::ADNLSModel,
  x::AbstractVector,
  v::AbstractVector,
  Jtv::AbstractVector{T},
) where {T}
  @lencheck nls.meta.nvar x Jtv
  @lencheck nls.meta.ncon v
  increment!(nls, :neval_jtprod)
  if nls.meta.nnln > 0
    jtprod_nln!(nls, x, v[(nls.meta.nlin + 1):end], Jtv)
    decrement!(nls, :neval_jtprod_nln)
  else
    fill!(Jtv, zero(T))
  end
  for i = 1:(nls.meta.lin_nnzj)
    Jtv[nls.clincols[i]] += nls.clinvals[i] * v[nls.clinrows[i]]
  end
  return Jtv
end

function NLPModels.jtprod_lin!(
  nls::ADNLSModel,
  x::AbstractVector,
  v::AbstractVector,
  Jtv::AbstractVector{T},
) where {T}
  @lencheck nls.meta.nvar x Jtv
  @lencheck nls.meta.nlin v
  increment!(nls, :neval_jtprod_lin)
  coo_prod!(nls.clincols, nls.clinrows, nls.clinvals, v, Jtv)
  return Jtv
end

function NLPModels.jtprod_nln!(
  nls::ADNLSModel,
  x::AbstractVector,
  v::AbstractVector,
  Jtv::AbstractVector,
)
  @lencheck nls.meta.nvar x Jtv
  @lencheck nls.meta.nnln v
  increment!(nls, :neval_jtprod_nln)
  c = get_c(nls, nls.adbackend.jtprod_backend)
  Jtprod!(nls.adbackend.jtprod_backend, Jtv, c, x, v, Val(:c))
  return Jtv
end

function NLPModels.hess_structure!(
  nls::ADNLSModel,
  rows::AbstractVector{<:Integer},
  cols::AbstractVector{<:Integer},
)
  @lencheck nls.meta.nnzh rows cols
  return hess_structure!(nls.adbackend.hessian_backend, nls, rows, cols)
end

function NLPModels.hess_coord!(
  nls::ADNLSModel,
  x::AbstractVector,
  vals::AbstractVector;
  obj_weight::Real = one(eltype(x)),
)
  @lencheck nls.meta.nvar x
  @lencheck nls.meta.nnzh vals
  increment!(nls, :neval_hess)
  return hess_coord!(nls.adbackend.hessian_backend, nls, x, obj_weight, vals)
end

function NLPModels.hess_coord!(
  nls::ADNLSModel,
  x::AbstractVector,
  y::AbstractVector,
  vals::AbstractVector;
  obj_weight::Real = one(eltype(x)),
)
  @lencheck nls.meta.nvar x
  @lencheck nls.meta.ncon y
  @lencheck nls.meta.nnzh vals
  increment!(nls, :neval_hess)
  return hess_coord!(
    nls.adbackend.hessian_backend,
    nls,
    x,
    view(y, (nls.meta.nlin + 1):(nls.meta.ncon)),
    obj_weight,
    vals,
  )
end

function NLPModels.hprod!(
  nls::ADNLSModel,
  x::AbstractVector,
  v::AbstractVector,
  Hv::AbstractVector;
  obj_weight = one(eltype(x)),
)
  @lencheck nls.meta.nvar x v Hv
  increment!(nls, :neval_hprod)
  ℓ = get_lag(nls, nls.adbackend.hprod_backend, obj_weight)
  Hvprod!(nls.adbackend.hprod_backend, Hv, x, v, ℓ, Val(:obj), obj_weight)
  return Hv
end

function NLPModels.hprod!(
  nls::ADNLSModel,
  x::AbstractVector,
  y::AbstractVector,
  v::AbstractVector,
  Hv::AbstractVector;
  obj_weight = one(eltype(x)),
)
  @lencheck nls.meta.nvar x v Hv
  @lencheck nls.meta.ncon y
  increment!(nls, :neval_hprod)
  ℓ = get_lag(nls, nls.adbackend.hprod_backend, obj_weight, y)
  yview = (length(y) == nls.meta.nnln) ? y : view(y, (nls.meta.nlin + 1):(nls.meta.ncon))
  Hvprod!(nls.adbackend.hprod_backend, Hv, x, v, ℓ, Val(:lag), yview, obj_weight)
  return Hv
end

function NLPModels.jth_hess_coord!(
  nls::ADNLSModel,
  x::AbstractVector,
  j::Integer,
  vals::AbstractVector{T},
) where {T}
  @lencheck nls.meta.nnzh vals
  @lencheck nls.meta.nvar x
  @rangecheck 1 nls.meta.ncon j
  increment!(nls, :neval_jhess)
  if j ≤ nls.meta.nlin
    fill!(vals, zero(T))
  else
    hess_coord!(nls.adbackend.hessian_backend, nls, x, j, vals)
  end
  return vals
end

function NLPModels.jth_hprod!(
  nls::ADNLSModel,
  x::AbstractVector,
  v::AbstractVector,
  j::Integer,
  Hv::AbstractVector{T},
) where {T}
  @lencheck nls.meta.nvar x v Hv
  @rangecheck 1 nls.meta.ncon j
  increment!(nls, :neval_jhprod)
  if j ≤ nls.meta.nlin
    fill!(Hv, zero(T))
  else
    hprod!(nls.adbackend.hprod_backend, nls, x, v, j, Hv)
  end
  return Hv
end

function NLPModels.ghjvprod!(
  nls::ADNLSModel,
  x::AbstractVector,
  g::AbstractVector,
  v::AbstractVector,
  gHv::AbstractVector{T},
) where {T}
  @lencheck nls.meta.nvar x g v
  @lencheck nls.meta.ncon gHv
  increment!(nls, :neval_hprod)
  @views gHv[1:(nls.meta.nlin)] .= zero(T)
  if nls.meta.nnln > 0
    c = get_c(nls, nls.adbackend.ghjvprod_backend)
    @views gHv[(nls.meta.nlin + 1):end] .=
      directional_second_derivative(nls.adbackend.ghjvprod_backend, c, x, v, g)
  end
  return gHv
end
