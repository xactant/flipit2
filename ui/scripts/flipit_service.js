/**
* The flipitservice module provides an insterface to the
* FlipIt contract.
*
* TODO Add better exception handling, web3 and contract
* state checking.
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
  var winEvent = null;
  var loseEvent = null;
  var playerAccount = '';
  var wager = initialWager();

  // Provide player's available choices.
  winchoices = {
    HEADS: 0,
    TAILS: 1
  };

  function initialWager() {
    return {
      claimed: false,
      pending: false,
      claimId: '0x0'
    };
  }

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
    });
  }

  function claimWin(queryId, callback) {
    console.log('Claiming win with queryId: ' + queryId);
    var callbackCalled = false;

    var config = {
      from: playerAccount,
      gas: 2000000
    };
/*
    return contractInstance.methods.claimWin(queryId).call()
      .then(function(result){
        console.log("claimWin(queryId) returned: " + JSON.stringify(result));
      });
*/
    return contractInstance.methods.claimWin(queryId)
    .send(config) //, function(){});
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

    /*
    .call()
      .then(function(result) {
        console.log(JSON.stringify(result));

        return {"amount": result["0"],
          "payout": result["1"],
          "timestamp": result["2"],
          "pending": result["3"],
          "claimed": result["4"],
          "win": result["5"],
          "choice": result["6"],
          "result": result["7"]};
      });
      */

  }

  /**
  * Send player's prediction and wager to the contract.
  * TODO replace alerts with notifications
  * TODO Maybe split post processing between events - is this necessary?
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
      alert ('Must choose heads or tails.');
      return null;
    }

    wager = initialWager();

    if (isInitialized) {
      var config = {
        from: playerAccount,
        value: dem == 'wei'? dem : web3.utils.toWei(wagerAmt, dem),
        gas: 2000000
      };

      contractInstance.methods.toss(parseInt(winChoice))
        .send(config, callback);
        /*
        .on("transactionHash", function(hash) {
          console.log('toss transactionHash: ' + hash);
        })
        .on("confirmation", function(confNum) {
          console.log('toss confNum: ' + confNum);
        })
        .on("receipt", function(receipt){
          console.log('toss receipt: ' + JSON.stringify(receipt));
        })
        .on("error", function(err){
          console.log('toss error: ' + JSON.stringify(err));
        });
        */
    }
    else {
      console.error ('toss Module flipitService is not initialized.');
    }
  }

  function getGameStats () {
    var unclaimedWin = false;
    var unclaimedQueryId = null;

    return contractInstance.methods.getAccountWager().call()
    .then (function(wagerData) {
      console.log("Wager Data: " + JSON.stringify(wagerData));

      unclaimedWin = (wagerData[7] && !wagerData[9]);

      if (unclaimedWin) {
        unclaimedQueryId = wagerData[5];
      }

      return contractInstance.methods.getGameStats().call()
        .then(function(result) {
          return {
            wagersMade: result[0],
            wagersWon: result[1],
            amountWagered: result[2],
            amountPaidOut: result[3],
            availableBalance: result[4],
            winMultiplyer: result[5],
            unclaimedWin: unclaimedWin,
            unclaimedQueryId: unclaimedQueryId
          };
      });
    });
  }

  function getPlayerAccount() {
    return playerAccount;
  }

  function getTossResultReturnedEvent () {
    return tossResultReturnedEvent;
  }

  function getTossSubmittedEvent () {
    return tossSubmittedEvent;
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

  function onLoseEvent () {
      if (loseEvent) {
        loseEvent();
      }
  }

  function onWinEvent () {
    if (winEvent) {
      winEvent();
    }
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
    gameStats: getGameStats,
    init: initializeService,
    isAdmin: isAdmin,
    loadGame: loadGame,
    doToss: doToss,
    web3: web3,
    winChoices: winchoices,
    withdraw: withdraw,
    playerAccount: getPlayerAccount,
    tossResultReturnedEvent: getTossResultReturnedEvent,
    tossSubmittedEvent: getTossSubmittedEvent
  };
}();
