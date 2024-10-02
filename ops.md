# EMQX Ops

## start service
```
systemctl start emqx
```

## stop service
```
systemctl stop emqx
```

## systemd status
```
systemctl status emqx
```

## Restapi secret
```
curl key:secret@localhost:18083/api/v5/metrics

```

## Remote shell

```
ssh emqx-0

```
then open remote console
```
sudo emqx remote_console
```

# Loadgen Ops

# Basics

First ssh to loadgen

``` bash
# become root
sudo bash

# goto /root/emqtt-bench
cd /root/emqtt-bench

./emqtt_bench conn -h lb.int.william

```


## Loadgen examples

### Reconnect tests
```
a=0; until timeout 130 bin/emqtt_bench pub -h emqx-0.int.william -t a -S -p 8883 ./quic_conn.eterm  -c 12500 -R 100 -k 0 --prefix BB ; do echo $a; let a=$a+1; done;
```
