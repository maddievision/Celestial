require './rom'

# Value Types
# :boolean, :u8, :s16, :s32, :float, :lookup, :bin, :rle

class Element
  attr_accessor :package, :name, :attributes, :children, :attributes_value_types;
  def initialize
    @attributes = {}
    @attributes_value_types = {}
    @children = []
    @package = nil
    @name = nil
  end
  def inspect
    disp
  end
  def disp pre=0
    fend = children.size == 0 ? (attributes.size == 0 ? " />" : "/>") : ">"
    pres = ' ' * pre
    fstart = if attributes.size == 0
      "#{pres}<#{name}#{fend}"
    else
      "#{pres}<#{name}\n#{attributes_disp(pre)}\n#{pres}#{fend}"
    end
    if children.size > 0
      "#{fstart}\n#{children_disp(pre)}#{pres}</#{name}>\n"
    else
      "#{fstart}\n"
    end
  end
  def attributes_disp pre=0
    pres = ' ' * (pre + 2)
    attributes.map do |k, v|
      value_type = attributes_value_types[k]
      case value_type
      when :boolean
        if v
          "#{pres}#{k}"
        else
          "#{pres}#{k}={#{v}}"
        end
      when :u8, :s16, :s32, :float
        "#{pres}#{k}={#{v}}"
      when :lookup
        "#{pres}#{k}=\"#{v}\""
      when :bin
        "#{pres}#{k}={bin#{v.inspect}}"
      when :rle
        "#{pres}#{k}={rle#{v.inspect}}"
      end
    end.join("\n")
  end
  def children_disp pre=0
    children.map { |c| c.disp(pre + 2) }.join("\n")
  end
  def get_children_by_name child_name
    children.select { |c| c.name == child_name }
  end
  def find_child_by_name child_name
    children.detect { |c| c.name == child_name }
  end
  def [] name
    attributes[name.to_s]
  end
end

class CelesteMapReader
  attr_accessor :rom, :package, :string_lookup, :root
  def initialize fn
    @rom = ROM.from_file(fn)
    raise "Not a celeste map" unless rom.read_str_varlen == 'CELESTE MAP'
    @package = rom.read_str_varlen
    @string_lookup = (0...rom.read_u16_le).map { rom.read_str_varlen }
    @root = read_element
    @root.package = @package
  end
  def read_element pre=0
    element = Element.new
    element.name = string_lookup[rom.read_u16_le]
    # puts "#{" " * pre}<#{element.name}"
    rom.read_byte.times do |i|
      key = string_lookup[rom.read_u16_le]
      value_type_enc = rom.read_byte
      value = nil
      value_type = nil
      case value_type_enc
      when 0
        value = rom.read_bool
        if value
          # puts "#{" " * (pre + 2)}#{key}"
        else 
          # puts "#{" " * (pre + 2)}#{key}={#{value}}"
        end
        value_type = :boolean
      when 1
        value = rom.read_byte
        # puts "#{" " * (pre + 2)}#{key}={#{value}}"
        value_type = :u8
      when 2
        value = rom.read_s16_le
        # puts "#{" " * (pre + 2)}#{key}={#{value}}"
        value_type = :s16
      when 3
        value = rom.read_s32_le
        # puts "#{" " * (pre + 2)}#{key}={#{value}}"
        value_type = :s32
      when 4
        value = rom.read_f32_le
        # puts "#{" " * (pre + 2)}#{key}={#{value}}"
        value_type = :float
      when 5
        value = string_lookup[rom.read_u16_le]
        # puts "#{" " * (pre + 2)}#{key}=\"#{value}\""
        value_type = :lookup
      when 6
        count = rom.read_varlen_le
        base = rom.tell
        bin = []
        while rom.tell < base + count
          bin << rom.read_byte
        end
        # value = rom.read_str_varlen
        # # puts "#{" " * (pre + 2)}#{key}=\"#{value}\""
        # puts "#{" " * (pre + 2)}#{key}={bin#{bin.inspect}}"
        value_type = :bin
      when 7
        count = rom.read_u16_le
        base = rom.tell
        bin = []
        while rom.tell < base + count
          num = rom.read_byte
          val = rom.read_byte
          num.times { bin << val }
        end
        value = bin
        # puts "#{" " * (pre + 2)}#{key}={rle#{bin.inspect}}"
        value_type = :rle
      end
      element.attributes[key] = value
      element.attributes_value_types[key] = value_type
    end
    # puts "#{" " * pre}>"
    rom.read_u16_le.times do |j|
      element.children << read_element(pre + 2)
    end
    # puts "#{" " * pre}</#{element.name}>"
    element
  end
  def inspect
    "<Bin #{package} />"
  end
end
