// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Burnable.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";

interface USDC {
  function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
  function balanceOf(address account) external view returns (uint256);
  function transfer(address recipient, uint256 amount) external returns (bool);
}

contract ItemNFT is ERC1155, Ownable, Pausable, ERC1155Burnable, ERC1155Supply {

    USDC public usdc;
    uint256 constant usdcDecimals = 6;

    uint256 public mintPrice = 416; // Includes share price, fee & maintenance advance

    mapping(address => bool) public verified;
    bool public pauseTransfers;

    mapping(uint256 => uint256) public maxSupply; // Maximum amount of supply per token
    mapping(uint256 => uint256) public maxUserSupply; // Maximum amount of supply per user per token 

    constructor() ERC1155("") {
      usdc = USDC(0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174);
      pauseTransfers = true;
      maxSupply[0] = 2000;
      maxUserSupply[0] = 666; // 1/3 max
    }

    function setURI(string memory newuri) public onlyOwner {
        _setURI(newuri);
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function setMintPrice(uint256 newPrice) public onlyOwner {
      mintPrice = newPrice;
    }

    function setMaxSupply(uint256 id, uint256 max) public onlyOwner {
      maxSupply[id] = max;
    }

    function setMaxUserSupply(uint256 id, uint256 max) public onlyOwner {
      maxUserSupply[id] = max;
    }

    function withdrawBalance(address to, uint256 amount) public onlyOwner {
      usdc.transfer(to, amount);
    }

    function mint(address account, uint256 id, uint256 amount, bytes memory data)
        private
        whenNotPaused
    {
        require(id == 0, "Invalid token id."); // Just allow 1 tier for now
        require(amount > 0, "Can't mint 0 shares.");
        require(super.totalSupply(id) + amount <= maxSupply[id], "Not enough shares left.");  // Make shares not go over supply

        _mint(account, id, amount, data);
    }

    function mintWithUSDC(uint256 id, uint256 amount)
      public
      whenNotPaused
    {
      // Subtract leftover if this exceeds total supply
      uint256 validAmount = calculateValidAmount(id, amount);

      // Transfer USDC from the account to this contract
      uint256 price = validAmount * mintPrice;
      usdc.transferFrom(msg.sender, address(this), price * 10 ** usdcDecimals);

      // Perform mint
      mint(msg.sender, id, validAmount, "");
    }

    // For transfers paid with fiat
    function manualMint(address receiver, uint256 id, uint256 amount)
      public
      onlyOwner
      whenNotPaused
    {
      uint256 validAmount = calculateValidAmount(id, amount);

      mint(receiver, id, validAmount, "");
    }

    // For accidents on manual mints :(
    function manualBurn(address account, uint256 id, uint256 amount) 
      public 
      onlyOwner 
      whenNotPaused  
    {
      _burn(account, id, amount);
    }

    function calculateValidAmount(uint256 id, uint256 amount) private view returns (uint256) {
      if (super.totalSupply(id) + amount > maxSupply[id]) {
        require(super.totalSupply(id) < maxSupply[id], "No more shares left.");
        return maxSupply[id] - super.totalSupply(id);
      } else {
        return amount;
      }
    }

    function addressIsVerified(address account) public view returns (bool){
      return verified[account];
    }

    function addVerifiedAddress(address account) public onlyOwner {
      verified[account] = true;
    }

    function removeVerifiedAddress(address account) public onlyOwner {
      verified[account] = false;
    }

    function togglePauseTransfers() public onlyOwner {
      pauseTransfers = !pauseTransfers;
    }

    function _beforeTokenTransfer(address operator, address from, address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data)
        internal
        whenNotPaused
        override(ERC1155, ERC1155Supply)
    {
        require(verified[to], "This account is not verified (KYC)."); // Check if receiver is whitelisted
        require(pauseTransfers == false || from == address(0) || to == address(0), "Transfers are not allowed yet."); // Check if transfers are allowed, or it's a mint, or it's a burn
        
        // Check if user doesn't own too much shares. Null address can own any amount (burns)
        if (to != address(0)) {
            for (uint256 i = 0; i < ids.length; ++i) {
                    uint256 id = ids[i];
                    uint256 amount = amounts[i];
                    uint256 userBalance = super.balanceOf(to, id);
                    require((userBalance + amount) <= maxUserSupply[id], "Account is not allowed to own this much shares.");
            }
        }

        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);
    }
}
