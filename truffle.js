const Web3 = require('web3');
const web3 = new Web3();
const WalletProvider = require('truffle-wallet-provider');
const Wallet = require('ethereumjs-wallet');

const ropstenPrivateKey = new Buffer(process.env.ROPSTEN_PRIVATE_KEY, 'hex');
const ropstenWallet = Wallet.fromPrivateKey(ropstenPrivateKey);
const ropstenProvider = new WalletProvider(ropstenWallet, 'https://ropsten.infura.io/' + process.env.INFURA_API_TOKEN);

module.exports = {
  networks: {
    development: {
      host: 'localhost',
      port: 8545,
      network_id: '*',
      gasPrice: 22000000000
    },
    coverage: {
      host: "localhost",
      port: 8555,
      network_id: "*",
      gas: 0xfffffffffff,
      gasPrice: 0x01
    },
    ropsten: {
      provider: ropstenProvider,
      gas: 5700000,
      gasPrice: web3.utils.toWei('50', 'gwei'),
      network_id: '3',
    }
  },
  rpc: {
    host: "localhost",
    port: 8545
  }
};
