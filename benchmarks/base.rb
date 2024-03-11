# frozen_string_literal: true

# Operation result return time is static per mode:
# - sync:  operation time + rules time + sampler (optional) + logger (optional)
# - async: operation time (~ ASAP)

# load gem from source
# $: << File.expand_path("../../lib", __FILE__)

require "contr"
require "benchmark"

class Contract < Contr::Act
  sampler nil # do not rely on filesystem "consistency"

  guarantee :g1 do |(task), _result|
    task.call
    true
  end

  guarantee :g2 do |(task), _result|
    task.call
    true
  end

  expect :e1 do |(task), _result|
    task.call
    false
  end

  expect :e2 do |(task), _result|
    task.call
    false # make contract fail to trigger logger
  end
end

# logger is the last checking point in a failed contract
# so it can be used to track the end of a contract
class FakeLogger < Contr::Logger::Base
  def initialize(latch)
    @latch = latch
  end

  def log(_state)
    @latch.count_down
  end
end

class TrackableIO < Contr::Async::Pool::Base
  def create_executor
    Concurrent::ThreadPoolExecutor.new
  end
end

class Base
  def initialize(task:, checks:, operation: -> { 1 + 1 })
    @task = task
    @checks = checks
    @operation = operation

    @cpu_cores = Concurrent.processor_count
    @thread_stats = {}
  end

  def run!
    puts "time stats:"

    Benchmark.bm(43) do |bm|
      report(bm, "sync") do
        sync
      end

      report(bm, "async | main: fixed, rules: nil") do
        async(
          main: Contr::Async::Pool::Fixed.new,
          rules: nil
        )
      end

      report(bm, "async | main: fixed (x2), rules: nil") do
        async(
          main: Contr::Async::Pool::Fixed.new(max_threads: @cpu_cores * 2),
          rules: nil
        )
      end

      report(bm, "async | main: fixed, rules: fixed") do
        async(
          main: Contr::Async::Pool::Fixed.new,
          rules: Contr::Async::Pool::Fixed.new
        )
      end

      report(bm, "async | main: fixed, rules: fixed (x2)") do
        async(
          main: Contr::Async::Pool::Fixed.new,
          rules: Contr::Async::Pool::Fixed.new(max_threads: @cpu_cores * 2)
        )
      end

      report(bm, "async | main: fixed (x2), rules: fixed (x2)") do
        async(
          main: Contr::Async::Pool::Fixed.new(max_threads: @cpu_cores * 2),
          rules: Contr::Async::Pool::Fixed.new(max_threads: @cpu_cores * 2)
        )
      end

      report(bm, "async | main: fixed, rules: io") do
        async(
          main: Contr::Async::Pool::Fixed.new,
          rules: TrackableIO.new
        )
      end

      report(bm, "async | main: fixed (x2), rules: io") do
        async(
          main: Contr::Async::Pool::Fixed.new(max_threads: @cpu_cores * 2),
          rules: TrackableIO.new
        )
      end

      report(bm, "async | main: io, rules: nil") do
        async(
          main: TrackableIO.new,
          rules: nil
        )
      end

      report(bm, "async | main: io, rules: fixed") do
        async(
          main: TrackableIO.new,
          rules: Contr::Async::Pool::Fixed.new
        )
      end

      report(bm, "async | main: io, rules: io") do
        async(
          main: TrackableIO.new,
          rules: TrackableIO.new
        )
      end
    end

    print_thread_stats!
  end

  private

  def report(bm, label)
    contract = nil
    time_stats = bm.report(label) { contract = yield }

    calc_thread_stats(label, time_stats, contract)
  end

  def sync
    contract = Contract.new(logger: nil)

    @checks.times do
      contract.check(@task) { @operation.call }
    rescue Contr::Matcher::ExpectationsNotMatched
      # exception can be ignored here
    end

    contract
  end

  def async(pools)
    latch = Concurrent::CountDownLatch.new(@checks)
    contract = Contract.new(async: {pools: pools}, logger: FakeLogger.new(latch))

    @checks.times do
      contract.check_async(@task) { @operation.call }
    end

    latch.wait

    contract
  end

  def calc_thread_stats(label, time_stats, contract)
    base = @thread_stats["sync"]

    threads_main  = contract.main_pool.executor.largest_length if base
    threads_rules = contract.rules_pool&.executor&.largest_length || 0 if base
    threads_total = base ? threads_main + threads_rules : 1

    change, time_diff = if base
      base_time_real = base[:time_real]

      if base_time_real > time_stats.real
        [:decr, (base_time_real / time_stats.real).round(3)]
      elsif base_time_real == time_stats.real
        [:eq, 1.0]
      else
        [:incr, (time_stats.real / base_time_real).round(3)]
      end
    end

    time_diff_per_thread = if base
      ((time_diff - 1) / threads_total).round(5)
    end

    @thread_stats[label] = {
      threads_main: threads_main,
      threads_rules: threads_rules,
      threads_total: threads_total,
      time_real: time_stats.real,
      change: change,
      time_diff: time_diff,
      time_diff_per_thread: time_diff_per_thread
    }
  end

  def print_thread_stats!
    headers = {
      label:                "",
      threads:              "total",
      threads_per_pool:     "per pool",
      time:                 "time",
      change:               "+/-",
      time_diff:            "diff",
      time_diff_per_thread: "diff/thread"
    }

    rows = @thread_stats.map do |label, data|
      threads_main  = data[:threads_main]  || "-"
      threads_rules = data[:threads_rules] || "-"

      threads_per_pool     = "#{threads_main.to_s.rjust(3)}/#{threads_rules.to_s.ljust(3)}"
      change               = data[:change] ? format_change(data[:change]) : ""
      time_diff            = data[:time_diff] ? "#{data[:time_diff]}x" : "-/-"
      time_diff_per_thread = data[:time_diff_per_thread] ? "#{data[:time_diff_per_thread]}x" : "-/-"

      {
        label:                label,
        threads:              data[:threads_total].to_s,
        threads_per_pool:     threads_per_pool,
        time:                 data[:time_real].round(3).to_s,
        change:               change,
        time_diff:            time_diff,
        time_diff_per_thread: time_diff_per_thread
      }
    end

    offsets = headers.each_with_object({}) do |(key, header), memo|
      offset = [header.size, *rows.map { |data| data[key].size }].max
      memo[key] = offset
    end

    headers_string = headers.map { |key, header| header.rjust(offsets[key]) }.join("  ")

    rows_strings = rows.map do |row|
      [
        row[:label].ljust(offsets[:label]),
        row[:threads].rjust(offsets[:threads]),
        row[:threads_per_pool].rjust(offsets[:threads_per_pool]),
        row[:time].rjust(offsets[:time]),
        row[:change].ljust(2).rjust(offsets[:change]),
        row[:time_diff].rjust(offsets[:time_diff]),
        row[:time_diff_per_thread].rjust(offsets[:time_diff_per_thread])
      ].join("  ")
    end

    puts "\n\nthread stats:"
    puts headers_string
    puts rows_strings.join("\n")
  end

  def format_change(change)
    case change
    when :decr then "⬇"
    when :eq   then "="
    when :incr then "⬆"
    end
  end
end
