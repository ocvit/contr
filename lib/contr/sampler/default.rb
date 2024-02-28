# frozen_string_literal: true

module Contr
  class Sampler
    class Default < Sampler::Base
      DEFAULT_FOLDER        = "/tmp/contracts"
      DEFAULT_PATH_TEMPLATE = "%<contract_name>s/%<period_id>i.dump"
      DEFAULT_PERIOD        = 10 * 60 # 10 minutes

      attr_reader :folder, :path_template, :period

      def initialize(folder: DEFAULT_FOLDER, path_template: DEFAULT_PATH_TEMPLATE, period: DEFAULT_PERIOD)
        @folder = folder
        @path_template = path_template
        @period = period
      end

      def sample!(state)
        path = dump_path(state[:contract_name])
        return if dump_present?(path)

        dump = Marshal.dump(state)

        save_dump(dump, path)
        create_dump_info(path)
      end

      def read(path: nil, contract_name: nil, period_id: nil)
        path ||= dump_path(contract_name, period_id)

        dump = File.read(path)
        Marshal.load(dump)
      end

      private

      def dump_path(contract_name, period_id = current_period_id)
        raise ArgumentError, "`contract_name` should be defined" unless contract_name
        raise ArgumentError, "`period_id` should be defined"     unless period_id

        file_path = @path_template % {
          contract_name: contract_name,
          period_id:     period_id
        }

        File.join(@folder, file_path)
      end

      def save_dump(dump, path)
        init_dump_folder!(path)
        File.write(path, dump)
      end

      def create_dump_info(path)
        {path: path}
      end

      def dump_present?(path)
        File.exist?(path)
      end

      def current_period_id
        Time.now.to_i / @period
      end

      def init_dump_folder!(path)
        dump_folder = File.dirname(path)
        FileUtils.mkdir_p(dump_folder)
      end
    end
  end
end
