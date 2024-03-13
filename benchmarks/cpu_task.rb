# frozen_string_literal: true

require_relative "base"

def fib(n)
  return n if (0..1).cover?(n)

  fib(n - 1) + fib(n - 2)
end

if __FILE__ == $0
  task = -> { fib(25) }

  Base.new(task: task, checks: 100).run!
end

##
# TL;DR
#
# - additional concurrency for CPU intensive tasks does not provide any viable time reduction
#
# ==============================================================================================
#
#                                       [ CHECKS: 50 ]
# time stats:
#                                                   user     system      total        real
# sync                                          4.250881   0.019885   4.270766 (  4.290467)
# async | main: fixed, rules: nil               4.235206   0.021865   4.257071 (  4.267535)
# async | main: fixed (x2), rules: nil          4.212905   0.051009   4.263914 (  4.272508)
# async | main: fixed, rules: fixed             4.274388   0.072532   4.346920 (  4.360085)
# async | main: fixed, rules: fixed (x2)        4.282669   0.055192   4.337861 (  4.356116)
# async | main: fixed (x2), rules: fixed (x2)   4.227645   0.087375   4.315020 (  4.317907)
# async | main: fixed, rules: io                4.190892   0.081147   4.272039 (  4.271017)
# async | main: fixed (x2), rules: io           4.195734   0.080313   4.276047 (  4.274868)
# async | main: io, rules: nil                  4.160617   0.077557   4.238174 (  4.237149)
# async | main: io, rules: fixed                4.192927   0.082717   4.275644 (  4.274397)
# async | main: io, rules: io                   4.201217   0.083978   4.285195 (  4.283295)
#
#
# thread stats:
#                                              total  per pool   time  +/-    diff  diff/thread
# sync                                             1     -/-     4.29          -/-          -/-
# async | main: fixed, rules: nil                 10    10/0    4.268   ⬇   1.005x      0.0005x
# async | main: fixed (x2), rules: nil            20    20/0    4.273   ⬇   1.004x      0.0002x
# async | main: fixed, rules: fixed               20    10/10    4.36   ⬆   1.016x      0.0008x
# async | main: fixed, rules: fixed (x2)          30    10/20   4.356   ⬆   1.015x      0.0005x
# async | main: fixed (x2), rules: fixed (x2)     40    20/20   4.318   ⬆   1.006x     0.00015x
# async | main: fixed, rules: io                  50    10/40   4.271   ⬇   1.005x      0.0001x
# async | main: fixed (x2), rules: io            100    20/80   4.275   ⬇   1.004x     4.0e-05x
# async | main: io, rules: nil                    50    50/0    4.237   ⬇   1.013x     0.00026x
# async | main: io, rules: fixed                  60    50/10   4.274   ⬇   1.004x     7.0e-05x
# async | main: io, rules: io                    250    50/200  4.283   ⬇   1.002x     1.0e-05x
#
# ==============================================================================================
#
#                                       [ CHECKS: 100 ]
# time stats:
#                                                   user     system      total        real
# sync                                          8.543808   0.104893   8.648701 (  8.669669)
# async | main: fixed, rules: nil               8.357270   0.149115   8.506385 (  8.504923)
# async | main: fixed (x2), rules: nil          8.415800   0.155927   8.571727 (  8.582525)
# async | main: fixed, rules: fixed             8.513098   0.071150   8.584248 (  8.596497)
# async | main: fixed, rules: fixed (x2)        8.447333   0.027577   8.474910 (  8.476787)
# async | main: fixed (x2), rules: fixed (x2)   8.612738   0.051878   8.664616 (  8.683243)
# async | main: fixed, rules: io                8.480218   0.037807   8.518025 (  8.565940)
# async | main: fixed (x2), rules: io           8.439694   0.031848   8.471542 (  8.483056)
# async | main: io, rules: nil                  8.372477   0.026578   8.399055 (  8.404046)
# async | main: io, rules: fixed                8.424610   0.030532   8.455142 (  8.457499)
# async | main: io, rules: io                   8.567914   0.046685   8.614599 (  8.609780)
#
#
# thread stats:
#                                              total  per pool   time  +/-    diff  diff/thread
# sync                                             1     -/-     8.67          -/-          -/-
# async | main: fixed, rules: nil                 10    10/0    8.505   ⬇   1.019x      0.0019x
# async | main: fixed (x2), rules: nil            20    20/0    8.583   ⬇    1.01x      0.0005x
# async | main: fixed, rules: fixed               20    10/10   8.596   ⬇   1.009x     0.00045x
# async | main: fixed, rules: fixed (x2)          30    10/20   8.477   ⬇   1.023x     0.00077x
# async | main: fixed (x2), rules: fixed (x2)     40    20/20   8.683   ⬆   1.002x     5.0e-05x
# async | main: fixed, rules: io                  50    10/40   8.566   ⬇   1.012x     0.00024x
# async | main: fixed (x2), rules: io            100    20/80   8.483   ⬇   1.022x     0.00022x
# async | main: io, rules: nil                   100   100/0    8.404   ⬇   1.032x     0.00032x
# async | main: io, rules: fixed                 110   100/10   8.457   ⬇   1.025x     0.00023x
# async | main: io, rules: io                    500   100/400   8.61   ⬇   1.007x     1.0e-05
#
# ==============================================================================================
#
#                                       [ CHECKS: 200 ]
# time stats:
#                                                   user     system      total        real
# sync                                         16.830111   0.037023  16.867134 ( 16.875315)
# async | main: fixed, rules: nil              16.645972   0.034002  16.679974 ( 16.674489)
# async | main: fixed (x2), rules: nil         16.850945   0.048107  16.899052 ( 16.908938)
# async | main: fixed, rules: fixed            17.079214   0.074882  17.154096 ( 17.164638)
# async | main: fixed, rules: fixed (x2)       16.974090   0.071376  17.045466 ( 17.049899)
# async | main: fixed (x2), rules: fixed (x2)  17.110340   0.100503  17.210843 ( 17.233636)
# async | main: fixed, rules: io               16.875315   0.058312  16.933627 ( 16.935570)
# async | main: fixed (x2), rules: io          16.928882   0.062430  16.991312 ( 16.998766)
# async | main: io, rules: nil                 16.797027   0.066425  16.863452 ( 16.869656)
# async | main: io, rules: fixed               16.978877   0.084309  17.063186 ( 17.085429)
# async | main: io, rules: io                  16.878359   0.136590  17.014949 ( 16.989438)
#
#
# thread stats:
#                                              total  per pool    time  +/-    diff  diff/thread
# sync                                             1     -/-    16.875          -/-          -/-
# async | main: fixed, rules: nil                 10    10/0    16.674   ⬇   1.012x      0.0012x
# async | main: fixed (x2), rules: nil            20    20/0    16.909   ⬆   1.002x      0.0001x
# async | main: fixed, rules: fixed               20    10/10   17.165   ⬆   1.017x     0.00085x
# async | main: fixed, rules: fixed (x2)          30    10/20    17.05   ⬆    1.01x     0.00033x
# async | main: fixed (x2), rules: fixed (x2)     40    20/20   17.234   ⬆   1.021x     0.00052x
# async | main: fixed, rules: io                  50    10/40   16.936   ⬆   1.004x     8.0e-05x
# async | main: fixed (x2), rules: io            100    20/80   16.999   ⬆   1.007x     7.0e-05x
# async | main: io, rules: nil                   200   200/0     16.81   ⬇   1.004x     0.00502x
# async | main: io, rules: fixed                 210   200/10   17.085   ⬆   1.012x     6.0e-05x
# async | main: io, rules: io                   1000   200/800  16.989   ⬆   1.007x     1.0e-05x
#
# ===============================================================================================
#
# System info:
# - CPU: Apple M1 Max (10 cores)
# - RAM: 64 GB
# - Ruby: ruby 3.3.0 (2023-12-25 revision 5124f9ac75) [arm64-darwin21]
#
# ===============================================================================================
