require 'bin_tools'
require 'json'

# Value Types
# :boolean, :u8, :s16, :s32, :float, :lookup, :bin, :rle

$ElementAutoParser = {}

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
          "#{pres}#{k}(#{value_type})"
        else
          "#{pres}#{k}(#{value_type})={#{v}}"
        end
      when :u8, :s16, :s32, :float
        "#{pres}#{k}(#{value_type})={#{v}}"
      when :lookup
        "#{pres}#{k}(#{value_type})=\"#{v}\""
      when :bin
        "#{pres}#{k}(#{value_type})={#{v.inspect}}"
      when :rle
        "#{pres}#{k}(#{value_type})={#{v.inspect}}"
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
  def set_attribute name, value_type, value
    attributes[name.to_s] = value
    attributes_value_types[name.to_s] = value_type
  end
  def self.auto_type num
    if (num >= 0 && num <= 255)
      :u8
    elsif num >= -32768 && num < 32768
      :s16
    else
      :s32
    end
  end

  def set_num_attribute name, num
    num = num.to_i(16) if num.is_a? String
    set_attribute name, self.class.auto_type(num), num
  end



  def set_lookup_attribute name, str
    set_attribute name, :lookup, str
  end

  def set_boolean_attribute name, val
    set_attribute name, :boolean, val
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
    extra_children = []
    element.children = obj['children'].map do |c|
      parser = nil
      c.each do |k, v|
        parser = $ElementAutoParser[k] if $ElementAutoParser[k]
      end
      z = if parser
        parser.from_h c
      else
        if c.has_key?('repeat')
          clones = (0..c['repeat']).each do |rr|
            nn = c.clone
            nn['attributes'] = nn['attributes'].clone
            nn['attribute_types'] = nn['attribute_types'].clone
            c['repeat_attributes'].each do |k, v|
              nn['attributes'][k] += (rr + 1) * v
              nn['attribute_types'][k] = 's16'
            end
            extra_children << from_h(nn)
          end
        end
        from_h c
      end
      if z.is_a? Array
        z.each_with_index do |zz, i|
          extra_children << zz if i > 0
        end
        z.first
      else
        z
      end
    end
    element.children += extra_children
    element
  end
end


class CelesteMap
  attr_accessor :debug, :rom, :package, :string_lookup, :root, :writer
  def initialize fn, fmt: :bin, debug: false
    @debug = debug
    case fmt
    when :bin
      @rom = BinTools::Reader.from_file(fn)
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
    @writer = BinTools::BinWriter.new(fn)
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

class NodeElement < Element
  def self.with_xy x, y
    e = self.new
    e.name = 'node'
    e.set_num_attribute 'x', x
    e.set_num_attribute 'y', y
    e
  end
end

