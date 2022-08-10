pragma solidity ^0.4.11;

import "zeppelin-solidity/contracts/token/ERC20.sol";

/**
 * @dev Extension of {ERC20} that adds a cap to the supply of tokens.
 */
contract ERC20Capped is ERC20 {
    uint256 private _cap;

    /**
     * @dev Sets the value of the `cap`. This value is immutable, it can only be
     * set once during construction.
     */
    function ERC20Capped(uint256 cap) public {
        require(cap > 0);
        _cap = cap;
    }

    /**
     * @dev Returns the cap on the token's total supply.
     */
    function cap() public returns (uint256) {
        return _cap;
    }
}
