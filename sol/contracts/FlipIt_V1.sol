pragma solidity >=0.4.21 <0.7.0;

import "./SafeMath.sol";
import "./Storage.sol";
import "./provableAPI.sol";

contract FlipIt_V1 is Storage, usingProvable {
  using SafeMath for uint256;

  /**
  * Event called when toss request has been submitted to the oracle.
  */
  event tossSubmitted(bytes32 queryId);
  /**
  * Event is raised when the oracle returns a result.
  */
  event tossResultReturned(bytes32 queryId, bool win);
  /**
  * Event is used to send logging messages back to the client.
  */
  event flipItLog(string message);

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
    _uint256Storage["minimum_wager"] = 1000000000000000;

    // Define a value that indicates how much to pay out.
    _uint256Storage["win_multiplyer"] = 2;

    // Initialize outcomes
    _uint32Storage["heads"] = 0;
    _uint32Storage["tails"] = 1;

    // Initialize random number oracle values.
    _uint256Storage["query_execution_delay"] = 0;
    _uint256Storage["gas_for_callback"] = 200000;

    _uint256Storage["num_bytes_requested"] = 1;

    provable_setProof(proofType_Ledger);
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
    // Must only be called by the oracle's contract
    require(msg.sender == provable_cbAddress());

	emit flipItLog ("callback returned, processiong ...");

    // Decode toss result.
    uint256 tossResult = uint256(keccak256(abi.encodePacked(_result))) % 2;

    // Lookup player address.
    address playerAddress = _playerNumberRequests[_queryId];

    // If a playerAddress is found for the _queryId.
    if (playerAddress != address(0)) {
      emit flipItLog ("calback: address found for queryId.");
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

		emit flipItLog ("callback: tos lost.");
      }
      else {
        // Mark palyer wager as a win.
        _playerWagers[playerAddress].win = true;

		emit flipItLog ("callback: toss won");
      }
    }
    else {
        emit flipItLog ("calback: queryId not matched to an address");
    }

    // Signal listeners that a response has returned.
    emit tossResultReturned(_queryId, isWinner);
  }

  /**
  * Provide a way for a win to be claimed. msg.sender must be associated
  * with _queryId.
  * TODO Implement roolback on transfer failure.
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

	  emit flipItLog ("processing claim.");

    // Mark wager as claimed.
    _playerWagers[playerAddress].claimed = true;
    // If player's choice equals toss result, player is a winner.
    if (_playerWagers[playerAddress].choice ==
        _playerWagers[playerAddress].result) {
	    emit flipItLog ("claim: processing win result.");
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
    returns (uint256, uint256, uint256, uint256, uint256, uint256, uint256){

    // Return various stats about the contract, game,
    // and msg.sender.
    return (_uint256Storage["wagers_made"],
      _uint256Storage["wagers_won"],
      _uint256Storage["amount_wagered"],
      _uint256Storage["amount_paid_out"],
      _uint256Storage["available_balance"],
      _uint256Storage["win_multiplyer"],
      _uint256Storage["minimum_wager"]);
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

	  emit flipItLog ("Added money to game.");
  }

  function setMinimumBet(uint256 _amt) public onlyOwner {
      _uint256Storage["minimum_wager"] = _amt;

	  emit flipItLog ("Minimum bet set.");
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
    require (msg.value >= _uint256Storage["minimum_wager"], 'WAGER_TOO_SMALL');

	emit flipItLog ("Processing toss request ...");

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

	emit flipItLog ("Submitting toss request ...");

    bytes32 queryId = provable_newRandomDSQuery(
      _uint256Storage["query_execution_delay"],
      _uint256Storage["num_bytes_requested"],
      _uint256Storage["gas_for_callback"]
    );

    // Set random request id in player's wager record.
    _playerWagers[msg.sender].randomRequestId = queryId;

    // Associate player address to queryId;
    _playerNumberRequests[queryId] = msg.sender;

    emit tossSubmitted(queryId);
  }


  /**
  * Provide a way for the owner to reap his / her rewards. Owner only,
  * contract cannot be frozen.
  * TODO Implement roolback on transfer failure.
  */
  function withdraw (uint256 _amt) public onlyOwner notFrozen {
      require (_amt <= _uint256Storage["available_balance"], "BAD_AMOUNT");

      _uint256Storage["available_balance"] = _uint256Storage["available_balance"].sub(_amt);

      msg.sender.transfer(_amt);
  }
}
