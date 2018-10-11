

module Binary

  abstract struct Bits
    def initialize(io : ::IO::Binary, size : Int)
    end

    def to_io(io : ::IO::Binary)
      # write bits
    end
  end

{% begin %}
  {% for type, i in %w(UBit1 Bit2 UBit2 Bit4 UBit4 Bit8 UBit8 Bit16 UBit16 Bit32) %}
    {% bitsize = 2 ** ((i+1) / 2) %}
    {% signed = i % 2 %}

    struct {{type.id}} < Bits
      @value : Int32

      def initialize(io : ::IO::Binary)
        val = io.read_bits({{bitsize}})

        {% if signed == 1 && bitsize == 1 %}
          raise Error.new("signed bitfield must have more than one bit")
        {% end %}

        {% if signed == 1 %}
          {% max = (1 << (bitsize - 1)) - 1 %}
          {% min = -(max + 1) %}
        {% else %}
          {% min = 0 %}
          {% max = (1 << bitsize) - 1 %}
        {% end %}

        val = (val < {{min}}) ? {{min}} : (val > {{max}}) ? {{max}} : val

        {% if bitsize == 1 %}
          # allow single bits to be used as booleans
          val = (val == true) ? 1 : (not val) ? 0 : clamp
        {% end %}

        @value = val
      end

      def bytesize
        {{bitsize}} / 8
      end

      def bitsize
        {{bitsize}}
      end

      def bit(bit)
        @value.bit(bit)
      end

      def self.from_io(io : ::IO::Binary, format : ::IO::ByteFormat)
        new(io)
      end

      def inspect(io : ::IO)
        @value.inspect(io)
      end

      {% for name, type in {
                       to_i: Int32, to_u: UInt32, to_f: Float64,
                       to_i8: Int8, to_i16: Int16, to_i32: Int32, to_i64: Int64,
                       to_u8: UInt8, to_u16: UInt16, to_u32: UInt32, to_u64: UInt64,
                       to_f32: Float32, to_f64: Float64,
                     } %}
        # Returns *self* converted to {{type}}.
        def {{name.id}} : {{type}}
          @value.{{name.id}}
        end
      {% end %}

      {% for num in %w(Int8 Int16 Int32 Int64 UInt8 UInt16 UInt32 UInt64 Float32 Float64) %}
        {% for op, desc in {
                             "==" => "equal to",
                             "!=" => "not equal to",
                             "<"  => "less than",
                             "<=" => "less than or equal to",
                             ">"  => "greater than",
                             ">=" => "greater than or equal to",
                           } %}
          # Returns true if *self* is {{desc.id}} *other*.
          def {{op.id}}(other : {{num.id}}) : Bool
            @value.{{op.id}}(other)
          end
        {% end %}
      {% end %}
    end

  {% end %}
{% end %}

end
