#!/usr/bin/ruby

require 'fluent-logger'
require 'net_http_unix'
require 'json'
require 'time'

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
sleep (2)

client = NetX::HTTPUnix.new(DOCKER_SOCKET) unless client
list_containers_req = Net::HTTP::Get.new("/containers/json?all=1&size=1") unless list_containers_req
fluent = Fluent::Logger::FluentLogger.new(TAG_PREFIX, :host=>FLUENTD_HOST, :port=>FLUENTD_PORT, :log_reconnect_error_threshold=>0, :buffer_limit=>16384)
loop do
  $stderr.puts "= Starting main loop" if DEBUG
  containers_resp = client.request(list_containers_req)
  if (containers_resp.code.to_s != '200') then
    $stderr.puts "= Error reading from: #{DOCKER_SOCKET} (#{containers_resp.code})"
    sleep (2)
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
    else
      next
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
      exit(1)
    end
  end
  sleep(WAIT_TIME)
end


