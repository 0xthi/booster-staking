// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

// Import OpenZeppelin Ownable contract for access control
import "@openzeppelin/contracts/access/Ownable.sol";
import "./IStakingContract.sol";

/**
 * @title StakingContract
 * @author Thileepan
 * @dev A contract for staking tokens with booster rewards.
 */
contract StakingContract is IStakingContract, Ownable {   
    // Number of seconds in one day
    uint256 constant SECONDS_PER_DAY = 86400;
    
    // Struct to represent a staker
    struct Staker {
        uint256 s_stakedAmount; // Amount of tokens staked
        uint256 s_lockDuration; // Duration for which tokens are locked in days
        uint256 s_startTime; // Timestamp when staking began
        uint256 s_lastClaimTime; // Timestamp when rewards were last claimed
    }

    // Mapping of addresses to stakers
    mapping(address => Staker) public stakers;

    // Public variables for contract parameters
    uint256 public s_maxLockDuration; // Maximum lock duration allowed in days
    uint256 public s_maxLockMultiplier; // Maximum lock multiplier allowed
    uint256 public s_claimDelay; // Delay before stakers can claim rewards again in days
    uint256 public s_apy; // Annual Percentage Yield

    /**
     * @dev Constructor to initialize contract parameters.
     * @param _maxLockDuration Maximum lock duration allowed in days.
     * @param _maxLockMultiplier Maximum lock multiplier allowed.
     * @param _claimDelay Delay before stakers can claim rewards again in days.
     * @param _apy Annual Percentage Yield.
     */
    constructor(uint256 _maxLockDuration, uint256 _maxLockMultiplier, uint256 _claimDelay, uint256 _apy) Ownable(msg.sender) {
        s_maxLockDuration = _maxLockDuration * SECONDS_PER_DAY;
        s_maxLockMultiplier = _maxLockMultiplier;
        s_claimDelay = _claimDelay * SECONDS_PER_DAY;
        s_apy = _apy;
    }

    // Setters for contract parameters, accessible only by owner
    function setMaxLockDuration(uint256 _maxLockDuration) external override onlyOwner {
        s_maxLockDuration = _maxLockDuration * SECONDS_PER_DAY;
    }
    
    function setMaxLockMultiplier(uint256 _maxLockMultiplier) external override onlyOwner {
        s_maxLockMultiplier = _maxLockMultiplier;
    }
    
    function setClaimDelay(uint256 _claimDelay) external override onlyOwner {
        s_claimDelay = _claimDelay * SECONDS_PER_DAY;
    }
    
    function setAPY(uint256 _apy) external override onlyOwner {
        s_apy = _apy;
    }

    /**
     * @dev Stake tokens with a specified lock duration.
     * @param _lockDuration Duration for which tokens will be locked in days.
     */
    function stake(uint256 _lockDuration) external payable override {
        uint256 lockDurationInSeconds = _lockDuration * SECONDS_PER_DAY;
        if (lockDurationInSeconds > s_maxLockDuration) revert LockDurationExceedsMax();
        if (msg.value == 0) revert MustStakeNonZeroAmount();
        if (stakers[msg.sender].s_stakedAmount > 0) revert StakingInProgress();
        
        Staker storage staker = stakers[msg.sender];
        staker.s_stakedAmount = msg.value;
        staker.s_lockDuration = lockDurationInSeconds;
        staker.s_startTime = block.timestamp;
        staker.s_lastClaimTime = block.timestamp;
        
        emit Staked(msg.sender, msg.value, _lockDuration);
    }
    
    /**
     * @dev Unstake tokens and claim rewards.
     */
    function unstake() external override {
        Staker storage staker = stakers[msg.sender];
        if (staker.s_stakedAmount == 0) revert NotStaking();
        if (block.timestamp < staker.s_startTime + staker.s_lockDuration) revert TokensStillLocked();
        
        uint256 amountToTransfer = staker.s_stakedAmount;
        staker.s_stakedAmount = 0;
        
        (bool success, ) = msg.sender.call{value: amountToTransfer}("");
        require(success, "Transfer failed");
        
        emit Unstaked(msg.sender, amountToTransfer);
    }

    /**
     * @dev Claim rewards for staking.
     */
    function claimRewards() external override {
        Staker storage staker = stakers[msg.sender];
        if (staker.s_stakedAmount == 0) revert NotStaking();
        if (block.timestamp < staker.s_lastClaimTime + s_claimDelay) revert ClaimDelayNotReached();
        
        uint256 reward = calculateReward(msg.sender);
        if (reward == 0) revert NoRewardsToClaim();
        
        (bool success, ) = msg.sender.call{value: reward}("");
        require(success, "Transfer failed");
        
        emit RewardClaimed(msg.sender, reward);
    }

    /**
     * @dev Calculate rewards for a staker.
     * @param _staker Address of the staker.
     * @return The amount of rewards to be claimed.
     */
    function calculateReward(address _staker) internal view returns (uint256) {
        Staker memory staker = stakers[_staker];
        uint256 elapsedTime = block.timestamp - staker.s_lastClaimTime;
        
        uint256 boosterMultiplier = 1;
        if (staker.s_lockDuration > 0) {
            uint256 lockMultiplier = (block.timestamp - staker.s_startTime) * s_maxLockMultiplier / staker.s_lockDuration;
            boosterMultiplier = lockMultiplier > s_maxLockMultiplier ? s_maxLockMultiplier : lockMultiplier;
        }
        
        uint256 reward = (staker.s_stakedAmount * elapsedTime * boosterMultiplier * s_apy) / (s_maxLockDuration * 100);
        return reward;
    }
    
    /**
     * @dev View the claimable rewards for a staker.
     * @param _staker Address of the staker.
     * @return The amount of rewards that can be claimed.
     */
    function viewClaimableRewards(address _staker) external view override returns (uint256) {
        return calculateReward(_staker);
    }
}
