require "./celeste_map"
# fn = 'app/Content/Maps/1-ForsakenCity.bin'

ARGV.each do |fn|
  base = File.basename(fn, ".json")
  a = CelesteMap.new(fn, fmt: :json)
  a.write "bin/#{base}.bin"
end
