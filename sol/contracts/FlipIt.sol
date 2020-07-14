pragma solidity >=0.5.16 <0.7.0;

import "./Storage.sol";

/**
* The FlipIt contract is a wrapper contract that wraps a target
* contract, enabling the target to be versioned.
*/
contract FlipIt is Storage {
  // This address holds the address of the target contract.
  address currentAddress;

  constructor(address _currentAddress) public {
    // Start with owner being the address that originally deploys the
    // contract
    owner = msg.sender;
    // Initial target contract address
    currentAddress = _currentAddress;

    // Initialize game statistics
    _uint256Storage["amount_paid_out"] = 0;
    _uint256Storage["amount_wagered"] = 0;
    _uint256Storage["wagers_made"] = 0;
    _uint256Storage["wagers_won"] = 0;
    _uint256Storage["available_balance"] = 0;

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
  * Provides a means forthe contract owner to retrieve the current address.
  * can be used in a deployment scenario to save off the current address
  * so that changes could be rolled back to a previous version if needed.
  */
  function getTargetAddress () public view onlyOwner returns(address) {
    return currentAddress;
  }

  /**
  * This method provides a means to update the target contract
  * so that the functionality of the contract is upgradable.
  */
  function upgrade(address _newAddress) public onlyOwner {
    currentAddress = _newAddress;
  }

  /**
  * FALLBACK FUNCTION. All other calls are forwarded to the target contract.
  */
  function () payable external {
    address implementation = currentAddress;
    require(currentAddress != address(0));
    bytes memory data = msg.data;

    //DELEGATECALL EVERY FUNCTION CALL
    assembly {
      let result := delegatecall(gas, implementation, add(data, 0x20), mload(data), 0, 0)
      let size := returndatasize
      let ptr := mload(0x40)
      returndatacopy(ptr, 0, size)
      switch result
      case 0 {revert(ptr, size)}
      default {return(ptr, size)}
    }
  }
}
