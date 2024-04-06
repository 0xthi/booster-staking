// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// Interface for events, errors, and functions
interface IStakingContract {
    // Events
    event Staked(address indexed staker, uint256 amount, uint256 duration);
    event Unstaked(address indexed staker, uint256 amount);
    event RewardClaimed(address indexed staker, uint256 amount);
    event ParametersChanged(uint256 maxLockDuration, uint256 maxLockMultiplier, uint256 claimDelay, uint256 apy);

    // Errors
    error StakingInProgress();
    error NotStaking();
    error TokensStillLocked();
    error ClaimDelayNotReached();
    error NoRewardsToClaim();
    error LockDurationExceedsMax();
    error MustStakeNonZeroAmount();
    error InvalidZeroInput();
    error TransferFailed();

    // Setter functions
    function setMaxLockDuration(uint256 _maxLockDuration) external;
    function setMaxLockMultiplier(uint256 _maxLockMultiplier) external;
    function setClaimDelay(uint256 _claimDelay) external;
    function setAPY(uint256 _apy) external;

    // Staking functions
    function stake(uint256 _lockDuration) external payable;
    function unstake() external;
    function claimRewards() external;

    // Getter function
    function getStakedAmount() external view returns (uint256);
}