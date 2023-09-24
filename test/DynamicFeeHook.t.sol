// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

// Foundry libraries
import "forge-std/Test.sol";
import "forge-std/console2.sol";
import {TestERC20} from "v4-core/test/TestERC20.sol";
import {CurrencyLibrary, Currency} from "v4-core/types/Currency.sol";

import {GasSnapshot} from "forge-gas-snapshot/GasSnapshot.sol";
import {PoolId, PoolIdLibrary} from "v4-core/types/PoolId.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";

import {IHooks} from "v4-core/interfaces/IHooks.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";

import {PoolManager} from "v4-core/PoolManager.sol";
import {PoolModifyPositionTest} from "v4-core/test/PoolModifyPositionTest.sol";
import {PoolSwapTest} from "v4-core/test/PoolSwapTest.sol";

import {DynamicFeeHook} from "../src/DynamicFeeHook.sol";
import {DynamicFeeStub} from "../src/DynamicFeeStub.sol";

import {TickMath} from "v4-core/libraries/TickMath.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import {FeeLibrary} from "v4-core/libraries/FeeLibrary.sol";
// import {Data} from "../src/DynamicFeeHook.sol";

contract DynamicFeeHookTest is Test, GasSnapshot {
    address lp;
    address user;

    using PoolIdLibrary for PoolKey;

    DynamicFeeHook hook = DynamicFeeHook(
            address(
                uint160(Hooks.AFTER_MODIFY_POSITION_FLAG | Hooks.BEFORE_SWAP_FLAG | Hooks.AFTER_SWAP_FLAG)
            )
        );
    
    PoolManager poolManager;

    PoolModifyPositionTest modifyPositionRouter;

    PoolSwapTest swapRouter;

    TestERC20 token0;
    TestERC20 token1;

    PoolKey poolKey;
    PoolId poolId;

    uint160 constant SQRT_RATIO_1_1 = 79228162514264337593543950336;

    function setUp() public {
        lp = makeAddr('lp');
        user = makeAddr('user');
        vm.deal(lp, 100_000 ether);
        
        _deployERC20Tokens();
        poolManager = new PoolManager(500_000);
        // hook = new DynamicFeeHook(poolManager);
        _stubValidateHookAddress();
        _initializePool();
        _addLiquidityToPool();
        console2.log(address(modifyPositionRouter));
    }

    function test_Swap() public {
        bool zeroForOne = true;
        IPoolManager.SwapParams memory params = IPoolManager.SwapParams({
            zeroForOne: !zeroForOne,
            amountSpecified: 1 ether,
            sqrtPriceLimitX96: TickMath.MAX_SQRT_RATIO - 1
        });
        PoolSwapTest.TestSettings memory testSettings = PoolSwapTest.TestSettings({withdrawTokens: true, settleUsingTransfer: true});

        token1.mint(user, 100 ether);
        token0.mint(user, 100 ether);
        vm.startPrank(user);
        token0.approve(address(swapRouter), 100 ether);
        token1.approve(address(swapRouter), 100 ether);
        swapRouter.swap(poolKey, params, testSettings);
        vm.stopPrank();

        console2.log(token1.balanceOf(user));
        console2.log(token0.balanceOf(user));
        console2.log(address(hook).balance);
    }

    function _addLiquidityToPool() private {
        token1.mint(lp, 100 ether);
        token0.mint(lp, 100 ether);
        vm.startPrank(lp, lp);
        // Mint a lot of tokens to ourselves
        string memory path = "./output.txt";
        
        // token0.mint(address(this), 100 ether);
        // token1.mint(address(this), 100 ether);

        // Approve the modifyPositionRouter to spend your tokens
        token0.approve(address(modifyPositionRouter), 100 ether);
        token1.approve(address(modifyPositionRouter), 100 ether);

        // Add liquidity across different tick ranges
        // First, from -60 to +60
        // Then, from -120 to +120
        // Then, from minimum possible tick to maximum possible tick
        IPoolManager.ModifyPositionParams memory params = IPoolManager.ModifyPositionParams(-60, 60, 10 ether);
        hook.feeTier(2000);
        // Add liquidity from -60 to +60
        modifyPositionRouter.modifyPosition(
            poolKey,
            params
        );
        vm.writeLine(path, string.concat("Owner Address: ", Strings.toHexString(uint256(uint160(address(this))), 20)));
        vm.writeLine(path, string.concat("TickLower: ", Strings.toStringSigned(int256(params.tickLower))));
        vm.writeLine(path, string.concat("TickUpper: ", Strings.toStringSigned(int256(params.tickUpper))));
        vm.writeLine(path, string.concat("LiquidityDelta: ", Strings.toStringSigned(int256(params.liquidityDelta))));
        vm.writeLine(path, string.concat("LiquidityInPool: ", Strings.toString(uint256(poolManager.getLiquidity(poolKey.toId())))));
        vm.writeLine(path, string.concat("Fee Tier: ", Strings.toString(hook.getFeeTier(lp))));
        vm.writeLine(path, "\n");

        IPoolManager.ModifyPositionParams memory params2 = IPoolManager.ModifyPositionParams(60, 120, 10 ether);
        hook.feeTier(2000);
        // Add liquidity from 60 to +120
        modifyPositionRouter.modifyPosition(
            poolKey,
            params2
        );

        vm.writeLine(path, string.concat("Owner Address: ", Strings.toHexString(uint256(uint160(address(this))), 20)));
        vm.writeLine(path, string.concat("TickLower: ", Strings.toStringSigned(int256(params2.tickLower))));
        vm.writeLine(path, string.concat("TickUpper: ", Strings.toStringSigned(int256(params2.tickUpper))));
        vm.writeLine(path, string.concat("LiquidityDelta: ", Strings.toStringSigned(int256(params2.liquidityDelta))));
        vm.writeLine(path, string.concat("LiquidityInPool: ", Strings.toString(uint256(poolManager.getLiquidity(poolKey.toId())))));
        vm.writeLine(path, string.concat("Fee Tier: ", Strings.toString(hook.getFeeTier(lp))));
        vm.writeLine(path, "\n");

        // Approve the tokens for swapping through the swapRouter
        token0.approve(address(swapRouter), 100 ether);
        token1.approve(address(swapRouter), 100 ether);

        IPoolManager.ModifyPositionParams memory params3 = IPoolManager.ModifyPositionParams(-120, 120, 50 ether);
        hook.feeTier(2000);
        // Add liquidity from 60 to +120
        modifyPositionRouter.modifyPosition(
            poolKey,
            params2
        );

        vm.writeLine(path, string.concat("Owner Address: ", Strings.toHexString(uint256(uint160(address(this))), 20)));
        vm.writeLine(path, string.concat("TickLower: ", Strings.toStringSigned(int256(params3.tickLower))));
        vm.writeLine(path, string.concat("TickUpper: ", Strings.toStringSigned(int256(params3.tickUpper))));
        vm.writeLine(path, string.concat("LiquidityDelta: ", Strings.toStringSigned(int256(params3.liquidityDelta))));
        vm.writeLine(path, string.concat("LiquidityInPool: ", Strings.toString(uint256(poolManager.getLiquidity(poolKey.toId())))));
        vm.writeLine(path, string.concat("Fee Tier: ", Strings.toString(hook.getFeeTier(lp))));
        vm.writeLine(path, "\n");

        // Approve the tokens for swapping through the swapRouter
        token0.approve(address(swapRouter), 100 ether);
        token1.approve(address(swapRouter), 100 ether);
    }

    function _deployERC20Tokens() private {
        TestERC20 tokenA = new TestERC20(2 ** 128);
        TestERC20 tokenB = new TestERC20(2 ** 128);

        // Token 0 and Token 1 are assigned in a pool based on
        // the address of the token
        if (address(tokenA) < address(tokenB)) {
            token0 = tokenA;
            token1 = tokenB;
        } else {
            token0 = tokenB;
            token1 = tokenA;
        }
    }

    function _initializePool() private {
        // Deploy the test-versions of modifyPositionRouter and swapRouter
        modifyPositionRouter = new PoolModifyPositionTest(
            IPoolManager(address(poolManager))
        );
        swapRouter = new PoolSwapTest(IPoolManager(address(poolManager)));

        // Specify the pool key and pool id for the new pool
        poolKey = PoolKey({
            currency0: Currency.wrap(address(token0)),
            currency1: Currency.wrap(address(token1)),
            fee: 0xC00000,//FeeLibrary.DYNAMIC_FEE_FLAG,
            tickSpacing: 60,
            hooks: IHooks(hook)
        });
        poolId = poolKey.toId();

        // Initialize the new pool with initial price ratio = 1
        poolManager.initialize(poolKey, SQRT_RATIO_1_1, bytes(""));
    }

    function _stubValidateHookAddress() private {
        // Deploy the stub contract
        DynamicFeeStub stub = new DynamicFeeStub(poolManager, hook);

        // Fetch all the storage slot writes that have been done at the stub address
        // during deployment
        (, bytes32[] memory writes) = vm.accesses(address(stub));

        // Etch the code of the stub at the hardcoded hook address
        vm.etch(address(hook), address(stub).code);

        // Replay the storage slot writes at the hook address
        unchecked {
            for (uint256 i = 0; i < writes.length; i++) {
                bytes32 slot = writes[i];
                vm.store(address(hook), slot, vm.load(address(stub), slot));
            }
        }
    }
}