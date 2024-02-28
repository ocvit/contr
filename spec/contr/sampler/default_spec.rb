# frozen_string_literal: true

require "securerandom"
require "timecop"

RSpec.describe Contr::Sampler::Default do
  include ClassHelpers
  include FileHelpers

  before :all do
    @dump_folder = "/tmp/contract_tests/#{SecureRandom.uuid}"
  end

  after do
    FileUtils.rm_rf(@dump_folder)
  end

  describe ".new" do
    context "with default setup" do
      subject(:sampler) { described_class.new }

      it "has correct attributes" do
        expect(sampler).to have_attributes(
          folder: "/tmp/contracts",
          path_template: "%<contract_name>s/%<period_id>i.dump",
          period: 600
        )
      end
    end

    context "with custom setup" do
      subject(:sampler) do
        described_class.new(
          folder: "/tmp/other",
          path_template: "%<contract_name>s_<period_id>i.bin",
          period: 9000
        )
      end

      it "has correct attributes" do
        expect(sampler).to have_attributes(
          folder: "/tmp/other",
          path_template: "%<contract_name>s_<period_id>i.bin",
          period: 9000
        )
      end
    end
  end

  describe "#sample!" do
    let(:sampler) { described_class.new(folder: @dump_folder) }
    let(:state) { {contract_name: "SomeContract"} }

    subject(:dump_info) { sampler.sample!(state) }

    context "when dump does not exist" do
      before :all do
        Timecop.freeze(Time.utc(1999))
      end

      after :all do
        Timecop.return
      end

      context "with default path template and period" do
        it "saves dump to correct destination and returns dump info" do
          dump_path = "#{@dump_folder}/SomeContract/1525248.dump"

          expect(dump_info).to eq({path: dump_path})
          expect(File.exist?(dump_path)).to eq true
        end
      end

      context "with non-default path template" do
        let(:sampler) { described_class.new(folder: @dump_folder, path_template: "%<contract_name>s_%<period_id>i.dump") }

        it "saves dump to correct destination and returns dump info" do
          dump_path = "#{@dump_folder}/SomeContract_1525248.dump"

          expect(dump_info).to eq({path: dump_path})
          expect(File.exist?(dump_path)).to eq true
        end
      end

      context "with non-default period" do
        let(:sampler) { described_class.new(folder: @dump_folder, period: 3600) }

        it "saves dump to correct destination and returns dump info" do
          dump_path = "#{@dump_folder}/SomeContract/254208.dump"

          expect(dump_info).to eq({path: dump_path})
          expect(File.exist?(dump_path)).to eq true
        end
      end
    end

    context "when dump exists" do
      before do
        @contract_folder = "#{@dump_folder}/SomeContract"
        @dump_path = "#{@contract_folder}/1525248.dump"

        create_empty_file(@dump_path)
        @original_dump_timestamps = read_file_timestamps(@dump_path)
      end

      it "does not override it, does not save another dump and returns nil" do
        Timecop.freeze(Time.utc(1999)) do
          expect(dump_info).to eq nil
        end

        current_dump_timestamps = read_file_timestamps(@dump_path)
        contract_dumps = list_folder_entries(@contract_folder)

        expect(current_dump_timestamps).to eq @original_dump_timestamps
        expect(contract_dumps).to eq [@dump_path]
      end
    end
  end

  describe "#read" do
    before :all do
      Timecop.freeze(Time.utc(1999))
      @dump_path = "#{@dump_folder}/SomeContract/1525248.dump"
    end

    after :all do
      Timecop.return
    end

    let(:sampler) { described_class.new(folder: @dump_folder) }
    let(:state) do
      {
        ts:            "1999-01-01T00:00:00.000Z",
        contract_name: "SomeContract",
        failed_rules: [
          {type: :expectation, name: :e1, status: :unexpected_error, error: StandardError.new("some error")},
          {type: :expectation, name: :e2, status: :failed}
        ],
        ok_rules: [
          {type: :guarantee, name: :g1, status: :ok},
          {type: :guarantee, name: :g2, status: :ok}
        ],
        async:      false,
        input_args: [1, 2, 3],
        output:     2
      }
    end

    context "when path provided explicitly" do
      before do
        create_file(@dump_path, Marshal.dump(state))
      end

      subject(:read_dump) { sampler.read(path: @dump_path) }

      it "returns decoded dump" do
        expect(read_dump).to eq state
      end
    end

    context "when path components provided" do
      before do
        create_file(@dump_path, Marshal.dump(state))
      end

      subject(:read_dump) { sampler.read(contract_name: "SomeContract", period_id: "1525248") }

      it "returns decoded dump" do
        expect(read_dump).to eq state
      end
    end

    context "when `contract_name` path component is not defined" do
      subject(:read_dump) { sampler.read(contract_name: nil, period_id: 1234) }

      it "raises an error" do
        expect { read_dump }.to raise_error(ArgumentError, "`contract_name` should be defined")
      end
    end

    context "when `period_id` path component is not defined" do
      subject(:read_dump) { sampler.read(contract_name: "SomeContract", period_id: nil) }

      it "raises an error" do
        expect { read_dump }.to raise_error(ArgumentError, "`period_id` should be defined")
      end
    end
  end
end
