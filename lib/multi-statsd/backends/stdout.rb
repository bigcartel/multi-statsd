# Example backend which prints out the all stats to stdout
class MultiStatsd::Backend::Stdout < MultiStatsd::Backend::Base
  # Prints the name of this backend, the current time, and inspected stats to stdout
  # @return [nil]
  def flush
    $stdout.puts "[#{@name}:#{Time.now.to_i}] #{reset_stats.inspect}"
  end
end