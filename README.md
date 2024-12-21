![](https://avatars3.githubusercontent.com/u/31820267?v=4&s=100)

QBX Token
=======================

[![Build Status](https://travis-ci.org/qiibee/qb-contracts.svg?branch=master)](https://travis-ci.org/qiibee/qb-token)
[![Coverage Status](https://coveralls.io/repos/github/qiibee/qb-contracts/badge.svg?branch=master)](https://coveralls.io/github/qiibee/qb-contracts?branch=master)

QBX is the token (ERC20 based) of the qiibee protocol.


## Requirements

Node v8 or higher

## Install

```sh
npm install
```

## Main Contracts

- [QiibeeToken](contracts/QiibeeToken.sol)

## Test

* To run all tests: `npm test`

* To enable verbose mode: `npm test --v` OR `npm test --verbose`

* To run a specific test: `npm test -- test/QiibeeToken.js`


## Coverage
Coverage has been disable because of conflicts with the different solidity versions of the contracts.


## Deploy to Ropsten
* Set environment variables:
    * `ROPSTEN_PRIVATE_KEY` - private key of account you want to use to deploy with (omit `0x`)
    * `INFURA_API_TOKEN` - your Infura API token
* Update values in `migrations/2_token_migration.js` 
    * update address with address you want to set as owner


## License

qiibee Token is open source and distributed under the [Apache License v2.0](https://github.com/qiibee/qb-token/blob/master/LICENSE)
