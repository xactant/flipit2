const FlipIt_V1 = artifacts.require("FlipIt_V1");

module.exports = async function(deployer, network, accounts){
  //Deploy Contracts
  deployer.deploy(FlipIt_V1);
};
