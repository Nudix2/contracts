# Nudix

The Nudix project is conducting an early public sale of the T-NUDIX token. The T-NUDIX token is temporary. We anticipate that in the future, a dedicated smart contract will be developed to allow the exchange of the temporary token for the actual NUDIX token.

## Smart Contract Overview

Two smart contracts have been implemented:

- [Nudix.sol](./src/Nudix.sol). ERC-20 standard permanent protocol token.
- [TemporaryNudix.sol](./src/TemporaryNudix.sol). ERC-20 standard temporary token.
- [NudixSale](./src/NudixSale.sol). A public sale process for the temporary token.

### Audits

You can find audit report under the audits folder:

- [Beosin](./audits/Beosin.pdf) (May 29th, 2025)

### Nudix overview

Smart contract implements a simple fungible protocol token. Which in the future will be issued to users in place of a T-NUDIX. ERC-2612: Permit extension for EIP-20 signed approvals support added.

### TemporaryNudix overview

The smart contract implements the following features:
- Token minting via the mint and mintBatch functions, accessible only to accounts with specify role.
- Restricted token transfers, allowing transfers only to whitelisted addresses (intended for future migration to the permanent NUDIX token via a dedicated smart contract).
- ERC-2612 support: Permit extension for EIP-20 signed approvals.
- Cap to the supply of tokens (1_000_000_000)
- Token burning, permitted only for whitelisted accounts.

### NudixSale overview

The smart contract realizes T-NUDIX public sale and implements the following features:
- Flexible sale round creation by accounts with a dedicated role, allowing configurable parameters: start time, round rate (or pricing), cap, and minimum purchase. The number of rounds is not limited. But there can only be one active round.
- Manual sale round closure by authorized accounts.
- Automatic sale round closure upon reaching the predefined round limit.
- T-NUDIX purchase functionality for participants during active sale rounds.
- The payment token address must be set at the time of contract deployment.

_Important!_ The smart contract does not hold any assets. During the purchase process, it mints T_NUDIX to the buyer and transfers the payment tokens directly to the wallet address that was set during the smart contract deployment."

### Defining the ROUND_RATE parameter for the start of a round

_Note_: USDT may have either 6 or 18 decimals depending on the network (e.g., 6 decimals on Ethereum mainnet, but 18 on BNB Chain)

For this example, assume USDT has 6 decimals, and T-NUDIX has 18 decimals (standard)

Goal: establish a 1:1 exchange rate (1 USDT -> 1 T-NUDIX).

The formula used in the contract to get the token payment amount is `paymentAmount = (amount * roundRate) / TOKEN_SCALE`, where:
  - `paymentAmount` -> USDT.
  - `amount` -> T-NUDIX.
  - `TOKEN_SCALE` -> 1e18 (constant is set to 1e18 to normalize rates to 18 decimals).

We want to receive 1e18 T-NUDIX tokens. How much USDT should be spent? -> 1e6 (i.e. 1 USDT in 6-decimal format).

Plug into the formula: (1e18 * roundRate) / 1e18 = 1e6.
Then roundRate = 1e6.

Therefore:
  - If USDT has 6 decimals, use roundRate = 1e6 for a 1:1 exchange
  - If USDT has 18 decimals, use roundRate = 1e18

## Usage

The project was implemented using the [Foundry framework](https://book.getfoundry.sh/).

### Build and test

```shell
$ forge build
```

```shell
$ forge test
```

### Deploy

Deployment of smart contracts is supposed to be via a deployment script from `/script` folder.

1. Create `.env` file.
2. You need to add the deployer's private key to `.env` according to `.env.example`.

**Deploy Nudix.sol**
```shell
$ forge script script/DeployNudix.s.sol --rpc-url <RPC_URL> --etherscan-api-key <API_KEY> --sig "run(address)" "<recipient_address>" --slow --broadcast --verify
```

**Deploy TemporaryNudix.sol**
```shell
$ forge script script/DeployTemporaryNudix.s.sol --rpc-url <RPC_URL> --etherscan-api-key <API_KEY> --sig "run(address)" "<admin_address>" --slow --broadcast --verify
```

**Deploy NudixSale.sol**
```shell
$ forge script script/DeployNudixSale.s.sol --rpc-url <RPC_URL> --etherscan-api-key <API_KEY> --sig "run(address,address,address,address)" "<TemporaryNudix_address>" "<payment_token_address>" "<wallet_address>" "<initial_owner_address>" --slow --broadcast --verify
```

**Deploy All (First deploy)**
```shell
$ forge script script/DeployAll.s.sol --rpc-url <RPC_URL> --etherscan-api-key <API_KEY> --sig "run(address,address,address,address,address)" "<TemporaryNudix_admin_address>" "<payment_token_address>" "<wallet_address>" "<sale_owner_address>" "<backend_minter>" --slow --broadcast --verify
```

**Start T-NUDIX sale**

Before running script you need to open [file](./script/StartNudixSale.s.sol) and edit sale params.

```shell
forge script script/StartNudixSale.s.sol --rpc-url <RPC_URL> --slow --broadcast --sig "run(address)" "<NudixSale_address>"
```

Important! You may need to add the 0x prefix to the private key (in .env file - 6070) before running the deployment scripts.