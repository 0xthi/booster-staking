// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/StakingContract.sol";
import "forge-std/console.sol";

contract StakingContractTest is Test {
    StakingContract stakingContract;
    address owner;
    address UserAddress = address(0xa000000000000000000000000000000000000000);
    address UserAddress2 = address(0xf000000000000000000000000000000000000000);

    function setUp() public {
        owner = address(this);
        stakingContract = new StakingContract(365, 5, 7, 10);
        vm.deal(address(stakingContract), 100 ether);
        vm.deal(UserAddress, 100 ether);
        vm.warp(1 days); // Advance block timestamp to simulate passing time
    }


    // Test constructor
    function testConstructor() public view {
    assertEq(stakingContract.s_maxLockDuration(), 365 days);
    assertEq(stakingContract.s_maxLockMultiplier(), 5);
    assertEq(stakingContract.s_claimDelay(), 7 days);
    assertEq(stakingContract.s_apy(), 10);
    }

//     function testOut() public {
//     vm.startPrank(UserAddress);
//     stakingContract.stake{value: 100 ether}(100);
//     vm.warp(100 days);
//     stakingContract.calculateBoosterMultiplier(100,365,5);
// }

    // Test staking
    function testStake() public {
    vm.prank(UserAddress);
    uint256 initialBalance = UserAddress.balance;
    // console.log("Initial balance of UserAddress: %s", initialBalance);
    stakingContract.stake{value: 1 ether}(30);
    assertEq(stakingContract.getStakedAmount(UserAddress), 1 ether);
    uint256 finalBalance = UserAddress.balance;
    // console.log("Final balance of UserAddress: %s", finalBalance);
    assertEq(finalBalance, initialBalance - 1 ether);
    }

    // Test Unstaking
    function testUnstake() public {

    vm.startPrank(UserAddress);
    uint256 initialBalance = UserAddress.balance;
    stakingContract.stake{value: 1 ether}(30);
    vm.warp(31);
    stakingContract.unstake();
    vm.stopPrank();

    uint256 finalBalance = UserAddress.balance;

    // For example, checking if the final balance is equal to the initial balance
    assertTrue(finalBalance == initialBalance, "Final balance should be equal to initial balance");
    // assertTrue(finalStakedAmount == 0, "Staked amount should be 0 after unstaking");
    }

// Test multiple claims
// function testMultipleClaims() public {
//     vm.prank(UserAddress);
//     stakingContract.stake{value: 1 ether}(30);
//     vm.warp(31 days); // Advance block timestamp to unlock tokens
//     stakingContract.claimRewards();
//     vm.expectRevert("Claiming rewards again should fail");
//     stakingContract.claimRewards();
// }

// // Test claiming rewards with different lock durations
// function testClaimRewardsWithDifferentLockDurations() public {
//     vm.prank(UserAddress);
//     uint256 initialBalance = UserAddress.balance;

//     // Stake 1 ether for 30 days
//     stakingContract.stake{value: 1 ether}(30);
//     vm.warp(31 days); // Advance block timestamp to unlock tokens
//     stakingContract.claimRewards();
//     uint256 rewardAfter30Days = UserAddress.balance - initialBalance;

//     // Stake 2 ether for 60 days
//     initialBalance = UserAddress.balance;
//     stakingContract.stake{value: 2 ether}(60);
//     vm.warp(61 days); // Advance block timestamp to unlock tokens
//     stakingContract.claimRewards();
//     uint256 rewardAfter60Days = UserAddress.balance - initialBalance;

//     assertTrue(rewardAfter30Days < rewardAfter60Days, "Reward should be higher for longer lock duration");
// }

function testBoosterAndReward() public {
    // Stake 100 ether for 100 days
uint256  SECONDS_PER_DAY = 86400;
uint256  STAKE_AMOUNT = 100 ether;
uint256  LOCK_DURATION = 100;
uint256  MAX_LOCK_DURATION = 365;
uint256  MAX_LOCK_MULTIPLIER = 5;
uint256  APY = 10;
vm.startPrank(UserAddress);
    stakingContract.stake{value: STAKE_AMOUNT}(LOCK_DURATION);
    vm.warp(LOCK_DURATION); // Advance block timestamp to unlock 

    // Calculate the expected booster multiplier
    uint256 expectedMultiplier = (LOCK_DURATION * MAX_LOCK_MULTIPLIER * 1e5) / (MAX_LOCK_DURATION);

    // Calculate the expected reward
    uint256 expectedReward = (STAKE_AMOUNT * LOCK_DURATION * APY * expectedMultiplier) / (100 * 1e5);

    // Get the actual booster multiplier and reward
    uint256 actualMultiplier = stakingContract.calculateBoosterMultiplier(LOCK_DURATION);
    uint256 actualReward = stakingContract.calculateReward();
    vm.stopPrank();

    console.log("Expected Multiplier", expectedMultiplier);
    console.log("Actual Multiplier", actualMultiplier);
    console.log("Expected Reward", expectedReward);
    console.log("Actual Reward", actualReward);

    // Verify the booster multiplier and reward
    assertTrue(actualMultiplier == expectedMultiplier, "Booster multiplier should match the expected value");
    assertTrue(actualReward == expectedReward, "Reward should match the expected value");
}

// Test multiple staking and unstaking
function testMultipleStakingUnstaking() public {
    vm.startPrank(UserAddress);

    // Stake 1 ether for 30 days
    stakingContract.stake{value: 1 ether}(30);
    vm.warp(31 days); // Advance block timestamp to unlock tokens
    assertEq(stakingContract.getStakedAmount(UserAddress), 1 ether);
    stakingContract.unstake();

    // Stake 2 ether for 60 days
    stakingContract.stake{value: 2 ether}(2);
    vm.warp(3 days); // Advance block timestamp to unlock tokens
    assertEq(stakingContract.getStakedAmount(UserAddress), 2 ether);
    stakingContract.unstake();

    vm.stopPrank();
}

    function testSetParameters() public {
    // Test setting max lock duration
    stakingContract.setMaxLockDuration(35);
    assertEq(stakingContract.s_maxLockDuration(), 35 days, "Max lock duration should be updated");

    // Test setting max lock multiplier
    stakingContract.setMaxLockMultiplier(2);
    assertEq(stakingContract.s_maxLockMultiplier(), 2, "Max lock multiplier should be updated");

    // Test setting claim delay
    stakingContract.setClaimDelay(7);
    assertEq(stakingContract.s_claimDelay(), 7 days, "Claim delay should be updated");

    // Test setting APY
    stakingContract.setAPY(10);
    assertEq(stakingContract.s_apy(), 10, "APY should be updated");
}
}