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

    uint256 public mintPrice = 600;
    uint256 public mintingFee = 30; // 5% fee on crowdfund

    constructor() ERC1155("") {
      usdc = USDC(0x0FA8781a83E46826621b3BC094Ea2A0212e71B23);
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
    {
        _mint(account, id, amount, data);
    }

    function mintWithUSDC(uint256 id, uint256 amount)
      public
    {
      // Transfer USDC from the account to this contract
      uint256 price = amount * (mintPrice + mintingFee);
      usdc.transferFrom(msg.sender, address(this), price * 10 ** usdcDecimals);

      // Perform mint
      mint(msg.sender, id, amount, "");
    }

    function _beforeTokenTransfer(address operator, address from, address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data)
        internal
        whenNotPaused
        override(ERC1155, ERC1155Supply)
    {
        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);
    }
}
