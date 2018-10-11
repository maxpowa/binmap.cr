def String.new(io : ::IO, params)
  str = new
  if !params.has_key?(:size) || params[:size]? == 0
    val = io.gets('\u{00}')
    raise ::IO::EOFError.new if val.nil?
    str += val.chomp('\u{00}')
  else
    slice = Slice(UInt8).new(params[:size]?.not_nil!)
    io.read_fully(slice)
    str += String.new(slice)
  end
  str
end

def Array.new(io : ::IO, params)
  ary = new
  from_io(io, params) do |element|
    ary << element
  end
  ary
end

def Array.from_io(io : ::IO, params)
  (1..params[:size]).each do
    yield io.read_bytes(T, params[:endianness])
  end
end

# TODO: Other types
