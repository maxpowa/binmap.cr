require "./binmap/*"

module Binary
  SIZE_REQUIRED = [::Binary::Skip]

  macro mapping(properties, endianness = ::IO::ByteFormat::SystemEndian)
    {% for key, value in properties %}
      {% properties[key] = {type: value} unless value.is_a?(HashLiteral) || value.is_a?(NamedTupleLiteral) %}
      {% if (properties[key][:type].is_a?(Generic) || SIZE_REQUIRED.includes?(properties[key][:type].resolve)) && !properties[key][:size] && !properties[key][:converter] %}
        {% raise "must specify size for #{properties[key][:type]} value \"#{key}\"" %}
      {% end %}
    {% end %}

    # Start generated getters/setters for properties
    {% for key, value in properties %}
      {% if value[:type].is_a?(Generic) || !SIZE_REQUIRED.includes?(value[:type].resolve) %}
        @{{key.id}} : {{value[:type]}} {{ (value[:nilable] ? "?" : "").id }}

        {% if value[:setter] == nil ? true : value[:setter] %}
          # Setter for {{key.id}}
          def {{key.id}}=(_{{key.id}} : {{value[:type]}} {{ (value[:nilable] ? "?" : "").id }})
            @{{key.id}} = _{{key.id}}
          end
        {% end %}

        {% if value[:getter] == nil ? true : value[:getter] %}
          # Getter for {{key.id}}
          def {{key.id}}
            @{{key.id}}
          end
        {% end %}
      {% end %}
    {% end %}
    # End generated getters/setters for properties

    def initialize(io : ::IO)
      %io = ::IO::Binary.new(io)
      {% for key, value in properties %}
        {% if value[:converter] %}
          %var{key.id} = {{value[:converter]}}.from_io(%io, {{ value[:endianness] ? value[:endianness] : endianness }})
        {% elsif value[:type].is_a?(Generic) || [String, Binary::Skip].includes?(value[:type].resolve) %}
          %var{key.id} = {{value[:type]}}.new(%io, {{value[:size]}}, {{ value[:endianness] ? value[:endianness] : endianness }})
        {% else %}
          %var{key.id} = %io.read_bytes({{value[:type]}}, {{ value[:endianness] ? value[:endianness] : endianness }})
        {% end %}

        {% if value[:nilable] %}
          {% if value[:default] != nil %}
            @{{key.id}} = %found{key.id} ? %var{key.id} : {{value[:default]}}
          {% else %}
            @{{key.id}} = %var{key.id}
          {% end %}
        {% elsif value[:default] != nil %}
          @{{key.id}} = %var{key.id}.is_a?(Nil) ? {{value[:default]}} : %var{key.id}
        {% else %}
          @{{key.id}} = (%var{key.id}).as({{value[:type]}})
        {% end %}
      {% end %}
    end

    def to_io(io : ::IO)
      # TODO
    end
  end

  macro mapping(**properties)
    ::Binary.mapping({{properties}})
  end
end
