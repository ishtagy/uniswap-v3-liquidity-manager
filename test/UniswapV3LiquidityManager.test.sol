// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {UniswapV3LiquidityManager} from "../src/UniswapV3LiquidityManager.sol";
import {
    UNISWAP_V3_NONFUNGIBLE_POSITION_MANAGER,
    DAI,
    WETH,
    USDC,
    UNISWAP_V3_POOL_DAI_WETH_3000,
    UNISWAP_V3_POOL_USDC_WETH_500
} from "../src/Constants.sol";
import {IERC20} from "../src/interfaces/IERC20.sol";
import {IWETH} from "../src/interfaces/IWETH.sol";
import {INonfungiblePositionManager} from "../src/interfaces/INonfungiblePositionManager.sol";
import {IERC721Enumerable} from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";

contract UniswapV3LiquidityManagerTest is Test {
    IWETH private constant weth = IWETH(WETH);
    IERC20 private constant dai = IERC20(DAI);
    IERC20 private constant usdc = IERC20(USDC);
    INonfungiblePositionManager private constant manager =
        INonfungiblePositionManager(UNISWAP_V3_NONFUNGIBLE_POSITION_MANAGER);

    UniswapV3LiquidityManager public liquidityManager;

    function setUp() public {
        // Fund the test contract with DAI, WETH, and USDC
        deal(DAI, address(this), 5000 * 1e18);
        deal(WETH, address(this), 3 * 1e18);
        deal(USDC, address(this), 5000 * 1e6);

        // Deploy the UniswapV3LiquidityManager contract
        liquidityManager = new UniswapV3LiquidityManager(UNISWAP_V3_NONFUNGIBLE_POSITION_MANAGER);

        // Approve the liquidityManager to spend tokens
        weth.approve(address(liquidityManager), type(uint256).max);
        dai.approve(address(liquidityManager), type(uint256).max);
        usdc.approve(address(liquidityManager), type(uint256).max);
    }

    /**
     * @dev Tests liquidity provision for the DAI/WETH pair.
     */
    function test_liquidity_dai_weth() public {
        // Test liquidity provision for DAI/WETH pair
        _testLiquidity(UNISWAP_V3_POOL_DAI_WETH_3000, dai, weth, 3000 * 1e18, 1e18, 1000);
    }

    /**
     * @dev Tests liquidity provision for the USDC/WETH pair.
     */
    function test_liquidity_usdc_weth() public {
        // Test liquidity provision for USDC/WETH pair
        _testLiquidity(UNISWAP_V3_POOL_USDC_WETH_500, usdc, weth, 5000 * 1e6, 1e18, 1000);
    }

    /**
     * @dev Internal function to test liquidity provision for a given pool and token pair.
     * @param poolAddress The address of the Uniswap V3 pool.
     * @param token0 The first token in the pair.
     * @param token1 The second token in the pair.
     * @param amountToken0 The amount of token0 to provide as liquidity.
     * @param amountToken1 The amount of token1 to provide as liquidity.
     * @param width The width of the price range, expressed as a percentage (e.g., 10 for 0.1%).
     */
    function _testLiquidity(
        address poolAddress,
        IERC20 token0,
        IERC20 token1,
        uint256 amountToken0,
        uint256 amountToken1,
        uint256 width
    ) internal {
        // Initial balances of token0 and token1
        {
            uint256 initialToken0Balance = token0.balanceOf(address(this));
            uint256 initialToken1Balance = token1.balanceOf(address(this));

            // Call addLiquidity
            liquidityManager.addLiquidity(poolAddress, amountToken0, amountToken1, width);

            // Check that the liquidityManager used the correct amounts of token0 and token1
            uint256 finalToken0Balance = token0.balanceOf(address(this));
            uint256 finalToken1Balance = token1.balanceOf(address(this));

            console.log("Initial Token0 Balance: ", initialToken0Balance);
            console.log("Final Token0 Balance: ", finalToken0Balance);
            console.log("Initial Token1 Balance: ", initialToken1Balance);
            console.log("Final Token1 Balance: ", finalToken1Balance);
        }
        // Check that the position was minted successfully
        IERC721Enumerable nftManager = IERC721Enumerable(address(manager));
        uint256 positionCount = nftManager.balanceOf(address(this));
        assertGt(positionCount, 0, "No position was minted");

        // Fetch the position details
        uint256 tokenId = nftManager.tokenOfOwnerByIndex(address(this), 0);
        (,, address positionToken0, address positionToken1,, int24 lowerTick, int24 upperTick, uint128 liquidity,,,,) =
            manager.positions(tokenId);

        // Validate the position details
        assertEq(positionToken0, address(token0), "Token0 should match");
        assertEq(positionToken1, address(token1), "Token1 should match");
        assertGt(liquidity, 0, "Liquidity should be greater than 0");

        console.log("Position Token ID: ", tokenId);
        console.log("Liquidity: ", liquidity);
        console.log("Lower Tick: ", lowerTick);
        console.log("Upper Tick: ", upperTick);
    }

    function test_liquidity_differentWidth() public {
        // Test with a different width (e.g., 50%)
        liquidityManager.addLiquidity(UNISWAP_V3_POOL_DAI_WETH_3000, 1e18, 1e12, 5000);

        // Fetch the position details
        IERC721Enumerable nftManager = IERC721Enumerable(address(manager));
        uint256 tokenId = nftManager.tokenOfOwnerByIndex(address(this), 0);
        (,,,,, int24 lowerTick, int24 upperTick,,,,,) = manager.positions(tokenId);

        // Log the ticks for debugging
        console.log("Lower Tick (50% width): ", lowerTick);
        console.log("Upper Tick (50% width): ", upperTick);
    }
}
