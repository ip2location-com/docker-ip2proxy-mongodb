docker-ip2proxy-mongodb
=======================

A ready-to-run MongoDB server preloaded with an [IP2Proxy](https://www.ip2location.com/database/ip2proxy) proxy IP database. Supports the commercial packages and the free [LITE](https://lite.ip2location.com) package. Register for an account first as download token is required.



## Usage

```bash
docker network create ip2proxy-network

docker run --name ip2proxy \
  --network ip2proxy-network \
  -d \
  -e TOKEN={DOWNLOAD_TOKEN} \
  -e CODE={DOWNLOAD_CODE} \
  -e IP_TYPE=IPV4 \
  -e MONGODB_PASSWORD={MONGODB_PASSWORD} \
  ip2proxy/mongodb

docker logs -f ip2proxy      # Wait for "✓ Setup completed"
```

**ENV Variables**

| Variable | Description |
|---|---|
| `TOKEN` | Download token. Required. |
| `CODE` | Database code. Required. See below. |
| `IP_TYPE` | `IPV4` (default) or `IPV6`. |
| `MONGODB_PASSWORD` | Password for the `mongoAdmin` user. Random if omitted. |

**`CODE`** — Free Database: `PX1-LITE`, `PX2-LITE`, `PX3-LITE`, `PX4-LITE`, `PX5-LITE`, `PX6-LITE`, `PX7-LITE`, `PX8-LITE`, `PX9-LITE`, `PX10-LITE`, `PX11-LITE`, `PX12-LITE`.
Commercial Database: `PX1`, `PX2`, `PX3`, `PX4`, `PX5`, `PX6`, `PX7`, `PX8`, `PX9`, `PX10`, `PX11`, `PX12`.

Only one address family is installed per container. To switch, start a fresh container with an empty `/data/db` — an existing install is not converted in place, and re-running with different settings prints a note explaining that.

The admin password is written to `/ip2proxy.conf` inside the container, so `docker logs` and `docker exec` access are equivalent to knowing it.

To start over:

```bash
docker rm -f ip2proxy
docker volume rm ip2proxy-data        # if you used -v ip2proxy-data:/data/db
```



## Query for IP Information

Four fields matter. `ip_from` and `ip_to` are the IP **numbers** bounding the range; `ip_from_index` and `ip_to_index` are those same numbers zero-padded to 40 characters and prefixed with `A`, which is what makes range comparison work as a string. Which pair you filter on depends on the `IP_TYPE` you installed.

**Both bounds are required.** The database lists only addresses that have proxy data, so the ranges are sparse: they do not cover the address space and most addresses sit in a gap between two ranges. A query on `ip_to` alone matches a large part of the collection, and `findOne` returns an arbitrary one of those matches — reporting a proxy record for an address that is not a proxy.

**IPv4** — both IP numbers as plain strings:

```js
use ip2proxy_database
db.ip2proxy_database.findOne( { $and: [ { ip_from: { $lte: "134744072" } }, { ip_to: { $gte: "134744072" } } ] } )
```

**IPv6** — the padded, `A`-prefixed form. For `2001:4860:4860::8888` the IP number is `42541956123769884636017138956568135816`:

```js
use ip2proxy_database
db.ip2proxy_database.findOne( { $and: [ { ip_from_index: { $lte: "A0042541956123769884636017138956568135816" } }, { ip_to_index: { $gte: "A0042541956123769884636017138956568135816" } } ] } )
```

**Every search value is a quoted string.** `mongoimport --type csv` imports each CSV value as text unless the field types are declared, so the unquoted form `{ ip_to: { $gte: 134744072 } }` matches **nothing** and returns `null` — BSON compares across types by type order, and numbers sort before strings.

To convert an address to an IP number see the [IP2Location FAQs](https://www.ip2location.com/faqs#technical).



## Connect from an Application

Put your application on the same network and reach the container by name (`ip2proxy`):

```bash
docker run --network ip2proxy-network -t -i {YOUR_APPLICATION}
```

```bash
mongosh --host ip2proxy -u mongoAdmin -p {MONGODB_PASSWORD} --authenticationDatabase admin
```



## Update IP2Proxy Database

```bash
docker exec -it ip2proxy /update.sh
```

Imports a fresh copy and swaps it in with `renameCollection(..., true)`, so queries keep working against the old data until the swap. The daily download quota is limited. If you get `[QUOTA EXCEEDED]` error, please try again after 24 hours.



## Articles and Tutorials

[IP2Proxy Articles and Tutorials](https://blog.ip2location.com)
