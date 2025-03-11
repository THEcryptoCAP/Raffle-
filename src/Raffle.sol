// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// internal & private view & pure functions
// external & public view & pure functions


/**
 * @title A sample Raffle contract
 * @author Avinash Singh
 * @notice This contract is for creating a simple smart contract lottery
 * @dev Implements chainlink vrfv2.5
 */
import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";
import {Counter} from "../src/Counter.sol";
import {Script, console} from "forge-std/Script.sol";
import {Test, console} from "forge-std/Test.sol";

contract Raffle is VRFConsumerBaseV2Plus {
    
    error Raffle__SendMoreToEnterRaffle();  
    error Raffle__TransferFailed();
    error Raffle__RaffleNotOpen();
    error Raffle__UpkeepNotNeeded( uint256 balance, uint256 playersLenght, uint256 raffleState);


    /* Type Declarations */
    enum  RaffleState {
        OPEN,             //0
        CALCULATING       //1
    }


    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint256 private immutable i_entranceFee;
    // @dev the duration of lottery in seconds
    uint32 private constant NUM_WORDS = 1;
    uint256 private immutable i_interval;
    uint256 private immutable i_subscriptionId;
    uint32 private immutable i_callbackGasLimit;
    address payable[] private s_players;
    uint256 private s_lastTimeStamp;
    bytes32 private immutable i_keyHash;
    address private s_recentWinner;
    RaffleState private s_raffleState;

    /*Events */
    event RaffleEntered(address indexed player);
    event WinnerPicked(address indexed winner);
   

    constructor(
        uint256 entranceFee,
        uint256 interval,
        address vrfCoordinator,
        bytes32 gasLane,
        uint256 subscriptionId,
        uint32 callbackGasLimit
    ) VRFConsumerBaseV2Plus(vrfCoordinator) {
        i_entranceFee = entranceFee;
        i_interval = interval;
        s_lastTimeStamp = block.timestamp;

        i_keyHash = gasLane;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;

        s_raffleState = RaffleState.OPEN; 
        
    }

    function enterRaffle() public payable {
        if (msg.value < i_entranceFee) {
            revert Raffle__SendMoreToEnterRaffle();
        }
        if (s_raffleState != RaffleState.OPEN){
            revert Raffle__RaffleNotOpen();
        }
        s_players.push(payable(msg.sender));
        emit RaffleEntered(msg.sender);
    }

   /* @dev the following function helps the node operator to decide whether to pick winner or not.
      it will hold good if:
      1) the time interval has passed between raffle runs 
      2) the lottery is open 
      3) the contract has eth (has players)
      4) Implicitly , your subscription has LINK */

    function checkUpkeep(bytes memory /*checkdata */) 
         public 
         view 
         returns (bool upkeepNeeded, bytes memory /* performData */)
         { 
           bool timeHasPassed= ((block.timestamp - s_lastTimeStamp) >= i_interval);
           bool isOpen = s_raffleState == RaffleState.OPEN;
           bool hasBalance = address(this).balance > 0;
           bool hasPlayers = s_players.length > 0;
           upkeepNeeded = timeHasPassed && isOpen && hasBalance && hasPlayers;
           return (upkeepNeeded, "");  
         }
  
    function performUpkeep(bytes calldata /* performData */ ) external {
        
        (bool upkeepNeeded,) = checkUpkeep("");
        if (!upkeepNeeded) {
            revert Raffle__UpkeepNotNeeded(address(this).balance, s_players.length, uint256(s_raffleState));
        }
        s_raffleState = RaffleState.CALCULATING;
        // get our random number
        VRFV2PlusClient.RandomWordsRequest memory request = VRFV2PlusClient.RandomWordsRequest({
            keyHash: i_keyHash,
            subId: i_subscriptionId,
            requestConfirmations: REQUEST_CONFIRMATIONS,
            callbackGasLimit: i_callbackGasLimit,
            numWords: NUM_WORDS,
            extraArgs: VRFV2PlusClient._argsToBytes(
                // Set nativePayment to true to pay for VRF requests with Sepolia ETH instead of LINK
                VRFV2PlusClient.ExtraArgsV1({nativePayment: false})
            )   
        }); 
           uint256 requestId = s_vrfCoordinator.requestRandomWords(request);

       
    }
    //CEI: checks, Effects, Interactions Pattern
    function fulfillRandomWords(uint256 requestId, uint256[] calldata randomWords) internal 
    override {
        //Checks- includes require statements



        //effects (internal contract state)
        uint256 indexofWinner = randomWords[0] % s_players.length;
        address payable recentWinner = s_players[indexofWinner];
        s_recentWinner = recentWinner;

        s_raffleState = RaffleState.OPEN;
        s_players = new address payable[](0);
        s_lastTimeStamp = block.timestamp;
        
        emit WinnerPicked(s_recentWinner);

        //Interactions (External Contract Interactions)
        (bool success,) = recentWinner.call{value: address(this).balance}("");
        if(!success) {
            revert Raffle__TransferFailed();
         }
   
    }

    /**
     * Getter Functions
     */
    function getEntranceFee() external view returns (uint256) {
        return i_entranceFee;
    }

    function getRaffleState() external view returns ( RaffleState) {
        return s_raffleState;
    }

    function getPlayer(uint256 indexOfPlayer) external view returns (address){
        return s_players[indexOfPlayer];
    }

    function getLastTimeStamp() external view returns (uint256) {
        return s_lastTimeStamp;
    }

    function getRecentWinner() external view returns(address){
        return s_recentWinner;
    }
}          

