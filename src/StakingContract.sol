// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

// Import OpenZeppelin Ownable contract for access control
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./IStakingContract.sol";

/**
 * @title StakingContract
 * @dev A contract for staking tokens with booster rewards.
 */
contract StakingContract is IStakingContract, Ownable, ReentrancyGuard {   

    // Number of seconds in one day
    uint256 constant SECONDS_PER_DAY = 86400;

    // Struct to represent a staker
    struct Staker {
        uint256 s_stakedAmount;     // Amount of tokens staked
        uint256 s_lockDuration;     // Duration for which tokens are locked in days
        uint256 s_startTime;        // Timestamp when staking began
        uint256 s_lastClaimTime;    // Timestamp when rewards were last claimed
    }

    // Mapping of addresses to stakers
    mapping(address => Staker) public stakers;

    // Public variables for contract parameters
    uint256 public s_maxLockDuration;    // Maximum lock duration allowed in days
    uint256 public s_maxLockMultiplier;  // Maximum lock multiplier allowed
    uint256 public s_claimDelay;         // Delay before stakers can claim rewards again in days
    uint256 public s_apy;                // Annual Percentage Yield

    /**
     * @dev Constructor to initialize contract parameters.
     * @param _maxLockDuration Maximum lock duration allowed in days.
     * @param _maxLockMultiplier Maximum lock multiplier allowed.
     * @param _claimDelay Delay before stakers can claim rewards again in days.
     * @param _apy Annual Percentage Yield.
     */
    constructor(uint256 _maxLockDuration, uint256 _maxLockMultiplier, uint256 _claimDelay, uint256 _apy) Ownable(msg.sender) {
        require(_maxLockDuration != 0 && _maxLockMultiplier != 0 && _claimDelay != 0 && _apy != 0, "InvalidZeroInput");

        s_maxLockDuration = _maxLockDuration;
        s_maxLockMultiplier = _maxLockMultiplier;
        s_claimDelay = _claimDelay * SECONDS_PER_DAY;
        s_apy = _apy;
    }

    /**
     * @dev Set the maximum lock duration allowed.
     * @param _maxLockDuration Maximum lock duration in days.
     */
    function setMaxLockDuration(uint256 _maxLockDuration) external override onlyOwner {
        s_maxLockDuration = _maxLockDuration;
        emit ParametersChanged(s_maxLockDuration, s_maxLockMultiplier, s_claimDelay, s_apy);
    }

    /**
     * @dev Set the maximum lock multiplier allowed.
     * @param _maxLockMultiplier Maximum lock multiplier.
     */
    function setMaxLockMultiplier(uint256 _maxLockMultiplier) external override onlyOwner {
        s_maxLockMultiplier = _maxLockMultiplier;
        emit ParametersChanged(s_maxLockDuration, s_maxLockMultiplier, s_claimDelay, s_apy);
    }

    /**
     * @dev Set the delay before stakers can claim rewards again.
     * @param _claimDelay Claim delay in days.
     */
    function setClaimDelay(uint256 _claimDelay) external override onlyOwner {
        s_claimDelay = _claimDelay * SECONDS_PER_DAY;
        emit ParametersChanged(s_maxLockDuration, s_maxLockMultiplier, s_claimDelay, s_apy);
    }

    /**
     * @dev Set the Annual Percentage Yield (APY) for staking rewards.
     * @param _apy Annual Percentage Yield.
     */
    function setAPY(uint256 _apy) external override onlyOwner {
        s_apy = _apy;
        emit ParametersChanged(s_maxLockDuration, s_maxLockMultiplier, s_claimDelay, s_apy);
    }

    /**
     * @dev Stake tokens with a specified lock duration.
     * @param _lockDuration Duration for which tokens will be locked in days.
     */
    function stake(uint256 _lockDuration) external payable override {
        require(_lockDuration <= s_maxLockDuration, "LockDurationExceedsMax");
        require(msg.value > 0, "MustStakeNonZeroAmount");
        require(stakers[msg.sender].s_stakedAmount == 0, "StakingInProgress");

        Staker storage staker = stakers[msg.sender];
        staker.s_stakedAmount = msg.value;
        staker.s_lockDuration = _lockDuration;
        staker.s_startTime = block.timestamp;
        staker.s_lastClaimTime = block.timestamp;

        emit Staked(msg.sender, msg.value, _lockDuration);
    }

    /**
     * @dev Unstake tokens and claim rewards.
     */
    function unstake() external override nonReentrant {
        Staker storage staker = stakers[msg.sender];
        if(staker.s_stakedAmount == 0) revert NotStaking();
        if(block.timestamp < staker.s_startTime + staker.s_lockDuration * SECONDS_PER_DAY) revert TokensStillLocked();

        uint256 amountToTransfer = staker.s_stakedAmount;
        staker.s_stakedAmount = 0;

        (bool success, ) = payable(msg.sender).call{value: amountToTransfer}("");
        require(success, "TransferFailed");

        emit Unstaked(msg.sender, amountToTransfer);
    }

    /**
     * @dev Claim rewards for staking.
     */
    function claimRewards() external override nonReentrant {
        Staker storage staker = stakers[msg.sender];
        require(staker.s_stakedAmount > 0, "NotStaking");
        require(block.timestamp > staker.s_lastClaimTime + s_claimDelay, "ClaimDelayNotReached");

        uint256 reward = calculateReward();
        require(reward > 0, "NoRewardsToClaim");

        (bool success, ) = payable(msg.sender).call{value: reward}("");
        require(success, "TransferFailed");

        emit RewardClaimed(msg.sender, reward);
        staker.s_lastClaimTime = block.timestamp;
    }

    /**
     * @dev Calculate the reward for the staker.
     */
    function calculateReward() public view returns (uint256) {
        Staker memory staker = stakers[msg.sender];
        uint256 boosterMultiplier = calculateBoosterMultiplier(staker.s_lockDuration);
        return (staker.s_stakedAmount * staker.s_lockDuration * s_apy * boosterMultiplier) / (100 * 1e5);
    }

    /**
     * @dev Calculate the booster multiplier based on lock duration.
     * @param lockDuration Lock duration in days.
     */
    function calculateBoosterMultiplier(uint256 lockDuration) public view returns (uint256) {
        uint256 multiplier = (lockDuration * s_maxLockMultiplier) * 1e5 / s_maxLockDuration;
        uint256 maxMultiplierFixed = s_maxLockMultiplier * 1e5;
        return multiplier > maxMultiplierFixed ? maxMultiplierFixed : multiplier;
    }

    /**
     * @dev Get the staked amount for a staker.
     * @return The amount of tokens staked by the staker.
     */
    function getStakedAmount() external view override returns (uint256) {
        return stakers[msg.sender].s_stakedAmount;
    }
}
