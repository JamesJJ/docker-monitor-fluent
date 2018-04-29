#!/usr/bin/ruby

require 'fluent-logger'
require 'net_http_unix'
require 'json'
require 'time'
require 'mini_cache'

TAG_PREFIX =      ENV['TAG_PREFIX']          || nil
FLUENTD_HOST =    ENV['FLUENTD_HOST']        || 'fluentd'
FLUENTD_PORT =    ENV['FLUENTD_PORT'].to_i   || 24224
WAIT_TIME =       ENV['WAIT_TIME'].to_i      || 60
DOCKER_SOCKET =   ENV['DOCKER_SOCKET']       || 'unix:///var/run/docker.sock'
DEBUG =           (ENV['DEBUG'] == 'true')   ? true : false

puts '== Docker Monitor Fluentd'
puts DateTime.now
puts sprintf("TAG_PREFIX: %s", TAG_PREFIX)
puts sprintf("FLUENTD_HOST: %s", FLUENTD_HOST)
puts sprintf("FLUENTD_PORT: %d", FLUENTD_PORT)
puts sprintf("WAIT_TIME: %d", WAIT_TIME)
puts sprintf("DOCKER_SOCKET: %s", DOCKER_SOCKET)
puts sprintf("DEBUG: %s", DEBUG.to_s)

# Wait a couple of seconds before we start
sleep (6)

history ||= MiniCache::Store.new

client = NetX::HTTPUnix.new(DOCKER_SOCKET) unless client
list_containers_req = Net::HTTP::Get.new("/containers/json?all=1&size=1") unless list_containers_req
fluent = Fluent::Logger::FluentLogger.new(TAG_PREFIX, :host=>FLUENTD_HOST, :port=>FLUENTD_PORT, :log_reconnect_error_threshold=>0, :buffer_limit=>16384)
loop do
  $stderr.puts "= Starting main loop" if DEBUG
  containers_resp = client.request(list_containers_req)
  if (containers_resp.code.to_s != '200') then
    $stderr.puts "= Error reading from: #{DOCKER_SOCKET} (#{containers_resp.code})"
    sleep (6)
    next
  end
  containers = JSON.parse(containers_resp.body)
  $stderr.puts "= Got containers data:" if DEBUG
  $stderr.puts containers.inspect if DEBUG
  containers.each do |_c|
    $stderr.puts "= Container loop: #{_c['State']}, #{_c['Id']}" if DEBUG
    stats = { }
    case _c['State']
    when 'running'
      stats_req = Net::HTTP::Get.new("/containers/#{_c['Id']}/stats?stream=0")
      stats_resp = client.request(stats_req)
      stats = JSON.parse(stats_resp.body) if (stats_resp.code.to_s == '200')
    when 'restarting'
      # Do not request per-container stats for "restarting" container,
      # but do continue on and sned the restarting status to fluentd
      nil
    else
      next
    end

    # For ease of downstream processing, we can do some calculations here and add them in to the stats object
    if  stats.dig('memory_stats', 'usage') &&
        stats.dig('memory_stats', 'max_usage') &&
        stats.dig('memory_stats', 'limit') &&
        stats.dig('memory_stats','stats','cache')

      # As we are doing integer maths, the 100* needs to go before the division
      cache_use = stats.dig('memory_stats','stats','cache').to_i rescue 0
      total_use = stats.dig('memory_stats', 'usage').to_i rescue 0
      max_use = stats.dig('memory_stats', 'max_usage').to_i rescue 0
      mem_limit = stats.dig('memory_stats', 'limit').to_i rescue 1024
      stats['memory_stats']['_usage_percent'] = 100 * (total_use - cache_use) / mem_limit  ## Current use excludes cache
      stats['memory_stats']['_max_usage_percent'] = 100 * (max_use) / mem_limit            ## Max use includes cache
    end

    if  stats.dig('cpu_stats', 'cpu_usage', 'total_usage') &&
        stats.dig('cpu_stats', 'cpu_usage', 'percpu_usage') &&
        stats.dig('cpu_stats', 'system_cpu_usage')

      total_usage = stats.dig('cpu_stats', 'cpu_usage', 'total_usage')
      ncpu = stats.dig('cpu_stats', 'online_cpus') rescue stats.dig('cpu_stats', 'cpu_usage', 'percpu_usage').length
      system_cpu_usage = stats.dig('cpu_stats', 'system_cpu_usage')

      $stderr.puts "= Per CPU Usage for #{stats.dig('id')}: #{stats.dig('cpu_stats', 'cpu_usage', 'percpu_usage')}" if DEBUG
      $stderr.puts "= Number of CPUs for #{stats.dig('id')}: #{ncpu}" if DEBUG

      if history.set?(stats.dig('id'))
        previous = history.get(stats.dig('id'))
        $stderr.puts "= Previous for #{stats.dig('id')}: #{previous.inspect}" if DEBUG
        cpu_delta = total_usage - previous[:tu]
        system_delta = system_cpu_usage - previous[:scu]
        cpu_percent = (system_delta > 0 && cpu_delta > 0) ? (cpu_delta.to_f / system_delta.to_f) * ncpu.to_f * 100.0 : 0.0
        $stderr.puts "= CPU percent for #{stats.dig('id')}: #{cpu_percent}" if DEBUG
        stats['cpu_stats']['_cpu_usage_percent'] = cpu_percent.dup
      end

      history.set(stats.dig('id'), expires_in: WAIT_TIME * 3) {{
        tu: total_usage,
        scu: system_cpu_usage
      }}
    end

    $stderr.puts "= Fluent post: #{_c['State']}, #{_c['Id']}" if DEBUG
    unless fluent.post(_c['Id'], {
      id: _c['Id'],
      names: _c['Names'],
      image: _c['Image'],
      state: _c['State'],
      status: _c['Status'],
      labels: _c['Labels'].inject({}){ |hash, (k, v)| hash.merge( k.tr('.', '#') => v )  },
      size: _c['SizeRootFs'] / 1024 / 1024,
      stats: stats
    })
      $stderr.puts fluent.last_error
      sleep 10
    end
  end
  sleep(WAIT_TIME)
end


