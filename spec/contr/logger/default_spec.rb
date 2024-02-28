# frozen_string_literal: true

RSpec.describe Contr::Logger::Default do
  describe ".new" do
    let(:stream_logger_set_stream) { logger.stream_logger.instance_variable_get(:@logdev).dev }

    context "with default setup" do
      subject(:logger) { described_class.new }

      it "has correct attributes" do
        expect(logger).to have_attributes(
          stream_logger: be_instance_of(::Logger),
          stream: $stdout,
          log_level: :debug,
          tag: "contract-failed"
        )

        expect(stream_logger_set_stream).to eq $stdout
      end
    end

    context "with custom setup" do
      subject(:logger) { described_class.new(stream: $stderr, log_level: :warn, tag: "other-tag") }

      it "has correct attributes" do
        expect(logger).to have_attributes(
          stream_logger: be_instance_of(::Logger),
          stream: $stderr,
          log_level: :warn,
          tag: "other-tag"
        )

        expect(stream_logger_set_stream).to eq $stderr
      end
    end
  end

  describe "#log" do
    let(:logger) { described_class.new(stream: IO::NULL) }
    let(:state) { {contract_name: "SomeContract"} }

    subject(:log) { logger.log(state) }

    it "logs correct message" do
      expect(logger.stream_logger)
        .to receive(:debug)
        .with("{\"contract_name\":\"SomeContract\",\"tag\":\"contract-failed\"}")
        .once
        .and_call_original

      log
    end
  end
end
