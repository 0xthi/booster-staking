// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../src/StakingContract.sol";

contract DeployStakingContract is Script {
    function run() external {
        vm.startBroadcast();
        // Deploy StakingContract
        StakingContract stakingContract = new StakingContract(
            // Set your constructor parameters here
            365, // Max lock duration in days
            5,   // Max lock multiplier
            7,   // Claim delay in days
            100    // APY
        );
        vm.stopBroadcast();
        console.log("StakingContract deployed at:", address(stakingContract));
    }
}