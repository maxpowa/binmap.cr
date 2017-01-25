module Binary
  class Skip
    def intialize
    end

    def self.new(io : ::IO, size : Int, endianness = IO::ByteFormat::SystemEndian)
      io.skip(size)
      new
    end
  end
end
