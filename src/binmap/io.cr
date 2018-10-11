class IO::Binary < IO
  def initialize(io : ::IO)
    @offset = 0
    @raw_io = io

    stream_init

    # bits when reading
    @rnbits = 0
    @rval = 0
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

  def reset_read_bits
    @rnbits = 0
    @rval = 0
  end

  def read_bits(nbits)
    while @rnbits < nbits
      accumulate_bits
    end

    val = (@rval >> (@rnbits - nbits)) & mask(nbits)
    @rnbits -= nbits
    @rval &= mask(@rnbits)

    val
  end

  def accumulate_bits
    byte = @raw_io.read_byte
    raise ::IO::EOFError.new if byte.nil?
    byte = byte & 0xff

    @rval = @rval | (byte << @rnbits)
    @rnbits += 8
  end

  def mask(nbits)
    (0b1 << nbits) - 0b1
  end
end
