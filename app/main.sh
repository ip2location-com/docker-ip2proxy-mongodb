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

USER_AGENT="Mozilla/5.0+(compatible; IP2Proxy/MongoDB-Docker; https://hub.docker.com/r/ip2proxy/mongodb)"
CODES=(PX1-LITE PX2-LITE PX3-LITE PX4-LITE PX5-LITE PX6-LITE PX7-LITE PX8-LITE PX9-LITE PX10-LITE PX11-LITE PX12-LITE PX1 PX2 PX3 PX4 PX5 PX6 PX7 PX8 PX9 PX10 PX11 PX12)

trim() { local v="${1//$'\r'/}"; v="${v#"${v%%[![:space:]]*}"}"; v="${v%"${v##*[![:space:]]}"}"; printf '%s' "$v"; }

TOKEN="$(trim "$TOKEN")"
CODE="$(trim "$CODE")"
IP_TYPE="$(trim "$IP_TYPE")"
CODE_INPUT="$CODE"

if [ -f /ip2proxy.conf ]; then
	CONF_TOKEN="$(grep '^TOKEN=' /ip2proxy.conf | cut -d= -f2-)"
	CONF_CODE="$(grep '^CODE=' /ip2proxy.conf | cut -d= -f2-)"
	CONF_IP_TYPE="$(grep '^IP_TYPE=' /ip2proxy.conf | cut -d= -f2-)"
	CONF_PASSWORD="$(grep '^MONGODB_PASSWORD=' /ip2proxy.conf | cut -d= -f2-)"

	if [ -n "$CODE_INPUT" ] && [ "$CODE_INPUT" != "$CONF_CODE" ]; then
		echo " > NOTE: CODE has changed from '$CONF_CODE' to '$CODE_INPUT', but the database"
		echo " >       is already installed. The existing data is kept. To install"
		echo " >       '$CODE_INPUT' instead, start a fresh container with an empty /data/db."
	fi
	if [ -n "$TOKEN" ] && [ "$TOKEN" != "$CONF_TOKEN" ]; then
		echo " > NOTE: TOKEN has changed but is not re-applied to an existing install."
	fi
	if [ -n "$IP_TYPE" ] && [ "$IP_TYPE" != "$CONF_IP_TYPE" ]; then
		echo " > NOTE: IP_TYPE has changed from '$CONF_IP_TYPE' to '$IP_TYPE', but the"
		echo " >       database is already installed and is not converted in place."
		echo " >       To install '$IP_TYPE', start a fresh container with an empty /data/db."
	fi
	if [ -n "$MONGODB_PASSWORD" ] && [ "$MONGODB_PASSWORD" != "$CONF_PASSWORD" ]; then
		echo " > NOTE: MONGODB_PASSWORD has changed but the existing admin password is kept."
		echo " >       Change it with: db.changeUserPassword('mongoAdmin', '...')"
	fi

	quiet_run mongod --quiet --fork --logpath /var/log/mongodb/mongod.log --auth --bind_ip_all
	tail -f /dev/null
fi

[ -z "$TOKEN" ] && fail "Missing download token. Pass it with -e TOKEN=..."
[ -z "$CODE" ] && fail "Missing database code. Pass it with -e CODE=... (e.g. PX1-LITE)"

if [ -z "$MONGODB_PASSWORD" ]; then
	MONGODB_PASSWORD="$(< /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c${1:-12})"
fi

export MONGODB_PASSWORD

FOUND=""
for i in "${CODES[@]}"; do
	if [ "$i" == "$CODE" ] ; then
		FOUND="$CODE"
	fi
done

if [ -z "$FOUND" ]; then
	fail "Download code '$CODE' is invalid. See the README for the list of supported codes."
fi

if [ "$IP_TYPE" == "IPV6" ]; then
	IP_TYPE="IPV6"
	SUFFIX="CSVIPV6"
	CODE_SUFFIX="IPV6"
else
	[ -n "$IP_TYPE" ] && [ "$IP_TYPE" != "IPV4" ] && echo " > IP_TYPE '$IP_TYPE' is not recognised, using IPV4."
	IP_TYPE="IPV4"
	SUFFIX="CSV"
	CODE_SUFFIX=""
fi

CASE_CODE="$(echo $CODE | sed 's/-//')${CODE_SUFFIX}"

banner "IP2Proxy Database Setup"
field "Database" "ip2proxy_database"
field "Code" "$CODE_INPUT"
field "IP type" "$IP_TYPE"

rm -rf /_tmp && mkdir /_tmp && cd /_tmp

echo ""
T0=$(date +%s)
step "Download IP2Proxy $IP_TYPE database"

ARCHIVE="/_tmp/database.zip"
wget -O "$ARCHIVE" -q --user-agent="$USER_AGENT" "https://www.ip2location.com/download?token=${TOKEN}&code=$(echo $CODE | sed 's/-//')${SUFFIX}" > /dev/null 2>&1

[ ! -z "$(grep 'NO PERMISSION' "$ARCHIVE")" ] && fail "DENIED"
[ ! -z "$(grep '5 TIMES' "$ARCHIVE")" ] && fail "QUOTA EXCEEDED"

unzip -t "$ARCHIVE" >/dev/null 2>&1

[ $? -ne 0 ] && fail "FILE CORRUPTED"

ok "$(( $(stat -c%s "$ARCHIVE") / 1048576 )) MB"

CSV=$(unzip -l "$ARCHIVE" | sort -nr | grep -Eio 'IP(V6)?.*CSV' | head -n 1)

T1=$(date +%s)
step "Decompress the downloaded archive"

unzip -oq "$ARCHIVE" "$CSV"

if [ ! -f "/_tmp/$CSV" ]; then
	fail "ERROR"
fi

ok "$(elapsed $T1)"

step "Create data directory"
mkdir -p /data/db

[ $? -ne 0 ] && fail "ERROR" || ok

step "Start daemon"
quiet_run mongod --quiet --fork --logpath /var/log/mongodb/mongod.log --bind_ip_all

[ $? -ne 0 ] && fail "ERROR" || ok

step "Create admin user"
quiet_run mongosh --eval 'const a = db.getSiblingDB("admin"), p = process.env.MONGODB_PASSWORD; if (a.getUser("mongoAdmin")) { a.changeUserPassword("mongoAdmin", p); } else { a.createUser({user: "mongoAdmin", pwd: p, roles: ["root"]}); }'

[ $? -ne 0 ] &&  fail "ERROR"

USERS="$(mongosh --quiet --eval 'db.getSiblingDB("admin").system.users.countDocuments({user: "mongoAdmin"})' 2>/dev/null | tr -dc '0-9')"

[ "$USERS" == "1" ] || fail "admin user was not created"

ok

step "Shut down daemon"
quiet_run mongod --shutdown
[ $? -ne 0 ] && fail "ERROR" || ok

step "Start daemon with authentication"
quiet_run mongod --quiet --fork --logpath /var/log/mongodb/mongod.log --auth --bind_ip_all

[ $? -ne 0 ] &&  fail "ERROR" || ok

step "Verify admin credentials"

AUTH=""
for i in $(seq 1 30); do
	AUTH="$(mongosh -u mongoAdmin -p "$MONGODB_PASSWORD" --authenticationDatabase admin --quiet \
		--eval 'db.getSiblingDB("admin").system.users.countDocuments()' 2>&1)"
	[ "$(echo "$AUTH" | tr -dc '0-9')" == "1" ] && break
	sleep 1
done

case "$(echo "$AUTH" | tr -dc '0-9')" in
	1) ok ;;
	*) fail "mongoAdmin cannot authenticate: $(echo "$AUTH" | tr '\n' ' ')" ;;
