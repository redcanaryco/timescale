# frozen_string_literal: true

module Timescale
  # If you want your model to hook into its underlying hypertable
  # as well as have access to TimescaleDB specific data, methods, and more,
  # specify this macro in your model.
  #
  # @note Your model's table needs to have already been converted to a hypertable
  # via the TimescaleDB `create_hypertable` function for this to work.
  #
  # @see https://docs.timescale.com/api/latest/hypertable/create_hypertable/ for
  #   how to use the SQL `create_hypertable` function.
  # @see Timescale::MigrationHelpers#create_table for how to create a new hypertable
  # via a Rails migration utilizing the standard `create_table` method.
  #
  # @example Enabling the macro on your model
  #   class Event < ActiveRecord::Base
  #     acts_as_hypertable
  #   end
  #
  # @see Timescale::ActsAsHypertable#acts_as_hypertable
  #   for configuration options
  module ActsAsHypertable
    DEFAULT_OPTIONS = {
      time_column: :created_at
    }.freeze

    def acts_as_hypertable?
      included_modules.include?(Timescale::ActsAsHypertable::Core)
    end

    # == Configuration options
    #
    # @param [Hash] options The options to initialize your macro with.
    # @option options [Symbol] :time_column The name of the column in your
    #   model's table containing time values. The name provided should be
    #   the same name as the `time_column_name` you passed to the
    #   TimescaleDB `create_hypertable` function.
    #
    # @example Enabling the macro on your model with options
    #   class Event < ActiveRecord::Base
    #     acts_as_hypertable time_column: :timestamp
    #   end
    #
    def acts_as_hypertable(options = {})
      return if acts_as_hypertable?

      include Timescale::ActsAsHypertable::Core

      class_attribute :hypertable_options, instance_writer: false

      self.hypertable_options = DEFAULT_OPTIONS.dup
      hypertable_options.merge!(options)
      normalize_hypertable_options

      define_association_scopes
      define_default_scopes
    end
  end
end

ActiveRecord::Base.extend Timescale::ActsAsHypertable
