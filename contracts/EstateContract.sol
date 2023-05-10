// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/common/ERC2981.sol";

import "./extensions/ERC4907.sol";

contract EstateContract is ERC4907, ERC721Enumerable, ERC721URIStorage, ERC2981, Pausable, Ownable, ERC721Burnable {
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIdCounter;

    constructor(
        string memory name_,
        string memory symbol_,
        address _royaltyRecipient,
        uint96 _royaltyBps
    ) ERC4907(name_, symbol_) {
        _setDefaultRoyalty(_royaltyRecipient, _royaltyBps);
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function safeMint(address to, string memory uri) public {
        uint256 _tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        _safeMint(to, _tokenId);
        _setTokenURI(_tokenId, uri);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 _tokenId,
        uint256 batchSize
    ) internal override(ERC721, ERC4907, ERC721Enumerable) whenNotPaused {
        super._beforeTokenTransfer(from, to, _tokenId, batchSize);
    }

    // The following functions are overrides required by Solidity.

    function _burn(uint256 _tokenId) internal override(ERC721, ERC721URIStorage) {
        super._burn(_tokenId);
        _resetTokenRoyalty(_tokenId);
    }

    function tokenURI(uint256 _tokenId) public view override(ERC721, ERC721URIStorage) returns (string memory) {
        return super.tokenURI(_tokenId);
    }

    function tokenId() public view returns (uint256) {
        return _tokenIdCounter.current();
    }

    function supportsInterface(
        bytes4 interfaceId
    ) public view override(ERC721, ERC4907, ERC2981, ERC721Enumerable) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
