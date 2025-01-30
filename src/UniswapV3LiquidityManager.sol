// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {INonfungiblePositionManager} from "src/interfaces/INonfungiblePositionManager.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import "src/interfaces/TickMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol";
// import {console} from "forge-std/Test.sol";

/**
 * @title UniswapV3LiquidityManager
 * @dev A contract to manage liquidity provision on Uniswap V3.
 * Allows users to provide liquidity within a specified price range (width) for any Uniswap V3 pool.
 */
contract UniswapV3LiquidityManager {
    using SafeERC20 for IERC20;

    INonfungiblePositionManager public immutable positionManager;

    /**
     * @dev Constructor to initialize the contract.
     * @param _manager The address of the Uniswap V3 NonfungiblePositionManager.
     */
    constructor(address _manager) {
        positionManager = INonfungiblePositionManager(_manager);
    }

    /**
     * @dev Adds liquidity to a Uniswap V3 pool within a specified price range.
     * @param _poolAddress The address of the Uniswap V3 pool.
     * @param amountToken0 The amount of token0 to provide as liquidity.
     * @param amountToken1 The amount of token1 to provide as liquidity.
     * @param width The width of the price range, expressed as a percentage (e.g., 10 for 0.1%).
     *              The price range is calculated as: [currentPrice * (1 - width%), currentPrice * (1 + width%)].
     */
    function addLiquidity(address _poolAddress, uint256 amountToken0, uint256 amountToken1, uint256 width) external {
        IUniswapV3Pool pool = IUniswapV3Pool(_poolAddress);
        // (uint160 sqrtPriceX96,,,,,,) = pool.slot0();

        // Calculate the price range (upperPrice and lowerPrice)
        (int24 lowerTick, int24 upperTick) = _calculateTicks(pool, width);

        // Get token addresses
        address token0 = pool.token0();
        address token1 = pool.token1();

        // Transfer tokens from the user to this contract
        TransferHelper.safeTransferFrom(token0, msg.sender, address(this), amountToken0);
        TransferHelper.safeTransferFrom(token1, msg.sender, address(this), amountToken1);

        // Approve the position manager to spend tokens
        TransferHelper.safeApprove(token0, address(positionManager), amountToken0);
        TransferHelper.safeApprove(token1, address(positionManager), amountToken1);

        // Calculate liquidity
        // uint160 sqrtPriceLowerX96 = TickMath.getSqrtRatioAtTick(lowerTick);
        // uint160 sqrtPriceUpperX96 = TickMath.getSqrtRatioAtTick(upperTick);
        // uint128 liquidity = LiquidityAmounts.getLiquidityForAmounts(
        //     sqrtPriceX96, sqrtPriceLowerX96, sqrtPriceUpperX96, amountToken0, amountToken1
        // );
        // console.log("Calculated liquidity: ", liquidity);

        // Mint the position
        INonfungiblePositionManager.MintParams memory params = INonfungiblePositionManager.MintParams({
            token0: token0,
            token1: token1,
            fee: pool.fee(),
            tickLower: lowerTick,
            tickUpper: upperTick,
            amount0Desired: amountToken0,
            amount1Desired: amountToken1,
            amount0Min: 0,
            amount1Min: 0,
            recipient: msg.sender,
            deadline: block.timestamp
        });

        (,, uint256 amount0, uint256 amount1) = positionManager.mint(params);

        // (uint256 amount0, uint256 amount1) = pool.mint(address(this), lowerTick, upperTick, liquidity, "");
        if (amount0 < amountToken0) {
            IERC20(token0).safeTransfer(msg.sender, amountToken0 - amount0);
        }
        if (amount1 < amountToken1) {
            IERC20(token1).safeTransfer(msg.sender, amountToken1 - amount1);
        }
    }

    /**
     * @dev Calculates the lower and upper ticks for the specified price range.
     * @param pool The Uniswap V3 pool.
     * @param width The width of the price range, expressed as a percentage (e.g., 10 for 0.1%).
     * @return lowerTick The lower tick of the price range.
     * @return upperTick The upper tick of the price range.
     */
    function _calculateTicks(IUniswapV3Pool pool, uint256 width)
        private
        view
        returns (int24 lowerTick, int24 upperTick)
    {
        // Get the current price of the pool
        (uint160 sqrtPriceX96,,,,,,) = pool.slot0();

        int24 tickSpacing = pool.tickSpacing();
        // Calculate the spread based on the width
        // uint160 sqrtRatioAX96 = uint160(
        //     (sqrtPriceX96 * (1e18 - width * 1e16)) / 1e18 // Lower bound: (1 - width%)
        // );
        // uint160 sqrtRatioBX96 = uint160(
        //     (sqrtPriceX96 * (1e18 + width * 1e16)) / 1e18 // Upper bound: (1 + width%)
        // );

        // Convert prices to sqrt ratios
        uint160 sqrtRatioAX96 = uint160((sqrtPriceX96 * (10000 - width)) / 10000); // Lower bound
        uint160 sqrtRatioBX96 = uint160((sqrtPriceX96 * (10000 + width)) / 10000); // Upper bound

        // Calculate the ticks for the lower and upper bounds
        lowerTick = TickMath.getTickAtSqrtRatio(sqrtRatioAX96);
        upperTick = TickMath.getTickAtSqrtRatio(sqrtRatioBX96);

        // Ensure ticks align with tickSpacing
        lowerTick = _alignToTickSpacing(lowerTick, tickSpacing);
        upperTick = _alignToTickSpacing(upperTick, tickSpacing);
    }

    /**
     * @dev Aligns a tick to the nearest multiple of the tick spacing.
     * @param tick The tick to align.
     * @param tickSpacing The tick spacing of the pool.
     * @return The aligned tick.
     */
    function _alignToTickSpacing(int24 tick, int24 tickSpacing) internal pure returns (int24) {
        int24 remainder = tick % tickSpacing;
        if (remainder != 0) {
            tick = tick - remainder; // Round down to nearest tickSpacing
        }
        return tick;
    }
}
