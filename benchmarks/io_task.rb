# frozen_string_literal: true

require_relative "base"

if __FILE__ == $0
  task = -> { sleep(0.3) }

  Base.new(task: task, checks: 200).run!
end

##
# TL;DR
#
# - while `io` provides the best performance it does not have max_threads limit (almost), so it's
#   pretty easy to overload the system with excessive number of threads, especially with the high
#   number of contract check invocations
# - it's comparably safe to use `io` for rules pool while `fixed` main pool works like a limiting
#   factor preventing `io` from indefinite creation of threads
# - increasing number of threads in main pool with disabled rules pool is more effective than having
#   the same number of threads across both of them enabled, i.e. configurations `fixed/fixed` should
#   be avoided
#
# Pool configs compared:
#   fixed/nil   | yes   | predictable, linear performance boost
#   fixed/io    | yes   | predictable, great performance (warning: more threads involved)
#   fixed/fixed | no    | wasting threads, fixed/nil is more efficient
#   io/nil      | maybe | no max_threads limit, great performance, safe only for infrequent checks
#   io/io       | maybe | no max_threads limit, best performance, safe only for infrequent checks
#   io/fixed    | no    | `fixed` pool blocks `io` pool giving the same performance as `fixed/nil`
#                         config while consuming a lot more threads
#
# ===============================================================================================
#
#                                       [ CHECKS: 50 ]
# time stats:
#                                                   user     system      total        real
# sync                                          0.029054   0.003960   0.033014 ( 60.730443)
# async | main: fixed, rules: nil               0.037581   0.006289   0.043870 (  6.102996)
# async | main: fixed (x2), rules: nil          0.013672   0.006369   0.020041 (  3.658370)
# async | main: fixed, rules: fixed             0.045739   0.009818   0.055557 (  6.105275)
# async | main: fixed, rules: fixed (x2)        0.048882   0.007210   0.056092 (  3.058503)
# async | main: fixed (x2), rules: fixed (x2)   0.061931   0.009909   0.071840 (  3.081287)
# async | main: fixed, rules: io                0.048239   0.010111   0.058350 (  1.575488)
# async | main: fixed (x2), rules: io           0.062420   0.012960   0.075380 (  0.993189)
# async | main: io, rules: nil                  0.010998   0.006536   0.017534 (  1.235455)
# async | main: io, rules: fixed                0.050765   0.014542   0.065307 (  6.115675)
# async | main: io, rules: io                   0.041993   0.020064   0.062057 (  0.370872)
#
#
# thread stats:
#                                              total  per pool   time  +/-     diff  diff/thread
# sync                                             1     -/-    60.73           -/-          -/-
# async | main: fixed, rules: nil                 10    10/0    6.103   ⬇    9.951x      0.8951x
# async | main: fixed (x2), rules: nil            20    20/0    3.658   ⬇     16.6x        0.78x
# async | main: fixed, rules: fixed               20    10/10   6.105   ⬇    9.947x     0.44735x
# async | main: fixed, rules: fixed (x2)          30    10/20   3.059   ⬇   19.856x     0.62853x
# async | main: fixed (x2), rules: fixed (x2)     40    20/20   3.081   ⬇   19.709x     0.46773x
# async | main: fixed, rules: io                  50    10/40   1.575   ⬇   38.547x     0.75094x
# async | main: fixed (x2), rules: io            100    20/80   0.993   ⬇   61.147x     0.60147x
# async | main: io, rules: nil                    50    50/0    1.235   ⬇   49.156x     0.96312x
# async | main: io, rules: fixed                  60    50/10   6.116   ⬇     9.93x     0.14883x
# async | main: io, rules: io                    250    50/200  0.371   ⬇   163.75x       0.651x
#
# ===============================================================================================
#
#                                       [ CHECKS: 100 ]
# time stats:
#                                                   user     system      total        real
# sync                                          0.055339   0.008615   0.063954 (121.464142)
# async | main: fixed, rules: nil               0.028633   0.010361   0.038994 ( 12.177779)
# async | main: fixed (x2), rules: nil          0.037569   0.010526   0.048095 (  6.106619)
# async | main: fixed, rules: fixed             0.105311   0.018323   0.123634 ( 12.197988)
# async | main: fixed, rules: fixed (x2)        0.096907   0.013051   0.109958 (  6.114231)
# async | main: fixed (x2), rules: fixed (x2)   0.105981   0.014082   0.120063 (  6.104263)
# async | main: fixed, rules: io                0.082036   0.018177   0.100213 (  3.107185)
# async | main: fixed (x2), rules: io           0.112657   0.025035   0.137692 (  1.648126)
# async | main: io, rules: nil                  0.050145   0.017948   0.068093 (  1.256689)
# async | main: io, rules: fixed                0.086865   0.032995   0.119860 ( 12.211977)
# async | main: io, rules: io                   0.087008   0.049833   0.136841 (  0.425713)
#
#
# thread stats:
#                                              total  per pool     time  +/-      diff  diff/thread
# sync                                             1     -/-    121.464            -/-          -/-
# async | main: fixed, rules: nil                 10    10/0     12.178   ⬇     9.974x      0.8974x
# async | main: fixed (x2), rules: nil            20    20/0      6.107   ⬇    19.891x     0.94455x
# async | main: fixed, rules: fixed               20    10/10    12.198   ⬇     9.958x      0.4479x
# async | main: fixed, rules: fixed (x2)          30    10/20     6.114   ⬇    19.866x     0.62887x
# async | main: fixed (x2), rules: fixed (x2)     40    20/20     6.104   ⬇    19.898x     0.47245x
# async | main: fixed, rules: io                  50    10/40     3.107   ⬇    39.091x     0.76182x
# async | main: fixed (x2), rules: io            100    20/80     1.648   ⬇    73.698x     0.72698x
# async | main: io, rules: nil                   100   100/0      1.257   ⬇    96.654x     0.95654x
# async | main: io, rules: fixed                 110   100/10    12.212   ⬇     9.946x     0.08133x
# async | main: io, rules: io                    500   100/400    0.426   ⬇   285.319x     0.56864x
#
# ==================================================================================================
#
#                                       [ CHECKS: 200 ]
# time stats:
#                                                   user     system      total        real
# sync                                          0.141575   0.016051   0.157626 (243.061935)
# async | main: fixed, rules: nil               0.047256   0.020366   0.067622 ( 24.305634)
# async | main: fixed (x2), rules: nil          0.071847   0.019492   0.091339 ( 12.183187)
# async | main: fixed, rules: fixed             0.240031   0.028739   0.268770 ( 24.320212)
# async | main: fixed, rules: fixed (x2)        0.201068   0.028274   0.229342 ( 12.187651)
# async | main: fixed (x2), rules: fixed (x2)   0.167911   0.030028   0.197939 ( 12.196199)
# async | main: fixed, rules: io                0.138820   0.038072   0.176892 (  6.252542)
# async | main: fixed (x2), rules: io           0.106197   0.039303   0.145500 (  3.171551)
# async | main: io, rules: nil                  0.046821   0.044440   0.091261 (  1.261595)
# async | main: io, rules: fixed                0.152188   0.075875   0.228063 ( 24.370940)
# async | main: io, rules: io                   0.125763   0.186338   0.312101 (  0.492362)
#
#
# thread stats:
#                                              total  per pool     time  +/-      diff  diff/thread
# sync                                             1     -/-    243.062            -/-          -/-
# async | main: fixed, rules: nil                 10    10/0     24.306   ⬇      10.0x         0.9x
# async | main: fixed (x2), rules: nil            20    20/0     12.183   ⬇    19.951x     0.94755x
# async | main: fixed, rules: fixed               20    10/10     24.32   ⬇     9.994x      0.4497x
# async | main: fixed, rules: fixed (x2)          30    10/20    12.188   ⬇    19.943x     0.63143x
# async | main: fixed (x2), rules: fixed (x2)     40    20/20    12.196   ⬇    19.929x     0.47322x
# async | main: fixed, rules: io                  50    10/40     6.253   ⬇    38.874x     0.75748x
# async | main: fixed (x2), rules: io            100    20/80     3.172   ⬇    76.638x     0.75638x
# async | main: io, rules: nil                   200   200/0      1.262   ⬇   192.662x     0.95831x
# async | main: io, rules: fixed                 210   200/10    24.371   ⬇     9.973x     0.04273x
# async | main: io, rules: io                   1000   200/800    0.492   ⬇   493.665x     0.49267x
#
# ==================================================================================================
