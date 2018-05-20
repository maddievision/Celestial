# General purpose binary reader

# 8 16 32 64
# C S L Q - unsigned
# c s l q - unsigned
# < LE
# > BE
# A - binary string
# z - null terminated
# H - hex string

class ROM
  def initialize str
    @rom = str
    @cur = 0
    @base = 0
  end

  def self.from_file fn
    data = File.open(fn, "rb") { |io| io.read }
    ROM.new data
  end

  def set_base pos
    @base = pos
  end

  def seek pos
    @cur = pos + @base
  end

  def seek_rel pos
    @cur += pos
  end

  def tell
    @cur - @base
  end

  def read_str len
    r = @rom[@cur..(@cur + len - 1)].unpack("A#{len}").first
    @cur += len
    r
  end

  def read_str_varlen
    len = read_varlen_le
    r = @rom[@cur..(@cur + len - 1)].unpack("A#{len}").first
    @cur += len
    r
  end

  def read_byte
    r = @rom[@cur].ord
    @cur += 1
    r
  end

  def read_bool
    read_byte == 1
  end

  def read_s8
    r = @rom[@cur].unpack("c").first
    @cur += 1
    r
  end

  def read_u16_le
    r = @rom[@cur..(@cur + 3)].unpack('S<').first
    @cur += 2
    r
  end

  def read_s16_le
    r = @rom[@cur..(@cur + 3)].unpack('s<').first
    @cur += 2
    r
  end

  def read_u16_be
    r = @rom[@cur..(@cur + 3)].unpack('S>').first
    @cur += 2
    r
  end

  def read_u32_le
    r = @rom[@cur..(@cur + 3)].unpack('L<').first
    @cur += 4
    r
  end

  def read_s32_le
    r = @rom[@cur..(@cur + 3)].unpack('l<').first
    @cur += 4
    r
  end

  def read_u32_be
    r = @rom[@cur..(@cur + 3)].unpack('L>').first
    @cur += 4
    r
  end

  def read_f32_le
    r = @rom[@cur..(@cur + 3)].unpack('e').first
    @cur += 4
    r
  end

  def read_bin len
    r = @rom[@cur..(@cur + len - 1)]
    @cur += len
    r
  end

  def read_binswap len
    togo = len
    bin_data = "".b
    while togo > 0
      r = @rom[@cur..(@cur + 3)].unpack('L>')
      bin_data += r.pack('L<')
      @cur += 4
      togo -= 4
    end
    bin_data
  end

  def read_varlen_le
    val = 0
    r = read_byte
    val = r & 0x7F
    return val if r < 0x80
    r = read_byte << 7
    val + r
  end

  def read_varlen_be
    val = 0
    r = read_byte
    val = r & 0x7F
    return val if r < 0x80
    r = read_byte
    val = (val << 8) + r
    val
  end

  def msg str
    puts "%08X(%08X): %s" % [@cur, tell, str]
  end
end
