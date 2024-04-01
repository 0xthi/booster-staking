-include	.env

deploy:
	forge script script/DeployStakingContract.s.sol --broadcast --rpc-url $(RPC_URL)  --private-key $(PRIVATE_KEY) --etherscan-api-key $(ETHERSCAN_API_KEY) --verify