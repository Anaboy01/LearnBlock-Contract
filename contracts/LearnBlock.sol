// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract EduTechQuiz {
    address public admin;

    struct Content {
        string title;
        bool exists;
    }

    struct Completion {
        bool eligible;
        bool claimed;
    }

    struct UserProfile {
        uint256 userId;
        uint256 quizzesCompleted;
        bool registered;
    }

    mapping(uint256 => Content) public contents;
    mapping(address => UserProfile) public profiles;
    mapping(address => mapping(uint256 => Completion)) public completions;

    uint256 public nextUserId = 1;

    event ContentRegistered(uint256 contentId, string title);
    event UserRegistered(address indexed user, uint256 userId);
    event QuizVerified(address indexed user, uint256 contentId);
    event RewardClaimed(address indexed user, uint256 contentId);

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin");
        _;
    }

    constructor() {
        admin = msg.sender;
    }

    function registerContent(uint256 contentId, string memory title) external onlyAdmin {
        require(!contents[contentId].exists, "Content already exists");

        contents[contentId] = Content({
            title: title,
            exists: true
        });

        emit ContentRegistered(contentId, title);
    }

    function registerUser(address user) external onlyAdmin {
        require(!profiles[user].registered, "User already registered");

        profiles[user] = UserProfile({
            userId: nextUserId,
            quizzesCompleted: 0,
            registered: true
        });

        emit UserRegistered(user, nextUserId);
        nextUserId++;
    }

    function markEligible(address user, uint256 contentId) external onlyAdmin {
        require(contents[contentId].exists, "Content not found");
        require(profiles[user].registered, "User not registered");
        require(!completions[user][contentId].eligible, "Already marked eligible");

        completions[user][contentId].eligible = true;

        emit QuizVerified(user, contentId);
    }

    function claimReward(uint256 contentId) external {
        require(profiles[msg.sender].registered, "Not registered");

        Completion storage completion = completions[msg.sender][contentId];
        require(contents[contentId].exists, "Invalid content");
        require(completion.eligible, "Not eligible");
        require(!completion.claimed, "Already claimed");

        completion.claimed = true;
        profiles[msg.sender].quizzesCompleted++;

        emit RewardClaimed(msg.sender, contentId);
    }

    function checkEligibility(address user, uint256 contentId) external view returns (bool eligible, bool claimed) {
        Completion memory c = completions[user][contentId];
        return (c.eligible, c.claimed);
    }

    function getUserId(address user) external view returns (uint256) {
        require(profiles[user].registered, "User not registered");
        return profiles[user].userId;
    }

    function getQuizzesCompleted(address user) external view returns (uint256) {
        return profiles[user].quizzesCompleted;
    }
}
