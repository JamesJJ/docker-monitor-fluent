# Docker Monitor Fluent
*Docker Hub: [jamesjj/docker-monitor-fluent](https://hub.docker.com/r/jamesjj/docker-monitor-fluent/)*

[![CodeFactor](https://www.codefactor.io/repository/github/JamesJJ/docker-monitor-fluent/badge)](https://www.codefactor.io/repository/github/JamesJJ/docker-monitor-fluent)
[![Docker Automated build](https://img.shields.io/docker/automated/jamesjj/docker-monitor-fluent.svg)](https://hub.docker.com/r/jamesjj/docker-monitor-fluent/)
[![Docker Automated build](https://img.shields.io/docker/build/jamesjj/docker-monitor-fluent.svg)](https://hub.docker.com/r/jamesjj/docker-monitor-fluent/)


This docker container will read resource usage statistics for each running container, and then forward the data as JSON to Fluentd.

### Why?
Simple free detailed read-only monitoring and analysis!

This is a very lightweight container that you can run on each of your docker machines. Forwarding to fluentd is an easy way to aggregate the resource data. Fluentd has many [plugins](https://www.fluentd.org/plugins), so for example fluentd can directly input data to Elasticsearch, and then you can query or visualalize with Kibana.

![Container memory usage](test/201608-docker-cluster-memory.jpg?raw=true "Container memory usage")
*Screenshot: Memory usage for each container in a docker cluster visualized in Kibana*

### What information is available?

* Network interface counters (tx/rx/bytes/packets/dropped/errors)
* Memory (many many counters)
* CPU (usermode/kernelmode/per_cpu/system/throttling)
* Image name
* Container name
* Container ID
* Container state
* Disk usage

### Where does the usage information come from?
We call Docker's built-in API, using a UNIX socket or network connection:

* [More information about Docker's built-in API](https://docs.docker.com/engine/reference/api/docker_remote_api_v1.24/#/get-container-stats-based-on-resource-usage)

# How to use this container

### Supported environment variables

Name            | Default   | Description
---:            | :---      | :---
`DEBUG`         | `false`   | Normally a just short message is shown when this container starts. Setting `DEBUG` to `true` will output continuous verbose debug information.
`FLUENTD_HOST`  | `fluentd` | The hostname of your Fluentd
`FLUENTD_PORT`  | `24224`   | The port your Fluentd is listening on (see `./test/fluentd.conf`)
`TAG_PREFIX`    | null      | Each message sent to Fluentd will be tagged with: `<TAG_PREFIX>.<container-id>`
`WAIT_TIME`     | `60`      | How long to wait in seconds between each data collection
`DOCKER_SOCKET` | `unix:///var/run/docker.sock` | The address of your docker daemon. The recommended way to connect is by mounting the docker UNIX socket in to the container using a volume e.g. `docker run -it -v /var/run/docker.sock:/var/run/docker.sock jamesjj/docker-monitor-fluent:prod` ...but you should also be able to specify a TCP/HTTP endpoint here if you have configured your Docker daemon to listen on the network e.g. `http://127.0.0.1:8088`
 
## Simple demo

This demo will just start this monitoring container and a fluentd container. The resource ststistics will be dumped as JSON to fluentd's STDOUT.

* Install Docker + Docker Compose
* Clone this repo
`git clone https://github.com/JamesJJ/docker-monitor-fluent.git`
* Run it:

```
$ docker-compose up --force-recreate
Recreating dockermonitorfluent_fluentd-test_1
Recreating dockermonitorfluent_docker-monitor_1
Attaching to dockermonitorfluent_docker-monitor_1, dockermonitorfluent_fluentd-test_1
fluentd-test_1    | 2016-08-02 15:17:15 +0000 [info]: reading config file path="/fluentd/etc/test/fluentd.conf"
fluentd-test_1    | 2016-08-02 15:17:15 +0000 [info]: starting fluentd-0.12.26
fluentd-test_1    | 2016-08-02 15:17:15 +0000 [info]: gem 'fluentd' version '0.12.26'
fluentd-test_1    | 2016-08-02 15:17:15 +0000 [info]: adding match pattern="testing_docker_monitor.**" type="stdout"
fluentd-test_1    | 2016-08-02 15:17:15 +0000 [info]: adding match pattern="**" type="null"
fluentd-test_1    | 2016-08-02 15:17:15 +0000 [info]: adding source type="forward"
fluentd-test_1    | 2016-08-02 15:17:15 +0000 [info]: using configuration file: <ROOT>
fluentd-test_1    |   <source>
fluentd-test_1    |     @type forward
fluentd-test_1    |     port 24224
fluentd-test_1    |     bind 0.0.0.0
fluentd-test_1    |   </source>
fluentd-test_1    |   <match testing_docker_monitor.**>
fluentd-test_1    |     @type stdout
fluentd-test_1    |     output_type json
fluentd-test_1    |   </match>
fluentd-test_1    |   <match **>
fluentd-test_1    |     @type null
fluentd-test_1    |   </match>
fluentd-test_1    | </ROOT>
fluentd-test_1    | 2016-08-02 15:17:15 +0000 [info]: listening fluent socket on 0.0.0.0:24224
fluentd-test_1    | 2016-08-02 15:17:17 +0000 testing_docker_monitor.05575d2f7c3eb77dd3d3fe4a6c00fe161616d42603bc4e689ca92159e29c5f6c: {
    "id": "05575d2f7c3eb77dd3d3fe4a6c00fe161616d42603bc4e689ca92159e29c5f6c",
    "image": "jamesjj/docker-monitor-fluent:prod",
    "names": [
        "/dockermonitorfluent_docker-monitor_1"
    ],
    "size": 43,
    "state": "running",
    "stats": {
        "blkio_stats": {
            "io_merged_recursive": [],
            "io_queue_recursive": [],
            "io_service_bytes_recursive": [],
            "io_service_time_recursive": [],
            "io_serviced_recursive": [],
            "io_time_recursive": [],
            "io_wait_time_recursive": [],
            "sectors_recursive": []
        },
        "cpu_stats": {
            "cpu_usage": {
                "percpu_usage": [
                    123127181,
                    19924385
                ],
                "total_usage": 143051566,
                "usage_in_kernelmode": 40000000,
                "usage_in_usermode": 100000000
            },
            "system_cpu_usage": 73929710000000,
            "throttling_data": {
                "periods": 0,
                "throttled_periods": 0,
                "throttled_time": 0
            }
        },
        "memory_stats": {
            "failcnt": 0,
            "limit": 2097827840,
            "max_usage": 8843264,
            "stats": {
                "active_anon": 8642560,
                "active_file": 0,
                "cache": 16384,
                "dirty": 0,
                "hierarchical_memory_limit": 9223372036854771712,
                "hierarchical_memsw_limit": 9223372036854771712,
                "inactive_anon": 0,
                "inactive_file": 0,
                "mapped_file": 0,
                "pgfault": 2511,
                "pgmajfault": 0,
                "pgpgin": 2405,
                "pgpgout": 295,
                "rss": 8626176,
                "rss_huge": 0,
                "swap": 0,
                "total_active_anon": 8642560,
                "total_active_file": 0,
                "total_cache": 16384,
                "total_dirty": 0,
                "total_inactive_anon": 0,
                "total_inactive_file": 0,
                "total_mapped_file": 0,
                "total_pgfault": 2511,
                "total_pgmajfault": 0,
                "total_pgpgin": 2405,
                "total_pgpgout": 295,
                "total_rss": 8626176,
                "total_rss_huge": 0,
                "total_swap": 0,
                "total_unevictable": 0,
                "total_writeback": 0,
                "unevictable": 0,
                "writeback": 0
            },
            "usage": 8835072
        },
        "networks": {
            "eth0": {
                "rx_bytes": 1132,
                "rx_dropped": 0,
                "rx_errors": 0,
                "rx_packets": 14,
                "tx_bytes": 690,
                "tx_dropped": 0,
                "tx_errors": 0,
                "tx_packets": 9
            }
        },
        "pids_stats": {
            "current": 2
        },
        "precpu_stats": {
            "cpu_usage": {
                "percpu_usage": [
                    123127181,
                    19924385
                ],
                "total_usage": 143051566,
                "usage_in_kernelmode": 40000000,
                "usage_in_usermode": 100000000
            },
            "system_cpu_usage": 73927720000000,
            "throttling_data": {
                "periods": 0,
                "throttled_periods": 0,
                "throttled_time": 0
            }
        },
        "read": "2016-08-02T15:17:17.854008301Z"
    },
    "status": "Up 2 seconds"
}
fluentd-test_1    | 2016-08-02 15:17:19 +0000 testing_docker_monitor.ee7f3f84f5c2e846e12d335d13934472fc5feddb5bfe9d620835641f1aa8082f: {
    "id": "ee7f3f84f5c2e846e12d335d13934472fc5feddb5bfe9d620835641f1aa8082f",
    "image": "fluent/fluentd:latest",
    "names": [
        "/dockermonitorfluent_fluentd-test_1"
    ],
    "size": 36,
    "state": "running",
    "stats": {
        "blkio_stats": {
            "io_merged_recursive": [],
            "io_queue_recursive": [],
            "io_service_bytes_recursive": [],
            "io_service_time_recursive": [],
            "io_serviced_recursive": [],
            "io_time_recursive": [],
            "io_wait_time_recursive": [],
            "sectors_recursive": []
        },
        "cpu_stats": {
            "cpu_usage": {
                "percpu_usage": [
                    126266750,
                    316274500
                ],
                "total_usage": 442541250,
                "usage_in_kernelmode": 80000000,
                "usage_in_usermode": 370000000
            },
            "system_cpu_usage": 73933710000000,
            "throttling_data": {
                "periods": 0,
                "throttled_periods": 0,
                "throttled_time": 0
            }
        },
        "memory_stats": {
            "failcnt": 0,
            "limit": 2097827840,
            "max_usage": 33087488,
            "stats": {
                "active_anon": 32989184,
                "active_file": 0,
                "cache": 28672,
                "dirty": 0,
                "hierarchical_memory_limit": 9223372036854771712,
                "hierarchical_memsw_limit": 9223372036854771712,
                "inactive_anon": 0,
                "inactive_file": 4096,
                "mapped_file": 0,
                "pgfault": 8667,
                "pgmajfault": 0,
                "pgpgin": 8386,
                "pgpgout": 331,
                "rss": 32964608,
                "rss_huge": 0,
                "swap": 0,
                "total_active_anon": 32989184,
                "total_active_file": 0,
                "total_cache": 28672,
                "total_dirty": 0,
                "total_inactive_anon": 0,
                "total_inactive_file": 4096,
                "total_mapped_file": 0,
                "total_pgfault": 8667,
                "total_pgmajfault": 0,
                "total_pgpgin": 8386,
                "total_pgpgout": 331,
                "total_rss": 32964608,
                "total_rss_huge": 0,
                "total_swap": 0,
                "total_unevictable": 0,
                "total_writeback": 0,
                "unevictable": 0,
                "writeback": 0
            },
            "usage": 33087488
        },
        "networks": {
            "eth0": {
                "rx_bytes": 2668,
                "rx_dropped": 0,
                "rx_errors": 0,
                "rx_packets": 13,
                "tx_bytes": 690,
                "tx_dropped": 0,
                "tx_errors": 0,
                "tx_packets": 9
            }
        },
        "pids_stats": {
            "current": 6
        },
        "precpu_stats": {
            "cpu_usage": {
                "percpu_usage": [
                    126154899,
                    315176563
                ],
                "total_usage": 441331462,
                "usage_in_kernelmode": 80000000,
                "usage_in_usermode": 370000000
            },
            "system_cpu_usage": 73931720000000,
            "throttling_data": {
                "periods": 0,
                "throttled_periods": 0,
                "throttled_time": 0
            }
        },
        "read": "2016-08-02T15:17:19.851005175Z"
    },
    "status": "Up 1 seconds"
}

^C
Gracefully stopping... (press Ctrl+C again to force)
Stopping dockermonitorfluent_docker-monitor_1 ... done
Stopping dockermonitorfluent_fluentd-test_1 ... done
```
