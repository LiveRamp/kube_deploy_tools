def check_call(cmd)
  puts ">>> Running: #{cmd.join(' ')}"
  ok = system(*cmd)
  raise "!!! Failed to run #{cmd}: exit status #{$?}" unless ok
end
