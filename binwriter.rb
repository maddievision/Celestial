16# 8 16 32 64
# C S L Q - unsigned
# c s l q - unsigned
# < LE
# > BE
# A - binary string
# z - null terminated
# H - hex string


class BinWriter
  def initialize fn
    @f = File.new fn, "wb"
  end

  def self.open fn, &block
    f = BinWriter.new fn
    block.call f
    f.close
  end

  def seek pos
    @f.seek pos
  end

  def tell
    @f.tell
  end

  def write_str str
    @f.write str
  end

  def write_str_varlen str
    write_varlen_le str.size
    @f.write str
  end

  def write_byte val
    @f.write [val].pack("C")
  end

  def write_bool val
    write_byte val ? 1 : 0
  end

  def write_u16_le val
    @f.write [val].pack("S<")
  end

  def write_s16_le val
    @f.write [val].pack("s<")
  end

  def write_u16_be val
    @f.write [val].pack("S>")
  end

  def write_u32_le val
    @f.write [val].pack("L<")
  end

  def write_s32_le val
    @f.write [val].pack("l<")
  end

  def write_u32_be val
    @f.write [val].pack("L>")
  end

  def write_f32_le val
    @f.write [val].pack("e")
  end

  def write_u24_be val
    write_byte val >> 16
    write_u16_be val & 0xFFFF
  end

  def write_bin str
    @f.write str
  end

  def write_varlen_be val
    out = [val & 0x7F]
    val = val >> 7
    while val > 0
        out << (val & 0x7f) + 0x80
        val = val >> 7
    end
    out.reverse.each do |x|
      write_byte x
    end
  end

  def write_varlen_le val
    out = [val & 0x7F]
    val = val >> 7
    while val > 0
        out << (val & 0x7f)
        val = val >> 7
    end
    out.each_with_index do |x, i|
      write_byte(x + ((i == out.size - 1) ? 0 : 0x80))
    end
  end

  def write_binswap str
    togo = str.size
    pos = 0
    while togo > 0
      r = @rom[pos..(pos+3)].unpack('L>')
      d = r.pack('L<')
      write_bin d
      pos += 4
      togo -= 4
    end
  end

  def close
    @f.close
  end
end
