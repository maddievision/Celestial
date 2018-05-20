require './rom'
require './binwriter'
require 'json'
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
  def to_h
    {
      'name' => name,
      'package' => package,
      'attributes' => attributes,
      'attribute_types' => attributes_value_types,
      'children' => children.map(&:to_h)
    }
  end
  def strings
    strs = []
    strs << name
    attributes.each do |k, v|
      strs << k
      strs << v if attributes_value_types[k].to_sym == :lookup
    end
    children.each do |c|
      strs += c.strings
    end
    strs.compact.uniq
  end
  def self.from_h obj
    element = self.new
    element.name = obj['name']
    element.package = obj['package']
    element.attributes = obj['attributes']
    element.attributes_value_types = obj['attribute_types']
    element.children = obj['children'].map { |c| from_h c }
    element
  end
end

class CelesteMapReader
  attr_accessor :debug, :rom, :package, :string_lookup, :root, :writer
  def initialize fn, fmt: :bin, debug: false
    @debug = debug
    case fmt
    when :bin
      @rom = ROM.from_file(fn)
      raise "Not a celeste map" unless rom.read_str_varlen == 'CELESTE MAP'
      @package = rom.read_str_varlen
      @string_lookup = (0...rom.read_u16_le).map { rom.read_str_varlen }
      @root = read_element
      @root.package = @package
    when :json
      obj = File.open(fn, 'rb') { |f| JSON.parse(f.read) }
      raise "Not a celeste map" unless obj['type'] == 'CELESTE MAP'
      @root = Element.from_h(obj['root'])
      @package = @root.package
    else
      raise "unknown fmt #{fmt}"
    end
  end

  def write fn
    @writer = BinWriter.new(fn)
    @string_lookup = root.strings
    writer.write_str_varlen 'CELESTE MAP'
    writer.write_str_varlen root.package
    writer.write_u16_le string_lookup.size
    string_lookup.each do |s|
      writer.write_str_varlen s
    end
    write_element root
    writer.close
  end

  def write_json fn
    File.open(fn, 'wb') do |f|
      f.write JSON.pretty_generate(
        obj = {
          'type' => 'CELESTE MAP',
          'root' => root.to_h
        }
      )
    end
  end

  def write_element element
    writer.write_u16_le string_lookup.index(element.name)
    writer.write_byte element.attributes.size
    element.attributes.each do |k, v|
      writer.write_u16_le string_lookup.index(k)
      vt = element.attributes_value_types[k]
      case vt.to_sym
      when :boolean
        writer.write_byte 0
        writer.write_bool v
      when :u8
        writer.write_byte 1
        writer.write_byte v
      when :s16
        writer.write_byte 2
        writer.write_s16_le v
      when :s32
        writer.write_byte 3
        writer.write_s32_le v
      when :float
        writer.write_byte 4
        writer.write_f32_le v
      when :lookup
        writer.write_byte 5
        writer.write_u16_le string_lookup.index(v)
      when :bin
        writer.write_byte 6
        writer.write_varlen_le v.size
        v.each do |b|
          writer.write_byte b
        end
      when :rle
        writer.write_byte 7
        rle = []
        count = 0
        lb = -1
        v.each do |b|
          if b != lb
            if lb >= 0
              rle << count
              rle << lb
            end
            count = 0
            lb = b
          end
          count += 1
        end
        if lb >= 0
          rle << count
          rle << lb
        end
        writer.write_u16_le rle.size
        rle.each do |b|
          writer.write_byte b
        end
      else
        raise "unknown value type #{vt} for key #{k} with value #{v}"
      end

    end
    writer.write_u16_le element.children.size
    element.children.each do |child|
      write_element child
    end
  end

  def read_element pre=0
    element = Element.new
    element.name = string_lookup[rom.read_u16_le]
    dputs "#{" " * pre}<#{element.name}"
    rom.read_byte.times do |i|
      key = string_lookup[rom.read_u16_le]
      value_type_enc = rom.read_byte
      value = nil
      value_type = nil
      case value_type_enc
      when 0
        value = rom.read_bool
        if value
          dputs "#{" " * (pre + 2)}#{key}"
        else 
          dputs "#{" " * (pre + 2)}#{key}={#{value}}"
        end
        value_type = :boolean
      when 1
        value = rom.read_byte
        dputs "#{" " * (pre + 2)}#{key}={#{value}}"
        value_type = :u8
      when 2
        value = rom.read_s16_le
        dputs "#{" " * (pre + 2)}#{key}={#{value}}"
        value_type = :s16
      when 3
        value = rom.read_s32_le
        dputs "#{" " * (pre + 2)}#{key}={#{value}}"
        value_type = :s32
      when 4
        value = rom.read_f32_le
        dputs "#{" " * (pre + 2)}#{key}={#{value}}"
        value_type = :float
      when 5
        value = string_lookup[rom.read_u16_le]
        dputs "#{" " * (pre + 2)}#{key}=\"#{value}\""
        value_type = :lookup
      when 6
        count = rom.read_varlen_le
        base = rom.tell
        bin = []
        while rom.tell < base + count
          bin << rom.read_byte
        end
        # value = rom.read_str_varlen
        dputs "#{" " * (pre + 2)}#{key}=\"#{value}\""
        dputs "#{" " * (pre + 2)}#{key}={bin#{bin.inspect}}"
        value = bin
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
        dputs "#{" " * (pre + 2)}#{key}={rle#{bin.inspect}}"
        value_type = :rle
      else
        raise "unknown value type byte #{value_type_enc} for key #{key}"
      end
      element.attributes[key] = value
      element.attributes_value_types[key] = value_type
    end
    dputs "#{" " * pre}>"
    rom.read_u16_le.times do |j|
      element.children << read_element(pre + 2)
    end
    dputs "#{" " * pre}</#{element.name}>"
    element
  end
  def inspect
    "<Bin #{package} />"
  end
  def dputs s
    puts s if @debug
  end
end
