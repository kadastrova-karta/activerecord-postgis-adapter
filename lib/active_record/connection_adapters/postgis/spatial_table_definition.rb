# frozen_string_literal: true

module ActiveRecord  # :nodoc:
  module ConnectionAdapters  # :nodoc:
    module PostGIS  # :nodoc:
      class TableDefinition < PostgreSQL::TableDefinition  # :nodoc:
        include ColumnMethods

        # super: https://github.com/rails/rails/blob/master/activerecord/lib/active_record/connection_adapters/abstract/schema_definitions.rb
        def new_column_definition(name, type, **options)
          col_type = if type.to_sym == :virtual
            options[:type]
          else
            type
          end

          if (info = PostGISAdapter.spatial_column_options(col_type))
            if (limit = options.delete(:limit)) && limit.is_a?(::Hash)
              options.merge!(limit)
            end

            geo_type = ColumnDefinitionUtils.geo_type(options[:type] || type || info[:type])
            base_type = info[:type] || (options[:geographic] ? :geography : :geometry)

            options[:limit] = ColumnDefinitionUtils.limit_from_options(geo_type, options)
            options[:spatial_type] = geo_type
            column = super(name, base_type, **options)
          else
            column = super(name, type, **options)
          end

          column
        end

        private

        def valid_column_definition_options
          super + [:geographic, :srid, :spatial_type, :has_m, :has_z]
        end
      end

      module ColumnDefinitionUtils
        class << self
          def geo_type(type = "GEOMETRY")
            g_type = type.to_s.delete("_").upcase
            return "POINT" if g_type == "STPOINT"
            return "POLYGON" if g_type == "STPOLYGON"
            g_type
          end

          def limit_from_options(type, options = {})
            spatial_type = geo_type(type)
            spatial_type << "Z" if options[:has_z]
            spatial_type << "M" if options[:has_m]
            spatial_type << ",#{options[:srid] || default_srid(options)}"
            spatial_type
          end

          def default_srid(options)
            options[:geographic] ? 4326 : PostGISAdapter::DEFAULT_SRID
          end
        end
      end
    end
  end
end
