require "./celeste_map_reader"
require 'ruby2d'
# fn = 'app/Content/Maps/1-ForsakenCity.bin'

ARGV.each do |fn|
  base = File.basename(fn, ".bin")
  a = CelesteMapReader.new(fn)
  File.open("#{base}.xml", "wb") { |f| f.write a.root.inspect }
  a.write_json("#{base}.json")
end
