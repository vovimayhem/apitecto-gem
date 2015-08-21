require "apitecto/version"
require "matter_compiler/blueprint"
require "rspec"

module Apitecto
  mattr_reader    :blueprints, :lines_of_spec
  mattr_accessor  :output_dir

  def self.blueprints; @@blueprints ||= {}; end
  def self.blueprint_exists?(blueprint_name); blueprints.has_key?(blueprint_name); end


  def self.lines_of_spec; @@lines_of_spec ||= {}; end
  def self.get_lines_of_spec(spec_file_path)
    unless lines_of_spec[spec_file_path].present?
      lines_of_spec[spec_file_path] = File.read(spec_file_path).each_line.to_a.map(&:strip).inject({}) do |lines, line|
        lines[lines.values.count + 1] = (line =~ /\A#/i || line == "") ? (line == "" ? "" : line[1..-1]) : nil
        lines
      end
    end
    lines_of_spec[spec_file_path]
  end
end

# TODO: This is a BIG, NASTY chunk of code we really need to split out...
RSpec.configure do |config|

  config.before(:suite) do
    Apitecto.output_dir = File.join((defined?(Rails) ? Rails.root : File.expand_path('.')), 'doc')
  end

  # Formar el AST de Blueprint a partir de los examples de request...
  config.after(:each, type: :request) do |rspec_example|

    if rspec_example.metadata[:rest_api_name].present?

      ################################################################################################
      #
      lines_of_spec = Apitecto.get_lines_of_spec rspec_example.metadata[:file_path]

      ##############################################################################
      # Find or create the Root AST node:
      rest_api_name = rspec_example.metadata[:rest_api_name] || :default
      rest_api_key = rest_api_name.to_s.downcase.split.join("-").dasherize

      blueprint_ast = if Apitecto.blueprint_exists? rest_api_key
        Apitecto.blueprints[rest_api_key]
      else
        Apitecto.blueprints[rest_api_key] = { name: rest_api_name, description: nil, resourceGroups: [] }
      end

      blueprint_ast[:description] = blueprint_ast[:description] || rspec_example.metadata[:rest_api_description]

      ##############################################################################################
      # Find the rspec_example's Example Groups metadata mappable to
      # API Blueprint's Resource Group, Resource and Action:
      rspec_action_metadata         = rspec_example.metadata[:example_group]
      rspec_resource_metadata       = rspec_action_metadata[:parent_example_group]
      rspec_resource_group_metadata = rspec_resource_metadata[:parent_example_group]

      ##############################################################################################
      # Retrieve or form the resource group AST:

      # ...find:
      resource_group_ast = blueprint_ast[:resourceGroups].detect do |resource_group|
        resource_group[:rspec_file_path] == rspec_resource_group_metadata[:file_path]
      end

      # ...create unless found:
      unless resource_group_ast.present?
        resource_group_comment_end_line_number = rspec_resource_group_metadata[:line_number]
        resource_group_comment_start_line_number = resource_group_comment_end_line_number
        while (!lines_of_spec[resource_group_comment_start_line_number-1].nil?) do
          resource_group_comment_start_line_number -= 1
        end

        resource_group_comment_range = resource_group_comment_start_line_number..resource_group_comment_end_line_number
        resource_group_comment_lines = lines_of_spec.select { |key| resource_group_comment_range.include? key }.values.compact

        resource_group_name = resource_group_comment_lines.detect { |line| line =~ /\A#\s+(.+)/i }
        resource_group_name = $1 unless resource_group_name.blank?
        resource_group_name = rspec_resource_group_metadata[:description] unless resource_group_name.present?

        resource_group_description = resource_group_comment_lines.select { |line| line !~ /\A#|\s+\+/i }.map(&:strip)
        resource_group_description.shift  if resource_group_description.first.blank?
        resource_group_description.pop    if resource_group_description.last.blank?
        resource_group_description = resource_group_description.join("\n")

        resource_group_sort_order = rspec_resource_group_metadata[:doc_sort_order] || 90000000000000

        blueprint_ast[:resourceGroups] << {
          sort_order:       resource_group_sort_order,                  # Ignored as it's not part of the API Blueprint AST
          rspec_file_path:  rspec_resource_group_metadata[:file_path],  # Ignored as it's not part of the API Blueprint AST
          name:             resource_group_name,
          description:      resource_group_description,
          resources:        []
        }
        resource_group_ast = blueprint_ast[:resourceGroups].last
      end

      ##############################################################################################
      # Retrieve or form the example's resource AST:

      # ...find:
      resource_ast = resource_group_ast[:resources].detect do |r|
        r[:sort_order] == rspec_resource_metadata[:line_number]
      end

      # ...create unless found:
      unless resource_ast.present?

        resource_comment_start_line_number = rspec_resource_metadata[:line_number]
        while (!lines_of_spec[resource_comment_start_line_number-1].nil?) do
          resource_comment_start_line_number -= 1
        end

        resource_comment_range = resource_comment_start_line_number..rspec_resource_metadata[:line_number]
        resource_comment_lines = lines_of_spec.select { |key| resource_comment_range.include? key }.values.compact

        resource_name         = resource_comment_lines.detect { |line| line =~ /\A#\s+(.+)\[(.+)\]/i }
        resource_name         = $1.strip unless resource_name.blank?
        resource_uri_template = $2.strip unless resource_name.blank?

        # Name & UriTemplate last try... rspec example_group metadata:
        resource_name         = rspec_resource_metadata[:description]   unless resource_name.present?
        resource_uri_template = rspec_resource_metadata[:uri_template]  unless resource_uri_template.present?

        resource_description = resource_comment_lines.select { |line| line !~ /\A#|\s+\+/i }.map(&:strip)
        resource_description.shift  if resource_description.first.blank?
        resource_description.pop    if resource_description.last.blank?
        resource_description = resource_description.join("\n")

        resource_group_ast[:resources] << {
          sort_order:   rspec_resource_metadata[:line_number], # Ignored as it's not part of the API Blueprint AST
          name:         resource_name,
          description:  resource_description,  # TODO: Extract from somewhere, or default to...

          uriTemplate:  resource_uri_template,
          model:        nil,  # No Model, as rspec request examples generate some output.
          parameters:   [],
          actions:      []
        }

        resource_ast = resource_group_ast[:resources].last
      end

      #############################################################################################
      # Retrieve the rspec example's request & response:
      request   ||= respond_to?(:last_request)  ? last_request  : @request
      response  ||= respond_to?(:last_response) ? last_response : @response

      #############################################################################################
      # Retrieve or form the example's action AST:

      action_ast = resource_ast[:actions].detect { |a| a[:sort_order] == rspec_action_metadata[:line_number] }
      unless action_ast.present?

        action_comment_start_line_number = rspec_action_metadata[:line_number]
        while (!lines_of_spec[action_comment_start_line_number-1].nil?) do
          action_comment_start_line_number -= 1
        end

        action_comment_range = action_comment_start_line_number..rspec_action_metadata[:line_number]
        action_comment_lines = lines_of_spec.select { |key| action_comment_range.include? key }.values.compact

        # 1st try: Group Comments in MD:
        action_name   = action_comment_lines.detect { |line| line =~ /\A#\s+(.+)\[(.+)\]/i }
        action_name   = $1.strip unless action_name.blank?
        action_method = $2.strip unless action_name.blank?

        # 2nd try: extract the method from the RSpec Example Group Metadata's description:
        action_method = $1.strip if action_method.blank? && rspec_action_metadata[:description] =~ /\A(GET|POST|PUT|PATCH|DELETE)\s/

        # Last try: extract the method from a custom metadata tag:
        action_method = rspec_action_metadata[:method] if action_method.blank?

        # abort ast if no method was found...
        if action_method.present?

          action_description = action_comment_lines.select { |line| line !~ /\A#|\s+\+/i }.map(&:strip)
          action_description.shift  if action_description.first.blank?
          action_description.pop    if action_description.last.blank?
          action_description = action_description.join("\n")

          resource_ast[:actions] << {
            sort_order:   rspec_action_metadata[:line_number], # Ignored as it's not part of the API Blueprint AST
            name:         action_name,
            description:  action_description,
            method:       action_method,
            parameters:   [],  # TODO: Extract from somewhere, or default to...
            examples:     []
          }
          action_ast = resource_ast[:actions].last
        end
      end

      if action_ast.present?

        ##############################################################################################
        # Form the transaction example AST + add request & response AST's
        example_comment_start_line_number = rspec_example.metadata[:line_number]
        while (!lines_of_spec[example_comment_start_line_number-1].nil?) do
          example_comment_start_line_number -= 1
        end

        example_comment_range = example_comment_start_line_number..rspec_example.metadata[:line_number]
        example_comment_lines = lines_of_spec.select { |key| example_comment_range.include? key }.values.compact

        # 1st try: Group Comments in MD:
        example_name          = example_comment_lines.detect { |line| line =~ /\A#\s+(.+)\s+\((.+)\)|#\s+(.+)\z/i }
        example_content_type  = $2.strip if example_name.present? && $2.present?
        example_name          = ($1 || $3).strip unless example_name.blank?

        # Last try: extract the example_name from the rspec_example metadata description:
        example_name = rspec_example.metadata[:description] if example_name.blank?
        example_content_type = request.headers["CONTENT_TYPE"] unless example_content_type.present?

        example_content_type = example_content_type.present? ? "(#{example_content_type})" : ""
        #example_name = "#{example_name} #{example_content_type}".strip

        example_description = example_comment_lines.select { |line| line !~ /\A#|\s+\+/i }.map(&:strip)
        example_description.shift  if example_description.first.blank?
        example_description.pop    if example_description.last.blank?
        example_description = example_description.join("\n")

        ##############################################################################################
        # Form the request AST:
        request_ast = {
          name:         example_name,
          description:  example_description,
          parameters:   [],  # TODO: Extract from somewhere, or default to...

          # Filter headers from the request.headers (env) hash, convert header names:
          headers:      request.headers.select { |k,v| (k =~ /\AHTTP_/ && k !~ /HOST|COOKIE|USER_AGENT\z/i) || k == "CONTENT_TYPE" }
                          .map { |k, v| { name: (k == "CONTENT_TYPE" ? k : k[5..-1]).titleize.split().join('-'), value: v } },
          body:         request.body.read,
          schema:       nil   # TODO: Extract from somewhere, or default to...
        }

        ##############################################################################################
        # Form the response AST Hash:

        response_name = response.status # TODO: el status es sufijo? Se puede agregar mas palabras?

        response_ast  = {
          name:       response_name,
          parameters: [],  # TODO: Extract from somewhere, or default to...

          # Assign the response headers
          # TODO: Filter-out irrelevant headers:
          headers:    response.headers.select { |k,v| k !~ /\AX-/i && k !~ /Cookie\z/i }
                        .map { |k, v| { name: k, value: v } },
          body:       response.body,
          schema:     nil   # TODO: Extract from somewhere, or default to...
        }

        #########################################################################################################

        transaction_example_ast = {
          sort_order:   rspec_example.metadata[:line_number], # Ignored as it's not part of the API Blueprint AST
          #name:         example_name,
          #description:  example_description,
          requests:     [ request_ast   ],
          responses:    [ response_ast  ]
        }

        # append the transaction_example_ast
        action_ast[:examples] << transaction_example_ast
      end
    end
  end

  # Escribir los archivos a partir de los AST's recolectados
  config.after(:suite) do

    Apitecto.blueprints.each do |api_name, blueprint_ast|

      # RSpec corre los ejemplos en random order (eso es bueno para las pruebas... pero malo para documentacion)
      # Ordenar los resource groups, resources, actions y examples del AST por su sort_order:
      sorter = ->(x,y) { x[:sort_order] <=> y[:sort_order] }

      blueprint_ast[:resourceGroups].each do |resource_group_ast|
        resource_group_ast[:resources].each do |resource_ast|
          resource_ast[:actions].each do |action_ast|
            action_ast[:examples].sort!(&sorter)
          end
          resource_ast[:actions].sort!(&sorter)
        end
        resource_group_ast[:resources].sort!(&sorter)
      end
      blueprint_ast[:resourceGroups].sort!(&sorter)

      # Generar el directorio a partir del nombre del api:
      api_docs_path = File.join(Apitecto.output_dir, api_name)
      Dir.mkdir(api_docs_path) unless Dir.exists?(api_docs_path)

      # Generar el archivo de API Blueprint:
      api_blueprint_path = File.join(api_docs_path, "api_blueprint.md")

      blueprint = MatterCompiler::Blueprint.new(blueprint_ast)

      File.open(api_blueprint_path, "w") { |f| f.write blueprint.serialize }

    end
  end
end


############################
