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
    require(_maxLockDuration != 0, "Max lock duration cannot be zero");
    require(_maxLockMultiplier != 0, "Max lock multiplier cannot be zero");
    require(_claimDelay != 0, "Claim delay cannot be zero");

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
            staker.s_lockDuration = _lockDuration;
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
                if (block.timestamp > staker.s_startTime + staker.s_lockDuration*SECONDS_PER_DAY) revert TokensStillLocked();
                
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
            
            uint256 reward = calculateReward();
            if (reward == 0) revert NoRewardsToClaim();
            
            (bool success, ) = msg.sender.call{value: reward}("");
            require(success, "Transfer failed");
            
            emit RewardClaimed(msg.sender, reward);
        }

    function calculateReward() public view returns (uint256) {
    Staker memory staker = stakers[msg.sender];

    // Calculate booster multiplier
    uint256 boosterMultiplier = calculateBoosterMultiplier(staker.s_lockDuration);
    // Calculate reward using fixed-point arithmetic
    uint256 reward = (staker.s_stakedAmount * staker.s_lockDuration * s_apy * boosterMultiplier) / (100 * 1e5); 

    return reward;
}

    function calculateBoosterMultiplier(uint256 lockDuration) public view returns (uint256) {
    // Calculate booster multiplier using fixed-point arithmetic
    uint256 multiplier = (lockDuration * s_maxLockMultiplier) * 1e5 / s_maxLockDuration; // Multiply by 10^5 to account for fixed-point arithmetic
    uint256 maxMultiplierFixed = s_maxLockMultiplier * 1e5; // Convert max multiplier to fixed-point

    return multiplier > maxMultiplierFixed ? maxMultiplierFixed : multiplier;
}

    // Assuming other parts of the contract like structs, constants, and other functions are defined here
        
        /**
         * @dev Get the staked amount for a staker.
         * @param _staker Address of the staker.
         * @return The amount of tokens staked by the staker.
         */
        function getStakedAmount(address _staker) external view returns (uint256) {
            return stakers[_staker].s_stakedAmount;
        }
    }
