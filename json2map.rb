require "./celeste_map"
# fn = 'app/Content/Maps/1-ForsakenCity.bin'

ARGV.each do |fn|
  base = File.basename(fn, ".json")
  puts "Opening #{fn}"
  a = CelesteMap.new(fn, fmt: :json)
  outfn = "bin/#{base}.bin"
  puts "Writing #{outfn}"
  a.write outfn
end
