// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {DynamicFeeHook} from "./DynamicFeeHook.sol";

import {BaseHook} from "periphery-next/BaseHook.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";

contract DynamicFeeStub is DynamicFeeHook {
    constructor(
        IPoolManager _poolManager,
        DynamicFeeHook addressToEtch
    ) DynamicFeeHook (_poolManager) {}

    // make this a no-op in testing
    function validateHookAddress(BaseHook _this) internal pure override {}
}