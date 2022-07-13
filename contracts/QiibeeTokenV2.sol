pragma solidity ^0.4.11;

import "zeppelin-solidity/contracts/token/PausableToken.sol";
import "zeppelin-solidity/contracts/token/BurnableToken.sol";
import "zeppelin-solidity/contracts/token/VestedToken.sol";
import "zeppelin-solidity/contracts/ownership/Ownable.sol";
import "./extensions/ERC20Capped.sol";
import "./extensions/ERC20Mintable.sol";

// @dev Migration Agent interface
contract MigrationAgentInterface {
    function migrateFrom(address _from, uint256 _value);

    function setSourceToken(address _qbxSourceToken);

    function updateSupply();

    function qbxSourceToken() returns (address);
}

/**
   @title QBX, the qiibee V2 token

   Implementation of QBX, an ERC20 token for the qiibee ecosystem. The smallest unit of a qbx is
   the atto. The token call be migrated to a new token by calling the `migrate()` function.
 */
contract QiibeeTokenV2 is
    Ownable,
    BurnableToken,
    PausableToken,
    VestedToken,
    ERC20Mintable,
    ERC20Capped
{
    using SafeMath for uint256;

    string public constant symbol = "QBX";
    string public constant name = "qiibeeCoin";
    uint8 public constant decimals = 18;

    // migration vars
    uint256 public totalMigrated;
    uint256 public newTokens; // amount of tokens minted after migrationAgent has been set
    uint256 public burntTokens; // amount of tokens burnt after migrationAgent has been set
    address public migrationAgent;
    address public migrationMaster;
    address public upgradeEngine;
    bool public upgradeStarted;

    event Migrate(address indexed _from, address indexed _to, uint256 _value);
    event NewVestedToken(
        address indexed from,
        address indexed to,
        uint256 value,
        uint256 grantId
    );
    /**
     * @dev Emitted when the upgrade token swap engine is conected or disconnected to the token contract.
     * @param engineConnected the status of the upgrade engine when the connection status changes
     * @param upgradeEngine address of the engine contract.
     */
    event SwapEngineConnected(
        bool indexed engineConnected,
        address indexed upgradeEngine
    );

    modifier onlyMigrationMaster() {
        require(msg.sender == migrationMaster);
        _;
    }

    /**
     * @dev Throws if called by any account other than the owner or the migration agent.
     */
    modifier onlyOwnerOrUpgradeEngine() {
        require(msg.sender == owner || msg.sender == upgradeEngine);
        _;
    }

    /*
     * Constructor.
     */
    function QiibeeTokenV2(address _migrationMaster)
        ERC20Capped(1380392157 * 10**18)
    {
        require(_migrationMaster != address(0));
        migrationMaster = _migrationMaster;
    }

    /**
      @dev Similar to grantVestedTokens but minting tokens instead of transferring.
    */
    function mintVestedTokens(
        address _to,
        uint256 _value,
        uint64 _start,
        uint64 _cliff,
        uint64 _vesting,
        bool _revokable,
        bool _burnsOnRevoke,
        address _wallet
    ) public onlyOwner returns (bool) {
        // Check for date inconsistencies that may cause unexpected behavior
        require(_cliff >= _start && _vesting >= _cliff);

        require(tokenGrantsCount(_to) < MAX_GRANTS_PER_ADDRESS); // To prevent a user being spammed and have his balance locked (out of gas attack when calculating vesting).

        uint256 count = grants[_to].push(
            TokenGrant(
                _revokable ? _wallet : 0, // avoid storing an extra 20 bytes when it is non-revokable
                _value,
                _cliff,
                _vesting,
                _start,
                _revokable,
                _burnsOnRevoke
            )
        );

        NewVestedToken(msg.sender, _to, _value, count - 1);
        return mint(_to, _value); //mint tokens
    }

    /**
      @dev Overrides VestedToken#grantVestedTokens(). Only owner can call it.
    */
    function grantVestedTokens(
        address _to,
        uint256 _value,
        uint64 _start,
        uint64 _cliff,
        uint64 _vesting,
        bool _revokable,
        bool _burnsOnRevoke
    ) public onlyOwner {
        super.grantVestedTokens(
            _to,
            _value,
            _start,
            _cliff,
            _vesting,
            _revokable,
            _burnsOnRevoke
        );
    }

    /**
      @dev Set address of migration agent contract and enable migration process.
      @param _agent The address of the MigrationAgent contract
     */
    function setMigrationAgent(address _agent) public onlyMigrationMaster {
        require(
            MigrationAgentInterface(_agent).qbxSourceToken() == address(this)
        );
        require(migrationAgent == address(0));
        require(_agent != address(0));
        migrationAgent = _agent;
    }

    /**
      @dev Migrates the tokens to the target token through the MigrationAgent.
      @param _value The amount of tokens (in atto) to be migrated.
     */
    function migrate(uint256 _value) public whenNotPaused {
        require(migrationAgent != address(0));
        require(_value != 0);
        require(_value <= balances[msg.sender]);
        require(_value <= transferableTokens(msg.sender, uint64(now)));
        balances[msg.sender] = balances[msg.sender].sub(_value);
        totalSupply = totalSupply.sub(_value);
        totalMigrated = totalMigrated.add(_value);

        Migrate(msg.sender, migrationAgent, _value);
    }

    /**
     * @dev Connect the upgrade token swap engine so that this new token can be minted for old token holders.
     * @notice Only owner can set the engineAddress. This action is one-time only.
     * @param engineAddress address of the token upgrade token swap engine contract.
     */
    function connectUpgradeEngine(address engineAddress) public onlyOwner {
        require(!upgradeStarted);
        upgradeEngine = engineAddress;
        upgradeStarted = true;
        SwapEngineConnected(upgradeStarted, upgradeEngine);
    }

    /**
     * @dev Disconnect the upgrade token swap engine.
     * @notice Only owner can disconnect the engine. This action is one-time only.
     */
    function removeUpgradeEngine() public onlyOwner {
        require(upgradeStarted);

        // leave the minter to address zero.
        upgradeEngine = address(0);
        SwapEngineConnected(false, upgradeEngine);
    }

    /**
     * @dev Overrides mint() function so as to keep track of the tokens minted after the
     * migrationAgent has been set. This is to ensure that the migration agent has always the
     * totalTokens variable up to date. This prevents the failure of the safetyInvariantCheck().
     *
     * Requirements:
     * - minted tokens must not cause the total supply to go over the cap.
     * @param _to The address that will receive the minted tokens.
     * @param _amount The amount of tokens to mint.
     * @return A boolean that indicates if the operation was successful.
     */
    function mint(address _to, uint256 _amount)
        public
        onlyOwnerOrUpgradeEngine
        canMint
        returns (bool)
    {
        require(totalSupply.add(_amount) <= super.cap());

        bool mint = super.mint(_to, _amount);
        if (mint && migrationAgent != address(0)) {
            newTokens = newTokens.add(_amount);
        }
        return mint;
    }

    /*
     * @dev Changes the migration master.
     * @param _master The address of the migration master.
     */
    function setMigrationMaster(address _master) public onlyMigrationMaster {
        require(_master != address(0));
        migrationMaster = _master;
    }

    /*
     * @dev Resets newTokens to zero. Can only be called by the migrationAgent
     */
    function resetNewTokens() {
        require(msg.sender == migrationAgent);
        newTokens = 0;
    }

    /*
     * @dev Resets burntTokens to zero. Can only be called by the migrationAgent
     */
    function resetBurntTokens() {
        require(msg.sender == migrationAgent);
        burntTokens = 0;
    }

    /*
     * @dev Burns a specific amount of tokens.
     * @param _value The amount of tokens to be burnt.
     */
    function burn(uint256 _value) public whenNotPaused onlyOwner {
        super.burn(_value);
        if (migrationAgent != address(0)) {
            burntTokens = burntTokens.add(_value);
        }
    }
}
