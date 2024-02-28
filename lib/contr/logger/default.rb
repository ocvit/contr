# frozen_string_literal: true

require "json"
require "logger"

module Contr
  class Logger
    class Default < Logger::Base
      DEFAULT_STREAM    = $stdout
      DEFAULT_LOG_LEVEL = :debug
      DEFAULT_TAG       = "contract-failed"

      attr_reader :stream, :stream_logger, :log_level, :tag

      def initialize(stream: DEFAULT_STREAM, log_level: DEFAULT_LOG_LEVEL, tag: DEFAULT_TAG)
        @stream = stream
        @stream_logger = ::Logger.new(stream)
        @log_level = log_level
        @tag = tag
      end

      def log(state)
        message = state.merge(tag: tag).to_json

        stream_logger.send(log_level, message)
      end
    end
  end
end
