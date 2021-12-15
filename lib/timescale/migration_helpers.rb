require 'active_record/connection_adapters/postgresql_adapter'

# Useful methods to run TimescaleDB in you Ruby app.
module Timescale
  # Migration helpers can help you to setup hypertables by default.
  module MigrationHelpers
    # create_table can receive `hypertable` argument
    # @example
    #  options = {
    #    time_column: 'created_at',
    #    chunk_time_interval: '1 min',
    #    compress_segmentby: 'identifier',
    #    compress_orderby: 'created_at',
    #    compression_interval: '7 days'
    #  }
    #
    #  create_table(:events, id: false, hypertable: options) do |t|
    #    t.string :identifier, null: false
    #    t.jsonb :payload
    #    t.timestamps
    #  end
    def create_table(table_name, id: :primary_key, primary_key: nil, force: nil, **options)
      super
      create_hypertable(table_name, **options[:hypertable]) if options.key?(:hypertable)
    end

    # Setup hypertable from options
    # @see create_table with the hypertable options.
    def create_hypertable(table_name,
                                 time_column: 'created_at',
                                 chunk_time_interval: '1 week',
                                 compress_segmentby: nil,
                                 compress_orderby: 'created_at',
                                 compression_interval: nil
                                )

      ActiveRecord::Base.logger = Logger.new(STDOUT)
      execute "SELECT create_hypertable('#{table_name}', '#{time_column}', chunk_time_interval => INTERVAL '#{chunk_time_interval}')"

      if compress_segmentby
        execute <<~SQL
        ALTER TABLE #{table_name} SET (
          timescaledb.compress,
          timescaledb.compress_orderby = '#{compress_orderby}',
          timescaledb.compress_segmentby = '#{compress_segmentby}'
        )
        SQL
      end
      if compression_interval
        execute "SELECT add_compression_policy('#{table_name}', INTERVAL '#{compression_interval}')"
      end
    end

    # Create a new continuous aggregate
    #
    # @param name [String, Symbol] The name of the continuous aggregate.
    # @param query [String] The SQL query for the aggregate view definition.
    # @param with_data [Boolean] Set to true to create the aggregate WITH DATA
    # @param refresh_policies [Hash] Set to create a refresh policy
    # @option refresh_policies [String] start_offset: INTERVAL or integer
    # @option refresh_policies [String] end_offset: INTERVAL or integer
    # @option refresh_policies [String] schedule_interval: INTERVAL
    #
    # @see https://docs.timescale.com/api/latest/continuous-aggregates/add_continuous_aggregate_policy/
    #
    # @example
    #   create_continuous_aggregate(:activity_counts, query: <<-SQL, refresh_policies: { schedule_interval: "INTERVAL '1 hour'" })
    #     SELECT
    #       time_bucket(INTERVAL '1 day', activity.created_at) AS bucket,
    #       count(*)
    #     FROM activity
    #     GROUP BY bucket
    #   SQL
    #
    def create_continuous_aggregate(name, query, **options)
      execute <<~SQL
        CREATE MATERIALIZED VIEW #{name}
        WITH (timescaledb.continuous) AS
        #{query.respond_to?(:to_sql) ? query.to_sql : query}
        WITH #{"NO" unless options[:with_data]} DATA;
      SQL

      if (policy = options[:refresh_policies])
        # TODO: assert valid keys
        execute <<~SQL
          SELECT add_continuous_aggregate_policy('#{name}',
            start_offset => #{policy[:start_offset]},
            end_offset => #{policy[:end_offset]},
            schedule_interval => #{policy[:schedule_interval]});
        SQL
      end
    end
    alias_method :create_continuous_aggregates, :create_continuous_aggregate

    def create_retention_policy(table_name, interval:)
      execute "SELECT add_retention_policy('#{table_name}', INTERVAL '#{interval}')"
    end

    def remove_retention_policy(table_name)
      execute "SELECT remove_retention_policy('#{table_name}')"
    end
  end
end

ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.include(Timescale::MigrationHelpers)
