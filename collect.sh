#!/bin/sh

set -e

#
# Globals
#

: ${CEPH_SCRIPTS_DIR:=$(readlink -f $(dirname $0))}
: ${CEPH_DATA_DIR:=${CEPH_SCRIPTS_DIR}/data}

DATE=$(date '+%F')

_CEPH_CLUSTER_IPS=

#
# Functions
#

list_ips()
{
    test -z "${_CEPH_CLUSTER_IPS}" &&
    _CEPH_CLUSTER_IPS=$(
	(
	    for id in `ceph osd ls`
	    do
		ceph osd find ${id} |
		sed -nEe 's/^.*"ip": "([^:]*):.*/\1/p'
	    done
	    ceph mon dump 2>/dev/null |
	    sed -nEe 's/^[0-9]*: ([^:]*):.*$/\1/p'
	) | sort -u
    )
    echo ${_CEPH_CLUSTER_IPS}
    return
}

is_my_ip()
{
    local ip=$1

    ip address list | fgrep -q "inet ${ip}/"
}

prepare()
{
    mkdir -p "${CEPH_DATA_DIR}"

    for ip in $(list_ips)
    do
	if ! is_my_ip ${ip}
	then
	    deploy_scripts ${ip}
	fi
    done

    trap "pkill -P $$" INT TERM
}

deploy_scripts()
{
    local ip=$1

    tar -C / -cf - "${CEPH_SCRIPTS_DIR}" |
    ssh ${ip} tar -C / -xf -
}

collect_host_stats()
{
    local ip=$1
    local period=$2
    local count=$3

    # Forse 10 sec period if it is larger
    if [ -n "${count}" -a -n "${period}" ] && [ "${period}" -gt 10 ]
    then
	count=$((count * period / 10))
	period=10
    fi

    mkdir -p "${CEPH_DATA_DIR}"/${ip}
    ssh ${ip} ${CEPH_SCRIPTS_DIR}/host-stats/report.sh || :
    ssh ${ip} ${CEPH_SCRIPTS_DIR}/ceph-stats/report_all_daemons.sh || :
    ssh ${ip} ${CEPH_SCRIPTS_DIR}/host-stats/collect.sh ${period} ${count} || :
    ssh ${ip} ${CEPH_SCRIPTS_DIR}/host-stats/report.sh || :
    ssh ${ip} ${CEPH_SCRIPTS_DIR}/ceph-stats/report_all_daemons.sh || :
    scp ${ip}:"/var/log/ceph/ceph-*.log" "${CEPH_DATA_DIR}/${ip}"
}

collect_perf_stats()
{
    local ip=$1; shift

    ssh ${ip} ${CEPH_SCRIPTS_DIR}/ceph-stats/collect-perf_all_daemons.sh "$@" || :
    scp ${ip}:"/var/log/ceph/ceph-stats.*.perf.${DATE}.log" "${CEPH_DATA_DIR}"
}

collect_ceph_stats()
{
    ${CEPH_SCRIPTS_DIR}/ceph-stats/collect.sh "$@"
    cp /var/log/ceph/ceph-stats.${DATE}.log "${CEPH_DATA_DIR}"
}

collect()
{
    for ip in $(list_ips)
    do
	collect_host_stats ${ip} "$@"&
	collect_perf_stats ${ip} "$@"&
    done

    collect_ceph_stats "$@"&

    wait
}

make_tarball()
{
    local rootdir=$(dirname "${CEPH_DATA_DIR}")
    local datadir=$(basename "${CEPH_DATA_DIR}")

    tar -C "${rootdir}" -czf "${datadir}.tar.gz" "${datadir}"
}


#
# Main
#

prepare
collect "$@"
make_tarball
