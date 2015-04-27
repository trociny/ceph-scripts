#!/bin/sh

#
# Globals
#

# Ceph stats data to generate

CEPHSTATS_DATA_df_rbd_objects="df 'pools 0 stats objects'"
CEPHSTATS_DATA_df_rbd_kb_used="df 'pools 0 stats kb_used'"
CEPHSTATS_DATA_monmap_election_epoch="status 'election_epoch'"
CEPHSTATS_DATA_osdmap_osds="status 'osdmap osdmap num_osds' 'osdmap osdmap num_up_osds' 'osdmap osdmap num_in_osds'"
CEPHSTATS_DATA_osdmap_remapped_pgs="status 'osdmap osdmap num_remapped_pgs'"
CEPHSTATS_DATA_pgmap_version="status 'pgmap version'"
CEPHSTATS_DATA_pgmap_data_bytes="status 'pgmap data_bytes'"
CEPHSTATS_DATA_pgmap_usage="status 'pgmap bytes_used' 'pgmap bytes_avail' 'pgmap bytes_total'"

# Generate data for this date
: ${CEPHSTATS_DATE:=$(date '+%F')}

# Gnuplot command (set to empty to disable graphs)
: ${CEPHSTATS_GNUPLOT:=gnuplot}

# Location of ceph-stats scripts
: ${CEPHSTATS_BINDIR:=$(pwd)}

# Location of generated data
: ${CEPHSTATS_DATADIR:=$(pwd)/data}

# Location of generated plots
: ${CEPHSTATS_PLOTDIR:=$(pwd)/plot}

# Gnuplot command (set to empty to disable graphs)
: ${CEPHSTATS_DEBUG:=1}

#
# Functions
#

debug()
{
    test -n "${CEPHSTATS_DEBUG}" || return

    echo "DEBUG: $@" >&2
}

list_vars()
{
    local line var

    set |
    while read line
    do
        var="${line%%=*}"
        case "${var}" in
            "${line}"|*[!a-zA-Z0-9_]*)
		continue
		;;
            $1)
		echo ${var}
		;;
	esac
    done
}

generate_data()
{
    local cmd name var

    if ! mkdir -p "${CEPHSTATS_DATADIR}"
    then
	echo "Failed to create CEPHSTATS_DATADIR" >&2
	exit 1
    fi

    for var in $(list_vars 'CEPHSTATS_DATA_*')
    do
	name=${var##CEPHSTATS_DATA_}
	debug "Processing $name"
	(eval exec "${CEPHSTATS_BINDIR}/process.py" -d "${CEPHSTATS_DATE}" \
	    $(eval echo \$${var})
	) > "${CEPHSTATS_DATADIR}/${name}.${CEPHSTATS_DATE}.dat"
    done

}

generate_plots()
{
    local f

    if [ -z "${CEPHSTATS_GNUPLOT}" ]
    then
	return
    fi

    if ! mkdir -p "${CEPHSTATS_PLOTDIR}"
    then
	echo "Failed to create CEPHSTATS_PLOTDIR" >&2
	exit 1
    fi

    for f in "${CEPHSTATS_DATADIR}"/*."${CEPHSTATS_DATE}.dat"
    do
	debug "Plotting $name"
	(
	    echo "set term png size 800,600"
	    echo "set output '${CEPHSTATS_PLOTDIR}/$(basename $f .dat).png'"
	    echo "set timefmt '%Y-%m-%d %H:%M'"
	    echo "set xdata time"
	    echo "set format x '%H:%M'"
	    echo "set xlabel 'time'"
	    echo "set ylabe '$(basename $f .${CEPHSTATS_DATE}.dat)'"
	    echo "set title '$(basename $f .${CEPHSTATS_DATE}.dat) ${CEPHSTATS_DATE}'"
	    echo -n "plot"
	    head -1 ${f} | sed -e 's/#"date" "time" "//; s/" "/\n/g; s/"//;' |
	    awk "{
                   if (NR > 1) printf \",\"
                   printf \" '%s' using 1:%d title '%s'\", \""${f}"\", NR + 2, \$0
                 }"
	    echo
	) | gnuplot
    done
}

main()
{
    generate_data
    generate_plots
}

#
# Main
#

main
