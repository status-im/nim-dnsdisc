# Usage

## Shell

A development shell can be started using:
```sh
nix develop
```

## Building

To build creator you can use:
```sh
nix build '.#creator'
```

It can be also done without even cloning the repo:
```sh
nix build 'git+https://github.com/status-im/nim-dnsdisc'
```
When using `github:` schema the `?submodules=1#` argument is required:
```sh
nix build 'github:status-im/nimbus-eth2?submodules=1#'
```
This is [a known issue with `github:` schema](https://github.com/NixOS/nix/issues/14982) as well [as a URI parsing bug in Nix](https://github.com/NixOS/nix/issues/6633).

## Running

```sh
nix run 'git+https://github.com/status-im/nim-dnsdisc?submodules=1#''
```

## Testing

```sh
nix flake check ".?submodules=1#"
```
