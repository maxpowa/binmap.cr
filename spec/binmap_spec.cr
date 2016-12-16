require "./spec_helper"

private class BasicMapping
  Binary.mapping(
    foo: UInt8,
    bar: Int16,
    baz: Float32
  )
end

private class StringMapping
  Binary.mapping(
    foo: {
      type: String,
      size: 8
    },
    bar: {
      type: String,
      size: 16
    }
  )
end

private class SkipMapping
  Binary.mapping(
    foo: {
      type: String,
      size: 4
    },
    bar: {
      type: Binary::Skip,
      size: 12
    },
    baz: {
      type: String,
      size: 4
    }
  )
end

private class ReferenceMapping
  Binary.mapping(
    length: UInt16,
    value: {
      type: String,
      size: @length
    }
  )
end

private class IPConverter
  def self.from_io(io : IO, endianness = IO::ByteFormat::BigEndian)
    array = Array(UInt8).new
    4.times do
      array << io.read_bytes(UInt8, endianness)
    end
    array.join('.')
  end
end

private class Octet12_13
  getter offset
  getter flags

  def initialize(@offset : UInt8, flags : UInt16)
    @flags = Array(Bool).new
    9.times do |x|
      @flags << (flags.bit(8-x) == 1)
    end
  end

  def self.from_io(io : IO, endianness = IO::ByteFormat::BigEndian)
    bytes = io.read_bytes(UInt16, endianness)
    Octet12_13.new(((bytes & 0xF000) >> 12).to_u8, bytes)
  end
end

private class TCPPacketMapping
  Binary.mapping({
    source_ip: {
      type: String,
      converter: IPConverter
    },
    destination_ip: {
      type: String,
      converter: IPConverter
    },
    source_port: UInt16,
    destination_port: UInt16,
    seq: UInt32,
    ack: UInt32,
    octet_tt: {
      type: Octet12_13,
      converter: Octet12_13
    },
    window_size: UInt16,
    checksum: UInt16,
    urgent: UInt16
  }, IO::ByteFormat::BigEndian)
end

describe "Binary Mapping" do

  it "parses an IO into a simple mapping" do
    io = IO::Memory.new
    io.write_bytes(1_u8, IO::ByteFormat::SystemEndian)
    io.write_bytes(-1_i16, IO::ByteFormat::SystemEndian)
    io.write_bytes(1.0_f32, IO::ByteFormat::SystemEndian)
    io.rewind

    mapping = BasicMapping.new(io)

    mapping.foo.should be_a(UInt8)
    mapping.foo.should eq(1_u8)

    mapping.bar.should be_a(Int16)
    mapping.bar.should eq(-1_i16)

    mapping.baz.should be_a(Float32)
    mapping.baz.should eq(1.0_f32)
  end

  it "parses an IO into a string mapping" do
    io = IO::Memory.new("ABCDEFGHIJKLMNOPQRSTUVWX")

    mapping = StringMapping.new(io)

    mapping.foo.should be_a(String)
    mapping.foo.should eq("ABCDEFGH")

    mapping.bar.should be_a(String)
    mapping.bar.should eq("IJKLMNOPQRSTUVWX")
  end

  it "parses an IO into a mapping with skips" do
    io = IO::Memory.new("ABCD----SKIP----WXYZ")

    mapping = SkipMapping.new(io)

    mapping.foo.should be_a(String)
    mapping.foo.should eq("ABCD")

    mapping.baz.should be_a(String)
    mapping.baz.should eq("WXYZ")
  end

  it "parses an IO using a dynamic sized mapping" do
    io = IO::Memory.new
    io.write_bytes(0x0010_u16, IO::ByteFormat::SystemEndian)
    io.write("ABCDEFGHIJKLMNOP".to_slice)
    io.rewind

    mapping = ReferenceMapping.new(io)

    mapping.length.should be_a(UInt16)
    mapping.length.should eq(16)

    mapping.value.should be_a(String)
    mapping.value.should eq("ABCDEFGHIJKLMNOP")
  end

  it "parses an IO containing a sample TCP packet" do
    io = IO::Memory.new
    io.write_bytes(0xAC100009_u32, IO::ByteFormat::BigEndian) # Source IP
    io.write_bytes(0xAC100001_u32, IO::ByteFormat::BigEndian) # Destination IP
    io.write_bytes(0x0447_u16, IO::ByteFormat::BigEndian) # Source Port
    io.write_bytes(0x0017_u16, IO::ByteFormat::BigEndian) # Destination Port
    io.write_bytes(0x60C6DF90_u32, IO::ByteFormat::BigEndian) # Sequence Number
    io.write_bytes(0x00000000_u32, IO::ByteFormat::BigEndian) # ACK Number
    io.write_bytes(0b01100000_u8, IO::ByteFormat::BigEndian) # Offset/Header Length (High bits) | Reserved (3 low bits) | NS flag (last low bit)
    io.write_bytes(0b00000010_u8, IO::ByteFormat::BigEndian) # CWR/ECE/URG/ACK/PSH/RST/SYN/FIN flags (one bit flags)
    io.write_bytes(0x0200_u16, IO::ByteFormat::BigEndian) # Window size
    io.write_bytes(0xF946_u16, IO::ByteFormat::BigEndian) # Checksum
    io.write_bytes(0x0000_u16, IO::ByteFormat::BigEndian) # Urgent pointer
    # Options
    io.rewind

    # puts io.to_slice

    mapping = TCPPacketMapping.new(io)

    mapping.source_ip.should be_a(String)
    mapping.source_ip.should eq("172.16.0.9")

    mapping.destination_ip.should be_a(String)
    mapping.destination_ip.should eq("172.16.0.1")

    mapping.source_port.should be_a(UInt16)
    mapping.source_port.should eq(1095)

    mapping.destination_port.should be_a(UInt16)
    mapping.destination_port.should eq(23)

    mapping.seq.should be_a(UInt32)
    mapping.seq.should eq(1623646096)

    mapping.ack.should be_a(UInt32)
    mapping.ack.should eq(0)

    mapping.octet_tt.offset.should be_a(UInt8)
    mapping.octet_tt.offset.should eq(6)

    # SYN flag should be true
    mapping.octet_tt.flags.size.should eq(9)
    mapping.octet_tt.flags.should be_a(Array(Bool))
    mapping.octet_tt.flags.should eq([false, false, false, false, false, false, false, true, false])

    mapping.window_size.should be_a(UInt16)
    mapping.window_size.should eq(512)

    mapping.checksum.should be_a(UInt16)
    mapping.checksum.should eq(63814)

    mapping.urgent.should be_a(UInt16)
    mapping.urgent.should eq(0)
  end
end
