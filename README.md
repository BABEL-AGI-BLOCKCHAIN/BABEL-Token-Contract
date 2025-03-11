## Foundry

**Foundry is a blazing fast, portable and modular toolkit for Ethereum application development written in Rust.**

Foundry consists of:

-   **Forge**: Ethereum testing framework (like Truffle, Hardhat and DappTools).
-   **Cast**: Swiss army knife for interacting with EVM smart contracts, sending transactions and getting chain data.
-   **Anvil**: Local Ethereum node, akin to Ganache, Hardhat Network.
-   **Chisel**: Fast, utilitarian, and verbose solidity REPL.

## Deployed Contract Addresses

### Testnets

| Network | BABELPlaceholder                           | Exchange                                   |
| ------- | ------------------------------------------ | ------------------------------------------ |
| Sepolia | 0xb5d14101e5C7140f163aB29A5fa620355d0B8DA9 | 0x7C6B3363c2cf638f773d475210C55D3aE7519bf6 |

### Mainnets

| Network  | BABELPlaceholder | Exchange |
| -------- | ---------------- | -------- |
| Ethereum |                  |          |

## Documentation

https://book.getfoundry.sh/

## Usage

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```

### Format

```shell
$ forge fmt
```

### Gas Snapshots

```shell
$ forge snapshot
```

### Anvil

```shell
$ anvil
```

### Deploy

```shell
$ forge script script/BABELPlaceholder.s.sol:BABELPlaceholderScript --rpc-url <your_rpc_url> --private-key <your_private_key>
$ forge script script/Exchange.s.sol:ExchangeScript --rpc-url <your_rpc_url> --private-key <your_private_key>
```

### Cast

```shell
$ cast <subcommand>
```

### Help

```shell
$ forge --help
$ anvil --help
$ cast --help
```
