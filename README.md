# Raffle-
This is a smart contract lottery system in which people enter the lottery system by giving an entrance fee and a winner is decided after regular intervals randomly using chainlink VRF(Verifiable Random function). The src file includes Raffle.sol with main source code with functions such as checkUpkeep, performupkeep and fullfill randomwords which automates the process of choosing winner(provably random) and pushing the price to winner's account and finaaly some getter functions. It also contains some advanced deployment scripts and helperconfigs used to manage networkconfig and deploying on different chains such as ETH sepolia or anvil. It also contains Raffletest.t.sol with numerous advanced unit test and also a mock Link Token contract for robust testing. 
