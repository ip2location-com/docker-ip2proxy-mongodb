#!/bin/bash

if [ -n "$NO_COLOR" ]; then
	C_RESET=; C_DIM=; C_BOLD=; C_OK=; C_WARN=; C_ERR=
else
	C_RESET=$'\e[0m'; C_DIM=$'\e[2m'; C_BOLD=$'\e[1m'
	C_OK=$'\e[32m'; C_WARN=$'\e[33m'; C_ERR=$'\e[31m'
fi

STEP_N=0
STEP_WIDTH=58

banner() {
	printf '\n%s  %s%s\n%s  %s%s\n\n' \
		"$C_BOLD" "$1" "$C_RESET" \
		"$C_DIM" "$(printf '─%.0s' $(seq 1 $((${#1} + 2))))" "$C_RESET"
}

step() {
	STEP_N=$((STEP_N + 1))
	printf '  %s%2d.%s ' "$C_DIM" "$STEP_N" "$C_RESET"
	local label="$1"

	[ ${#label} -gt "$STEP_WIDTH" ] && label="${label:0:$((STEP_WIDTH - 3))}..."

	local pad=$((STEP_WIDTH - ${#label})) dots=""
	[ $pad -gt 0 ] && dots="$(printf '·%.0s' $(seq 1 $pad))"

	printf '%s %s%s%s ' "$label" "$C_DIM" "$dots" "$C_RESET"
	printf '%s' "$C_DIM"
}
ok()   { if [ -n "$1" ]; then printf '%s✓%s %s(%s)%s\n' "$C_OK" "$C_RESET" "$C_DIM" "$1" "$C_RESET"; else printf '%s✓%s\n' "$C_OK" "$C_RESET"; fi; }
warn() { printf '%s!%s %s%s%s\n' "$C_WARN" "$C_RESET" "$C_DIM" "$1" "$C_RESET"; }
fail() { printf '%s✗%s %s\n' "$C_ERR" "$C_RESET" "$1"; exit 1; }

note()  { printf '     %s%s%s\n' "$C_DIM" "$1" "$C_RESET"; }
field() { printf '  %s%-9s%s %s\n' "$C_DIM" "$1" "$C_RESET" "$2"; }

group() {
	local n="$1" out=""
	while [ ${#n} -gt 3 ]; do
		out=",${n: -3}${out}"
		n="${n:0:${#n}-3}"
	done
	printf '%s%s' "$n" "$out"
}

summary() {
	printf '\n  %s✓%s %s%s%s\n' "$C_OK" "$C_RESET" "$C_BOLD$C_OK" "$1" "$C_RESET"
	[ -n "$2" ] && printf '    %s%s%s\n' "$C_DIM" "$2" "$C_RESET"
	printf '\n'
}

quiet_run() {
	local out rc
	out="$("$@" 2>&1)"
	rc=$?
	if [ $rc -ne 0 ]; then

		printf '%s\n' "$out" | tr '\r' '\n' | grep -v '^[[:space:]]*$' | tail -n 15
	fi
	return $rc
}

elapsed() { echo "$(( $(date +%s) - $1 ))s"; }

[ ! -f /ip2proxy.conf ] && fail "Missing configuration file."

banner "IP2Proxy Database Update"

USER_AGENT="Mozilla/5.0+(compatible; IP2Proxy/MongoDB-Docker; https://hub.docker.com/r/ip2proxy/mongodb)"
TOKEN=$(grep '^TOKEN=' /ip2proxy.conf | cut -d= -f2-)
CODE=$(grep '^CODE=' /ip2proxy.conf | cut -d= -f2-)
CODE_INPUT="$CODE"
IP_TYPE=$(grep '^IP_TYPE=' /ip2proxy.conf | cut -d= -f2-)
MONGODB_PASSWORD=$(grep '^MONGODB_PASSWORD=' /ip2proxy.conf | cut -d= -f2-)

if [ "$IP_TYPE" == "IPV6" ]; then
	IP_TYPE="IPV6"
	SUFFIX="CSVIPV6"
	CODE_SUFFIX="IPV6"
else
	IP_TYPE="IPV4"
	SUFFIX="CSV"
	CODE_SUFFIX=""
fi

CASE_CODE="$(echo $CODE | sed 's/-//')${CODE_SUFFIX}"

rm -rf /_tmp && mkdir /_tmp && cd /_tmp

step "Download IP2Proxy $IP_TYPE database"

ARCHIVE="/_tmp/database.zip"
wget -O "$ARCHIVE" -q --user-agent="$USER_AGENT" "https://www.ip2location.com/download?token=${TOKEN}&code=$(echo $CODE | sed 's/-//')${SUFFIX}" > /dev/null 2>&1

[ ! -z "$(grep 'NO PERMISSION' "$ARCHIVE")" ] && fail "DENIED"
[ ! -z "$(grep '5 TIMES' "$ARCHIVE")" ] && fail "QUOTA EXCEEDED"

unzip -t "$ARCHIVE" >/dev/null 2>&1

[ $? -ne 0 ] && fail "FILE CORRUPTED"

ok

CSV=$(unzip -l "$ARCHIVE" | sort -nr | grep -Eio 'IP(V6)?.*CSV' | head -n 1)

step "Decompress the downloaded archive"

unzip -oq "$ARCHIVE" "$CSV"

if [ ! -f "/_tmp/$CSV" ]; then
	fail "ERROR"
fi

ok

case "$CASE_CODE" in
	PX1|PX1IPV6|PX1LITECSV|PX1LITECSVIPV6|PX1LITE|PX1LITEIPV6 )
		FIELDS=',country_code,country_name'
	;;

	PX2|PX2IPV6|PX2LITECSV|PX2LITECSVIPV6|PX2LITE|PX2LITEIPV6 )
		FIELDS=',proxy_type,country_code,country_name'
	;;

	PX3|PX3IPV6|PX3LITECSV|PX3LITECSVIPV6|PX3LITE|PX3LITEIPV6 )
		FIELDS=',proxy_type,country_code,country_name,region_name,city_name'
	;;

	PX4|PX4IPV6|PX4LITECSV|PX4LITECSVIPV6|PX4LITE|PX4LITEIPV6 )
		FIELDS=',proxy_type,country_code,country_name,region_name,city_name,isp'
	;;

	PX5|PX5IPV6|PX5LITECSV|PX5LITECSVIPV6|PX5LITE|PX5LITEIPV6 )
		FIELDS=',proxy_type,country_code,country_name,region_name,city_name,isp,domain'
	;;

	PX6|PX6IPV6|PX6LITECSV|PX6LITECSVIPV6|PX6LITE|PX6LITEIPV6 )
		FIELDS=',proxy_type,country_code,country_name,region_name,city_name,isp,domain,usage_type'
	;;

	PX7|PX7IPV6|PX7LITECSV|PX7LITECSVIPV6|PX7LITE|PX7LITEIPV6 )
		FIELDS=',proxy_type,country_code,country_name,region_name,city_name,isp,domain,usage_type,asn,as'
	;;

	PX8|PX8IPV6|PX8LITECSV|PX8LITECSVIPV6|PX8LITE|PX8LITEIPV6 )
		FIELDS=',proxy_type,country_code,country_name,region_name,city_name,isp,domain,usage_type,asn,as,last_seen'
	;;

	PX9|PX9IPV6|PX9LITECSV|PX9LITECSVIPV6|PX9LITE|PX9LITEIPV6 )
		FIELDS=',proxy_type,country_code,country_name,region_name,city_name,isp,domain,usage_type,asn,as,last_seen,threat'
	;;

	PX10|PX10IPV6|PX10LITECSV|PX10LITECSVIPV6|PX10LITE|PX10LITEIPV6 )
		FIELDS=',proxy_type,country_code,country_name,region_name,city_name,isp,domain,usage_type,asn,as,last_seen,threat'
	;;

	PX11|PX11IPV6|PX11LITECSV|PX11LITECSVIPV6|PX11LITE|PX11LITEIPV6 )
		FIELDS=',proxy_type,country_code,country_name,region_name,city_name,isp,domain,usage_type,asn,as,last_seen,threat,provider'
	;;

	PX12|PX12IPV6|PX12LITECSV|PX12LITECSVIPV6|PX12LITE|PX12LITEIPV6 )
		FIELDS=',proxy_type,country_code,country_name,region_name,city_name,isp,domain,usage_type,asn,as,last_seen,threat,provider,fraud_score'
	;;
