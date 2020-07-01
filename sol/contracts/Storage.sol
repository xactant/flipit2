pragma solidity >=0.5.16 <0.7.0;

/*
Provide a seperate container for persisted data. This enables state to be
maintained even if processing contract is upgraded.
*/
contract Storage {
  address public owner;
  bool public gameFrozen = false;

  modifier onlyOwner(){
      require(msg.sender == owner);
      _; // Continue execution
  }

  modifier notFrozen(){
    require(gameFrozen == false, "Game cannot be played at this time.");
    _; // Continue execution.
  }

  /*
  Information about customer's last wager
  */
  struct Wager {
    uint256 choice;
    uint256 result;
    uint256 amount;
    uint256 payout;
    uint256 timestamp;
    bytes32 randomRequestId;
    bool pending;
    bool win;
    bool submitted;
    bool claimed;
  }

  /*
  Define general use named variable holders
  */
  mapping (string => uint256) _uint256Storage;
  mapping (string => uint32) _uint32Storage;
  mapping (string => address) _addressStorage;
  mapping (string => bool) _boolStorage;
  mapping (string => string) _stringStorage;
  mapping (string => bytes4) _bytesStorage;

  /*
  Define a list to hold latest bet based on Customer's address.
  */
  mapping (address => Wager) _playerWagers;

  /*
  Random request to player address mapping.
  */
  mapping (bytes32 => address) _playerNumberRequests;
}
