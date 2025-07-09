// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC20 {
    function transfer(address recipient, uint256 amount) external returns (bool);
}

contract EduTechQuiz {
    address public admin;
    IERC20 public rewardToken;

    struct Content {
        string title;
        uint256 tokenReward;
        bool exists;
    }

    struct Completion {
        bool eligible;
        bool claimed;
    }


    mapping(uint256 => Content) public contents;

   
    mapping(address => mapping(uint256 => Completion)) public completions;

    event ContentRegistered(uint256 contentId, string title, uint256 tokenReward);
    event QuizVerified(address indexed user, uint256 contentId);
    event RewardClaimed(address indexed user, uint256 contentId, uint256 amount);

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin");
        _;
    }

    constructor(address _token) {
        admin = msg.sender;
        rewardToken = IERC20(_token);
    }

    function registerContent(uint256 contentId, string memory title, uint256 rewardAmount) external onlyAdmin {
        require(!contents[contentId].exists, "Already exists");

        contents[contentId] = Content({
            title: title,
            tokenReward: rewardAmount,
            exists: true
        });

        emit ContentRegistered(contentId, title, rewardAmount);
    }

    // Called by backend when user passes the quiz
    function markEligible(address user, uint256 contentId) external onlyAdmin {
        require(contents[contentId].exists, "Content not found");
        require(!completions[user][contentId].eligible, "Already marked");

        completions[user][contentId].eligible = true;

        emit QuizVerified(user, contentId);
    }

    // Called by user from frontend
    function claimReward(uint256 contentId) external {
        Completion storage completion = completions[msg.sender][contentId];
        Content memory content = contents[contentId];

        require(content.exists, "Invalid content");
        require(completion.eligible, "Not eligible");
        require(!completion.claimed, "Already claimed");

        completion.claimed = true;
        rewardToken.transfer(msg.sender, content.tokenReward);

        emit RewardClaimed(msg.sender, contentId, content.tokenReward);
    }

    function checkEligibility(address user, uint256 contentId) external view returns (bool eligible, bool claimed) {
        Completion memory c = completions[user][contentId];
        return (c.eligible, c.claimed);
    }
}