esac

if [ "$IP_TYPE" == "IPV6" ]; then
	step "Create index fields"
	cat "$CSV" | awk 'BEGIN { FS="\",\""; } { s1 = "0000000000000000000000000000000000000000"substr($1, 2); s2 = "0000000000000000000000000000000000000000"$2; print "\"A"substr(s1, 1 + length(s1) - 40)"\",""\"A"substr(s2, 1 + length(s2) - 40)"\","$0; }' > ./INDEXED.CSV

	[ $? -ne 0 ] && fail "ERROR" || ok

	T1=$(date +%s)
	step "Import the CSV into a new collection"
	quiet_run mongoimport -u mongoAdmin -p "$MONGODB_PASSWORD" --authenticationDatabase admin --drop --db ip2proxy_database --collection ip2proxy_database_tmp --type csv --file "./INDEXED.CSV" --fields ip_from_index,ip_to_index,ip_from,ip_to$FIELDS

	[ $? -ne 0 ] && fail "ERROR" || ok "$(elapsed $T1)"

	step "Create index"
	quiet_run mongosh -u mongoAdmin -p "$MONGODB_PASSWORD" --authenticationDatabase admin --quiet --eval 'db.getSiblingDB("ip2proxy_database").ip2proxy_database_tmp.createIndex({ip_from_index: 1, ip_to_index: 1})'

	[ $? -ne 0 ] && fail "ERROR" || ok
else
	T1=$(date +%s)
	step "Import the CSV into a new collection"
	quiet_run mongoimport -u mongoAdmin -p "$MONGODB_PASSWORD" --authenticationDatabase admin --drop --db ip2proxy_database --collection ip2proxy_database_tmp --type csv --file "$CSV" --fields ip_from,ip_to$FIELDS

	[ $? -ne 0 ] && fail "ERROR" || ok "$(elapsed $T1)"

	step "Create index"
	quiet_run mongosh -u mongoAdmin -p "$MONGODB_PASSWORD" --authenticationDatabase admin --quiet --eval 'db.getSiblingDB("ip2proxy_database").ip2proxy_database_tmp.createIndex({ip_from: 1, ip_to: 1})'

	[ $? -ne 0 ] && fail "ERROR" || ok
fi

step "Activate ip2proxy_database"
quiet_run mongosh -u mongoAdmin -p "$MONGODB_PASSWORD" --authenticationDatabase admin --quiet --eval 'db.getSiblingDB("ip2proxy_database").ip2proxy_database_tmp.renameCollection("ip2proxy_database", true)'

[ $? -ne 0 ] && fail "ERROR" || ok

rm -rf /_tmp

summary "Update completed" "$CODE_INPUT ($IP_TYPE) refreshed"
field "Database" "ip2proxy_database"
note "The previous data was dropped only after the new table finished loading."
printf '\n'
