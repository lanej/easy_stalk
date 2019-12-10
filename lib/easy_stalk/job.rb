# frozen_string_literal: true

module EasyStalk
  class Job
    extend DescendantsTracker
    include Interactor

    SECONDS_IN_DAY = 24 * 60 * 60

    def self.inherited(klass)
      super
      klass.serializable_context_keys = serializable_context_keys || []
    end

    def self.tube_name(tube = nil)
      if tube
        @tube_name = tube
      else
        tube_prefix + (@tube_name || name.split('::').last)
      end
    end

    def self.tube_prefix(prefix = nil)
      if prefix
        @tube_prefix = prefix
      else
        @tube_prefix || EasyStalk.configuration.default_tube_prefix
      end
    end

    def self.priority(pri = nil)
      # integer < 2**32. 0 is highest
      if pri
        @priority = pri
      else
        @priority || EasyStalk.configuration.default_priority
      end
    end

    def self.time_to_run(seconds = nil)
      # integer seconds to run this job
      if seconds
        @time_to_run = seconds
      else
        @time_to_run || EasyStalk.configuration.default_time_to_run
      end
    end

    def self.delay(seconds = nil)
      # integer seconds before job is in ready queue
      if seconds
        @delay = seconds
      else
        @delay || EasyStalk.configuration.default_delay
      end
    end

    def self.retry_times(attempts = nil)
      # max number of times to retry job before burying
      if attempts
        @retry_times = attempts
      else
        @retry_times || EasyStalk.configuration.default_retry_times
      end
    end

    class << self
      def serializable_context_keys(*keys)
        @serializable_context_keys ||= [] if keys.empty?

        @serializable_context_keys |= keys
      end

      protected

      attr_writer :serializable_context_keys
    end

    def enqueue(
      beanstalk_connection,
      priority: nil,
      time_to_run: nil,
      delay: nil,
      delay_until: nil,
      tube_name: nil
    )
      tube = beanstalk_connection.tubes[tube_name || self.class.tube_name]
      pri = priority || self.class.priority
      ttr = time_to_run || self.class.time_to_run
      delay ||= self.class.delay

      if delay_until && Time === delay_until
        days = delay_until - Time.now
        delay = (days * SECONDS_IN_DAY).to_i
      end

      tube.put job_data, pri: pri, ttr: ttr, delay: [delay, 0].max
    end

    def job_data
      data = context.to_h.select { |key, _value| self.class.serializable_context_keys.include? key }
      JSON.dump(data)
    end

    def call
      raise NotImplementedError
    end
  end
end
