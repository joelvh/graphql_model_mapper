module GraphqlModelMapper
    def self.Schema(log_query_depth: false, log_query_complexity: false, use_backtrace: false, use_authorize: false)

      return GraphqlModelMapper.get_constant("GraphqlModelMapperSchema".upcase) if GraphqlModelMapper.defined_constant?("GraphqlModelMapperSchema".upcase)
      GraphqlModelMapper.use_authorize = use_authorize
      if GraphqlModelMapper.use_authorize
        metadata_definitions = {
          authorized: ->(field, authorized_proc) { field.metadata[:authorized_proc] = authorized_proc },
          model_name: GraphQL::Define.assign_metadata_key(:model_name),
          access_type: GraphQL::Define.assign_metadata_key(:access_type)
        }
        GraphQL::Field.accepts_definitions(metadata_definitions)
        GraphQL::Argument.accepts_definitions(metadata_definitions)
      end

      schema = GraphQL::Schema.define do
        use GraphQL::Backtrace if use_backtrace
        default_max_page_size 100
        mutation GraphqlModelMapper.MutationType
        query GraphqlModelMapper.QueryType
      end

     
      schema.query_analyzers << GraphQL::Analysis::QueryDepth.new { |query, depth| Rails.logger.info("[******GraphqlModelMapper Query Depth] #{depth}") } if log_query_depth
      schema.query_analyzers << GraphQL::Analysis::QueryComplexity.new { |query, complexity| Rails.logger.info("[******GraphqlModelMapper Query Complexity] #{complexity}")} if log_query_complexity

      GraphqlModelMapper.set_constant("GraphqlModelMapperSchema".upcase, schema)

    end


    def self.QueryType
      return GraphQL::ObjectType.define do
        name 'Query'
        # create queries for each AR model object
        field :welcomeQuery, types.String, hash_key: :welcomeMutation do
          resolve -> (obj, args, ctx){
            {
              welcomeQuery: "this is a placeholder mutation in case you do not have access to other queries"
            }
          }
        end
        GraphqlModelMapper.schema_queries.each do |f|
          field f[:name], f[:field]  do
            if GraphqlModelMapper.use_authorize
              authorized ->(ctx, model_name, access_type) { GraphqlModelMapper.authorized?(ctx, model_name, access_type.to_sym) }
              model_name f[:model_name]
              access_type f[:access_type].to_s
            end
          end   
        end
      end
    end

    def self.MutationType
      return GraphQL::ObjectType.define do
        name 'Mutation'
      
        field :welcomeMutation, types.String, hash_key: :welcomeMutation do
          resolve -> (obj, args, ctx){
            {
              welcomeMutation: "this is a placeholder mutation in case you do not have access to other mutations"
            }
          }
        end
    
        GraphqlModelMapper.schema_mutations.each do |f|
          field f[:name], f[:field]  do
            if GraphqlModelMapper.use_authorize
              authorized ->(ctx, model_name, access_type) { GraphqlModelMapper.authorized?(ctx, model_name, access_type.to_sym) }
              model_name  f[:model_name]
              access_type f[:access_type].to_s
            end
          end
        end   
      end
    end
  end

  GraphqlModelMapper::GEOMETRY_TYPE = GraphQL::ScalarType.define do
    name "Geometry"
    description "The Geometry scalar type enables the serialization of Geometry data"
  
    coerce_input ->(value, ctx) do
        begin
            value.nil? ? nil : GeoRuby::SimpleFeatures::Geometry.from_geojson(value)
        rescue ArgumentError
            raise GraphQL::CoercionError, "cannot coerce `#{value.inspect}` to json"
        end
    end
    coerce_result ->(value, ctx) { value.nil? ? "" : value.to_json }
  end
  
  GraphqlModelMapper::DATE_TYPE = GraphQL::ScalarType.define do
    name "Date"
    description "The Date scalar type enables the serialization of date data to/from iso8601"
  
    coerce_input ->(value, ctx) do
        begin
            value.nil? ? nil :  Date.iso8601(value)
        rescue ArgumentError
            raise GraphQL::CoercionError, "cannot coerce `#{value.inspect}` to date"
        end
    end
    coerce_result ->(value, ctx) { value.nil? ? nil : value.iso8601 }
  end
  