class EntityElement < Element
  def self.gen_id key
    @gen_id = {} unless @gen_id
    @gen_id[key] = 0 unless @gen_id[key]
    @gen_id[key] = @gen_id[key] + 1
    @gen_id[key]
  end

  def self.reset_id key
    @gen_id = {} unless @gen_id
    @gen_id[key] = 0
  end

  def set_gen_id key
    set_num_attribute 'id', self.class.gen_id(key)
  end  

  def set_auto_name obj
    self.name = obj['__entity']
  end

  def set_auto_num_attribute obj, name
    set_num_attribute name, obj[name]
  end

  def set_auto_lookup_attribute obj, name
    set_lookup_attribute name, obj[name]
  end

  def set_auto_boolean_attribute obj, name
    set_boolean_attribute name, obj[name]
  end

  def set_auto_xy obj, oX = 0, oY = 0
    x = obj['x']
    y = obj['y']
    x = x.to_i(16) if x.is_a? String
    y = y.to_i(16) if y.is_a? String

    set_num_attribute 'x', x + oX
    set_num_attribute 'y', y + oY
  end

  def set_auto_width obj
    set_auto_num_attribute obj, 'width'
  end

  def set_auto_height obj
    set_auto_num_attribute obj, 'height'
  end

  def set_auto_wh obj
    set_auto_width obj
    set_auto_height obj
  end

  def set_origin x, y
    set_num_attribute 'originX', x
    set_num_attribute 'originY', y
  end

  def self.parse_player obj
    e = self.new
    e.set_auto_name obj
    e.set_gen_id 'entity'
    e.set_auto_xy obj
    e.set_num_attribute 'width', 8
    e.set_origin 4, 8
    e
  end

  def self.parse_badeline_chaser obj
    e = self.new
    e.name = 'darkChaser'
    e.set_gen_id 'entity'
    e.set_auto_xy obj
    e.set_origin 4, 8
    e
  end

  def self.parse_booster obj
    e = self.new
    e.set_auto_name obj
    e.set_gen_id 'entity'
    e.set_auto_xy obj
    e.set_auto_boolean_attribute obj, 'red'
    e.set_origin 4, 4
    e
  end

  def self.parse_move_block obj
    e = self.new
    e.name = 'moveBlock'
    e.set_gen_id 'entity'
    e.set_auto_xy obj
    e.set_auto_wh obj
    e.set_auto_lookup_attribute obj, 'direction'
    e.set_auto_boolean_attribute obj, 'canSteer'
    e.set_auto_boolean_attribute obj, 'fast'
    e.set_origin 0, 0
    e
  end

  def self.parse_black_gem obj
    e = self.new
    e.name = 'blackGem'
    e.set_gen_id 'entity'
    e.set_auto_xy obj
    e.set_auto_boolean_attribute obj, 'removeCameraTriggers'
    e.set_origin 6, 6
    e
  end

  def self.parse_golden_berry obj
    e = self.new
    e.name = 'goldenBerry'
    e.set_gen_id 'entity'
    e.set_auto_xy obj
    e.set_origin 8, 8
    e
  end

  def self.parse_dream_block obj
    e = self.new
    e.name = 'dreamBlock'
    e.set_gen_id 'entity'
    e.set_auto_xy obj
    e.set_auto_wh obj
    e.set_auto_boolean_attribute obj, 'fastMoving'
    e.set_origin 0, 0    
    e
  end

  def self.parse_kevin obj
    e = self.new
    e.name = 'crushBlock'
    e.set_gen_id 'entity'
    e.set_auto_xy obj
    e.set_auto_wh obj
    e.set_auto_lookup_attribute obj, 'axes'
    e.set_auto_boolean_attribute obj, 'chillout'
    e.set_origin 0, 0
    e
  end

  def self.parse_water obj
    e = self.new
    e.name = 'water'
    e.set_gen_id 'entity'
    e.set_auto_xy obj
    e.set_auto_wh obj
    e.set_auto_boolean_attribute obj, 'steamy'
    e.set_auto_boolean_attribute obj, 'hasBottom'
    e.set_origin 0, 0
    e
  end

  def self.parse_jump_thru obj
    e = self.new
    e.name = 'jumpThru'
    e.set_gen_id 'entity'
    e.set_auto_xy obj
    e.set_auto_width obj
    e.set_origin 0, 0
    e
  end

  def self.parse_zip_mover obj
    e = self.new
    e.name = 'zipMover'
    e.set_gen_id 'entity'
    e.set_auto_xy obj
    e.set_auto_wh obj
    e.set_origin 0, 0
    e.children << NodeElement.with_xy(obj['x2'], obj['y2'])
    e
  end

  def self.parse_switch_gate obj
    e = self.new
    e.name = 'switchGate'
    e.set_gen_id 'entity'
    e.set_auto_xy obj
    e.set_auto_wh obj
    e.set_auto_boolean_attribute obj, 'persistent'
    e.set_auto_lookup_attribute obj, 'sprite'
    e.set_origin 0, 0
    e.children << NodeElement.with_xy(obj['x2'], obj['y2'])
    e
  end

  def self.parse_bumper obj
    e = self.new
    e.name = 'bigSpinner'
    e.set_gen_id 'entity'
    e.set_auto_xy obj
    e.set_origin 16, 16
    e
  end

  def self.parse_cloud obj
    e = self.new
    e.set_auto_name obj
    e.set_gen_id 'entity'
    e.set_auto_xy obj
    e.set_auto_boolean_attribute obj, 'fragile'
    e.set_origin 16, 0
    e
  end

  def self.parse_spikes obj
    e = self.new
    e.name = 'spikes' + obj['direction']
    e.set_gen_id 'entity'
    e.set_auto_xy obj
    e.set_auto_lookup_attribute obj, 'type'
    case obj['direction']
    when 'Up'
      e.set_auto_width obj
      e.set_origin 0, 4
    when 'Down'
      e.set_auto_width obj
      e.set_origin 0, 0
    when 'Left'
      e.set_auto_height obj
      e.set_origin 4, 0
    when 'Right'
      e.set_auto_height obj
      e.set_origin 0, 0
    end
    e
  end

  def self.parse_touch_switch obj
    e = self.new
    e.name = 'touchSwitch'
    e.set_gen_id 'entity'
    e.set_auto_xy obj
    e.set_origin 4, 4
    e
  end

  def self.parse_spinner obj
    nY = obj['nY'] || 1
    nX = obj['nX'] || 1
    dY = obj['dY'] || 16
    dX = obj['dX'] || 16
    elements = []
    nY.times do |iY|
      nX.times do |iX|
        e = self.new
        e.set_auto_name obj
        e.set_gen_id 'entity'
        e.set_auto_boolean_attribute obj, 'attachToSolid'
        e.set_auto_xy obj, iX * dX, iY * dY
        e.set_origin 8, 8
        elements << e
      end
    end
    elements
  end

  def self.from_h obj
    self.send("parse_#{obj['__entity']}", obj)
  end
end

$ElementAutoParser['__entity'] = EntityElement

class SolidsElement < Element
  def set_auto_xy obj, oX = 0, oY = 0
    x = obj['offsetX'] || 0
    y = obj['offsetY'] || 0
    x = x.to_i(16) if x.is_a? String
    y = y.to_i(16) if y.is_a? String

    set_num_attribute 'offsetX', x + oX
    set_num_attribute 'offsetY', y + oY
  end

  def self.from_h obj
    e = self.new
    e.name = 'solids'
    e.set_auto_xy obj
    inner = obj['map'].map do |str|
      str.split('').map { |ch| ch.ord == 32 && '0'.ord || ch.ord } + [10]
    end.flatten
    e.set_attribute 'innerText', :rle, inner
    e
  end
end

$ElementAutoParser['__solids'] = SolidsElement