esac

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

	T2=$(date +%s)
	step "Import the CSV into a new collection"
	quiet_run mongoimport -u mongoAdmin -p "$MONGODB_PASSWORD" --authenticationDatabase admin --drop --db ip2proxy_database --collection ip2proxy_database_tmp --type csv --file "./INDEXED.CSV" --fields ip_from_index,ip_to_index,ip_from,ip_to$FIELDS

	[ $? -ne 0 ] && fail "ERROR" || ok "$(elapsed $T2)"

	step "Create index"
	quiet_run mongosh -u mongoAdmin -p "$MONGODB_PASSWORD" --authenticationDatabase admin --quiet --eval 'db.getSiblingDB("ip2proxy_database").ip2proxy_database_tmp.createIndex({ip_from_index: 1, ip_to_index: 1})'

	[ $? -ne 0 ] && fail "ERROR" || ok
else
	T2=$(date +%s)
	step "Import the CSV into a new collection"
	quiet_run mongoimport -u mongoAdmin -p "$MONGODB_PASSWORD" --authenticationDatabase admin --drop --db ip2proxy_database --collection ip2proxy_database_tmp --type csv --file "$CSV" --fields ip_from,ip_to$FIELDS

	[ $? -ne 0 ] && fail "ERROR" || ok "$(elapsed $T2)"

	step "Create index"
	quiet_run mongosh -u mongoAdmin -p "$MONGODB_PASSWORD" --authenticationDatabase admin --quiet --eval 'db.getSiblingDB("ip2proxy_database").ip2proxy_database_tmp.createIndex({ip_from: 1, ip_to: 1})'
	[ $? -ne 0 ] && fail "ERROR" || ok
fi

step "Activate ip2proxy_database"
quiet_run mongosh -u mongoAdmin -p "$MONGODB_PASSWORD" --authenticationDatabase admin --quiet --eval 'db.getSiblingDB("ip2proxy_database").ip2proxy_database_tmp.renameCollection("ip2proxy_database", true)'

[ $? -ne 0 ] && fail "ERROR" || ok

banner "IP2Proxy Database Ready"
ROWS="$(mongosh -u mongoAdmin -p "$MONGODB_PASSWORD" --authenticationDatabase admin --quiet --eval 'db.getSiblingDB("ip2proxy_database").ip2proxy_database.countDocuments({})' 2>/dev/null | tr -dc '0-9')"
summary "Setup completed" "$(group "$ROWS") documents imported from $CODE_INPUT ($IP_TYPE)"
field "Host" "ip2proxy"
field "Database" "ip2proxy_database"
field "User" "mongoAdmin"
field "Password" "$MONGODB_PASSWORD"
printf '\n  %smongosh -h ip2proxy -u mongoAdmin -p "%s" --authenticationDatabase admin%s\n' "$C_DIM" "$MONGODB_PASSWORD" "$C_RESET"
printf '\n'

echo "MONGODB_PASSWORD=$MONGODB_PASSWORD" > /ip2proxy.conf
echo "TOKEN=$TOKEN" >> /ip2proxy.conf
echo "CODE=$CODE_INPUT" >> /ip2proxy.conf
echo "IP_TYPE=$IP_TYPE" >> /ip2proxy.conf

rm -rf /_tmp

tail -f /dev/null
