# Uniswap V3 Liquidity Manager

This repository contains a Solidity smart contract (**UniswapV3LiquidityManager**) for managing liquidity provision on Uniswap V3. The contract allows users to provide liquidity within a specified price range (**width**) for any Uniswap V3 pool.

## Features

- **Add Liquidity**: Provide liquidity to a Uniswap V3 pool within a custom price range.
- **Dynamic Price Range**: Specify the width of the price range as a percentage (e.g., `10` for `0.1%`).
- **Refund Unused Tokens**: Automatically refunds any unused tokens after liquidity provision.

## Installation

### Clone the Repository:

```bash
git clone https://github.com/ishtagy/uniswap-v3-liquidity-manager.git
cd uniswap-v3-liquidity-manager
```

## Install Dependencies

### Using Foundry

Dependencies are managed via submodules. Run the following command to install them:

```bash
forge install
```

## Running Tests

To run the tests, use the following command:

```bash
forge test --fork-url <url> --match-path test/UniswapV3LiquidityManager.test.sol -vvv
```
