const QiibeeToken = artifacts.require("./QiibeeToken.sol");

module.exports = function (deployer) {
    deployer.deploy(QiibeeToken, '0x82f42dc102f0d957053b2c8dbd8516f3d796279f');
};
