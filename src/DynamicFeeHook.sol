// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {BaseHook} from "periphery-next/BaseHook.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";
import {PoolId, PoolIdLibrary} from "v4-core/types/PoolId.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {BalanceDelta} from "v4-core/types/BalanceDelta.sol";
import {IDynamicFeeManager} from "v4-core/interfaces/IDynamicFeeManager.sol";

contract DynamicFeeHook is BaseHook, IDynamicFeeManager {
    // event PositionModifiedHook(address);

    struct Data {
        int128 tickLower;
        int128 tickUpper;
        int256 liquidity;
        uint256 feeTier;
        address owner;
    }

    mapping(address => Data) public userData;

    constructor(IPoolManager _poolManager) BaseHook(_poolManager) {}

    function getFee(address sender, PoolKey calldata key, IPoolManager.SwapParams calldata params, bytes calldata data) external returns (uint24) {
        return 2000;
    }

    function getHooksCalls() public pure override returns (Hooks.Calls memory) {
        return Hooks.Calls({
            beforeInitialize: false,
            afterInitialize: false,
            beforeModifyPosition: false,
            afterModifyPosition: true,
            beforeSwap: true,
            afterSwap: false,
            beforeDonate: false,
            afterDonate: false
        });
    }

    function feeTier(uint256 ft) external {
        userData[msg.sender].feeTier = ft;
    }


    // function claim(Curreny currency) external returns(int256) {//}, uint256, uint256) {
    //     // return userData[msg.sender].liquidity;
    //     int256 amount = poolManager.collectHookFees(msg.sender, currency, 0);
    //     return amount;
    // }   

    function afterModifyPosition(
        address,
        PoolKey calldata,
        IPoolManager.ModifyPositionParams calldata params,
        BalanceDelta,
        bytes calldata
    ) external override returns (bytes4) {
        userData[tx.origin].tickLower = params.tickLower;
        userData[tx.origin].tickUpper = params.tickUpper;
        userData[tx.origin].liquidity = params.liquidityDelta;
        userData[tx.origin].owner = tx.origin;

        return DynamicFeeHook.afterModifyPosition.selector;
    }

    function beforeSwap(address, PoolKey calldata, IPoolManager.SwapParams calldata, bytes calldata)
        external
        override
        returns (bytes4)
    {   
        return DynamicFeeHook.beforeSwap.selector;
    }

    function getFeeTier(address requiredAddress) external view returns(uint256) {
        return userData[requiredAddress].feeTier;
    }
}
