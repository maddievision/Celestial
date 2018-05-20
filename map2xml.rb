require "./celeste_map_reader"
require 'ruby2d'

# fn = 'app/Content/Maps/1-ForsakenCity.bin'

ARGV.each do |fn|
  a = CelesteMapReader.new(fn)
  File.open("#{File.basename(fn)}.xml", "wb") { |f| f.write a.root.inspect }
end
