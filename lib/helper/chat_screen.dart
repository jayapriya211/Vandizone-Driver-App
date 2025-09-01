// import 'dart:convert';
// import 'dart:math';
// import 'package:http/http.dart' as http;
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:agora_rtm/agora_rtm.dart';
// import 'package:permission_handler/permission_handler.dart';
//
// const String appId = "da5ba2c7378a4397b8fec54f3e4521ce";
//
// // Main Chat App Entry Point
// class ChatApp extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       title: 'Agora Chat',
//       theme: ThemeData(
//         primarySwatch: Colors.blue,
//         visualDensity: VisualDensity.adaptivePlatformDensity,
//       ),
//       home: ChatHomeScreen(),
//     );
//   }
// }
//
// // Chat Home Screen - Lists channels and conversations
// class ChatHomeScreen extends StatefulWidget {
//   @override
//   State<ChatHomeScreen> createState() => _ChatHomeScreenState();
// }
//
// class _ChatHomeScreenState extends State<ChatHomeScreen> {
//   final _channelController = TextEditingController();
//   final _searchController = TextEditingController();
//   AgoraRtmClient? _client;
//   List<ChatChannel> _channels = [];
//   List<ChatChannel> _filteredChannels = [];
//   bool _isInitialized = false;
//   String? _currentUserId;
//
//   @override
//   void initState() {
//     super.initState();
//     _initializeChat();
//   }
//
//   Future<void> _initializeChat() async {
//     try {
//       final user = FirebaseAuth.instance.currentUser;
//       if (user == null) return;
//
//       _currentUserId = user.uid;
//
//       // Create RTM client
//       _client = await AgoraRtmClient.createInstance(appId);
//
//       // Set up event callbacks
//       _client?.onMessageReceived = (AgoraRtmMessage message, String peerId) {
//         _handleDirectMessage(message, peerId);
//       };
//
//       _client?.onConnectionStateChanged = (int state, int reason) {
//         print("RTM Connection state: $state, reason: $reason");
//       };
//
//       // Login to RTM
//       final token = await _fetchRTMToken(_currentUserId!);
//       if (token != null) {
//         await _client?.login(token, _currentUserId!);
//         setState(() => _isInitialized = true);
//       }
//
//       _loadChannels();
//     } catch (e) {
//       print("Failed to initialize chat: $e");
//     }
//   }
//
//   Future<String?> _fetchRTMToken(String userId) async {
//     try {
//       final user = FirebaseAuth.instance.currentUser;
//       final idToken = await user?.getIdToken();
//
//       final response = await http.post(
//         Uri.parse("https://generateagorartmtoken-2eejyf46ra-uc.a.run.app"), // You'll need to create this endpoint
//         headers: {
//           'Content-Type': 'application/json',
//           'Authorization': 'Bearer $idToken',
//         },
//         body: jsonEncode({'userId': userId}),
//       );
//
//       if (response.statusCode == 200) {
//         final data = jsonDecode(response.body);
//         return data['token'];
//       }
//     } catch (e) {
//       print("Failed to fetch RTM token: $e");
//     }
//     return null;
//   }
//
//   void _handleDirectMessage(AgoraRtmMessage message, String peerId) {
//     // Handle incoming direct messages
//     setState(() {
//       final existingChannel = _channels.firstWhere(
//             (channel) => channel.id == peerId && channel.type == ChatType.direct,
//         orElse: () => ChatChannel(
//           id: peerId,
//           name: peerId,
//           type: ChatType.direct,
//           lastMessage: message.text,
//           lastMessageTime: DateTime.now(),
//           unreadCount: 0,
//         ),
//       );
//
//       if (!_channels.contains(existingChannel)) {
//         _channels.insert(0, existingChannel);
//       } else {
//         existingChannel.lastMessage = message.text;
//         existingChannel.lastMessageTime = DateTime.now();
//         existingChannel.unreadCount++;
//       }
//     });
//     _filterChannels();
//   }
//
//   void _loadChannels() {
//     // Load saved channels from local storage or API
//     // For demo purposes, we'll create some sample channels
//     setState(() {
//       _channels = [
//         ChatChannel(
//           id: "general",
//           name: "General",
//           type: ChatType.group,
//           lastMessage: "Welcome to the chat!",
//           lastMessageTime: DateTime.now().subtract(Duration(minutes: 30)),
//           unreadCount: 0,
//         ),
//         ChatChannel(
//           id: "developers",
//           name: "Developers",
//           type: ChatType.group,
//           lastMessage: "Anyone working on Flutter?",
//           lastMessageTime: DateTime.now().subtract(Duration(hours: 2)),
//           unreadCount: 3,
//         ),
//       ];
//     });
//     _filterChannels();
//   }
//
//   void _filterChannels() {
//     final query = _searchController.text.toLowerCase();
//     setState(() {
//       _filteredChannels = _channels.where((channel) {
//         return channel.name.toLowerCase().contains(query) ||
//             channel.lastMessage.toLowerCase().contains(query);
//       }).toList();
//     });
//   }
//
//   void _createOrJoinChannel() {
//     if (_channelController.text.trim().isEmpty) return;
//
//     final channelName = _channelController.text.trim();
//     final newChannel = ChatChannel(
//       id: channelName,
//       name: channelName,
//       type: ChatType.group,
//       lastMessage: "Channel created",
//       lastMessageTime: DateTime.now(),
//       unreadCount: 0,
//     );
//
//     setState(() {
//       _channels.removeWhere((c) => c.id == channelName);
//       _channels.insert(0, newChannel);
//     });
//     _filterChannels();
//     _channelController.clear();
//
//     // Navigate to chat screen
//     _openChat(newChannel);
//   }
//
//   void _openChat(ChatChannel channel) {
//     Navigator.push(
//       context,
//       MaterialPageRoute(
//         builder: (context) => ChatScreen(
//           channel: channel,
//           client: _client!,
//           currentUserId: _currentUserId!,
//         ),
//       ),
//     ).then((_) {
//       // Mark as read when returning
//       setState(() {
//         channel.unreadCount = 0;
//       });
//     });
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.grey[900],
//       appBar: AppBar(
//         title: Text("Chat", style: TextStyle(color: Colors.white)),
//         backgroundColor: Colors.transparent,
//         elevation: 0,
//         actions: [
//           IconButton(
//             icon: Icon(Icons.person_add, color: Colors.white),
//             onPressed: _showDirectMessageDialog,
//           ),
//         ],
//       ),
//       body: _isInitialized ? _buildChatList() : _buildLoadingScreen(),
//       floatingActionButton: FloatingActionButton(
//         onPressed: _showCreateChannelDialog,
//         backgroundColor: Colors.blue,
//         child: Icon(Icons.add, color: Colors.white),
//       ),
//     );
//   }
//
//   Widget _buildLoadingScreen() {
//     return Center(
//       child: Column(
//         mainAxisAlignment: MainAxisAlignment.center,
//         children: [
//           CircularProgressIndicator(color: Colors.blue),
//           SizedBox(height: 16),
//           Text(
//             "Initializing chat...",
//             style: TextStyle(color: Colors.white, fontSize: 16),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildChatList() {
//     return Column(
//       children: [
//         // Search bar
//         Container(
//           margin: EdgeInsets.all(16),
//           padding: EdgeInsets.symmetric(horizontal: 16),
//           decoration: BoxDecoration(
//             color: Colors.grey[800],
//             borderRadius: BorderRadius.circular(25),
//           ),
//           child: TextField(
//             controller: _searchController,
//             style: TextStyle(color: Colors.white),
//             decoration: InputDecoration(
//               hintText: "Search chats...",
//               hintStyle: TextStyle(color: Colors.grey[400]),
//               prefixIcon: Icon(Icons.search, color: Colors.grey[400]),
//               border: InputBorder.none,
//             ),
//             onChanged: (_) => _filterChannels(),
//           ),
//         ),
//
//         // Channel list
//         Expanded(
//           child: _filteredChannels.isEmpty
//               ? Center(
//             child: Text(
//               "No chats yet\nCreate a channel or start a conversation",
//               textAlign: TextAlign.center,
//               style: TextStyle(color: Colors.grey[400], fontSize: 16),
//             ),
//           )
//               : ListView.builder(
//             itemCount: _filteredChannels.length,
//             itemBuilder: (context, index) {
//               final channel = _filteredChannels[index];
//               return _buildChatListItem(channel);
//             },
//           ),
//         ),
//       ],
//     );
//   }
//
//   Widget _buildChatListItem(ChatChannel channel) {
//     return ListTile(
//       leading: CircleAvatar(
//         backgroundColor: channel.type == ChatType.group ? Colors.blue : Colors.green,
//         child: Icon(
//           channel.type == ChatType.group ? Icons.group : Icons.person,
//           color: Colors.white,
//         ),
//       ),
//       title: Text(
//         channel.name,
//         style: TextStyle(
//           color: Colors.white,
//           fontWeight: channel.unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
//         ),
//       ),
//       subtitle: Text(
//         channel.lastMessage,
//         style: TextStyle(color: Colors.grey[400]),
//         maxLines: 1,
//         overflow: TextOverflow.ellipsis,
//       ),
//       trailing: Column(
//         mainAxisAlignment: MainAxisAlignment.center,
//         crossAxisAlignment: CrossAxisAlignment.end,
//         children: [
//           Text(
//             _formatTime(channel.lastMessageTime),
//             style: TextStyle(color: Colors.grey[400], fontSize: 12),
//           ),
//           if (channel.unreadCount > 0)
//             Container(
//               margin: EdgeInsets.only(top: 4),
//               padding: EdgeInsets.all(6),
//               decoration: BoxDecoration(
//                 color: Colors.blue,
//                 shape: BoxShape.circle,
//               ),
//               child: Text(
//                 channel.unreadCount.toString(),
//                 style: TextStyle(color: Colors.white, fontSize: 10),
//               ),
//             ),
//         ],
//       ),
//       onTap: () => _openChat(channel),
//     );
//   }
//
//   String _formatTime(DateTime time) {
//     final now = DateTime.now();
//     final diff = now.difference(time);
//
//     if (diff.inMinutes < 1) return "now";
//     if (diff.inMinutes < 60) return "${diff.inMinutes}m";
//     if (diff.inHours < 24) return "${diff.inHours}h";
//     return "${diff.inDays}d";
//   }
//
//   void _showCreateChannelDialog() {
//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         backgroundColor: Colors.grey[800],
//         title: Text("Create Channel", style: TextStyle(color: Colors.white)),
//         content: TextField(
//           controller: _channelController,
//           style: TextStyle(color: Colors.white),
//           decoration: InputDecoration(
//             hintText: "Channel name",
//             hintStyle: TextStyle(color: Colors.grey[400]),
//             border: OutlineInputBorder(),
//           ),
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context),
//             child: Text("Cancel", style: TextStyle(color: Colors.grey[400])),
//           ),
//           TextButton(
//             onPressed: () {
//               Navigator.pop(context);
//               _createOrJoinChannel();
//             },
//             child: Text("Create", style: TextStyle(color: Colors.blue)),
//           ),
//         ],
//       ),
//     );
//   }
//
//   void _showDirectMessageDialog() {
//     final userIdController = TextEditingController();
//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         backgroundColor: Colors.grey[800],
//         title: Text("Direct Message", style: TextStyle(color: Colors.white)),
//         content: TextField(
//           controller: userIdController,
//           style: TextStyle(color: Colors.white),
//           decoration: InputDecoration(
//             hintText: "Enter user ID",
//             hintStyle: TextStyle(color: Colors.grey[400]),
//             border: OutlineInputBorder(),
//           ),
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context),
//             child: Text("Cancel", style: TextStyle(color: Colors.grey[400])),
//           ),
//           TextButton(
//             onPressed: () {
//               final userId = userIdController.text.trim();
//               if (userId.isNotEmpty) {
//                 Navigator.pop(context);
//                 final dmChannel = ChatChannel(
//                   id: userId,
//                   name: userId,
//                   type: ChatType.direct,
//                   lastMessage: "Start a conversation",
//                   lastMessageTime: DateTime.now(),
//                   unreadCount: 0,
//                 );
//                 _openChat(dmChannel);
//               }
//             },
//             child: Text("Start Chat", style: TextStyle(color: Colors.blue)),
//           ),
//         ],
//       ),
//     );
//   }
//
//   @override
//   void dispose() {
//     _client?.logout();
//     _client?.destroy();
//     super.dispose();
//   }
// }
//
// // Chat Screen - Individual chat interface
// class ChatScreen extends StatefulWidget {
//   final ChatChannel channel;
//   final AgoraRtmClient client;
//   final String currentUserId;
//
//   const ChatScreen({
//     Key? key,
//     required this.channel,
//     required this.client,
//     required this.currentUserId,
//   }) : super(key: key);
//
//   @override
//   State<ChatScreen> createState() => _ChatScreenState();
// }
//
// class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
//   final _messageController = TextEditingController();
//   final _scrollController = ScrollController();
//   AgoraRtmChannel? _channel;
//   List<ChatMessage> _messages = [];
//   bool _isTyping = false;
//   List<String> _typingUsers = [];
//
//   late AnimationController _typingController;
//   late Animation<double> _typingAnimation;
//
//   @override
//   void initState() {
//     super.initState();
//     _initializeChannel();
//
//     _typingController = AnimationController(
//       duration: Duration(milliseconds: 600),
//       vsync: this,
//     )..repeat(reverse: true);
//
//     _typingAnimation = Tween<double>(
//       begin: 0.0,
//       end: 1.0,
//     ).animate(CurvedAnimation(
//       parent: _typingController,
//       curve: Curves.easeInOut,
//     ));
//   }
//
//   Future<void> _initializeChannel() async {
//     if (widget.channel.type == ChatType.group) {
//       try {
//         _channel = await widget.client.createChannel(widget.channel.id);
//
//         _channel?.onMemberJoined = (AgoraRtmMember member) {
//           print("Member joined: ${member.userId}");
//         };
//
//         _channel?.onMemberLeft = (AgoraRtmMember member) {
//           print("Member left: ${member.userId}");
//         };
//
//         _channel?.onMessageReceived = (AgoraRtmMessage message, AgoraRtmMember member) {
//           _handleChannelMessage(message, member);
//         };
//
//         await _channel?.join();
//       } catch (e) {
//         print("Failed to join channel: $e");
//       }
//     } else {
//       // For direct messages, listen to client messages
//       widget.client.onMessageReceived = (AgoraRtmMessage message, String peerId) {
//         if (peerId == widget.channel.id) {
//           _handleDirectMessage(message, peerId);
//         }
//       };
//     }
//
//     _loadMessages();
//   }
//
//   void _handleChannelMessage(AgoraRtmMessage message, AgoraRtmMember member) {
//     setState(() {
//       _messages.add(ChatMessage(
//         id: DateTime.now().millisecondsSinceEpoch.toString(),
//         text: message.text,
//         senderId: member.userId,
//         timestamp: DateTime.now(),
//         isFromCurrentUser: member.userId == widget.currentUserId,
//       ));
//     });
//     _scrollToBottom();
//   }
//
//   void _handleDirectMessage(AgoraRtmMessage message, String peerId) {
//     setState(() {
//       _messages.add(ChatMessage(
//         id: DateTime.now().millisecondsSinceEpoch.toString(),
//         text: message.text,
//         senderId: peerId,
//         timestamp: DateTime.now(),
//         isFromCurrentUser: false,
//       ));
//     });
//     _scrollToBottom();
//   }
//
//   void _loadMessages() {
//     // Load message history - in a real app, this would come from a database
//     setState(() {
//       _messages = [
//         ChatMessage(
//           id: "1",
//           text: "Hello! Welcome to ${widget.channel.name}",
//           senderId: "system",
//           timestamp: DateTime.now().subtract(Duration(minutes: 30)),
//           isFromCurrentUser: false,
//         ),
//       ];
//     });
//     _scrollToBottom();
//   }
//
//   Future<void> _sendMessage() async {
//     if (_messageController.text.trim().isEmpty) return;
//
//     final messageText = _messageController.text.trim();
//     final message = AgoraRtmMessage.fromText(messageText);
//
//     try {
//       if (widget.channel.type == ChatType.group) {
//         await _channel?.sendMessage(message);
//       } else {
//         await widget.client.sendMessageToPeer(widget.channel.id, message);
//       }
//
//       // Add message to local list
//       setState(() {
//         _messages.add(ChatMessage(
//           id: DateTime.now().millisecondsSinceEpoch.toString(),
//           text: messageText,
//           senderId: widget.currentUserId,
//           timestamp: DateTime.now(),
//           isFromCurrentUser: true,
//         ));
//       });
//
//       _messageController.clear();
//       _scrollToBottom();
//       HapticFeedback.lightImpact();
//     } catch (e) {
//       print("Failed to send message: $e");
//     }
//   }
//
//   void _scrollToBottom() {
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       if (_scrollController.hasClients) {
//         _scrollController.animateTo(
//           _scrollController.position.maxScrollExtent,
//           duration: Duration(milliseconds: 300),
//           curve: Curves.easeOut,
//         );
//       }
//     });
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.grey[900],
//       appBar: AppBar(
//         title: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text(
//               widget.channel.name,
//               style: TextStyle(color: Colors.white, fontSize: 18),
//             ),
//             Text(
//               widget.channel.type == ChatType.group ? "Group chat" : "Direct message",
//               style: TextStyle(color: Colors.grey[400], fontSize: 12),
//             ),
//           ],
//         ),
//         backgroundColor: Colors.transparent,
//         elevation: 0,
//         iconTheme: IconThemeData(color: Colors.white),
//         actions: [
//           IconButton(
//             icon: Icon(Icons.info_outline, color: Colors.white),
//             onPressed: () => _showChannelInfo(),
//           ),
//         ],
//       ),
//       body: Column(
//         children: [
//           // Messages list
//           Expanded(
//             child: ListView.builder(
//               controller: _scrollController,
//               padding: EdgeInsets.all(16),
//               itemCount: _messages.length,
//               itemBuilder: (context, index) {
//                 final message = _messages[index];
//                 final showTimestamp = index == 0 ||
//                     _messages[index - 1].timestamp.difference(message.timestamp).inMinutes.abs() > 5;
//
//                 return _buildMessageBubble(message, showTimestamp);
//               },
//             ),
//           ),
//
//           // Typing indicator
//           if (_typingUsers.isNotEmpty)
//             Container(
//               padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//               child: Row(
//                 children: [
//                   AnimatedBuilder(
//                     animation: _typingAnimation,
//                     builder: (context, child) {
//                       return Opacity(
//                         opacity: _typingAnimation.value,
//                         child: Text(
//                           "${_typingUsers.join(", ")} is typing...",
//                           style: TextStyle(color: Colors.grey[400], fontSize: 12),
//                         ),
//                       );
//                     },
//                   ),
//                 ],
//               ),
//             ),
//
//           // Message input
//           Container(
//             padding: EdgeInsets.all(16),
//             decoration: BoxDecoration(
//               color: Colors.grey[800],
//               border: Border(
//                 top: BorderSide(color: Colors.grey[700]!, width: 1),
//               ),
//             ),
//             child: Row(
//               children: [
//                 Expanded(
//                   child: TextField(
//                     controller: _messageController,
//                     style: TextStyle(color: Colors.white),
//                     decoration: InputDecoration(
//                       hintText: "Type a message...",
//                       hintStyle: TextStyle(color: Colors.grey[400]),
//                       border: OutlineInputBorder(
//                         borderRadius: BorderRadius.circular(25),
//                         borderSide: BorderSide.none,
//                       ),
//                       filled: true,
//                       fillColor: Colors.grey[700],
//                       contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
//                     ),
//                     onSubmitted: (_) => _sendMessage(),
//                   ),
//                 ),
//                 SizedBox(width: 8),
//                 GestureDetector(
//                   onTap: _sendMessage,
//                   child: Container(
//                     padding: EdgeInsets.all(12),
//                     decoration: BoxDecoration(
//                       color: Colors.blue,
//                       shape: BoxShape.circle,
//                     ),
//                     child: Icon(Icons.send, color: Colors.white, size: 20),
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildMessageBubble(ChatMessage message, bool showTimestamp) {
//     return Column(
//       children: [
//         if (showTimestamp)
//           Container(
//             margin: EdgeInsets.symmetric(vertical: 8),
//             child: Text(
//               _formatMessageTime(message.timestamp),
//               style: TextStyle(color: Colors.grey[400], fontSize: 12),
//             ),
//           ),
//         Container(
//           margin: EdgeInsets.only(bottom: 8),
//           child: Row(
//             mainAxisAlignment: message.isFromCurrentUser
//                 ? MainAxisAlignment.end
//                 : MainAxisAlignment.start,
//             children: [
//               if (!message.isFromCurrentUser)
//                 CircleAvatar(
//                   radius: 16,
//                   backgroundColor: Colors.grey[700],
//                   child: Text(
//                     message.senderId.isNotEmpty ? message.senderId[0].toUpperCase() : "?",
//                     style: TextStyle(color: Colors.white, fontSize: 12),
//                   ),
//                 ),
//               SizedBox(width: 8),
//               Flexible(
//                 child: Container(
//                   padding: EdgeInsets.all(12),
//                   decoration: BoxDecoration(
//                     color: message.isFromCurrentUser ? Colors.blue : Colors.grey[700],
//                     borderRadius: BorderRadius.circular(16),
//                   ),
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       if (!message.isFromCurrentUser && widget.channel.type == ChatType.group)
//                         Text(
//                           message.senderId,
//                           style: TextStyle(
//                             color: Colors.white70,
//                             fontSize: 10,
//                             fontWeight: FontWeight.bold,
//                           ),
//                         ),
//                       Text(
//                         message.text,
//                         style: TextStyle(color: Colors.white),
//                       ),
//                     ],
//                   ),
//                 ),
//               ),
//               if (message.isFromCurrentUser) SizedBox(width: 8),
//               if (message.isFromCurrentUser)
//                 CircleAvatar(
//                   radius: 16,
//                   backgroundColor: Colors.blue[700],
//                   child: Icon(Icons.person, color: Colors.white, size: 16),
//                 ),
//             ],
//           ),
//         ),
//       ],
//     );
//   }
//
//   String _formatMessageTime(DateTime time) {
//     final now = DateTime.now();
//     final today = DateTime(now.year, now.month, now.day);
//     final messageDate = DateTime(time.year, time.month, time.day);
//
//     if (messageDate == today) {
//       return "Today ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}";
//     } else if (messageDate == today.subtract(Duration(days: 1))) {
//       return "Yesterday ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}";
//     } else {
//       return "${time.day}/${time.month}/${time.year}";
//     }
//   }
//
//   void _showChannelInfo() {
//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         backgroundColor: Colors.grey[800],
//         title: Text("Channel Info", style: TextStyle(color: Colors.white)),
//         content: Column(
//           mainAxisSize: MainAxisSize.min,
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text("Name: ${widget.channel.name}", style: TextStyle(color: Colors.white)),
//             Text("Type: ${widget.channel.type == ChatType.group ? "Group" : "Direct"}", style: TextStyle(color: Colors.white)),
//             Text("ID: ${widget.channel.id}", style: TextStyle(color: Colors.grey[400])),
//             Text("Messages: ${_messages.length}", style: TextStyle(color: Colors.grey[400])),
//           ],
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context),
//             child: Text("Close", style: TextStyle(color: Colors.blue)),
//           ),
//         ],
//       ),
//     );
//   }
//
//   @override
//   void dispose() {
//     _typingController.dispose();
//     _channel?.leave();
//     super.dispose();
//   }
// }
//
// // Data Models
// class ChatChannel {
//   final String id;
//   final String name;
//   final ChatType type;
//   String lastMessage;
//   DateTime lastMessageTime;
//   int unreadCount;
//
//   ChatChannel({
//     required this.id,
//     required this.name,
//     required this.type,
//     required this.lastMessage,
//     required this.lastMessageTime,
//     required this.unreadCount,
//   });
// }
//
// class ChatMessage {
//   final String id;
//   final String text;
//   final String senderId;
//   final DateTime timestamp;
//   final bool isFromCurrentUser;
//
//   ChatMessage({
//     required this.id,
//     required this.text,
//     required this.senderId,
//     required this.timestamp,
//     required this.isFromCurrentUser,
//   });
// }
//
// enum ChatType { group, direct }
//
// // Usage Example
// void main() {
//   runApp(ChatApp());
// }