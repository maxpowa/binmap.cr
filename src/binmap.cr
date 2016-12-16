require "./binmap/*"

module Binary
  class Skip
  end

  macro mapping(properties, endianness = IO::ByteFormat::SystemEndian)
    {% for key, value in properties %}
      {% properties[key] = {type: value} unless value.is_a?(HashLiteral) || value.is_a?(NamedTupleLiteral) %}
      {% if ([String, ::Binary::Skip].includes?(properties[key][:type].resolve)) && !properties[key][:size] && !properties[key][:converter] %}
        {% raise "must specify size for #{properties[key][:type]} value \"#{key}\"" %}
      {% end %}
    {% end %}

    {% for key, value in properties %}
      {% if value[:type].resolve != Binary::Skip %}
        @{{key.id}} : {{value[:type]}}

        {% if value[:setter] == nil ? true : value[:setter] %}
          def {{key.id}}=(_{{key.id}} : {{value[:type]}})
            @{{key.id}} = _{{key.id}}
          end
        {% end %}

        {% if value[:getter] == nil ? true : value[:getter] %}
          def {{key.id}}
            @{{key.id}}
          end
        {% end %}
      {% end %}
    {% end %}

    def initialize(%io : IO)
      {% for key, value in properties %}
        {% if value[:converter] %}
          @{{key.id}} = {{value[:converter]}}.from_io(%io, {{endianness}})
        {% elsif [Int8, Int16, Int32, Int64, UInt8, UInt16, UInt32, UInt64, Float32, Float64].includes?(value[:type].resolve) %}
          @{{key.id}} = %io.read_bytes({{value[:type]}}, {{endianness}})
        {% elsif [String].includes?(value[:type].resolve) %}
          %slice{key.id} = Slice(UInt8).new({{value[:size]}})
          %io.read_fully(%slice{key.id})
          @{{key.id}} = String.new(%slice{key.id})
        {% elsif value[:type].resolve == ::Binary::Skip %}
          %io.skip({{value[:size]}})
        {% else %}
          {% raise "unable to convert #{value[:type]} value \"#{key}\" -- maybe specify a converter" %}
        {% end %}
      {% end %}
    end
  end

  macro mapping(**properties)
    ::Binary.mapping({{properties}})
  end
end
