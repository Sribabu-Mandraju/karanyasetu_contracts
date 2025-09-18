// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {INFTBadge} from "./interfaces/INFTBadge.sol";

contract GeneralDonorBadge is ERC721, INFTBadge {
    uint256 private _nextTokenId;
    address public owner;
    address public escrowContract;
    string private _baseTokenURI;

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    modifier onlyEscrow() {
        require(msg.sender == escrowContract, "Only escrow can mint");
        _;
    }

    constructor() ERC721("GeneralDonorBadge", "GDB") {
        owner = msg.sender;
    }

    function setAllowedContract(address _escrowContract) external onlyOwner {
        require(_escrowContract != address(0), "Invalid escrow address");
        escrowContract = _escrowContract;
    }

    function mint(address to) external override onlyEscrow returns (uint256) {
        uint256 tokenId = ++_nextTokenId;
        _safeMint(to, tokenId);

        emit BadgeMinted(to, tokenId);
        return tokenId;
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return _baseTokenURI;
    }

    function setBaseURI(string memory newBaseURI) external onlyOwner {
        _baseTokenURI = newBaseURI;
    }

    function totalSupply() external view override returns (uint256) {
        return _nextTokenId;
    }
}
