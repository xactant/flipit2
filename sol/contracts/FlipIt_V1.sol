pragma solidity >=0.4.21 <0.7.0;

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";
import "./Storage.sol";

contract FlipIt_V1 is Storage {
  using SafeMath for uint256;

  /**
  Event called when toss request has been submitted to the oracle.
  */
  event tossSubmitted(bytes32 queryId);
  /**
  Event is raised when the oracle returns a result.
  */
  event tossResultReturned(bytes32 queryId, bool win);
  // TRUFFLE: Counter used for testing in truffle only.
  uint256 _queryIdCounter = 0;

  constructor() public {
    // Start with owner being the address that originally deploys the
    // contract
    owner = msg.sender;

    // Initialize game statistics
    _uint256Storage["amount_paid_out"] = 0;
    _uint256Storage["amount_wagered"] = 0;
    _uint256Storage["wagers_made"] = 0;
    _uint256Storage["wagers_won"] = 0;
    _uint256Storage["available_balance"] = 0;
    _uint256Storage["locked_balance"] = 0;

    // Define a value that indicates how much to pay out.
    _uint256Storage["win_multiplyer"] = 2;

    // Initialize outcomes
    _uint32Storage["heads"] = 0;
    _uint32Storage["tails"] = 1;

    // Initialize random number oracle values.
    _uint256Storage["query_execution_delay"] = 0;
    _uint256Storage["gas_for_callback"] = 200000;
  }

  /**
  * This function is called by the oracle with the results of the random
  * request. Once request is received and processed a tossResultReturned
  * event is raised.
  */
  function __callback(bytes32 _queryId,
    string memory _result,
    bytes memory _proof) public {
    bool isWinner = false;
    // PROD require(msg.sender == provable_cbAddress());

    // Calculate toss result.
    uint256 tossResult = 1; // PROD uint256(keccak256(abi.encodePacked(_result))) % 2;
    // Lookup player address.
    address playerAddress = _playerNumberRequests[_queryId];

    // If a playerAddress is found for the _queryId.
    if (playerAddress != address(0)) {
      // Record tossResult
      _playerWagers[playerAddress].result = tossResult;
      // Set pending to false indicating the toss was returned.
      _playerWagers[playerAddress].pending = false;

      isWinner = (_playerWagers[playerAddress].choice == tossResult);

      // If user choice does not equal toss, remove
      // adjust game locked balance and let contract claim wager.
      if (isWinner != true) {
        _uint256Storage["locked_balance"] =
          _uint256Storage["locked_balance"].sub(_playerWagers[playerAddress].payout);

        _uint256Storage["available_balance"] =
          _uint256Storage["available_balance"].add(_playerWagers[playerAddress].amount);

        // Not a win so the toss is claimed by the contract.
        // Other wager properties do not need to be set so save
        // some gas by not setting anything else :).
        _playerWagers[playerAddress].claimed = true;
      }
      else {
        // Mark palyer wager as a win.
        _playerWagers[playerAddress].win = true;
      }
    }

    // Signal listeners that a response has returned.
    emit tossResultReturned(_queryId, isWinner);
  }

  /**
  Provide a way for a win to be claimed. msg.sender must be associated
  with _queryId.
  */
  function claimWin (bytes32 _queryId) public
    returns (uint256, uint256, uint256, bool,
            bool, bool, uint256, uint256) {
    // Get address associated with the quireId sent.
    address playerAddress = _playerNumberRequests[_queryId];

    // queryId must be associated with an an actual address.
    require (playerAddress != address(0), 'INVALID_CLAIM');
    // Associated address must match msg.sender.
    require (playerAddress == msg.sender, 'INVALID_CLAIM_B');
    // The wager associated with msg.sender must be unclaimed.
    require (_playerWagers[playerAddress].claimed == false, 'INVALID_CLAIM_C');
    // Mark wager as claimed.
    _playerWagers[playerAddress].claimed = true;
    // If player's choice equals toss result, player is a winner.
    if (_playerWagers[playerAddress].choice ==
        _playerWagers[playerAddress].result) {
      // Calculate amount of payout that is amount to be deducted from the
      // available balance. The Player's wager is not part of available
      // balance.
      uint256 diffamt =
        _playerWagers[playerAddress].payout.sub(_playerWagers[playerAddress].amount);
      // Adjust balance available for wagers.
      _uint256Storage["available_balance"] =
        _uint256Storage["available_balance"].sub(diffamt);
      // Increment won count.
      _uint256Storage["wagers_won"] = _uint256Storage["wagers_won"].add(1);
      // Increase amount paid out by wager payout amount.
      _uint256Storage["amount_paid_out"] =
        _uint256Storage["amount_paid_out"].add(_playerWagers[playerAddress].payout);
      // Decrement locked balance.
      _uint256Storage["locked_balance"] =
        _uint256Storage["locked_balance"].sub(_playerWagers[playerAddress].payout);
      // Pay the player.
      msg.sender.transfer(_playerWagers[playerAddress].payout);
    }
    // Return complete wager results.
    return (_playerWagers[playerAddress].amount,
      _playerWagers[playerAddress].payout,
      _playerWagers[playerAddress].timestamp,
      _playerWagers[playerAddress].pending,
      _playerWagers[playerAddress].claimed,
      _playerWagers[playerAddress].win,
      _playerWagers[playerAddress].choice,
      _playerWagers[playerAddress].result);
  }

  /**
  * Provide a way to retrieve last wager information for
  * a player.
  */
  function getAccountWager () public view
    returns (uint256,uint256,uint256,uint256,uint256, bytes32,bool,bool,bool,bool){
    return (
      _playerWagers[msg.sender].choice,
      _playerWagers[msg.sender].result,
      _playerWagers[msg.sender].amount,
      _playerWagers[msg.sender].payout,
      _playerWagers[msg.sender].timestamp,
      _playerWagers[msg.sender].randomRequestId,
      _playerWagers[msg.sender].pending,
      _playerWagers[msg.sender].win,
      _playerWagers[msg.sender].submitted,
      _playerWagers[msg.sender].claimed
    );
  }

  /**
  * Retrieve game statistics.
  */
  function getGameStats() public view
    returns (uint256, uint256, uint256, uint256, uint256, uint256, bool){
    // THis variable is used to show that an unclaimed wager
    // exists for msg.sender or not.
    bool unclaimedWin = false;
    // Determine if unclaimed win exists.
    if(_playerWagers[msg.sender].win == true &&
      _playerWagers[msg.sender].claimed == false) {
        unclaimedWin = true;
      }
    // Return various stats about the contract, game,
    // and msg.sender.
    return (_uint256Storage["wagers_made"],
      _uint256Storage["wagers_won"],
      _uint256Storage["amount_wagered"],
      _uint256Storage["amount_paid_out"],
      _uint256Storage["available_balance"],
      _uint256Storage["win_multiplyer"],
      unclaimedWin);
  }

  /**
  * Provides an easy method to indicate if a use is a game admin.
  */
  function isAdmin() public view
    returns(bool) {
    return msg.sender == owner;
  }

  /**
  * Provides an easy way for the owner to add funds to the game. Only Owner,
  * contract cannot be frozen.
  */
  function loadGame() public payable onlyOwner notFrozen {
      require (msg.value > 0, 'FUNDS_REQUIRED');

      _uint256Storage["available_balance"] =
        _uint256Storage["available_balance"].add(msg.value);
  }

  /**
  * TRUFFLE This is for testing only
  * Submits a reuqest for a random number
  */
  function submitTossRequest () internal returns (bytes32) {
    // TRUFFLE This is for testing only
    _queryIdCounter = _queryIdCounter.add(1);
    // TRUFFLE THis is for testing only
    bytes32 queryId = bytes32(_queryIdCounter); //keccak256(_uint32Storage["queryid"]));

    // Map the player's address to the ID of the random request.
    _playerNumberRequests[queryId] = msg.sender;

    __callback(queryId, "1", bytes("test"));
    return queryId;
  }

  /**
  * Perform the toss. _tossCall is the players choice and
  * player's wager is msg.value. Once request for random value is made
  * a tossSubmitted event is raised.
  */
  function toss(uint256 _tossCall) public payable {
    // Cannot have an unclaimed toss wager.
    require(_playerWagers[msg.sender].claimed == true ||
      _playerWagers[msg.sender].pending == false, "UNCLAIMED");

    // Must send a wager.
    require (msg.value > 0, 'FUNDS_REQURIED');

    uint256 time = block.timestamp;
    uint256 wager = msg.value;
    uint256 winning = wager.mul(_uint256Storage["win_multiplyer"]);
    uint256 futureLocked = _uint256Storage["locked_balance"].add(winning);

    // Do what we can to make sure that outstanding possible
    // payout is not greater than current available balance.
    require (_uint256Storage["available_balance"] > futureLocked, 'WAGER TOO LARGE');

    // It is possible other wagers have come in
    // So update lock balance and redo addition -
    // this is on purpose.
    _uint256Storage["locked_balance"] =
      _uint256Storage["locked_balance"].add(winning);

    // Update some of the contracts statistics.
    _uint256Storage["wagers_made"] =
      _uint256Storage["wagers_made"].add(1);
    _uint256Storage["amount_wagered"] =
      _uint256Storage["amount_wagered"].add(wager);

    // Initialize player's wager record.
    _playerWagers[msg.sender] = Wager (
      _tossCall,
      99, // non result
      wager, // amount wagered
      winning, // payout amount.
      time,
      0, // non query id
      true, // IMPORTANT - pending must be true!
      false, // win
      true, // submitted
      false // claimed
    );

    bytes32 queryId = submitTossRequest();

    // Set random request id in player's wager record.
    _playerWagers[msg.sender].randomRequestId = queryId;

    emit tossSubmitted(queryId);
  }

  /**
  * Provide a way for the owner to reap his / her rewards. Owner only,
  * contract cannot be frozen.
  */
  function withdraw (uint256 _amt) public onlyOwner notFrozen {
      require (_amt < _uint256Storage["available_balance"], "BAD_AMOUNT");

      _uint256Storage["available_balance"] = _uint256Storage["available_balance"].sub(_amt);

      msg.sender.transfer(_amt);
  }
}
