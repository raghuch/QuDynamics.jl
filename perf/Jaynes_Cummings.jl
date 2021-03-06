using QuBase
using QuDynamics
using BenchmarkLite

type SampleProc{Alg} <: Proc end

# Jaynes-Cummings type which takes the configuration parameters.
# These parameters are used for benchmarking, creating various
# JaynesCummings types with various parameters and using
# the solvers to get the timing results.
type JaynesCummings
    N::Int
    wc::Float64
    wa::Float64
    g::Float64
    kappa::Float64
    gamma::Float64
    use_rwa::Bool
    tlist
end

# Name of the solver, used in the creating the table of timing analysis
Base.string{Alg}(::SampleProc{Alg}) = lowercase(string(Alg))

# Constructing a valid configuration, this is set to `true` as we have
# set the type of the required fields in the construct `JaynesCummings` itself.
Base.isvalid{Alg}(p::SampleProc{Alg}, cfg::JaynesCummings) = true

# This returns the `hamitlonian`, `collapse operators`, `initial density matrix`,
# `observable whose expectation value is to be calculated` taking in the `cfg`
# configuration of the system.
function operator_set(p::SampleProc, cfg::JaynesCummings)
    idc = QuArray(eye(cfg.N))
    ida = QuArray(eye(2))
    a  = tensor(lowerop(cfg.N), ida)
    sm = tensor(idc, lowerop(2))
    if cfg.use_rwa
        H = cfg.wc * a' * a + cfg.wa * sm' * sm + cfg.g * (a' * sm + a * sm')
    else
        H = cfg.wc * a' * a + cfg.wa * sm' * sm + cfg.g * (a' + a) * (sm + sm')
    end
    c_op_list = Array(QuBase.AbstractQuMatrix, 0)
    n_th_a = 0.0
    rate_1 = cfg.kappa * (1 + n_th_a)
    if rate_1 > 0.0
        push!(c_op_list, full(sqrt(rate_1) * a))
    end
    rate = cfg.kappa * n_th_a
    if rate > 0.0
        push!(c_op_list, full(sqrt(rate) * a'))
    end
    rate = cfg.gamma
    if rate > 0.0
        push!(c_op_list, full(sqrt(rate) * sm))
    end
    psi = complex(tensor(statevec(1, FiniteBasis(cfg.N)), statevec(2, FiniteBasis(2))))
    return full(H), c_op_list, psi*psi', a*a'
end

# Start states are pre-allocated, that is they are constructed before the evaluation
# here we return the `hamiltonian`, `collapse operator list`, `initial density matrix`,
# `observable whose expectation is to be calculated` using the above function
# i.e., operator_set. The first three remain fixed, the fourth can be varied as required.
Base.start(p::SampleProc, cfg::JaynesCummings) = (operator_set(p, cfg))

Base.length(p::SampleProc, cfg::JaynesCummings) = cfg.N

# This function gets the timing done for calculation of trace, using the pre-allocated
# constructions from the start method i.e., the hamiltonain, collapse operator list,
# initial density matrix and observable whose expectation is to be calculated.
function Base.run{Alg}(p::SampleProc{Alg}, cfg::JaynesCummings, s::(QuBase.QuArray, Array, QuBase.QuArray, QuBase.QuArray))
    qprop = QuPropagator(s[1], s[2], s[3], cfg.tlist, Alg())
    for (t, psi) in qprop
        trace(coeffs(psi*(s[4])))
    end
end

Base.done(p::SampleProc, cfg, s) = nothing

# Creating the array of methods on which benchmarks have to be performed
procs = Proc[ SampleProc{QuExpmV}(),
              SampleProc{QuExpokit}(),
              SampleProc{QuODE45}(),
              SampleProc{QuODE78}(),
              SampleProc{QuODE23s}()]

# Setting up various configurations.
cfgs = JaynesCummings[JaynesCummings(2, 1.0 * 2 * pi, 1.0 * 2 * pi, 0.05 * 2 * pi, 0.05, 0.15, true, 0.:0.1:2*pi),
                      JaynesCummings(3, 1.0 * 2 * pi, 1.0 * 2 * pi, 0.05 * 2 * pi, 0.05, 0.15, true, 0.:0.1:2*pi),
                      JaynesCummings(6, 1.0 * 2 * pi, 1.0 * 2 * pi, 0.05 * 2 * pi, 0.05, 0.15, true, 0.:0.1:2*pi),
                      JaynesCummings(10, 1.0 * 2 * pi, 1.0 * 2 * pi, 0.05 * 2 * pi, 0.05, 0.15, true, 0.:0.1:2*pi),
                      JaynesCummings(2, 1.0 * 2 * pi, 1.0 * 2 * pi, 0.05 * 2 * pi, 0.05, 0.15, false, 0.:0.1:2*pi),
                      JaynesCummings(3, 1.0 * 2 * pi, 1.0 * 2 * pi, 0.05 * 2 * pi, 0.05, 0.15, false, 0.:0.1:2*pi),
                      JaynesCummings(6, 1.0 * 2 * pi, 1.0 * 2 * pi, 0.05 * 2 * pi, 0.05, 0.15, false, 0.:0.1:2*pi),
                      JaynesCummings(10, 1.0 * 2 * pi, 1.0 * 2 * pi, 0.05 * 2 * pi, 0.05, 0.15, false, 0.:0.1:2*pi),
                      JaynesCummings(2, 1.0 * 2 * pi, 1.0 * 2 * pi, 0.05 * 2 * pi, 0.05, 0.15, true, 0.0:0.20134228187919462:30.0),
                      JaynesCummings(3, 1.0 * 2 * pi, 1.0 * 2 * pi, 0.05 * 2 * pi, 0.05, 0.15, true, 0.0:0.20134228187919462:30.0),
                      JaynesCummings(6, 1.0 * 2 * pi, 1.0 * 2 * pi, 0.05 * 2 * pi, 0.05, 0.15, true, 0.0:0.20134228187919462:30.0),
                      JaynesCummings(10, 1.0 * 2 * pi, 1.0 * 2 * pi, 0.05 * 2 * pi, 0.05, 0.15, true, 0.0:0.20134228187919462:30.0),
                      JaynesCummings(2, 1.0 * 2 * pi, 1.0 * 2 * pi, 0.05 * 2 * pi, 0.05, 0.15, false, 0.0:0.20134228187919462:30.0),
                      JaynesCummings(3, 1.0 * 2 * pi, 1.0 * 2 * pi, 0.05 * 2 * pi, 0.05, 0.15, false, 0.0:0.20134228187919462:30.0),
                      JaynesCummings(6, 1.0 * 2 * pi, 1.0 * 2 * pi, 0.05 * 2 * pi, 0.05, 0.15, false, 0.0:0.20134228187919462:30.0),
                      JaynesCummings(10, 1.0 * 2 * pi, 1.0 * 2 * pi, 0.05 * 2 * pi, 0.05, 0.15, false, 0.0:0.20134228187919462:30.0)]

# Generating the timing analysis.
rtable = run(procs, cfgs)

# Table display from the above method.
show(rtable; unit=:usec)
