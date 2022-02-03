// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBase.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Lottery is VRFConsumerBase, Ownable {
  address payable[] public players;
  uint256 public entryFeeInUSD;
  AggregatorV3Interface internal ethUSDPriceFeed;
  bytes32 public keyhash;
  uint256 public fee;
  enum LotteryState {
    OPEN,
    CALCULATING,
    CLOSED
  }
  LotteryState public lotteryState;
  event RequestedRandomness(bytes32 requestId);
  address payable public winner;
  uint256 public randomness;

  constructor(address _priceFeedAddress, address _vrfCoordinator, address _linkToken, bytes32 _keyhash, uint256 _fee) public VRFConsumerBase(_vrfCoordinator, _linkToken) {
    entryFeeInUSD = 50 * 10**18;
    ethUSDPriceFeed = AggregatorV3Interface(_priceFeedAddress);
    lotteryState = LotteryState.CLOSED;
    keyhash = _keyhash;
    fee = _fee;
  }

  function enter() public payable {
    require(lotteryState == LotteryState.OPEN, "Lottery has not started yet!");
    require(msg.value >= getEntryFee(), "You need to spend more ETH!");
    players.push(payable(msg.sender));
  }

  function getEntryFee() public view returns (uint256) {
    (, int256 price, , , ) = ethUSDPriceFeed.latestRoundData();
    uint256 adjustedPrice = uint256(price) * 10**10;
    uint256 feeToEnter = (entryFeeInUSD * 10**18) / adjustedPrice;
    return feeToEnter;
  }

  function startLottery() public onlyOwner {
    require(lotteryState == LotteryState.CLOSED, "Lottery is about to start!");
    lotteryState = LotteryState.OPEN;
  }

  function endLottery() public onlyOwner {
    lotteryState = LotteryState.CALCULATING;
    bytes32 requestId = requestRandomness(keyhash, fee);
    emit RequestedRandomness(requestId);
  }

  function fulfillRandomness(bytes32 _requestId, uint256 _randomness) internal override {
      require(lotteryState == LotteryState.CALCULATING, "Getting there!");
      require(_randomness > 0);

      uint256 winnerIndex = players.length % _randomness;
      winner = players[winnerIndex];
      winner.transfer(address(this).balance);

      players = new address payable[](0);

      lotteryState = LotteryState.CLOSED;
      randomness = _randomness;
  }
}
