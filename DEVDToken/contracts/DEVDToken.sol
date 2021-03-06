pragma solidity ^0.4.22;

// ----------------------------------------------------------------------------
// Safe maths
// ----------------------------------------------------------------------------
library SafeMath {
    function add(uint a, uint b) internal pure returns (uint c) {
        c = a + b;
        require(c >= a);
    }
    function sub(uint a, uint b) internal pure returns (uint c) {
        require(b <= a);
        c = a - b;
    }
    function mul(uint a, uint b) internal pure returns (uint c) {
        c = a * b;
        require(a == 0 || c / a == b);
    }
    function div(uint a, uint b) internal pure returns (uint c) {
        require(b > 0);
        c = a / b;
    }
}

// ----------------------------------------------------------------------------
// ERC Token Standard #20 Interface
// https://github.com/ethereum/EIPs/blob/master/EIPS/eip-20.md
// ----------------------------------------------------------------------------
contract ERC20Interface {
    function totalSupply() public constant returns (uint);
    function balanceOf(address tokenOwner) public constant returns (uint balance);
    function allowance(address tokenOwner, address spender) public constant returns (uint remaining);
    function transfer(address to, uint tokens) public returns (bool success);
    function approve(address spender, uint tokens) public returns (bool success);
    function transferFrom(address from, address to, uint tokens) public returns (bool success);

    event Transfer(address indexed from, address indexed to, uint tokens);
    event Approval(address indexed tokenOwner, address indexed spender, uint tokens);
}

// ----------------------------------------------------------------------------
// Owned contract
// ----------------------------------------------------------------------------
contract Owned {
    address public owner;
    address public newOwner;

    event OwnershipTransferred(address indexed _from, address indexed _to);

    constructor() public {
        owner = msg.sender;
    }

    modifier onlyOwner {
        require(msg.sender == owner);
        _;
    }

    function transferOwnership(address _newOwner) public onlyOwner {
        newOwner = _newOwner;
    }
    function acceptOwnership() public {
        require(msg.sender == newOwner);
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
        newOwner = address(0);
    }
}

