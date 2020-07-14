/**
* The flipitservice module provides an insterface to the
* FlipIt contract.
*
* TODO Add descriptive pop-ups for error status received from
* contract - most are only logged to console.
* TODO Currently events are handled in the UI script, it might
* be better to move event handling into this module.
*/
var flipitService = function () {
  //  Indicate that module has been initialized.
  var isInitialized = false;
  // Web3 instance.
  var web3 = new Web3(Web3.givenProvider);
  // Contract instance
  var contractInstance = null;
  var tossSubmittedEvent;
  var tossResultReturnedEvent;
  var flipItLogEvent;
  var winEvent = null;
  var loseEvent = null;
  var playerAccount = '';
  var minimumWager = 1000000;

  // Provide player's available choices.
  winchoices = {
    HEADS: 0,
    TAILS: 1
  };

  /**
  * Wait for Web3 to be start and retrieve an instance of
  * the FlipIt contract
  */
  function initializeService () {
    console.log('flipitService.initializeService called ...');
    return window.ethereum.enable()
    .then(function(accounts) {
      playerAccount = accounts[0];
      contractInstance = new web3.eth.Contract(abi, contractAddress, {from: playerAccount});
      console.log(contractInstance);
      isInitialized = true;

      tossResultReturnedEvent = contractInstance.events.tossResultReturned;
      tossSubmittedEvent = contractInstance.events.tossSubmitted;
      flipItLogEvent = contractInstance.events.flipItLog;
    });
  }

  function claimWin(queryId, callback) {
    console.log('Claiming win with queryId: ' + queryId);
    var callbackCalled = false;

    var config = {
      from: playerAccount,
      gas: 2000000
    };

    return contractInstance.methods.claimWin(queryId)
      .send(config)
      .on("transactionHash", function(hash) {
        console.log('claim transactionHash: ' + hash);
      })
      .on("confirmation", function(confNum) {
        console.log('claim confNum: ' + confNum);
        if (!callbackCalled) {
          callbackCalled = true;
          callback();
        }
      })
      .on("receipt", function(receipt){
        console.log('claim receipt: ' + receipt);

        if (!callbackCalled) {
          callbackCalled = true;
          callback();
        }
      })
      .on("error", function(err){
        console.log('claim error: ' + err);
      });

  }

  /**
  * Send player's prediction and wager to the contract.
  * TODO replace alerts with notifications
  * @param winChoice - player's prediction should be 0 (heads) or 1 (tails)
  * @param wager - amount player wagers on this toss.
  * @param dem - denomination of wager (valid web3 eth denominations: qwei,
  *              finney, ether, etc.)
  * @param callback - method to call when contract call completes.
  */
  function doToss (winChoice, wagerAmt, dem, callback) {
    console.log('flipitService.doToss called ...');
    if (winchoices.HEADS != winChoice &&
        winchoices.TAILS != winChoice) {
      callback('HEADS_OR_TAILS', null);
      return null;
    }

    var wagerValue = dem == 'wei'? wagerAmt : web3.utils.toWei(wagerAmt, dem);

    if (minimumWager > wagerValue) {
        callback('MINIMUM_WAGER', null);
        return null;
    }

    if (isInitialized) {
      var config = {
        from: playerAccount,
        value: wagerValue,
        gas: 2000000
      };

      contractInstance.methods.toss(parseInt(winChoice))
        .send(config, callback);
    }
    else {
      console.error ('toss Module flipitService is not initialized.');
    }
  }

  /**
  * Retrieve game statistics and any player wager information
  * (if applicable).
  */
  function getGameStats () {
    var unclaimedWin = false;
    var unclaimedQueryId = null;

    // Retrieve any wager outstanding information Associated
    // with currect user account.
    return contractInstance.methods.getAccountWager().call()
    .then (function(wagerData) {
      console.log("Wager Data: " + JSON.stringify(wagerData));

      unclaimedWin = (wagerData[7] && !wagerData[9]);

      if (unclaimedWin) {
        unclaimedQueryId = wagerData[5];
      }

      // Retrieve and return game statistics.
      return contractInstance.methods.getGameStats().call()
        .then(function(result) {
          minimumWager = result[6];

          return {
            wagersMade: result[0],
            wagersWon: result[1],
            amountWagered: result[2],
            amountPaidOut: result[3],
            availableBalance: result[4],
            winMultiplyer: result[5],
            unclaimedWin: unclaimedWin,
            unclaimedQueryId: unclaimedQueryId,
            minimumWager: minimumWager
          };
      });
    });
  }

  /**
  * Expose current user's account id
  */
  function getPlayerAccount() {
    return playerAccount;
  }

  /**
  * Expose toss result return event
  */
  function getTossResultReturnedEvent () {
    return tossResultReturnedEvent;
  }

  /**
  * Expose toss submitted event
  */
  function getTossSubmittedEvent () {
    return tossSubmittedEvent;
  }

  /**
  * Expose contract logging event.
  */
  function getFlipItLogEvent () {
    return flipItLogEvent;
  }

  /*
  * Determine if the curent user is a player or game administrator.
  */
  function isAdmin () {
    return contractInstance.methods.isAdmin().call()
      .then(function (result) {
        return result;
      }
    );
  }

  /**
  * Provides an easy way to add money to the game contract.
  */
  function loadGame(amt, callback) {
    var callbackCalled = false;
    var config = {
      from: playerAccount,
      value: web3.utils.toWei(amt, "ether")
    };

    contractInstance.methods.loadGame()
      .send(config)
      .on("transactionHash", function(hash) {
        console.log('transactionHash: ' + hash);
      })
      .on("confirmation", function(confNum) {
        console.log('confirmation: ' + confNum);
      })
      .on("receipt", function(receipt){
        console.log('receipt: ' + receipt);
        if(!callbackCalled) {
          callbackCalled = true;
          callback();
        }
      });
  }

  function setMinimumBet (amt, callback) {
    var callbackCalled = false;

    var config = {
      from: playerAccount
    };

    contractInstance.methods.setMinimumBet(web3.utils.toWei(amt, "ether"))
      .send(config)
      .on("transactionHash", function(hash) {
        console.log('transactionHash: ' + hash);
      })
      .on("confirmation", function(confNum) {
        console.log('confirmation: ' + confNum);
      })
      .on("receipt", function(receipt){
        console.log('receipt: ' + receipt);

        if(!callbackCalled) {
          callbackCalled = true;
          callback();
        }
      });
  }

  /**
  * Provides an easy way for the game owner to withdraw money from the
  * game contract.
  */
  function withdraw (amt, callback) {
    var callbackCalled = false;

    var config = {
      from: playerAccount
    };

    contractInstance.methods.withdraw(web3.utils.toWei(amt, "ether"))
      .send(config)
      .on("transactionHash", function(hash) {
        console.log('transactionHash: ' + hash);
      })
      .on("confirmation", function(confNum) {
        console.log('confirmation: ' + confNum);
      })
      .on("receipt", function(receipt){
        console.log('receipt: ' + receipt);

        if(!callbackCalled) {
          callbackCalled = true;
          callback();
        }
      });

  }

  return {
    claimWin: claimWin,
    doToss: doToss,
    flipItLogEvent: getFlipItLogEvent,
    gameStats: getGameStats,
    init: initializeService,
    isAdmin: isAdmin,
    loadGame: loadGame,
    playerAccount: getPlayerAccount,
    setMinimumBet: setMinimumBet,
    tossResultReturnedEvent: getTossResultReturnedEvent,
    tossSubmittedEvent: getTossSubmittedEvent,
    web3: web3,
    winChoices: winchoices,
    withdraw: withdraw
  };
}();
