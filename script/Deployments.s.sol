// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";

import {GeneralDonorBadge} from "../src/GeneralDonorBadge.sol";
import {DisasterDonorBadge} from "../src/DisasterDonorBadge.sol";
import {MockUSDC} from "../test/MockUSDC.sol";

contract Deployments is Script {
    function run() external returns (address generalBadge, address disasterBadge, address usdc) {
        vm.startBroadcast();
        generalBadge = address(new GeneralDonorBadge());
        console.log("GeneralDonorBadge address", generalBadge);

        disasterBadge = address(new DisasterDonorBadge());
        console.log("DisasterDonorBadge address", disasterBadge);

        usdc = address(new MockUSDC());
        console.log("Mock USDC address", usdc);
        vm.stopBroadcast();
    }
}
