#!/bin/bash

host=$(hostname)

ARCH=$(uname -m)

KERNEL_STRING=$(uname -r | sed -e 's/[^0-9]/ /g')
KERNEL_VERSION=$(echo "${KERNEL_STRING}" | awk '{ print $1 }')
MAJOR_VERSION=$(echo "${KERNEL_STRING}" | awk '{ print $2 }')
MINOR_VERSION=$(echo "${KERNEL_STRING}" | awk '{ print $3 }')
echo "${KERNEL_VERSION}.${MAJOR_VERSION}.${MINOR_VERSION}"

which bc
if [ $? -ne 0 ]; then
    echo "This script require GNU bc, cf. http://www.gnu.org/software/bc/"
fi

echo "Update sysctl for $host"

mem_bytes=$(awk '/MemTotal:/ { printf "%0.f",$2 * 1024}' /proc/meminfo)
shmmax=$(echo "$mem_bytes * 0.90" | bc | cut -f 1 -d '.')
shmall=$(expr $mem_bytes / $(getconf PAGE_SIZE))
max_orphan=$(echo "$mem_bytes * 0.10 / 65536" | bc | cut -f 1 -d '.')
file_max=$(echo "$mem_bytes / 4194304 * 256" | bc | cut -f 1 -d '.')
max_tw=$(($file_max*2))
min_free=$(echo "($mem_bytes / 1024) * 0.01" | bc | cut -f 1 -d '.')

if [ "$1" != "ssd" ]; then
    vm_dirty_bg_ratio=5
    vm_dirty_ratio=15
else
    # This setup is generally ok for ssd and highmem servers
    vm_dirty_bg_ratio=3
    vm_dirty_ratio=5
fi
 
>/etc/sysctl.d/60-init.conf cat << EOF
# Disable IPv6
net.ipv6.conf.all.disable_ipv6 = 1

# Disable IPV6 if it is not needed
net.ipv6.conf.all.disable_ipv6 = 1

# TODO : change TCP_SYNQ_HSIZE in include/net/tcp.h
# to keep TCP_SYNQ_HSIZE*16<=tcp_max_syn_backlog
net.ipv4.tcp_max_syn_backlog = 65536

# Enable faster reuse for TIME-WAIT sockets
net.ipv4.tcp_tw_reuse = 1

# Increase Linux autotuning TCP buffer limits
# Set max to 16MB for 1GE and 32M (33554432) or 54M (56623104) for 10GE
# Don't set tcp_mem itself! Let the kernel scale it based on RAM.
net.core.rmem_default = 16777216
net.core.wmem_default = 16777216
net.core.optmem_max = 81920

# Disable TCP slow start on idle connections
net.ipv4.tcp_slow_start_after_idle = 0

kernel.core_pattern = core.%e.%p.%t

# This file (new in Linux 2.5) specifies the value at which PIDs wrap around
# (i.e., the value in this file is one greater than the maximum PID). The
# default value for this file, 32768, results in the same range of PIDs as
# on earlier kernels. On 32-bit platfroms, 32768 is the maximum value for
# pid_max. On 64-bit systems, pid_max can be set to any value up to 2^22
# (PID_MAX_LIMIT, approximately 4 million).
kernel.pid_max = 4194303

EOF

/sbin/sysctl --system
exit $?

