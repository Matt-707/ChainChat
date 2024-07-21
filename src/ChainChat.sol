// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// internal & private view & pure functions
// external & public view & pure functions

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract ChainChat {
    /**errors */
    error ChainChat__YouAreNotAnActiveUser();
    error ChainChat__YouAreNotTheOwner();

    /**storage variables */

    //STUFF TO DEAL WITH USERS
    mapping(address => bool) private everyUserEver;
    mapping(address => string) private s_addressToUsername;
    mapping(address => bool) private s_isActiveUser;
    mapping(string => bool) private s_isUsernameTaken;

    //STUFF TO DEAL WITH CONVERSATIONS BETWEEN USERS
    uint256[] private s_allConversationIds;
    mapping(address => uint256[])
        public s_addressToParticipatingConversationIds;
    uint256 public conversationCounter = 0;

    struct Conversation {
        uint256 id;
        address user1;
        address user2;
        bool isActive;
    }
    // Mapping from a unique pair hash to conversation ID
    mapping(bytes32 => uint256) public userPairToConversationId;

    // Mapping from conversation ID to Conversation struct
    mapping(uint256 => Conversation) public conversations;

    // Mapping from user address to active conversation partner addresses
    //mapping(address => address[]) public userToActiveConversations;

    //STUFF TO DEAL WITH MESSAGES
    struct Message {
        uint256 msgId;
        address sender;
        string userName;
        string message;
    }
    mapping(uint256 => Message[]) public s_idToMessages;

    /**immutables */
    address private immutable i_owner;

    /**Constructor */
    constructor() {
        i_owner = msg.sender;
    }

    /**Functions */

    function join(string memory suggestedUsername) public {
        if (s_isActiveUser[msg.sender] == true) {
            revert("You are already an active user");
        }
        if (s_isUsernameTaken[suggestedUsername] == true) {
            revert("This Username Is Already Taken");
        }
        if (
            keccak256(abi.encodePacked(suggestedUsername)) ==
            keccak256(abi.encodePacked(""))
        ) {
            revert("Please Enter a Username");
        }
        if (
            everyUserEver[msg.sender] && (s_isActiveUser[msg.sender] == false)
        ) {
            rejoin(suggestedUsername);
        }
        //update the address list, addressToUsername, isActiveUser and isUsernameTaken to fit new user
        s_addressToUsername[msg.sender] = suggestedUsername;
        s_isActiveUser[msg.sender] = true;
        everyUserEver[msg.sender] = true;
        s_isUsernameTaken[suggestedUsername] = true;
    }

    function sendMessage(
        string memory text,
        uint256 conversationId
    ) public OnlyActiveUser {
        Message memory latestMessage = Message(
            conversationId,
            msg.sender,
            s_addressToUsername[msg.sender],
            text
        );
        s_idToMessages[conversationId].push(latestMessage);
    }

    //function to hash the 2 users together returning a unique bytes32 object
    function getUserPairHash(
        address user1,
        address user2
    ) internal pure returns (bytes32) {
        return
            user1 < user2
                ? keccak256(abi.encodePacked(user1, user2))
                : keccak256(abi.encodePacked(user2, user1));
    }

    // Function to start a conversation between two users
    function startConversation(address user2) public returns (uint256) {
        if (s_isActiveUser[user2] == false) {
            revert("This address is not an active user.");
        }
        require(msg.sender != user2, "Users must be different");

        bytes32 pairHash = getUserPairHash(msg.sender, user2);
        require(
            userPairToConversationId[pairHash] == 0,
            "Conversation already exists"
        );

        conversationCounter++;
        uint256 newConversationId = conversationCounter;

        conversations[newConversationId] = Conversation({
            id: newConversationId,
            user1: msg.sender,
            user2: user2,
            isActive: true
        });

        userPairToConversationId[pairHash] = newConversationId;

        //pushing the new conversation Id to both users
        s_addressToParticipatingConversationIds[msg.sender].push(
            newConversationId
        );
        s_addressToParticipatingConversationIds[user2].push(newConversationId);

        return newConversationId;
    }

    function getMessages(
        uint256 conversationId
    ) public view OnlyActiveUser returns (Message[] memory, string memory) {
        bool conversationStatus = conversations[conversationId].isActive;
        if (conversationStatus == false) {
            return (
                s_idToMessages[conversationId],
                "This Conversation is no longer active as one participant has left the platform"
            );
        }
        return (s_idToMessages[conversationId], "");
    }

    function deleteUser() private OnlyActiveUser {
        //removing the username for the taken list
        s_isUsernameTaken[s_addressToUsername[msg.sender]] = false;
        //clearing th leaver's username
        s_addressToUsername[msg.sender] = "";
        //deactivating their active status
        s_isActiveUser[msg.sender] = false;

        uint256[]
            memory activeConversations = s_addressToParticipatingConversationIds[
                msg.sender
            ];
        for (uint256 i = 0; i < activeConversations.length; i++) {
            conversations[activeConversations[i]].isActive = false;
        }
    }

    function rejoin(string memory userName) private returns (string memory) {
        //removing the username for the taken list
        s_isUsernameTaken[s_addressToUsername[msg.sender]] = true;
        //clearing th leaver's username
        s_addressToUsername[msg.sender] = userName;
        //deactivating their active status
        s_isActiveUser[msg.sender] = true;

        uint256[]
            memory activeConversations = s_addressToParticipatingConversationIds[
                msg.sender
            ];
        for (uint256 i = 0; i < activeConversations.length; i++) {
            conversations[activeConversations[i]].isActive = false;
        }
        return (string.concat("Welcome Back ", userName));
    }

    function displayActiveConversations()
        public
        view
        OnlyActiveUser
        returns (uint256[] memory, address[] memory)
    {
        uint256[]
            memory activeConversations = s_addressToParticipatingConversationIds[
                msg.sender
            ];
        address[] memory conversationParticipants = new address[](
            activeConversations.length
        );
        for (uint256 i = 0; i < activeConversations.length; i++) {
            Conversation memory conversation = conversations[
                activeConversations[i]
            ];
            address otherUser = msg.sender == conversation.user1
                ? conversation.user2
                : conversation.user1;
            conversationParticipants[i] = otherUser;
        }
        return (activeConversations, conversationParticipants);
    }

    /**checker functions*/
    // Function to check if an address is in the list
    function isAddressAnActiveUser(
        address _address
    ) public view returns (bool) {
        return s_isActiveUser[_address];
    }

    /**modifiers */
    modifier OnlyOwner() {
        if (msg.sender != i_owner) {
            revert ChainChat__YouAreNotTheOwner();
        }
        _;
    }

    modifier OnlyActiveUser() {
        if (s_isActiveUser[msg.sender] == false) {
            revert ChainChat__YouAreNotAnActiveUser();
        }
        _;
    }
}
