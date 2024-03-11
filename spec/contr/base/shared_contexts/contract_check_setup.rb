# frozen_string_literal: true

RSpec.shared_context "contract check setup" do
  before :all do
    Timecop.freeze(Time.utc(1999))
    @dump_folder = "/tmp/contract_tests/#{SecureRandom.uuid}"
    @dump_period_id = "1525248"
  end

  after :all do
    Timecop.return
  end

  after do
    FileUtils.rm_rf(@dump_folder)
  end

  before do
    # fixes visibility in block passed to `define_contract_class`
    dump_folder = @dump_folder

    define_contract_class("PreConfiguredContract") do
      logger Contr::Logger::Default.new(stream: IO::NULL)
      sampler Contr::Sampler::Default.new(folder: dump_folder)
    end
  end

  let(:contract)         { Object.const_get(contract_name).new }
  let(:operation)        { proc { 1 + 1 } }
  let(:operation_result) { 2 }
  let(:args)             { [1, 2, 3] }

  let(:dump_info) { {path: "#{@dump_folder}/#{contract_name}/#{@dump_period_id}.dump"} }
  let(:log_state) { state.merge(dump_info: dump_info) }

  def expect_log_with(*args)
    expect(contract.logger).to receive(:log).with(*args).once.and_call_original
  end

  def expect_sample_with(*args)
    expect(contract.sampler).to receive(:sample!).with(*args).once.and_call_original
  end

  def not_expect_log
    expect(contract.logger).not_to receive(:log)
  end

  def not_expect_sample
    expect(contract.sampler).not_to receive(:sample!)
  end
end
