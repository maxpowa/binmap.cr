def String.new(io : ::IO, size : (Int | Nil) = 0, endianness = ::IO::ByteFormat::LittleEndian)
  str = new
  if size == 0 || size.nil?
    val = io.gets('\u{00}')
    raise ::IO::EOFError.new if val.nil?
    str += val.chomp('\u{00}')
  else
    slice = Slice(UInt8).new(size)
    io.read_fully(slice)
    str += String.new(slice)
  end
  str
end

def Array.new(io : ::IO, size : Int, endianness = ::IO::ByteFormat::SystemEndian)
  ary = new
  new(io, size, endianness) do |element|
    ary << element
  end
  ary
end

def Array.new(io : ::IO, size : Int, endianness : ::IO::ByteFormat)
  (1..size).each do
    yield io.read_bytes(T, endianness)
  end
end

# TODO: Other types
