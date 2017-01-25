module IO
  class Binary
    include IO

    def initialize(io : ::IO)
      @offset = 0
      @raw_io = io
      @buffer_end_points = Array(Int32).new

      stream_init

      # bits when reading
      @rnbits  = 0
      @rval    = 0
      @rendian = ::IO::ByteFormat::SystemEndian

      self
    end

    def offset_raw
      @offset
    end

    def stream_init
      @offset = 0
    end

    macro method_missing(call)
      reset_read_bits

      @raw_io.{{call}}
    end

    def read(slice : Slice(UInt8))
      reset_read_bits

      @raw_io.read(slice)
    end

    def write(slice : Slice(UInt8)) : Nil
      reset_read_bits

      @raw_io.write(slice)
    end

    def offset
      offset_raw
    end

    # Reads exactly +nbits+ bits from the stream. +endian+ specifies whether
    # the bits are stored in +:big+ or +:little+ endian format.
    def read_bits(nbits, endian)
      if @rendian != endian
        # don't mix bits of differing endian
        reset_read_bits
        @rendian = endian
      end

      if endian == ::IO::ByteFormat::BigEndian
        read_big_endian_bits(nbits)
      else
        read_little_endian_bits(nbits)
      end
    end

    # Discards any read bits so the stream becomes aligned at the
    # next byte boundary.
    def reset_read_bits
      @rnbits = 0
      @rval   = 0
    end

    def read_big_endian_bits(nbits)
      while @rnbits < nbits
        accumulate_big_endian_bits
      end

      val     = (@rval >> (@rnbits - nbits)) & mask(nbits)
      @rnbits -= nbits
      @rval   &= mask(@rnbits)

      val
    end

    def accumulate_big_endian_bits
      byte = @raw_io.read_byte
      raise ::IO::EOFError.new("End of file reached") if byte.nil?
      byte = byte & 0xff

      @rval = (@rval << 8) | byte
      @rnbits += 8
    end

    def read_little_endian_bits(nbits)
      while @rnbits < nbits
        accumulate_little_endian_bits
      end

      val     = @rval & mask(nbits)
      @rnbits -= nbits
      @rval   >>= nbits

      val
    end

    def accumulate_little_endian_bits
      byte = @raw_io.read_byte
      raise ::IO::EOFError.new("End of file reached") if byte.nil?
      byte = byte & 0xff

      @rval = @rval | (byte << @rnbits)
      @rnbits += 8
    end

    def mask(nbits)
      (1 << nbits) - 1
    end
  end
end
