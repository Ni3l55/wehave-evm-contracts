// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Burnable.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";

interface USDC {
  function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
}

contract ItemNFT is ERC1155, Ownable, Pausable, ERC1155Burnable, ERC1155Supply {

    USDC public usdc;
    uint256 constant usdcDecimals = 18;

    uint256 public mintPrice = 800;
    uint256 public mintingFee = 40; // 5% fee on crowdfund

    mapping(address => bool) verified;
    bool public pauseTransfers;

    constructor() ERC1155("") {
      usdc = USDC(0x0FA8781a83E46826621b3BC094Ea2A0212e71B23);
      pauseTransfers = false;
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

    function mint(address account, uint256 id, uint256 amount, bytes memory data)
        private
        whenNotPaused
    {
        // TODO check whitelisted

        _mint(account, id, amount, data);
    }

    function mintWithUSDC(uint256 id, uint256 amount)
      public
      whenNotPaused
    {
      // Transfer USDC from the account to this contract
      uint256 price = amount * (mintPrice + mintingFee);
      usdc.transferFrom(msg.sender, address(this), price * 10 ** usdcDecimals);

      // Perform mint
      mint(msg.sender, id, amount, "");
    }

    function manualMint(address receiver, uint256 id, uint256 amount)
      public
      onlyOwner
      whenNotPaused
    {
      mint(receiver, id, amount, "");
    }

    function addressIsVerified(address account) public view returns (bool){
      return verified[account];
    }

    function addVerifiedAddress(address account) public onlyOwner {
      verified[account] = true;
    }

    function removeVerifiedAddressAt(uint index) public onlyOwner {
      delete verified[account] = false;
    }

    function togglePauseTransfers() public onlyOwner {
      pauseTransfers = !pauseTransfers;
    }

    function _beforeTokenTransfer(address operator, address from, address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data)
        internal
        whenNotPaused
        override(ERC1155, ERC1155Supply)
    {
        require(pauseTransfers == false);
        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);
    }
}
