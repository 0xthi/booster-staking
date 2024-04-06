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
        vm.deal(UserAddress2, 100 ether);
        vm.warp(1 days); // Advance block timestamp to simulate passing time
    }

    // Test constructor
    function testConstructor() public view {
        assertEq(stakingContract.s_maxLockDuration(), 365);
        assertEq(stakingContract.s_maxLockMultiplier(), 5);
        assertEq(stakingContract.s_claimDelay(), 7 days);
        assertEq(stakingContract.s_apy(), 10);
    }

    // Test staking
    function testStake() public {
        vm.startPrank(UserAddress);
        uint256 initialBalance = UserAddress.balance;
        stakingContract.stake{value: 1 ether}(30);
        assertEq(stakingContract.getStakedAmount(), 1 ether);
        uint256 finalBalance = UserAddress.balance;
        assertEq(finalBalance, initialBalance - 1 ether);
        vm.stopPrank();
    }

    // Test Unstaking
    function testUnstake() public {
        vm.startPrank(UserAddress);
        uint256 initialBalance = UserAddress.balance;
        stakingContract.stake{value: 1 ether}(30);
        vm.warp(31 days);
        stakingContract.unstake();
        vm.stopPrank();
        uint256 finalBalance = UserAddress.balance;
        assertTrue(finalBalance == initialBalance, "Final balance should be equal to initial balance");
    }

    // Test booster and reward calculation
    function testBoosterAndReward() public {
        uint256 STAKE_AMOUNT = 100 ether;
        uint256 LOCK_DURATION = 100;
        uint256 MAX_LOCK_DURATION = 365;
        uint256 MAX_LOCK_MULTIPLIER = 5;
        uint256 APY = 10;
        vm.startPrank(UserAddress);
        stakingContract.stake{value: STAKE_AMOUNT}(LOCK_DURATION);
        vm.warp(LOCK_DURATION);
        uint256 expectedMultiplier = (LOCK_DURATION * MAX_LOCK_MULTIPLIER * 1e5) / (MAX_LOCK_DURATION);
        uint256 expectedReward = (STAKE_AMOUNT * LOCK_DURATION * APY * expectedMultiplier) / (100 * 1e5);
        uint256 actualMultiplier = stakingContract.calculateBoosterMultiplier(LOCK_DURATION);
        uint256 actualReward = stakingContract.calculateReward();
        vm.stopPrank();
        console.log("Expected Multiplier", expectedMultiplier/1e5);
        console.log("Actual Multiplier", actualMultiplier/1e5);
        console.log("Expected Reward", expectedReward);
        console.log("Actual Reward", actualReward);
        assertTrue(actualMultiplier == expectedMultiplier, "Booster multiplier should match the expected value");
        assertTrue(actualReward == expectedReward, "Reward should match the expected value");
    }

   // Test multiple staking and unstaking
function testMultipleStakingUnstaking() public {
    vm.startPrank(UserAddress);
    stakingContract.stake{value: 1 ether}(30);
    vm.warp(31 days); // Advance time beyond lock duration
    assertEq(stakingContract.getStakedAmount(), 1 ether);
    stakingContract.unstake();
    vm.stopPrank();

    vm.startPrank(UserAddress2);
    stakingContract.stake{value: 2 ether}(90);
    vm.warp(121 days); // Advance time beyond lock duration
    assertEq(stakingContract.getStakedAmount(), 2 ether);
    stakingContract.unstake();
    vm.stopPrank();
}

    // Test setting parameters
    function testSetParameters() public {
        stakingContract.setMaxLockDuration(35);
        assertEq(stakingContract.s_maxLockDuration(), 35, "Max lock duration should be updated");

        stakingContract.setMaxLockMultiplier(2);
        assertEq(stakingContract.s_maxLockMultiplier(), 2, "Max lock multiplier should be updated");

        stakingContract.setClaimDelay(7);
        assertEq(stakingContract.s_claimDelay(), 7 days, "Claim delay should be updated");

        stakingContract.setAPY(10);
        assertEq(stakingContract.s_apy(), 10, "APY should be updated");
    }

    // Test claiming rewards after the claim delay
    function testClaimRewardsAfterDelay() public {
        vm.startPrank(UserAddress);
        stakingContract.stake{value: 1 ether}(10);
        vm.warp(11 days); // Move forward by the claim delay
        uint256 initialBalance = UserAddress.balance;
        stakingContract.claimRewards();
        uint256 finalBalance = UserAddress.balance;
        uint256 expectedReward = stakingContract.calculateReward();
        assertTrue(finalBalance == initialBalance + expectedReward, "Balance should increase by the calculated reward");
        vm.stopPrank();
    }

    // Test claiming rewards before the claim delay
function testClaimRewardsBeforeDelay() public {
    vm.startPrank(UserAddress);
    stakingContract.stake{value: 1 ether}(30);
    bool success;
    vm.warp(31);
    try stakingContract.claimRewards() {
        success = true; // Rewards claimed successfully
    } catch {
        success = false; // Failed to claim rewards
    }
    assertFalse(success, "Claiming rewards before the delay should fail");
    vm.stopPrank();
}
    // Test unstaking tokens before the lock duration
function testUnstakeBeforeLockDuration() public {
    vm.startPrank(UserAddress);
    stakingContract.stake{value: 1 ether}(30);
    bool success;
    vm.warp(26);
    try stakingContract.unstake() {
        success = true; // Unstake succeeded unexpectedly
    } catch {
        success = false; // Unstake failed as expected
    }
    assertFalse(success, "Unstaking before lock duration should fail");
    vm.stopPrank();
}
}
