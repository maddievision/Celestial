require "./celeste_map"
# fn = 'app/Content/Maps/1-ForsakenCity.bin'

ARGV.each do |fn|
  base = File.basename(fn, ".bin")
  a = CelesteMap.new(fn)
  File.open("#{base}.xml", "wb") { |f| f.write a.root.inspect } # Note: not valid XML, just for display
  a.write_json("#{base}.json")
end
