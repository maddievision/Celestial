require "./celeste_map_reader"
require 'ruby2d'
require 'pry'
# fn = 'app/Content/Maps/1-ForsakenCity.bin'

ARGV.each do |fn|
  base = File.basename(fn, ".json")
  a = CelesteMapReader.new(fn, fmt: :json)
  a.write "bin/#{base}.bin"
end