// ----------------------------------------------------------------------------
// ERC20 Token, with the addition of symbol, name and decimals and a
// fixed supply
// ----------------------------------------------------------------------------
contract DEVDToken is ERC20Interface, Owned {
    using SafeMath for uint;
   
    string public symbol;
    string public  name;
    uint8 public decimals;
    uint _totalSupply;
    uint256 public sellPrice;                 // For Automatic Buying and Selling
    uint256 public buyPrice;

    // balanceOf for each account
    mapping(address => uint256) balanceOfAccounts;
 
    // Owner of account approves the transfer of an amount to another account
    mapping(address => mapping (address => uint256)) allowed;
    mapping (address => bool) public frozenAccount;
    
    event FrozenFunds(address target, bool frozen);

    // This notifies clients about the amount burnt
    event Burn(address indexed from, uint256 value);

    constructor() public {
        symbol = "DEVD";
        name = "DEVD Supply Token";
        decimals = 18;
        _totalSupply = 1000000 * 10**uint(decimals);
        balanceOfAccounts[owner] = _totalSupply;
        emit Transfer(address(0), owner, _totalSupply);
  }

   // ------------------------------------------------------------------------
    // Total supply
    // ------------------------------------------------------------------------
    function totalSupply() public view returns (uint) {
        return _totalSupply.sub(balanceOfAccounts[address(0)]);
    }

    // ------------------------------------------------------------------------
    // Get the token balance for account `tokenOwner`
    // ------------------------------------------------------------------------
    function balanceOf(address tokenOwner) public view returns (uint balance) {
        return balanceOfAccounts[tokenOwner];
    }

    /**
     * Internal transfer, only can be called by this contract
     */
    function _transfer(address _from, address _to, uint _tokens) internal {

    // Prevent transfer to 0x0 address. Use burn() instead
       require(_to != 0x0);       

    // Check if the sender has enough
       require(balanceOfAccounts[_from] >= _tokens);

    // Funds should not be Frozen
       require(!frozenAccount[_from]);

    // Save this for an assertion in the future
       uint previousBalances = balanceOfAccounts[_from] + balanceOfAccounts[_to];       
       balanceOfAccounts[_from] = balanceOfAccounts[_from].sub(_tokens);
       balanceOfAccounts[_to] = balanceOfAccounts[_to].add(_tokens);
      
       emit Transfer(_from, _to, _tokens);
    // Asserts are used to use static analysis to find bugs in your code. They should never fail
       assert(balanceOfAccounts[_from] + balanceOfAccounts[_to] == previousBalances);
    }

   /**
     * Transfer tokens
     *
     * Send `_value` tokens to `_to` from your account
     *
     * @param _to The address of the recipient
     * @param _tokens the amount to send
     */

    function transfer(address _to, uint256 _value) public returns (bool success) {
        _transfer(msg.sender, _to, _value);
        return true;
    }

    // ------------------------------------------------------------------------
    // Token owner can approve for `spender` to transferFrom(...) `tokens`
    // from the token owner's account
    //
    // https://github.com/ethereum/EIPs/blob/master/EIPS/eip-20-token-standard.md
    // recommends that there are no checks for the approval double-spend attack
    // as this should be implemented in user interfaces 
    // ------------------------------------------------------------------------
    function approve(address spender, uint tokens) public returns (bool success) {
        allowed[msg.sender][spender] = tokens;
        emit Approval(msg.sender, spender, tokens);
        return true;
    }

    // ------------------------------------------------------------------------
    // Transfer `tokens` from the `from` account to the `to` account
    // 
    // The calling account must already have sufficient tokens approve(...)-d
    // for spending from the `from` account and
    // - From account must have sufficient balance to transfer
    // - Spender must have sufficient allowance to transfer
    // - 0 value transfers are allowed
    // ------------------------------------------------------------------------
    function transferFrom(address _from, address _to, uint _tokens) public returns (bool success) {
     /*  require(_tokens <= allowed[_from][msg.sender]);     // Check allowance Nnot required using safe math*/

       balanceOfAccounts[_from] = balanceOfAccounts[_from].sub(_tokens);
       allowed[_from][msg.sender] = allowed[_from][msg.sender].sub(_tokens);
       balanceOfAccounts[_to] = balanceOfAccounts[_to].add(_tokens);
       emit Transfer(_from, _to, _tokens);
       return true;
    }

    // ------------------------------------------------------------------------
    // Returns the amount of tokens approved by the owner that can be
    // transferred to the spender's account
    // ------------------------------------------------------------------------
    function allowance(address tokenOwner, address spender) public view returns (uint remaining) {
        return allowed[tokenOwner][spender];
    }    

    /**
     * Destroy tokens
     *
     * Remove `_value` tokens from the system irreversibly
     *
     * @param _value the amount of money to burn
     */
    function burn(uint256 _tokens) public returns (bool success) {
        require(balanceOfAccounts[msg.sender] >= _tokens);   // Check if the sender has enough
        balanceOfAccounts[msg.sender] = balanceOfAccounts[msg.sender].sub(_tokens);            // Subtract from the sender
        _totalSupply = _totalSupply.sub(_tokens);                      // Updates totalSupply
        emit Burn(msg.sender, _tokens);
        return true;
    }

   /** Contract owner to freeze or unfreeze assets */
    function freezeAccount(address target, bool freeze) onlyOwner {
        frozenAccount[target] = freeze;
        emit FrozenFunds(target, freeze);
    }

    /** Set Buying and Selling Prices */
    function setPrices(uint256 newSellPrice, uint256 newBuyPrice) onlyOwner {
        sellPrice = newSellPrice;
        buyPrice = newBuyPrice;
    }
    
        function buy() payable returns (uint amount){
        amount = msg.value / buyPrice;                    // calculates the amount
        _transfer(this, msg.sender, amount);
        return amount;
    }

    function sell(uint amount) returns (uint revenue){
        require(balanceOfAccounts[msg.sender] >= amount);      // checks if the sender has enough to sell
        balanceOfAccounts[this] += amount;                     // adds the amount to owner's balance
        balanceOfAccounts[msg.sender] -= amount;               // subtracts the amount from seller's balance
        revenue = amount * sellPrice;
        msg.sender.transfer(revenue);                          // sends ether to the seller: it's important to do this last to prevent recursion attacks
        emit Transfer(msg.sender, this, amount);               // executes an event reflecting on the change
        return revenue;                                        // ends function and returns
    }

    // ------------------------------------------------------------------------
    // Don't accept ETH
    // ------------------------------------------------------------------------
    function () public payable {
        revert();
    }

    // ------------------------------------------------------------------------
    // Owner can transfer out any accidentally sent ERC20 tokens
    // ------------------------------------------------------------------------
    function transferAnyERC20Token(address tokenAddress, uint tokens) public onlyOwner returns (bool success) {
        return ERC20Interface(tokenAddress).transfer(owner, tokens);
    }    

}