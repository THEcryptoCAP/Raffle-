//SPDX-License-Identifier:MIT
pragma solidity 0.8.19;

import {Test}  from "forge-std/Test.sol";
import {DeployRaffle} from "script/DeployRaffle.s.sol";
import {Raffle} from "../../src/Raffle.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {Vm} from "forge-std/Vm.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";

contract RaffleTest is Test {
      Raffle public raffle;
      HelperConfig public helperConfig;

       uint256 entranceFee;
        uint256 interval;
        address vrfCoordinator;
        bytes32 gasLane;
        uint256 subscriptionId;
        uint32 callbackGasLimit;

      address public PLAYER = makeAddr("player");
      uint256 public constant STARTING_PLAYER_BALANCE = 10 ether;

       event RaffleEntered(address indexed player);
       event WinnerPicked(address indexed winner);


      function setUp() external {
        DeployRaffle deployer = new DeployRaffle();
        (raffle, helperConfig) = deployer.deployContract();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
         entranceFee = config.entranceFee;
         interval =  config.interval;
         vrfCoordinator =  config.vrfCoordinator;
         gasLane = config.gasLane;
         subscriptionId = config.subscriptionId;
         callbackGasLimit = config.callbackGasLimit;

         vm.deal(PLAYER, STARTING_PLAYER_BALANCE);
      }

      function testRaffleInitializesInOpenState() public view {
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
      } 

      function testRaffleRevertsWhenNotPaidEnough() public {
        //arrange
          vm.prank(PLAYER);
        //act/ assert
          vm.expectRevert(Raffle.Raffle__SendMoreToEnterRaffle.selector);
          raffle.enterRaffle();
      }

      function testRaffleRecordsPlayersWhenTheyEnter() public {
        //Arrange 
        vm.prank(PLAYER);
        //Act 
        raffle.enterRaffle{value: entranceFee}();
        //assert
        address playerRecorded = raffle.getPlayer(0);
        assert(playerRecorded == PLAYER);
      }
      
      function testEnteringRaffleEmitsEvent() public {
        //Arrange 
          vm.prank(PLAYER);

        // Act
          vm.expectEmit(true, false, false, false, address(raffle));
          emit RaffleEntered(PLAYER);
        // Assert
          raffle.enterRaffle{value: entranceFee}();
      }

       function testDontAllowPlayersToEnterWhileRaffleIsCalculating() public {
          // arrange
          vm.prank(PLAYER);
          raffle.enterRaffle{value: entranceFee}();
          vm.warp(block.timestamp + interval + 1); // warp >> used to manipulate timestamp
          vm.roll(block.number + 1);               // roll >> used to manipulate block numbers
          raffle.performUpkeep("");

          // act / assert
          vm.expectRevert(Raffle.Raffle__RaffleNotOpen.selector);
          vm.prank(PLAYER);
          raffle.enterRaffle{value: entranceFee}();
          
       }
         ////// CHECK UPKEEP ///////

         function testCheckUpkeepReturnsFalseIfItHasNoBalance() public {
            // arrange 
            vm.warp(block.timestamp + interval + 1); // warp >> used to manipulate timestamp
            vm.roll(block.number + 1);               // roll >> used to manipulate block numbers
            
            // act
            (bool upkeepNeeded, ) = raffle.checkUpkeep("");

            //assert
            assert(!upkeepNeeded);

         }

         function testCheckUpkeepReturnsFalseIfRaffleIsntOpen() public {
            // arrange 
          vm.prank(PLAYER);
          raffle.enterRaffle{value: entranceFee}();
          vm.warp(block.timestamp + interval + 1); 
          vm.roll(block.number + 1);               
          raffle.performUpkeep("");
            
            //act 
            (bool upkeepNeeded, ) = raffle.checkUpkeep("");

            //assert 
            assert(!upkeepNeeded);
         }
         ////// PERFORM UPKEEP /////
          function testPerformUpkeepCanOnlyRunIfCheckUpkeepIsTrue() public {
        // Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: raffleEntranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        // Act / Assert
        // It doesnt revert
        raffle.performUpkeep("");
    }
          function testPerformUpkeepRevertsIfCheckUpkeepIsFalse() public {
        // Arrange
        uint256 currentBalance = 0;
        uint256 numPlayers = 0;
        Raffle.RaffleState rState = raffle.getRaffleState();
        // Act / Assert
        vm.expectRevert(
            abi.encodeWithSelector(Raffle.Raffle__UpkeepNotNeeded.selector, currentBalance, numPlayers, rState)
        );
        raffle.performUpkeep("");
    }

        modifier raffleEntered( ) {
            vm.prank(PLAYER);
            raffle.enterRaffle{value: raffleEntranceFee}();
            vm.warp(block.timestamp + interval + 1);
            vm.roll(block.number + 1);
            _;
        } 
          

        function testPerformUpkeepUpdatesRaffleStateAndEmitsRequestId() public raffleEntered {
          //arrange 
        

            //act 
            vm.recordLogs();
            raffle.performUpkeep("");
            Vm.Log[] memory entries = vm.getRecordedLogs(); // vm.log records all the logs(events, topics, data) emitted during a function call in an array
            bytes32 requestId = entries[1].topics[1];

            //assert
            Raffle.RaffleState raffleState = raffle.getRaffleState();
            assert(uint256(requestId) > 0);
            assert(uint256(raffleState) == 1);
        }
            //// FULFILLRANDOMWORDS //////
            function testFulfillrandomWordsCanOnlyBeCalledAfterPerformUpkeep(uint256 randomRequestId) public raffleEntered{
               vm.expectRevert(VRFCoordinatorV2_5Mock.InvalidRequest.selector);
               VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(randomRequestId, address(raffle)); // here, by assigning randomrequestid param in our test foundry checks the test 256 times with random values . this is called fuzz testingg
            }

            function testFulfillrandomWordsPicksWinnerResetsandSendsMoney() public raffleEntered {
              //arrange 
              uint256 additionalEntrants =3;
              uint256 startingIndex =1;
              address expectedWinner = address(1);

              for (uint256 i = startingIndex; i< startingIndex + additionalEntrants; i++){
                address newPlayer = address(uint160(i));
                hoax(newPlayer, 1 ether); // hoax cheatcode combines vm.prank and vm.deal { hoax(adress, value)}
                raffle.enterRaffle{value: entranceFee}();
              }
              uint256 startingTimeStamp = raffle.getLastTimeStamp();
              uint256 winnerStartingBalance = expectedWinner.balance;


              //act 
              vm.recordLogs();
              raffle.performUpkeep("");
              Vm.Log[] memory entries = vm.getRecordedLogs(); 
              bytes32 requestId = entries[1].topics[1];
              VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(uint256(requestId), address(raffle));

              //assert
              address recentWinner = raffle.getRecentWinner();
              Raffle.RaffleState raffleState = raffle.getRaffleState();
              uint256 winnerBalance = recentWinner.balance;
              uint256 endingTimeStamp = raffle.getLastTimeStamp();
              uint256 prize = entranceFee * (additionalEntrants + 1);

              assert(recentWinner == expectedWinner);
              assert(uint256(raffleState)== 0);
              assert(winnerBalance == winnerStartingBalance + prize); 
              assert(endingTimeStamp > startingTimeStamp);
            }
             
}