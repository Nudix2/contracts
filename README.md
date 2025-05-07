# Nudix

## Project description

## Usage

The project was implemented using the [Foundry framework](https://book.getfoundry.sh/).

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```

### Test coverage

```shell
$ forge coverage
```

### Format

```shell
$ forge fmt
```

### Deploy

Deployment of smart contracts is supposed to be via a deployment script from `/script` folder.

1. Create `.env` file
2. You need to add the deployer's private key to `.env` according to .env.example
3. Run script
   ```shell
     $ forge script script/DeployTemporaryNudix.s.sol --rpc-url <RPC_URL> --etherscan-api-key <API_KEY> --slow --broadcast --verify
   ```

Important! You may need to add the 0x prefix to the private key (in .env file - 6070) before running the deployment scripts.

### Help

```shell
$ forge --help
$ anvil --help
$ cast --help
```