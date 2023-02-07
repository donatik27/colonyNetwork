const config = require("./.solcover.js")
const log = console.log;
const { execSync } = require("child_process");

const existingCompileComplete = config.onCompileComplete;

config.istanbulFolder = "./coverage-cross-chain"


function provisionSafeContracts(config){
  let output;
  const provisionSafeContracts = `yarn run provision:safe:contracts`;

  log('Provisioning Safe contracts...')
  output = execSync(provisionSafeContracts);
  log(output.toString())
}

config.onCompileComplete = function() {
	existingCompileComplete();
	provisionSafeContracts();
}

module.exports = config