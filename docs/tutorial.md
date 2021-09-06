# DNS-based discovery Tree Creation: Basic Tutorial

## Background

The `tree_creator` is a command line utility used to create and update [EIP-1459](https://eips.ethereum.org/EIPS/eip-1459) compliant Merkle trees.
It takes as input a list of node records (in ENR text encoding) and link entries pointing to other trees.
The `tree_creator` utility will keep track of the tree sequence number and increase it whenever the encoded links or ENR entries are updated.
The root domain is configurable.
The most useful output is a map of subdomains to TXT records that can easily be converted to a zone file and deployed to a DNS name server,
from where the encoded lists of links and ENR can be retrieved by clients.

## How to build and run

To build and run `tree_creator` using its default configuration:

```bash
# Build `tree_creator` utility
make creator

# Run tree creator utility with default configuration
./build/tree_creator
```

To initialise the tree with some entries when running the utility,
specify `--enr-record` or `--link` command line options.
Both arguments may be repeated as many times as necessary.

```bash
./build/tree_creator \
--link=enrtree://AM5FCQLWIZX2QFPNJAP7VUERCCRNGRHWZG3YYHIUV7BVDQ5FDPRT2@never.gonna.give.you.up \
--enr-record=enr:-HW4QOFzoVLaFJnNhbgMoDXPnOvcdVuj7pDpqRvh6BRDO68aVi5ZcjB3vzQRZH2IcLBGHzo8uUN3snqmgTiE56CH3AMBgmlkgnY0iXNlY3AyNTZrMaECC2_24YYkYHEgdzxlSNKQEnHhuNAbNlMlWJxrJxbAFvA \
--enr-record=enr:-HW4QAggRauloj2SDLtIHN1XBkvhFZ1vtf1raYQp9TBW2RD5EEawDzbtSmlXUfnaHcvwOizhVYLtr7e6vw7NAf6mTuoCgmlkgnY0iXNlY3AyNTZrMaECjrXI8TLNXU0f8cthpAMxEshUyQlK-AM0PW2wfrnacNI
```

The domain can be specified when running the utility with the `--domain` option.
This can later be modified using the JSON-RPC API.

```bash
./build/tree_creator --domain=mydomain.example.org
```

For a full list of available command line options,
run the utility with the `--help` option:

```bash
./build/tree_creator --help
```

## Using the JSON-RPC API

The JSON-RPC API is exposed by default on the localhost (`127.0.0.1`) at port `8545`.
It is possible to change this configuration by setting the `rpc-address` and `rpc-port` options when running the node:

```bash
./build/tree_creator --rpc-address:127.0.1.1 --rpc-port:8546
``` 

The following JSON-RPC API methods are defined for the `tree_creator`:

---

### 1. `post_domain`

The `post_domain` method sets the fully qualified root domain name for the tree.

#### Parameters

| Field | Type | Inclusion | Description |
| ----: | :---: | :---: |----------- |
| `domain` | `String` | mandatory | The fully qualified domain name to set for the tree root entry |

#### Response

- **`Bool`** - `true` on success or an [error](https://www.jsonrpc.org/specification#error_object) on failure.

---

### 2. `get_domain`

The `get_domain` method returns the domain currently configured for this tree.

#### Parameters

none

#### Response

- The domain or an [error](https://www.jsonrpc.org/specification#error_object) on failure.

---

### 3. `post_enr_entries`

The `post_enr_entries` method adds a sequence of node records to the `tree_creator` to be encoded.
The node records must be ENR text encoded as per [EIP-778](https://eips.ethereum.org/EIPS/eip-778#text-encoding)

#### Parameters

| Field | Type | Inclusion | Description |
| ----: | :---: | :---: |----------- |
| `enrRecords` | `Array`[`String`] | mandatory | A list of ENR records to add to the tree |

#### Response

- **`Bool`** - `true` on success or an [error](https://www.jsonrpc.org/specification#error_object) on failure.

---

### 4. `post_link_entries`

The `post_link_entries` method adds a sequence of links referencing other trees to the `tree_creator` to be encoded.
The links must formatted according to the the `enrtree` scheme defined in [EIP-1459](https://eips.ethereum.org/EIPS/eip-1459#dns-record-structure)

#### Parameters

| Field | Type | Inclusion | Description |
| ----: | :---: | :---: |----------- |
| `links` | `Array`[`String`] | mandatory | A list of links to other trees to add to the tree |

#### Response

- **`Bool`** - `true` on success or an [error](https://www.jsonrpc.org/specification#error_object) on failure.

---

### 5. `get_txt_records`

The `get_txt_records` method returns a map of subdomains to TXT records for the encoded Merkle tree.
This can easily be converted to a zone file and deployed to a DNS name server.

#### Parameters

none

#### Response

- A map of subdomain to TXT record or an [error](https://www.jsonrpc.org/specification#error_object) on failure.

---

### 6. `get_public_key`

The `get_public_key` method returns the compressed 32 byte public key in base32 encoding.
This forms the "username" part of the tree location URL as per [EIP-1459](https://eips.ethereum.org/EIPS/eip-1459)

#### Parameters

none

#### Response

- The public key or an [error](https://www.jsonrpc.org/specification#error_object) on failure.

---

### 7. `get_url`

The `get_url` method returns the tree URL in the format `enrtree://<public_key>@<domain>` as per [EIP-1459](https://eips.ethereum.org/EIPS/eip-1459)

#### Parameters

none

#### Response

- The tree URL or an [error](https://www.jsonrpc.org/specification#error_object) on failure.

## JSON-RPC API example

One way to access JSON-RPC methods is by using the `cURL` command line tool.

For example:

```bash
curl -d '{"jsonrpc":"2.0","id":"id","method":"<method-name>", "params":[<params>]}' --header "Content-Type: application/json" http://localhost:8545
```

where `<method-name>` is the name of the JSON-RPC method to call and `<params>` is a comma-separated `Array` of parameters to pass as arguments to the selected method.

This example assumes that the `tree_creator` is running and the API is exposed on the `localhost` at port `8545` (the default configuration).

### Setting the domain

#### Example request:

```json
{
  "jsonrpc": "2.0",
  "id": "id",
  "method": "post_domain",
  "params": [
    "mynodes.example.org"
  ]
}
```

#### Example response:

```json
{
  "jsonrpc": "2.0",
  "id": "id",
  "result": true
}
```

### Adding ENR and link entries

#### Example request - adding ENR:

```json
{
  "jsonrpc": "2.0",
  "id": "id",
  "method": "post_enr_entries",
  "params": [
    [
      "enr:-HW4QOFzoVLaFJnNhbgMoDXPnOvcdVuj7pDpqRvh6BRDO68aVi5ZcjB3vzQRZH2IcLBGHzo8uUN3snqmgTiE56CH3AMBgmlkgnY0iXNlY3AyNTZrMaECC2_24YYkYHEgdzxlSNKQEnHhuNAbNlMlWJxrJxbAFvA",
      "enr:-HW4QLAYqmrwllBEnzWWs7I5Ev2IAs7x_dZlbYdRdMUx5EyKHDXp7AV5CkuPGUPdvbv1_Ms1CPfhcGCvSElSosZmyoqAgmlkgnY0iXNlY3AyNTZrMaECriawHKWdDRk2xeZkrOXBQ0dfMFLHY4eENZwdufn1S1o"
    ]
  ]
}
```

#### Example request - adding links:

```json
{
  "jsonrpc": "2.0",
  "id": "id",
  "method": "post_link_entries",
  "params": [
    [
      "enrtree://AM5FCQLWIZX2QFPNJAP7VUERCCRNGRHWZG3YYHIUV7BVDQ5FDPRT2@never.gonna.let.you.down"
    ]
  ]
}
```

### Retrieving encoded TXT records

#### Example request:

```json
{
  "jsonrpc": "2.0",
  "id": "id",
  "method": "get_txt_records",
  "params": []
}
```

#### Example response:

```json
{
  "jsonrpc": "2.0",
  "id": "id",
  "result": {
    "mynodes.example.org": "enrtree-root:v1 e=DHTTG472H5RVLIHOIQSPLVMGGA l=T7J7RURX6U73I7N4DKNIJYUOUU seq=1 sig=9e4E1Yw2cdPjuLvwjhfmBvjDKepAFow0x5BfVy8JzG56RDSTErOFxOz8eUzBO5l_acE-VHQLc9TFB8muSbZH6QE",
    "T7J7RURX6U73I7N4DKNIJYUOUU.mynodes.example.org": "enrtree://AM5FCQLWIZX2QFPNJAP7VUERCCRNGRHWZG3YYHIUV7BVDQ5FDPRT2@never.gonna.let.you.down",
    "DHTTG472H5RVLIHOIQSPLVMGGA.mynodes.example.org": "enrtree-branch:2XS2367YHAXJFGLZHVAWLQD4ZY,MHTDO6TMUBRIA2XWG5LUDACK24",
    "MHTDO6TMUBRIA2XWG5LUDACK24.mynodes.example.org": "enr:-HW4QLAYqmrwllBEnzWWs7I5Ev2IAs7x_dZlbYdRdMUx5EyKHDXp7AV5CkuPGUPdvbv1_Ms1CPfhcGCvSElSosZmyoqAgmlkgnY0iXNlY3AyNTZrMaECriawHKWdDRk2xeZkrOXBQ0dfMFLHY4eENZwdufn1S1o",
    "2XS2367YHAXJFGLZHVAWLQD4ZY.mynodes.example.org": "enr:-HW4QOFzoVLaFJnNhbgMoDXPnOvcdVuj7pDpqRvh6BRDO68aVi5ZcjB3vzQRZH2IcLBGHzo8uUN3snqmgTiE56CH3AMBgmlkgnY0iXNlY3AyNTZrMaECC2_24YYkYHEgdzxlSNKQEnHhuNAbNlMlWJxrJxbAFvA"
  }
}
```

### Retrieving the tree URL

#### Example request:

```json
{
  "jsonrpc": "2.0",
  "id": "id",
  "method": "get_url",
  "params": []
}
```

#### Example response:

```json
{
  "jsonrpc": "2.0",
  "id": "id",
  "result": "enrtree://AM5FCQLWIZX2QFPNJAP7VUERCCRNGRHWZG3YYHIUV7BVDQ5FDPRT2@mynodes.example.org"
}
```

## References

1. [EIP-778](https://eips.ethereum.org/EIPS/eip-778)
2. [EIP-1459](https://eips.ethereum.org/EIPS/eip-1459)
