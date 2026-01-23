#!/bin/sh

(ping 8.8.8.8 -i 0.05 > ping.log )&
ssh root@2a0a:4587:2032:614:ee08:6bff:fe8a:d26c /root/wg_trace_delay_c > wg_trace_delay_c.log
